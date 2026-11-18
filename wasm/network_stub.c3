// WASM build has no sockets: inert multiplayer stubs.
module minecraft;

const int NET_PORT = 22120;
const int NET_MAX_PLAYERS = 8;

struct NetPeer
{
	bool      active;
	int       id;
	char[32]  name;
	int       nameLen;
	float     x, y;
	int       facing;
	float     health, hurt;
}

struct NetChatMsg
{
	char[32]  name;
	int       nameLen;
	char[160] text;
	int       textLen;
}

bool netClientOpen = false;
bool netServerActive = false;
bool netApplying = false;

fn void net_init() {}
fn bool net_is_active() { return false; }
fn bool net_is_connected() { return false; }
fn ZString net_status() { return ""; }
fn void net_set_status(ZString text) {}
fn void net_update(float dt) {}
fn bool net_client_connect(ZString host, int port, ZString name) { return false; }
fn void net_close_client() {}
fn void net_client_disconnect() {}
fn bool net_server_start(int port, int seed, ZString name) { return false; }
fn void net_server_stop() {}
fn int net_remote_count() { return 0; }
fn NetPeer* net_remote(int index) { return null; }
fn int net_chat_count() { return 0; }
fn NetChatMsg* net_chat(int index) { return null; }
fn void net_send_edit(int x, int y, bool bg, ItemId id) {}
fn void net_send_chat(ZString text) {}
