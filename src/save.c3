// Binary world saves and resource-pack / mod discovery.
module minecraft;
import rl;
import std::collections::list;
import std::collections::map;
import std::core::string;
import std::core::mem;
import std::io, std::io::file, std::io::path;

const int SAVE_VERSION = 1;
const int SAVE_MAX_EDITS = 4000000;
const int SAVE_MAX_CELLS = 200000;
const int SAVE_MAX_ENTITIES = 200000;

// ---------------------------------------------------------------------------
// Binary writer / reader
// ---------------------------------------------------------------------------
struct SaveWriter
{
	File* file;
	bool  ok;
}

fn void sw_raw(SaveWriter* w, void* data, usz n)
{
	if (!w.ok) return;
	char* p = (char*)data;
	if (try written = w.file.write(p[0:n]))
	{
		if (written != (sz)n) w.ok = false;
	}
	else
	{
		w.ok = false;
	}
}

fn void sw_int(SaveWriter* w, int v) { sw_raw(w, &v, 4); }

fn void sw_uint(SaveWriter* w, uint v) { sw_raw(w, &v, 4); }

fn void sw_long(SaveWriter* w, long v) { sw_raw(w, &v, 8); }

fn void sw_float(SaveWriter* w, float v) { sw_raw(w, &v, 4); }

fn void sw_bool(SaveWriter* w, bool v)
{
	char b = v ? 1 : 0;
	sw_raw(w, &b, 1);
}

fn void sw_str(SaveWriter* w, char* data, int len)
{
	if (len < 0) len = 0;
	sw_int(w, len);
	if (len > 0) sw_raw(w, data, (usz)len);
}

struct SaveReader
{
	char* data;
	usz   len;
	usz   pos;
	bool  ok;
}

fn void sr_raw(SaveReader* r, void* out, usz n)
{
	if (!r.ok || r.pos + n > r.len)
	{
		r.ok = false;
		return;
	}
	mem::copy(out, &r.data[r.pos], (sz)n);
	r.pos += n;
}

fn int sr_int(SaveReader* r)
{
	int v;
	sr_raw(r, &v, 4);
	return v;
}

fn uint sr_uint(SaveReader* r)
{
	uint v;
	sr_raw(r, &v, 4);
	return v;
}

fn long sr_long(SaveReader* r)
{
	long v;
	sr_raw(r, &v, 8);
	return v;
}

fn float sr_float(SaveReader* r)
{
	float v;
	sr_raw(r, &v, 4);
	return v;
}

fn bool sr_bool(SaveReader* r)
{
	char b;
	sr_raw(r, &b, 1);
	return b != 0;
}

fn void sr_str(SaveReader* r, char* dst, usz cap, int* outLen)
{
	int len = sr_int(r);
	if (len < 0 || (usz)len > r.len - r.pos)
	{
		r.ok = false;
		if (outLen) *outLen = 0;
		return;
	}
	usz copyLen = (usz)len;
	if (copyLen + 1 > cap) copyLen = cap - 1;
	if (copyLen > 0) sr_raw(r, dst, copyLen);
	dst[copyLen] = 0;
	if (outLen) *outLen = (int)copyLen;
	if ((usz)len > copyLen)
	{
		// Skip the remainder we could not store.
		r.pos += (usz)len - copyLen;
	}
}

// ---------------------------------------------------------------------------
// Save helpers
// ---------------------------------------------------------------------------
fn String save_dir(int seed)
{
	if (seed <= 0) return (String)"saves";
	return string::tformat("saves/%d", seed);
}

fn String save_path(int seed)
{
	return string::tformat("saves/%d/world.sav", seed);
}

fn void write_edits(SaveWriter* w, HashMap{long, WorldEdit}* map)
{
	sw_int(w, map.count);
	foreach (e : map.iter())
	{
		WorldEdit ed = e.value;
		sw_int(w, ed.tx);
		sw_int(w, ed.ty);
		sw_int(w, ed.id);
		sw_bool(w, ed.has);
	}
}

fn void read_edits(SaveReader* r, HashMap{long, WorldEdit}* map)
{
	int count = sr_int(r);
	if (count < 0 || count > SAVE_MAX_EDITS)
	{
		r.ok = false;
		return;
	}
	for (int i = 0; i < count; i++)
	{
		WorldEdit ed;
		ed.tx = sr_int(r);
		ed.ty = sr_int(r);
		ed.id = sr_int(r);
		ed.bg = false;
		ed.has = sr_bool(r);
		if (!r.ok) return;
		map.set(tile_key(ed.tx, ed.ty), ed);
	}
}

fn bool save_world()
{
	if (!g.playerCreated)
	{
		show_msg("Cannot save before the player is initialized", 4);
		return false;
	}
	return_held_stack();
	(void)path::mkdir((Path)"saves", true);
	String dir = save_dir(g.currentSeed);
	(void)path::mkdir((Path)dir, true);
	String path = save_path(g.currentSeed);

	File? opened = file::open(path, "wb");
	File f;
	if (try got = opened)
	{
		f = got;
	}
	else
	{
		show_msg("Could not open world save for writing", 4);
		return false;
	}
	SaveWriter w;
	w.file = &f;
	w.ok = true;

	char[4] magic = { 'T', 'B', 'S', 'V' };
	sw_raw(&w, &magic, 4);
	sw_int(&w, SAVE_VERSION);
	sw_int(&w, g.currentSeed);
	sw_float(&w, g.timeOfDay);
	sw_int(&w, g.creativeMode ? 1 : 0);
	sw_bool(&w, g.hostilesEnabled);

	Player* p = &g.player;
	sw_float(&w, p.x);
	sw_float(&w, p.y);
	sw_float(&w, p.health);
	sw_float(&w, p.hunger);
	sw_int(&w, p.hot);
	sw_int(&w, p.facing);
	sw_float(&w, p.spawnX);
	sw_float(&w, p.spawnY);
	sw_bool(&w, p.flying);
	for (int i = 0; i < INVENTORY_SLOTS; i++)
	{
		sw_int(&w, p.inv[i].id);
		sw_int(&w, p.inv[i].count);
	}

	write_edits(&w, &g.edits);
	write_edits(&w, &g.editsBg);

	sw_int(&w, g.openDoors.count);
	foreach (d : g.openDoors.iter())
	{
		sw_long(&w, d.key);
		sw_bool(&w, d.value);
	}

	sw_int(&w, g.entities.count);
	foreach (e : g.entities.iter())
	{
		BlockEntity* be = e.value;
		if (!be) continue;
		sw_int(&w, (int)be.kind);
		sw_int(&w, be.x);
		sw_int(&w, be.y);
		sw_int(&w, be.position);
		sw_int(&w, be.progress);
		sw_int(&w, be.fuelTime);
		sw_int(&w, be.maxFuelTime);
		for (int i = 0; i < 20; i++)
		{
			sw_int(&w, be.slots[i].id);
			sw_int(&w, be.slots[i].count);
		}
		Stack[3] stacks = { be.input, be.fuel, be.output };
		for (int i = 0; i < 3; i++)
		{
			sw_int(&w, stacks[i].id);
			sw_int(&w, stacks[i].count);
		}
	}

	sw_int(&w, g.logic.count);
	foreach (l : g.logic.iter())
	{
		LogicCell* c = l.value;
		if (!c) continue;
		sw_int(&w, c.type);
		sw_int(&w, c.x);
		sw_int(&w, c.y);
		sw_int(&w, c.bitWidth);
		sw_uint(&w, c.value);
		sw_int(&w, c.timer);
		sw_uint(&w, c.outputs[0]);
		sw_uint(&w, c.outputs[1]);
		sw_bool(&w, c.hasBoard);
		if (c.hasBoard)
		{
			sw_int(&w, c.board.w);
			sw_int(&w, c.board.h);
			for (int i = 0; i < 4; i++)
			{
				sw_int(&w, c.board.pins[i].dir);
				sw_int(&w, c.board.pins[i].bits);
				sw_uint(&w, c.board.sides[i]);
			}
			sw_int(&w, c.board.cells.count);
			foreach (bc : c.board.cells.iter())
			{
				BoardCell cell = bc.value;
				sw_long(&w, bc.key);
				sw_int(&w, cell.type);
				sw_int(&w, cell.bitWidth);
				sw_uint(&w, cell.value);
				sw_int(&w, cell.timer);
				sw_int(&w, cell.x);
				sw_int(&w, cell.y);
			}
		}
		sw_int(&w, c.codeLen);
		if (c.codeLen > 0) sw_raw(&w, &c.code, (usz)c.codeLen);
		sw_bool(&w, c.codeValid);
		sw_str(&w, &c.codeError, c.codeError.len);
	}

	f.close();
	if (!w.ok)
	{
		show_msg("World save failed while writing data", 4);
		return false;
	}
	char[160] buf;
	zfmt(&buf, "World saved to saves/%d", g.currentSeed);
	show_msg((ZString)&buf[0], 2.2f);
	return true;
}

fn void load_player(SaveReader* r)
{
	Player* p = &g.player;
	p.x = sr_float(r);
	p.y = sr_float(r);
	p.health = sr_float(r);
	p.hunger = sr_float(r);
	p.hot = sr_int(r);
	p.facing = sr_int(r);
	p.spawnX = sr_float(r);
	p.spawnY = sr_float(r);
	p.flying = sr_bool(r);
	if (p.hot < 0) p.hot = 0;
	if (p.hot >= HOTBAR_SLOTS) p.hot = HOTBAR_SLOTS - 1;
	if (p.health < 0) p.health = 0;
	if (p.health > p.maxHealth) p.health = p.maxHealth;
	if (p.hunger < 0) p.hunger = 0;
	if (p.hunger > p.maxHunger) p.hunger = p.maxHunger;
	for (int i = 0; i < INVENTORY_SLOTS; i++)
	{
		ItemId id = sr_int(r);
		int count = sr_int(r);
		if (id < 0 || id >= ITEM_COUNT) id = 0;
		if (count < 0) count = 0;
		p.inv[i] = { id, count };
	}
}

fn void clear_logic_cells()
{
	foreach (e : g.logic.iter())
	{
		LogicCell* c = e.value;
		if (!c) continue;
		if (c.hasBoard) c.board.cells.free();
		free(c);
	}
	g.logic.clear();
}

fn void clear_block_entities()
{
	foreach (e : g.entities.iter())
	{
		free(e.value);
	}
	g.entities.clear();
}

fn void free_all_chunks()
{
	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		ch.fg.free();
		ch.bg.free();
		free(ch);
	}
	g.chunks.clear();
}

fn void read_entities(SaveReader* r)
{
	clear_block_entities();
	int count = sr_int(r);
	if (count < 0 || count > SAVE_MAX_ENTITIES)
	{
		r.ok = false;
		return;
	}
	for (int i = 0; i < count; i++)
	{
		int kind = sr_int(r);
		int x = sr_int(r);
		int y = sr_int(r);
		int position = sr_int(r);
		int progress = sr_int(r);
		int fuelTime = sr_int(r);
		int maxFuelTime = sr_int(r);
		BlockEntity* be = be_create(x, y, (BlockEntityKind)kind);
		if (be)
		{
			be.position = position;
			be.progress = progress;
			be.fuelTime = fuelTime;
			be.maxFuelTime = maxFuelTime;
			for (int s = 0; s < 20; s++)
			{
				be.slots[s].id = sr_int(r);
				be.slots[s].count = sr_int(r);
			}
			be.input.id = sr_int(r);
			be.input.count = sr_int(r);
			be.fuel.id = sr_int(r);
			be.fuel.count = sr_int(r);
			be.output.id = sr_int(r);
			be.output.count = sr_int(r);
		}
		else
		{
			for (int s = 0; s < 20; s++)
			{
				(void)sr_int(r);
				(void)sr_int(r);
			}
			(void)sr_int(r); (void)sr_int(r);
			(void)sr_int(r); (void)sr_int(r);
			(void)sr_int(r); (void)sr_int(r);
		}
		if (!r.ok) return;
	}
}

fn void read_logic_cells(SaveReader* r)
{
	clear_logic_cells();
	int count = sr_int(r);
	if (count < 0 || count > SAVE_MAX_CELLS)
	{
		r.ok = false;
		return;
	}
	for (int i = 0; i < count; i++)
	{
		int type = sr_int(r);
		int x = sr_int(r);
		int y = sr_int(r);
		int bitWidth = sr_int(r);
		uint value = sr_uint(r);
		int timer = sr_int(r);
		uint outE = sr_uint(r);
		uint outS = sr_uint(r);
		bool hasBoard = sr_bool(r);
		if (!r.ok) return;
		if (type <= 0 || type >= ITEM_COUNT || !is_logic(type)) continue;

		LogicCell* c = logic_cell_default(type, x, y);
		if (!c) continue;
		c.bitWidth = bitWidth;
		c.value = value;
		c.timer = timer;
		c.outputs[0] = outE;
		c.outputs[1] = outS;
		c.hasBoard = hasBoard;
		if (hasBoard && c.board.cells.is_initialized())
		{
			c.board.w = sr_int(r);
			c.board.h = sr_int(r);
			for (int s = 0; s < 4; s++)
			{
				c.board.pins[s].dir = sr_int(r);
				c.board.pins[s].bits = sr_int(r);
				c.board.sides[s] = sr_uint(r);
			}
			int cells = sr_int(r);
			if (cells < 0 || cells > SAVE_MAX_CELLS) { r.ok = false; }
			for (int k = 0; r.ok && k < cells; k++)
			{
				long key = sr_long(r);
				BoardCell bc;
				bc.type = sr_int(r);
				bc.bitWidth = sr_int(r);
				bc.value = sr_uint(r);
				bc.timer = sr_int(r);
				bc.x = sr_int(r);
				bc.y = sr_int(r);
				if (!r.ok) break;
				c.board.cells.set(key, bc);
			}
		}
		else if (hasBoard)
		{
			// Malformed save: board expected but this cell type has none.
			c.hasBoard = false;
			sr_int(r);
			sr_int(r);
			for (int s = 0; s < 4; s++)
			{
				(void)sr_int(r);
				(void)sr_int(r);
				(void)sr_uint(r);
			}
			int cells = sr_int(r);
			for (int k = 0; r.ok && k < cells; k++)
			{
				(void)sr_long(r);
				(void)sr_int(r);
				(void)sr_int(r);
				(void)sr_uint(r);
				(void)sr_int(r);
				(void)sr_int(r);
				(void)sr_int(r);
			}
		}
		int codeLen = sr_int(r);
		if (codeLen < 0 || (usz)codeLen > r.len - r.pos)
		{
			r.ok = false;
			free(c);
			return;
		}
		usz copyLen = (usz)codeLen;
		if (copyLen >= (usz)c.code.len) copyLen = (usz)c.code.len - 1;
		if (copyLen > 0) sr_raw(r, &c.code, copyLen);
		c.code[copyLen] = 0;
		c.codeLen = (int)copyLen;
		if (codeLen > (int)copyLen) r.pos += (usz)codeLen - copyLen;
		c.codeValid = sr_bool(r);
		sr_str(r, &c.codeError, c.codeError.len, null);
		if (!r.ok)
		{
			if (c.hasBoard) c.board.cells.free();
			free(c);
			return;
		}
		g.logic.set(tile_key(x, y), c);
	}
}

fn bool load_world(int seed)
{
	String path = save_path(seed);
	if (!file::exists(path))
	{
		char[96] buf;
		zfmt(&buf, "No save found for seed %d", seed);
		show_msg((ZString)&buf[0], 3);
		return false;
	}
	char[]? loaded = file::load(tmem, path);
	if (catch err = loaded)
	{
		show_msg("Could not read world save", 4);
		return false;
	}
	char[] raw = loaded;
	SaveReader r;
	r.data = &raw[0];
	r.len = raw.len;
	r.pos = 0;
	r.ok = true;
	if (raw.len < 4 || r.data[0] != 'T' || r.data[1] != 'B'
	    || r.data[2] != 'S' || r.data[3] != 'V')
	{
		show_msg("Save file is not a TerraBlock binary save", 4);
		return false;
	}
	r.pos = 4;
	int version = sr_int(&r);
	if (version > SAVE_VERSION)
	{
		show_msg("Save was made with a newer version", 4);
		return false;
	}
	int savedSeed = sr_int(&r);
	float tod = sr_float(&r);
	int mode = sr_int(&r);
	bool hostiles = sr_bool(&r);
	if (!r.ok) { show_msg("Save header is corrupt", 4); return false; }
	if (seed <= 0) seed = savedSeed;

	g.creativeMode = mode == 1;
	g.hostilesEnabled = hostiles;
	reset_world(seed);
	g.timeOfDay = tod;

	// The reset generated a few spawn chunks before edits were known: reload.
	free_all_chunks();
	clear_logic_cells();
	clear_block_entities();
	g.openDoors.clear();
	g.waterLevels.clear();

	load_player(&r);
	read_edits(&r, &g.edits);
	read_edits(&r, &g.editsBg);
	// read_edits always stores bg=false; fix the background map flags.
	foreach (e : g.editsBg.iter())
	{
		if (try ed = g.editsBg.get_ref(e.key))
		{
			ed.bg = true;
		}
	}
	int doorCount = sr_int(&r);
	if (doorCount < 0 || doorCount > SAVE_MAX_EDITS) r.ok = false;
	for (int i = 0; r.ok && i < doorCount; i++)
	{
		long key = sr_long(&r);
		bool open = sr_bool(&r);
		g.openDoors.set(key, open);
	}
	if (!r.ok) { show_msg("Save data is corrupt", 4); return false; }

	g.streamValid = false;
	g.lastStreamCenter = 0;
	g.lastStreamRadius = 0;
	update_streaming();
	if (!r.ok) { show_msg("Save data is corrupt", 4); return false; }

	read_entities(&r);
	read_logic_cells(&r);
	if (!r.ok)
	{
		show_msg("Save data is corrupt (entities/logic)", 4);
		return false;
	}
	g.player.vx = 0;
	g.player.vy = 0;
	g.player.fallSpeed = 0;
	g.player.hurt = 0;
	g.player.onGround = false;
	g.cameraX = g.player.x + (float)g.player.w / 2;
	g.cameraY = g.player.y + (float)g.player.h / 2;
	g.streamValid = false;
	update_streaming();

	char[120] buf;
	zfmt(&buf, "Loaded world %d", seed);
	show_msg((ZString)&buf[0], 2);
	return true;
}

fn int latest_save_seed()
{
	int best = 0;
	if (try entries = path::ls(tmem, (Path)"saves"))
	{
		foreach (p : entries)
		{
			String name = (String)p;
			if (try v = name.to_int())
			{
				if (v > best) best = v;
			}
		}
	}
	return best;
}

fn int save_compare(void* a, void* b)
{
	SaveEntry* sa = (SaveEntry*)a;
	SaveEntry* sb = (SaveEntry*)b;
	if (sa.seed < sb.seed) return 1;
	if (sa.seed > sb.seed) return -1;
	return 0;
}

fn void find_worlds()
{
	g.saves.clear();
	if (try entries = path::ls(tmem, (Path)"saves"))
	{
		foreach (p : entries)
		{
			String name = (String)p;
			int seed;
			if (catch err = name.to_int()) continue;
			seed = name.to_int() ?? 0;
			if (seed <= 0) continue;
			if (!file::exists(save_path(seed))) continue;
			char[]? raw = file::load(tmem, save_path(seed));
			if (catch e2 = raw) continue;
			char[] data = raw;
			if (data.len < 17) continue;
			if (data[0] != 'T' || data[1] != 'B' || data[2] != 'S' || data[3] != 'V') continue;
			SaveReader r;
			r.data = &data[0];
			r.len = data.len;
			r.pos = 4;
			r.ok = true;
			(void)sr_int(&r);
			int savedSeed = sr_int(&r);
			(void)sr_float(&r);
			int mode = sr_int(&r);
			bool hostiles = sr_bool(&r);
			if (!r.ok) continue;
			SaveEntry entry;
			entry.seed = savedSeed > 0 ? savedSeed : seed;
			entry.mode = mode;
			entry.hostiles = hostiles;
			entry.modified[0] = 0;
			g.saves.push(entry);
		}
	}
	if (g.saves.size > 1)
	{
		for (sz i = 1; i < g.saves.size; i++)
		{
			SaveEntry item = g.saves[i];
			sz j = i;
			while (j > 0 && g.saves[j - 1].seed < item.seed)
			{
				g.saves[j] = g.saves[j - 1];
				j--;
			}
			g.saves[j] = item;
		}
	}
	g.saveListDirty = false;
}

fn void delete_world(int seed)
{
	String dir = save_dir(seed);
	(void)file::delete(save_path(seed));
	(void)path::delete((Path)dir);
	g.saveListDirty = true;
}

// ---------------------------------------------------------------------------
// Mods and datapacks
// ---------------------------------------------------------------------------
fn void copy_string_to_buf(String s, char[] out)
{
	usz n = s.len;
	if (n + 1 > out.len) n = out.len - 1;
	if (n > 0) mem::copy(&out, s.ptr, (sz)n);
	out[n] = 0;
}

fn void extract_field(String text, ZString field, char[] out)
{
	out[0] = 0;
	usz flen = 0;
	while (field[flen] != 0) flen++;
	usz i = 0;
	while (i + flen + 2 < text.len)
	{
		bool match = true;
		for (usz j = 0; j < flen; j++)
		{
			if (text[i + j] != field[j]) { match = false; break; }
		}
		if (!match)
		{
			i++;
			continue;
		}
		usz k = i + flen;
		while (k < text.len && (text[k] == ' ' || text[k] == '\t')) k++;
		if (k >= text.len || text[k] != '=') { i++; continue; }
		k++;
		while (k < text.len && (text[k] == ' ' || text[k] == '\t')) k++;
		if (k >= text.len || (text[k] != '"' && text[k] != '\'')) { i++; continue; }
		char quote = text[k];
		k++;
		usz start = k;
		while (k < text.len && text[k] != quote) k++;
		usz n = k - start;
		if (n + 1 > out.len) n = out.len - 1;
		if (n > 0) mem::copy(&out, &text[start], (sz)n);
		out[n] = 0;
		return;
	}
}

fn void scan_pack_textures(String packFolder)
{
	ZString[5] kinds = { "blocks", "items", "tools", "entities", "ui" };
	for (int k = 0; k < 5; k++)
	{
		String dir = string::tformat("data/%s/textures/%s", packFolder, kinds[k].str_view());
		if (!file::is_dir(dir)) continue;
		if (catch err = path::ls(tmem, (Path)dir)) continue;
		PathList entries = path::ls(tmem, (Path)dir) ?? {};
		foreach (p : entries)
		{
			String file = (String)p;
			bool png = file.ends_with(".png") || file.ends_with(".PNG");
			if (!png) continue;
			TextureOverride ov;
			copy_string_to_buf(kinds[k].str_view(), &ov.kind);
			// Strip extension.
			usz dot = file.len;
			for (usz i = 0; i < file.len; i++)
			{
				if (file[i] == '.') { dot = i; break; }
			}
			char[48] idbuf;
			usz n = dot;
			if (n + 1 > idbuf.len) n = idbuf.len - 1;
			if (n > 0) mem::copy(&idbuf, file.ptr, (sz)n);
			idbuf[n] = 0;
			copy_string_to_buf((String)&idbuf, &ov.id);
			String full = string::tformat("%s/%s", dir, file);
			copy_string_to_buf(full, &ov.path);
			g.textureOverrides.push(ov);
		}
	}
}

fn void discover_resources()
{
	g.mods.clear();
	g.textureOverrides.clear();

	// Mods: folders with init.lua inside mods/.
	if (file::is_dir("mods"))
	{
		if (try modDirs = path::ls(tmem, (Path)"mods"))
		{
			foreach (p : modDirs)
			{
				String folder = (String)p;
				String initPath = string::tformat("mods/%s/init.lua", folder);
				if (!file::exists(initPath)) continue;
				ModEntry m;
				copy_string_to_buf(folder, &m.folder);
				copy_string_to_buf(folder, &m.name);
				copy_string_to_buf("1.0", &m.version);
				m.description[0] = 0;
				String infoPath = string::tformat("mods/%s/modinfo.lua", folder);
				if (file::exists(infoPath))
				{
					if (try text = file::load(tmem, infoPath))
					{
						extract_field((String)text, "name", &m.name);
						extract_field((String)text, "version", &m.version);
						extract_field((String)text, "description", &m.description);
					}
				}
				m.isDatapack = false;
				g.mods.push(m);
			}
		}
	}

	// Datapacks: folders with info.lua inside data/.
	if (file::is_dir("data"))
	{
		if (try packDirs = path::ls(tmem, (Path)"data"))
		{
			foreach (p : packDirs)
			{
				String folder = (String)p;
				String infoPath = string::tformat("data/%s/info.lua", folder);
				if (!file::exists(infoPath)) continue;
				ModEntry m;
				copy_string_to_buf(folder, &m.folder);
				copy_string_to_buf(folder, &m.name);
				copy_string_to_buf("1.0", &m.version);
				m.description[0] = 0;
				if (try text = file::load(tmem, infoPath))
				{
					extract_field((String)text, "name", &m.name);
					extract_field((String)text, "version", &m.version);
					extract_field((String)text, "description", &m.description);
				}
				m.isDatapack = true;
				g.mods.push(m);
				scan_pack_textures(folder);
			}
		}
	}
}

fn ZString texture_override_for(ZString kind, ZString id)
{
	for (int i = (int)g.textureOverrides.size - 1; i >= 0; i--)
	{
		TextureOverride* ov = &g.textureOverrides[i];
		if (zstr_eq((ZString)&ov.kind[0], kind) && zstr_eq((ZString)&ov.id[0], id))
		{
			return (ZString)&ov.path[0];
		}
	}
	return null;
}

fn bool zstr_eq(ZString a, ZString b)
{
	if (!a || !b) return false;
	int i = 0;
	while (a[i] != 0 && b[i] != 0)
	{
		if (a[i] != b[i]) return false;
		i++;
	}
	return a[i] == 0 && b[i] == 0;
}
