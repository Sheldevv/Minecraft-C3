// TerraBlock multiplayer: line-based TCP client plus a small built-in host.
// Keep every parse bounded; nothing from the network is ever trusted.
module minecraft;
import std::net;
import std::net::tcp;
import std::io;
import std::math;
import std::core::string;
import std::time;
import rl;

const net::PollEvent NET_POLL_READ = (net::PollEvent)net::PollSubscribe.ANY_READ;
const net::PollEvent NET_POLL_WRITE = (net::PollEvent)net::PollSubscribe.ANY_WRITE;

const int NET_PORT = 22120;
const int NET_MAX_PLAYERS = 8;
const int NET_LINE_MAX = 4096;
const int NET_BUF = 16384;
const int NET_MAX_NAME = 32;
const int NET_MAX_CHAT = 160;
const int NET_CHAT_HISTORY = 32;

struct NetPeer
{
	TcpSocket socket;
	bool      active;
	int       id;
	char[NET_MAX_NAME] name;
	int       nameLen;
	float     x, y;
	int       facing;
	float     health, hurt;
	char[NET_BUF] inBuf;
	int       inLen;
	char[NET_BUF] outBuf;
	int       outLen;
}

struct NetChatMsg
{
	char[NET_MAX_NAME] name;
	int   nameLen;
	char[NET_MAX_CHAT] text;
	int   textLen;
}

// Client state.
TcpSocket netClientSock;
bool  netClientOpen = false;
bool  netConnected = false;
int   netMyId = 0;
char[NET_MAX_NAME] netMyName;
int   netMyNameLen = 0;
char[NET_BUF] netInBuf;
int   netInLen = 0;
char[NET_BUF] netOutBuf;
int   netOutLen = 0;
char[256] netStatusBuf;
int   netStatusLen = 0;
float netPosTimer = 0;

// Remote players (client view).
NetPeer[NET_MAX_PLAYERS] netPlayers;

// Chat ring buffer.
NetChatMsg[NET_CHAT_HISTORY] netChats;
int netChatHead = 0;
int netChatCount = 0;

// Host/server state.
TcpServerSocket netServerSock;
bool netServerActive = false;
NetPeer[NET_MAX_PLAYERS] netPeers;
int  netNextPeerId = 1;
int  netHostSeed = 1;
char[NET_MAX_NAME] netHostName;
int  netHostNameLen = 0;

fn void net_set_status(ZString text)
{
	copy_cstr(&netStatusBuf, netStatusBuf.len, text ? text : "");
	netStatusLen = zstr_len((ZString)&netStatusBuf[0]);
}

fn ZString net_status()
{
	if (netStatusLen == 0) return "";
	return (ZString)&netStatusBuf[0];
}

fn bool net_is_active()
{
	return netClientOpen || netServerActive;
}

fn bool net_is_connected()
{
	return netConnected || netServerActive;
}

fn int net_remote_count()
{
	int n = 0;
	for (int i = 0; i < NET_MAX_PLAYERS; i++) if (netPlayers[i].active) n++;
	return n;
}

fn NetPeer* net_remote(int index)
{
	int n = 0;
	for (int i = 0; i < NET_MAX_PLAYERS; i++)
	{
		if (!netPlayers[i].active) continue;
		if (n == index) return &netPlayers[i];
		n++;
	}
	return null;
}

fn int net_chat_count()
{
	return netChatCount;
}

fn NetChatMsg* net_chat(int index)
{
	if (index < 0 || index >= netChatCount) return null;
	int pos = (netChatHead - netChatCount + index + NET_CHAT_HISTORY * 2) % NET_CHAT_HISTORY;
	return &netChats[pos];
}

fn void net_chat_add(ZString name, int nameLen, ZString text, int textLen)
{
	NetChatMsg* m = &netChats[netChatHead];
	m.nameLen = mini(nameLen, NET_MAX_NAME - 1);
	for (int i = 0; i < m.nameLen; i++) m.name[i] = name[i];
	m.name[m.nameLen] = 0;
	m.textLen = mini(textLen, NET_MAX_CHAT - 1);
	for (int i = 0; i < m.textLen; i++) m.text[i] = text[i];
	m.text[m.textLen] = 0;
	netChatHead = (netChatHead + 1) % NET_CHAT_HISTORY;
	if (netChatCount < NET_CHAT_HISTORY) netChatCount++;
}

fn void net_chat_clear()
{
	netChatHead = 0;
	netChatCount = 0;
}

fn void net_players_clear()
{
	for (int i = 0; i < NET_MAX_PLAYERS; i++)
	{
		netPlayers[i] = {};
		netPeers[i] = {};
	}
}

fn int net_parse_int(ZString s, int lo, int hi)
{
	if (!s || s[0] == 0) return 0;
	int i = 0;
	bool neg = false;
	if (s[0] == '-')
	{
		neg = true;
		i = 1;
	}
	else if (s[0] == '+')
	{
		i = 1;
	}
	long v = 0;
	for (; s[i] != 0; i++)
	{
		if (s[i] < '0' || s[i] > '9') return 0;
		v = v * 10 + (long)(s[i] - '0');
		if (v > 2147483647L) return 0;
	}
	if (neg) v = -v;
	if (v < lo || v > hi) return 0;
	return (int)v;
}

fn float net_parse_float(ZString s, float lo, float hi)
{
	if (!s || s[0] == 0) return 0;
	double v = 0;
	double frac = 0;
	bool dot = false;
	bool anyDigit = false;
	bool neg = false;
	int i = 0;
	if (s[0] == '-')
	{
		neg = true;
		i = 1;
	}
	else if (s[0] == '+')
	{
		i = 1;
	}
	for (; s[i] != 0; i++)
	{
		char c = s[i];
		if (c == '.')
		{
			if (dot) return 0;
			dot = true;
			continue;
		}
		if (c < '0' || c > '9') return 0;
		anyDigit = true;
		if (dot)
		{
			frac = frac * 10 + (double)(c - '0');
			v = v * 10;
		}
		else
		{
			v = v * 10 + (double)(c - '0');
		}
	}
	if (!anyDigit || v > 1.0e9) return 0;
	int digits = 0;
	for (int j = i - 1; j >= 0; j--)
	{
		if (s[j] == '.') break;
		digits++;
	}
	while (digits > 0)
	{
		frac /= 10;
		digits--;
	}
	float out = (float)(neg ? -(v + frac) : (v + frac));
	return out < lo || out > hi ? 0 : out;
}

fn int net_split(char* line, ZString[16]* fields)
{
	int count = 0;
	char* p = line;
	while (*p != 0 && count < 16)
	{
		while (*p == ' ' || *p == '\t' || *p == '\r' || *p == '\n') p++;
		if (*p == 0) break;
		(*fields)[count] = (ZString)p;
		count++;
		while (*p != 0 && *p != ' ' && *p != '\t' && *p != '\r' && *p != '\n') p++;
		if (*p != 0)
		{
			*p = 0;
			p++;
		}
	}
	return count;
}

fn void net_sanitize_name(char* dst, int cap, ZString src)
{
	dst[0] = 0;
	if (!src) return;
	int n = 0;
	for (int i = 0; src[i] != 0 && n < cap - 1; i++)
	{
		char c = src[i];
		if (c >= 'A' && c <= 'Z') c = (char)(c + 32);
		if ((c >= 'a' && c <= 'z') || (c >= '0' && c <= '9')
		    || c == ' ' || c == '_' || c == '-')
		{
			dst[n++] = c;
		}
	}
	dst[n] = 0;
}

fn void net_join_fields(ZString[16]* f, int from, int n, char* dst, int cap)
{
	dst[0] = 0;
	int len = 0;
	for (int i = from; i < n && len < cap - 1; i++)
	{
		if (i > from && len < cap - 1) dst[len++] = ' ';
		ZString s = (*f)[i];
		for (int j = 0; s[j] != 0 && len < cap - 1; j++) dst[len++] = s[j];
	}
	dst[len] = 0;
}

fn void net_sanitize_chat(char* dst, int cap, ZString src)
{
	dst[0] = 0;
	if (!src) return;
	int n = 0;
	for (int i = 0; src[i] != 0 && n < cap - 1; i++)
	{
		char c = src[i];
		dst[n++] = c < 32 || c == 127 ? ' ' : c;
	}
	dst[n] = 0;
}

fn void net_queue_line(char* buf, int* len, ZString line, int lineLen)
{
	if (lineLen <= 0 || lineLen >= NET_LINE_MAX) return;
	if (*len + lineLen + 1 > NET_BUF)
	{
		if (buf == &netOutBuf[0]) net_set_status("Network send buffer full");
		return;
	}
	for (int i = 0; i < lineLen; i++) buf[*len + i] = line[i];
	buf[*len + lineLen] = '\n';
	*len += lineLen + 1;
}

macro void net_queue(ZString fmt, args...)
{
	char[1024] tmp;
	ZString line = zfmt(&tmp, fmt.str_view(), ...args);
	net_queue_line(&netOutBuf[0], &netOutLen, line, zstr_len(line));
}

macro void net_peer_queue(NetPeer* peer, ZString fmt, args...)
{
	char[1024] tmp;
	ZString line = zfmt(&tmp, fmt.str_view(), ...args);
	net_queue_line(&peer.outBuf[0], &peer.outLen, line, zstr_len(line));
}

fn bool net_set_nonblocking(TcpSocket* sock)
{
	(void)sock.sock.set_non_blocking(true);
	return true;
}

fn void net_close_client()
{
	if (netClientOpen)
	{
		(void)netClientSock.close();
	}
	netClientOpen = false;
	netConnected = false;
	netMyId = 0;
	netInLen = 0;
	netOutLen = 0;
	netPosTimer = 0;
	net_players_clear();
	net_chat_clear();
	if (g.gameState == GS_PLAYING)
	{
		g.gameState = GS_MENU;
		g.menuSubstate = 0;
		g.paused = false;
	}
}

fn bool net_client_connect(ZString host, int port, ZString name)
{
	if (netClientOpen || netServerActive)
	{
		net_set_status("Already connected or hosting");
		return false;
	}
	if (!host || zstr_len(host) == 0 || zstr_len(host) > 253)
	{
		net_set_status("Enter a valid server address");
		return false;
	}
	if (port < 1 || port > 65535)
	{
		net_set_status("Port must be 1-65535");
		return false;
	}
	char[256] hostBuf;
	copy_cstr(&hostBuf, hostBuf.len, host);

	net_players_clear();
	net_chat_clear();
	net_set_status("Connecting...");

	TcpSocket? opened = tcp::connect((String)&hostBuf, port, time::sec(2));
	if (catch err = opened)
	{
		net_set_status("Could not connect to server");
		return false;
	}
	netClientSock = opened;
	net_set_nonblocking(&netClientSock);
	netClientOpen = true;
	netConnected = false;
	netInLen = 0;
	netOutLen = 0;
	net_sanitize_name(&netMyName[0], NET_MAX_NAME, name);
	netMyNameLen = zstr_len((ZString)&netMyName[0]);
	if (netMyNameLen == 0)
	{
		copy_cstr(&netMyName[0], NET_MAX_NAME, "Player");
		netMyNameLen = 6;
	}
	net_queue("JOIN %s", (ZString)&netMyName[0]);
	return true;
}

fn void net_client_disconnect()
{
	net_close_client();
	net_set_status("");
	g.gameState = GS_MENU;
	g.menuSubstate = 0;
	g.paused = false;
	show_msg("Disconnected from server", 2.0f);
}

fn bool net_server_start(int port, int seed, ZString name)
{
	if (netClientOpen || netServerActive)
	{
		net_set_status("Already connected or hosting");
		return false;
	}
	if (port < 1 || port > 65535)
	{
		net_set_status("Port must be 1-65535");
		return false;
	}
	TcpServerSocket? opened = tcp::listen("0.0.0.0", port, NET_MAX_PLAYERS,
	                                       SocketOption.REUSEADDR);
	if (catch err = opened)
	{
		net_set_status("Could not host on that port");
		return false;
	}
	netServerSock = opened;
	(void)netServerSock.sock.set_non_blocking(true);
	netServerActive = true;
	netNextPeerId = 1;
	netHostSeed = seed > 0 ? seed : world_seed_random();
	net_sanitize_name(&netHostName[0], NET_MAX_NAME, name);
	netHostNameLen = zstr_len((ZString)&netHostName[0]);
	if (netHostNameLen == 0)
	{
		copy_cstr(&netHostName[0], NET_MAX_NAME, "Host");
		netHostNameLen = 4;
	}
	net_players_clear();
	net_chat_clear();
	net_set_status("");
	g.currentSeed = netHostSeed;
	g.creativeMode = false;
	g.worldMode = 0;
	g.hostilesEnabled = true;
	reset_world(netHostSeed);
	g.gameState = GS_PLAYING;
	g.paused = false;
	show_msg("Server listening on port 22120", 3.0f);
	return true;
}

fn void net_server_stop()
{
	if (netServerActive) (void)netServerSock.close();
	netServerActive = false;
	for (int i = 0; i < NET_MAX_PLAYERS; i++)
	{
		if (netPeers[i].active) (void)netPeers[i].socket.close();
		netPeers[i] = {};
	}
	net_chat_clear();
	net_set_status("");
}

fn void net_peer_close(int index)
{
	NetPeer* p = &netPeers[index];
	if (!p.active) return;
	int id = p.id;
	(void)p.socket.close();
	*p = {};
	for (int k = 0; k < NET_MAX_PLAYERS; k++)
	{
		if (netPlayers[k].active && netPlayers[k].id == id) netPlayers[k] = {};
	}
	char[64] msg;
	zfmt(&msg, "LEFT %d", id);
	for (int j = 0; j < NET_MAX_PLAYERS; j++)
	{
		if (netPeers[j].active) net_peer_queue(&netPeers[j], (ZString)&msg[0]);
	}
}

// Apply an EDIT line coming from the network. Returns false if malformed.
fn bool net_apply_edit(ZString sx, ZString sy, ZString sbg, ZString stype)
{
	int x = net_parse_int(sx, -10000000, 10000000);
	int y = net_parse_int(sy, -10000000, 10000000);
	int bgv = net_parse_int(sbg, 0, 1);
	if (x == 0 && sx[0] != '0') return false;
	if (y == 0 && sy[0] != '0') return false;
	if (x % GRID != 0 || y % GRID != 0 || bgv == 0 && sbg[0] != '0') return false;
	if (bgv != 0 && sbg[0] != '1') return false;
	ItemId id = ITEM_NONE;
	if (!(stype[0] == '-' && stype[1] == 0))
	{
		id = net_parse_int(stype, 1, ITEM_COUNT - 1);
		if (id == 0) return false;
	}
	netApplying = true;
	if (id == ITEM_NONE)
	{
		(void)destroy_block(x, y, bgv != 0);
	}
	else
	{
		// A remote edit may be applied to an unloaded chunk; stream it in first.
		(void)ensure_chunk_loaded(chunk_index(x));
		ItemId existing = bgv != 0 ? bg_at(x, y) : block_at(x, y);
		if (existing == 0)
		{
			(void)place_block(x, y, id, bgv != 0);
		}
		else
		{
			remember_edit(x, y, bgv != 0, id);
		}
	}
	netApplying = false;
	return true;
}

fn void net_handle_client_line(char* line)
{
	if (zstr_len((ZString)line) > NET_LINE_MAX)
	{
		net_set_status("Server sent an oversized line");
		net_close_client();
		return;
	}
	ZString[16] f;
	int n = net_split(line, &f);
	if (n == 0) return;

	if (zstreq(f[0], "WELCOME") && n >= 5)
	{
		int id = net_parse_int(f[1], 1, 1000000);
		int seed = net_parse_int(f[2], 1, 2147483647);
		if (id == 0 || seed == 0)
		{
			net_set_status("Invalid server welcome");
			net_close_client();
			return;
		}
		netMyId = id;
		g.currentSeed = seed;
		g.creativeMode = zstreq(f[3], "creative");
		g.worldMode = g.creativeMode ? 1 : 0;
		g.hostilesEnabled = zstreq(f[4], "1");
		net_players_clear();
		net_chat_clear();
		reset_world(seed);
		net_set_status("Loading world...");
	}
	else if (zstreq(f[0], "READY"))
	{
		netConnected = true;
		net_set_status("");
		g.gameState = GS_PLAYING;
		g.paused = false;
		show_msg("Joined multiplayer world", 2.0f);
	}
	else if (zstreq(f[0], "PLAYER") && n >= 6)
	{
		int id = net_parse_int(f[1], 0, 1000000);
		float x = net_parse_float(f[3], -10000000, 10000000);
		float y = net_parse_float(f[4], -10000000, 10000000);
		int facing = net_parse_int(f[5], -1, 1);
		if (id == netMyId || x == 0 && f[3][0] != '0'
		    || y == 0 && f[4][0] != '0' || facing == 0 && f[5][0] != '0') return;
		int slot = -1;
		for (int i = 0; i < NET_MAX_PLAYERS; i++)
		{
			if (netPlayers[i].active && netPlayers[i].id == id) { slot = i; break; }
			if (!netPlayers[i].active && slot < 0) slot = i;
		}
		if (slot < 0) return;
		NetPeer* p = &netPlayers[slot];
		p.active = true;
		p.id = id;
		net_sanitize_name(&p.name[0], NET_MAX_NAME, f[2]);
		p.nameLen = zstr_len((ZString)&p.name[0]);
		p.x = x; p.y = y; p.facing = facing == 0 ? 1 : facing;
	}
	else if (zstreq(f[0], "POS") && n >= 5)
	{
		int id = net_parse_int(f[1], 0, 1000000);
		float x = net_parse_float(f[2], -10000000, 10000000);
		float y = net_parse_float(f[3], -10000000, 10000000);
		int facing = net_parse_int(f[4], -1, 1);
		if (id == netMyId || facing == 0 && f[4][0] != '0') return;
		for (int i = 0; i < NET_MAX_PLAYERS; i++)
		{
			NetPeer* p = &netPlayers[i];
			if (!p.active || p.id != id) continue;
			p.x = x; p.y = y;
			if (facing != 0) p.facing = facing;
		}
	}
	else if (zstreq(f[0], "LEFT") && n >= 2)
	{
		int id = net_parse_int(f[1], 0, 1000000);
		for (int i = 0; i < NET_MAX_PLAYERS; i++)
		{
			if (netPlayers[i].active && netPlayers[i].id == id) netPlayers[i] = {};
		}
	}
	else if (zstreq(f[0], "PSTATE") && n >= 4)
	{
		int id = net_parse_int(f[1], 1, 1000000);
		int hp = net_parse_int(f[2], 0, 100);
		if (id == netMyId && hp > 0) g.player.health = (float)hp;
	}
	else if (zstreq(f[0], "EDIT") && n >= 5)
	{
		(void)net_apply_edit(f[1], f[2], f[3], f[4]);
	}
	else if ((zstreq(f[0], "CHAT") || zstreq(f[0], "CHAT_HISTORY")) && n >= 3)
	{
		char[NET_MAX_NAME] name;
		char[NET_MAX_CHAT] raw;
		char[NET_MAX_CHAT] text;
		net_sanitize_name(&name[0], NET_MAX_NAME, f[1]);
		net_join_fields(&f, 2, n, &raw[0], NET_MAX_CHAT);
		net_sanitize_chat(&text[0], NET_MAX_CHAT, (ZString)&raw[0]);
		net_chat_add((ZString)&name[0], zstr_len((ZString)&name[0]),
		             (ZString)&text[0], zstr_len((ZString)&text[0]));
	}
	else if (zstreq(f[0], "ERROR"))
	{
		char[192] msg;
		ZString detail = n >= 2 ? f[1] : "rejected";
		zfmt(&msg, "Server error: %s", detail);
		net_set_status((ZString)&msg[0]);
		net_close_client();
	}
}

fn void net_handle_server_line(int index, char* line)
{
	if (!netPeers[index].active) return;
	if (zstr_len((ZString)line) > NET_LINE_MAX)
	{
		net_peer_close(index);
		return;
	}
	ZString[16] f;
	int n = net_split(line, &f);
	if (n == 0) return;
	NetPeer* p = &netPeers[index];

	if (zstreq(f[0], "JOIN") && n >= 2 && p.nameLen == 0)
	{
		net_sanitize_name(&p.name[0], NET_MAX_NAME, f[1]);
		p.nameLen = zstr_len((ZString)&p.name[0]);
		if (p.nameLen == 0)
		{
			copy_cstr(&p.name[0], NET_MAX_NAME, "Player");
			p.nameLen = 6;
		}
		// Send current world + peers to the newcomer.
		net_peer_queue(p, "WELCOME %d %d %s %d", p.id, netHostSeed,
		               g.creativeMode ? "creative" : "survival",
		               g.hostilesEnabled ? 1 : 0);
		net_peer_queue(p, "PLAYER 0 %s %d %d %d", (ZString)&netHostName[0],
		               (int)g.player.x, (int)g.player.y, g.player.facing);
		for (int j = 0; j < NET_MAX_PLAYERS; j++)
		{
			NetPeer* other = &netPeers[j];
			if (!other.active || other == p || other.nameLen == 0) continue;
			net_peer_queue(p, "PLAYER %d %s %d %d %d", other.id,
			               (ZString)&other.name[0],
			               (int)other.x, (int)other.y, other.facing);
		}
		for (int c = 0; c < netChatCount; c++)
		{
			NetChatMsg* m = net_chat(c);
			if (!m) continue;
			net_peer_queue(p, "CHAT_HISTORY %s %s", (ZString)&m.name[0],
			               (ZString)&m.text[0]);
		}
		net_peer_queue(p, "READY");
		net_peer_queue(p, "CHAT Server %s joined", (ZString)&p.name[0]);
		char[128] msg;
		zfmt(&msg, "CHAT Server %s joined", (ZString)&p.name[0]);
		for (int j = 0; j < NET_MAX_PLAYERS; j++)
		{
			if (j != index && netPeers[j].active)
			{
				net_queue_line(&netPeers[j].outBuf[0], &netPeers[j].outLen,
				               (ZString)&msg[0], zstr_len((ZString)&msg[0]));
			}
		}
	}
	else if (zstreq(f[0], "POS") && n >= 4)
	{
		float x = net_parse_float(f[1], -10000000, 10000000);
		float y = net_parse_float(f[2], -10000000, 10000000);
		int facing = net_parse_int(f[3], -1, 1);
		if (facing == 0 && f[3][0] != '0') return;
		p.x = x; p.y = y;
		if (facing != 0) p.facing = facing;
		// Track remote players for the host's own view.
		int slot = -1;
		for (int k = 0; k < NET_MAX_PLAYERS; k++)
		{
			if (netPlayers[k].active && netPlayers[k].id == p.id) { slot = k; break; }
			if (!netPlayers[k].active && slot < 0) slot = k;
		}
		if (slot >= 0)
		{
			NetPeer* rp = &netPlayers[slot];
			rp.active = true;
			rp.id = p.id;
			rp.nameLen = p.nameLen;
			for (int k = 0; k < rp.nameLen; k++) rp.name[k] = p.name[k];
			rp.name[rp.nameLen] = 0;
			rp.x = p.x; rp.y = p.y; rp.facing = p.facing;
		}
		char[128] msg;
		zfmt(&msg, "POS %d %d %d %d", p.id, (int)p.x, (int)p.y, p.facing);
		for (int j = 0; j < NET_MAX_PLAYERS; j++)
		{
			if (j != index && netPeers[j].active)
			{
				net_queue_line(&netPeers[j].outBuf[0], &netPeers[j].outLen,
				               (ZString)&msg[0], zstr_len((ZString)&msg[0]));
			}
		}
	}
	else if (zstreq(f[0], "EDIT") && n >= 5)
	{
		if (!net_apply_edit(f[1], f[2], f[3], f[4])) return;
		char[128] msg;
		zfmt(&msg, "EDIT %s %s %s %s", f[1], f[2], f[3], f[4]);
		for (int j = 0; j < NET_MAX_PLAYERS; j++)
		{
			if (j != index && netPeers[j].active)
			{
				net_queue_line(&netPeers[j].outBuf[0], &netPeers[j].outLen,
				               (ZString)&msg[0], zstr_len((ZString)&msg[0]));
			}
		}
	}
	else if (zstreq(f[0], "CHAT") && n >= 2)
	{
		char[NET_MAX_CHAT] raw;
		char[NET_MAX_CHAT] text;
		net_join_fields(&f, 1, n, &raw[0], NET_MAX_CHAT);
		net_sanitize_chat(&text[0], NET_MAX_CHAT, (ZString)&raw[0]);
		if (text[0] == 0) return;
		net_chat_add((ZString)&p.name[0], p.nameLen,
		             (ZString)&text[0], zstr_len((ZString)&text[0]));
		char[256] msg;
		zfmt(&msg, "CHAT %s %s", (ZString)&p.name[0], (ZString)&text[0]);
		for (int j = 0; j < NET_MAX_PLAYERS; j++)
		{
			if (netPeers[j].active)
			{
				net_queue_line(&netPeers[j].outBuf[0], &netPeers[j].outLen,
				               (ZString)&msg[0], zstr_len((ZString)&msg[0]));
			}
		}
	}
}

fn void net_read_lines(char* buf, int* len, bool fromClient)
{
	int start = 0;
	for (int i = 0; i < *len; i++)
	{
		if (buf[i] != '\n') continue;
		buf[i] = 0;
		if (i - start < NET_LINE_MAX)
		{
			if (fromClient)
			{
				net_handle_client_line(&buf[start]);
			}
		}
		i = start - 1;
		start = i + 2;
		// The handler may have closed the connection.
		if (fromClient && !netClientOpen) return;
	}
	if (start < *len)
	{
		int remain = *len - start;
		for (int i = 0; i < remain; i++) buf[i] = buf[start + i];
		*len = remain;
	}
	else
	{
		*len = 0;
	}
}

fn void net_read_peer_lines(int index)
{
	NetPeer* p = &netPeers[index];
	char* buf = &p.inBuf[0];
	int start = 0;
	int len = p.inLen;
	for (int i = 0; i < len; i++)
	{
		if (buf[i] != '\n') continue;
		buf[i] = 0;
		if (i - start < NET_LINE_MAX) net_handle_server_line(index, &buf[start]);
		start = i + 1;
		if (!netPeers[index].active) return;
	}
	int remain = len - start;
	for (int i = 0; i < remain; i++) buf[i] = buf[start + i];
	p.inLen = remain;
}

fn void net_flush_socket(TcpSocket* sock, char* buf, int* len)
{
	if (*len <= 0) return;
	if (try n = sock.write(buf[0:*len]))
	{
		if (n > 0)
		{
			*len -= (int)n;
			for (int i = 0; i < *len; i++) buf[i] = buf[n + i];
			return;
		}
	}
}

fn void net_update_client(float dt)
{
	if (!netClientOpen) return;

	net::Poll[1] polls;
	polls[0] = { netClientSock.sock, net::PollSubscribe.ANY_READ, (net::PollEvent)0 };
	if (netOutLen > 0) polls[0].events |= net::PollSubscribe.ANY_WRITE;
	if (catch err = net::poll_ms(polls[0:1], 0)) return;
	if (netInLen >= NET_BUF - 1)
	{
		net_set_status("Server sent an oversized message");
		net_close_client();
		return;
	}
	if ((polls[0].revents & NET_POLL_READ) != (net::PollEvent)0 && netInLen < NET_BUF)
	{
		char[2048] tmp;
		if (try n = netClientSock.read(tmp[0:min((int)tmp.len, NET_BUF - netInLen)]))
		{
			if (n == 0)
			{
				net_set_status("Connection closed");
				net_close_client();
				return;
			}
			for (int i = 0; i < (int)n; i++) netInBuf[netInLen + i] = tmp[i];
			netInLen += (int)n;
			net_read_lines(&netInBuf[0], &netInLen, true);
		}
		else
		{
			net_set_status("Connection lost");
			net_close_client();
			return;
		}
	}
	if ((polls[0].revents & NET_POLL_WRITE) != (net::PollEvent)0)
	{
		net_flush_socket(&netClientSock, &netOutBuf[0], &netOutLen);
	}

	if (netConnected)
	{
		netPosTimer -= dt;
		if (netPosTimer <= 0)
		{
			net_queue("POS %d %d %d", (int)g.player.x, (int)g.player.y, g.player.facing);
			netPosTimer = 0.05f;
		}
	}
}

fn void net_update_server(float dt)
{
	if (!netServerActive) return;

	// Accept pending connections.
	for (int guard = 0; guard < 4; guard++)
	{
		TcpSocket? accepted = tcp::accept(&netServerSock);
		if (catch e = accepted) break;
		int slot = -1;
		for (int i = 0; i < NET_MAX_PLAYERS; i++)
		{
			if (!netPeers[i].active) { slot = i; break; }
		}
		if (slot < 0)
		{
			(void)accepted.close();
			continue;
		}
		NetPeer* p = &netPeers[slot];
		*p = {};
		p.socket = accepted;
		p.active = true;
		p.id = netNextPeerId++;
		if (netNextPeerId > 1000000) netNextPeerId = 1;
		p.x = g.player.x;
		p.y = g.player.y;
		p.facing = 1;
		net_set_nonblocking(&p.socket);
	}

	net::Poll[NET_MAX_PLAYERS] polls;
	int count = 0;
	for (int i = 0; i < NET_MAX_PLAYERS; i++)
	{
		if (!netPeers[i].active) continue;
		polls[count] = { netPeers[i].socket.sock, net::PollSubscribe.ANY_READ, (net::PollEvent)0 };
		if (netPeers[i].outLen > 0) polls[count].events |= net::PollSubscribe.ANY_WRITE;
		count++;
	}
	if (count == 0) return;
	if (catch err = net::poll_ms(polls[0:count], 0)) return;
	int pi = 0;
	for (int i = 0; i < NET_MAX_PLAYERS; i++)
	{
		if (!netPeers[i].active) continue;
		NetPeer* p = &netPeers[i];
		if (p.inLen >= NET_BUF - 1)
		{
			net_peer_close(i);
			pi++;
			continue;
		}
		if ((polls[pi].revents & NET_POLL_READ) != (net::PollEvent)0 && p.inLen < NET_BUF)
		{
			char[2048] tmp;
			int room = min((int)tmp.len, NET_BUF - p.inLen);
			if (try n = p.socket.read(tmp[0:room]))
			{
				if (n == 0)
				{
					net_peer_close(i);
					pi++;
					continue;
				}
				for (int k = 0; k < (int)n; k++) p.inBuf[p.inLen + k] = tmp[k];
				p.inLen += (int)n;
				net_read_peer_lines(i);
			}
			else
			{
				net_peer_close(i);
				pi++;
				continue;
			}
		}
		if (netPeers[i].active && (polls[pi].revents & NET_POLL_WRITE) != (net::PollEvent)0)
		{
			net_flush_socket(&p.socket, &p.outBuf[0], &p.outLen);
		}
		pi++;
	}

	// Broadcast the host player's position.
	netPosTimer -= dt;
	if (netPosTimer <= 0)
	{
		char[128] msg;
		zfmt(&msg, "POS 0 %d %d %d", (int)g.player.x, (int)g.player.y, g.player.facing);
		for (int i = 0; i < NET_MAX_PLAYERS; i++)
		{
			if (netPeers[i].active)
			{
				net_queue_line(&netPeers[i].outBuf[0], &netPeers[i].outLen,
				               (ZString)&msg[0], zstr_len((ZString)&msg[0]));
			}
		}
		netPosTimer = 0.05f;
	}
}

fn void net_update(float dt)
{
	net_update_client(dt);
	net_update_server(dt);
}

// ---------------------------------------------------------------------------
// Outgoing events, called from the rest of the game.
// ---------------------------------------------------------------------------
bool netApplying = false;

fn void net_send_edit(int x, int y, bool bg, ItemId id)
{
	if (!net_is_connected() || netApplying) return;
	net_queue("EDIT %d %d %d %d", x, y, bg ? 1 : 0, id);
	if (netServerActive)
	{
		char[128] msg;
		zfmt(&msg, "EDIT %d %d %d %d", x, y, bg ? 1 : 0, id);
		for (int i = 0; i < NET_MAX_PLAYERS; i++)
		{
			if (netPeers[i].active)
			{
				net_queue_line(&netPeers[i].outBuf[0], &netPeers[i].outLen,
				               (ZString)&msg[0], zstr_len((ZString)&msg[0]));
			}
		}
	}
}

fn void net_send_chat(ZString text)
{
	char[NET_MAX_CHAT] msg;
	net_sanitize_chat(&msg[0], NET_MAX_CHAT, text);
	int len = zstr_len((ZString)&msg[0]);
	if (len == 0) return;
	if (netClientOpen)
	{
		net_queue("CHAT %s", (ZString)&msg[0]);
	}
	else if (netServerActive)
	{
		net_chat_add((ZString)&netHostName[0], netHostNameLen,
		             (ZString)&msg[0], len);
		char[256] line;
		zfmt(&line, "CHAT %s %s", (ZString)&netHostName[0], (ZString)&msg[0]);
		for (int i = 0; i < NET_MAX_PLAYERS; i++)
		{
			if (netPeers[i].active)
			{
				net_queue_line(&netPeers[i].outBuf[0], &netPeers[i].outLen,
				               (ZString)&line[0], zstr_len((ZString)&line[0]));
			}
		}
	}
}

fn void net_init()
{
	net_players_clear();
	net_chat_clear();
	net_set_status("");
}
