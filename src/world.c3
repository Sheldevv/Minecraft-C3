// World generation, chunk storage and block edits.
module minecraft;
import rl;
import std::collections::map;
import perlin;
import std::math;
import std::collections::list;

// ---------------------------------------------------------------------------
// Noise / biomes
// ---------------------------------------------------------------------------
fn float fbm(float tileX, int seed, float salt, int octaves, float freq, float amp)
{
	float total = 0;
	float maxA = 0;
	float f = freq;
	float a = amp;
	for (int i = 1; i <= octaves; i++)
	{
		total += perlin::noise(tileX * f, (float)seed * 0.137f, salt + (float)i * 41.7f) * a;
		maxA += a;
		f *= 2.0f;
		a *= 0.5f;
	}
	return maxA != 0 ? total / maxA : 0;
}

fn float designed_height(int col, int seed)
{
	float tx = (float)col / (float)GRID;
	float h = fbm(tx, seed, 0, 3, 0.012f, 1) * 26;
	h += fbm(tx, seed, 7, 3, 0.060f, 1) * 9;
	h += fbm(tx, seed, 19, 2, 0.180f, 1) * 2.5f;
	h -= 10;
	return math::floor(h) * (float)GRID;
}

fn int surface_y(int col, int seed)
{
	return SEA + (int)designed_height(col, seed);
}

// 0 desert, 1 forest, 2 snow, 3 swamp, 4 plains
fn int biome_at(int col, int seed)
{
	int band = (int)math::floor(((float)col / (float)GRID + (float)seed * 7) / 48.0f) % 5;
	if (band < 0) band += 5;
	float r = hash1((int)math::floor((float)col / (float)(GRID * 16)), seed, 40);
	if (band == 0 || r < 0.18f) return 0;
	if (band == 1 || (r > 0.18f && r < 0.32f)) return 1;
	if (band == 2) return 2;
	if (band == 3) return 3;
	return 4;
}

fn ZString biome_name(int biome)
{
	switch (biome)
	{
		case 0: return "desert";
		case 1: return "forest";
		case 2: return "snow";
		case 3: return "swamp";
		default: return "plains";
	}
}

// ---------------------------------------------------------------------------
// Block lookup
// ---------------------------------------------------------------------------
fn Chunk* get_chunk(int index)
{
	if (try c = g.chunks.get(index)) return c;
	return null;
}

fn ItemId block_at(int tx, int ty)
{
	Chunk* c = get_chunk(chunk_index(tx));
	if (!c) return 0;
	if (try v = c.fg.get(tile_key(tx, ty))) return v;
	return 0;
}

fn ItemId bg_at(int tx, int ty)
{
	Chunk* c = get_chunk(chunk_index(tx));
	if (!c) return 0;
	if (try v = c.bg.get(tile_key(tx, ty))) return v;
	return 0;
}

fn bool block_exists(int tx, int ty)
{
	return block_at(tx, ty) != 0;
}

// ---------------------------------------------------------------------------
// Editing
// ---------------------------------------------------------------------------
fn void remember_edit(int tx, int ty, bool bg, ItemId id)
{
	WorldEdit e;
	e.tx = tx; e.ty = ty; e.bg = bg; e.id = id; e.has = id != 0;
	long k = tile_key(tx, ty);
	if (bg) {g.editsBg.set(k, e);}
	else {g.edits.set(k, e);}
}

fn bool place_block_impl(int x, int y, ItemId id, bool bg, bool remember)
{
	int gx = (x / GRID) * GRID;
	int gy = (y / GRID) * GRID;
	if (x < 0 && x % GRID != 0) gx -= GRID;
	if (y < 0 && y % GRID != 0) gy -= GRID;
	int ci = chunk_index(gx);
	Chunk* chunk = g.activeChunk;
	if (!chunk) chunk = get_chunk(ci);
	if (!chunk) chunk = ensure_chunk_loaded(ci);
	if (!chunk) return false;
	if (g.activeChunk && (gx < chunk.firstTx || gx >= chunk.lastTx)) return false;

	if (id == ITEM_CAVEBLOCK) bg = true;
	if (id != ITEM_CAVEBLOCK && !is_block(id)) return false;

	HashMap{long, ItemId}* map = bg ? &chunk.bg : &chunk.fg;
	long k = tile_key(gx, gy);
	if (map.has_key(k)) return false;

	map.set(k, id);

	if (remember && !g.generatingChunk) remember_edit(gx, gy, bg, id);
	if (!g.generatingChunk) net_send_edit(gx, gy, bg, id);
	if (id == ITEM_DOOR) g.openDoors.set(k, false);
	if (id == ITEM_PLATFORM) (void)be_create(gx, gy, BlockEntityKind.PLATFORM);
	if (is_logic(id)) logic_on_place_block(gx, gy, id);
	return true;
}

fn bool place_block(int x, int y, ItemId id, bool bg)
{
	return place_block_impl(x, y, id, bg, true);
}

fn ItemId remove_at(int x, int y, bool bg)
{
	int gx = (x / GRID) * GRID;
	int gy = (y / GRID) * GRID;
	if (x < 0 && x % GRID != 0) gx -= GRID;
	if (y < 0 && y % GRID != 0) gy -= GRID;
	Chunk* chunk = get_chunk(chunk_index(gx));
	if (!chunk) return 0;
	HashMap{long, ItemId}* map = bg ? &chunk.bg : &chunk.fg;
	long k = tile_key(gx, gy);
	ItemId id = 0;
	if (try v = map.get(k)) id = v;
	if (id == 0) return 0;
	map.remove(k);
	return id;
}

fn bool destroy_block(int x, int y, bool bg)
{
	int gx = (x / GRID) * GRID;
	int gy = (y / GRID) * GRID;
	if (x < 0 && x % GRID != 0) gx -= GRID;
	if (y < 0 && y % GRID != 0) gy -= GRID;
	ItemId btype = remove_at(gx, gy, bg);
	if (btype == 0) return false;
	if (!g.generatingChunk)
	{
		remember_edit(gx, gy, bg, 0);
		net_send_edit(gx, gy, bg, ITEM_NONE);
		be_destroy(gx, gy);
		if (is_logic(btype)) logic_on_destroy_block(gx, gy);

		BlockDef* def = block_def(btype);
		if (def && def.drop) spawn_drop(gx, gy, def.drop, 1);
		if (def) spawn_parts(gx, gy, def.color, 7);
		if ((btype == ITEM_LEAVES || btype == ITEM_PINELEAVES) && frandom() < 0.08f)
		{
			spawn_drop(gx, gy, ITEM_APPLE, 1);
		}
	}
	return true;
}

fn void apply_edits(Chunk* chunk)
{
	foreach (e : g.edits.iter())
	{
		WorldEdit ed = e.value;
		if (ed.tx >= chunk.firstTx && ed.tx < chunk.lastTx)
		{
			remove_at(ed.tx, ed.ty, false);
			if (ed.has) place_block_impl(ed.tx, ed.ty, ed.id, false, false);
		}
	}
	foreach (e : g.editsBg.iter())
	{
		WorldEdit ed = e.value;
		if (ed.tx >= chunk.firstTx && ed.tx < chunk.lastTx)
		{
			remove_at(ed.tx, ed.ty, true);
			if (ed.has) place_block_impl(ed.tx, ed.ty, ed.id, true, false);
		}
	}
}

// ---------------------------------------------------------------------------
// Chunk generation
// ---------------------------------------------------------------------------
fn bool tree_blocked(int x, int sy)
{
	for (int ox = -3; ox <= 3; ox++)
	{
		for (int oy = 0; oy <= 6; oy++)
		{
			if (block_at(x + ox * GRID, sy - oy * GRID) == ITEM_LOG) return true;
		}
	}
	return false;
}

fn void gen_tree(int x, int sy, int seed, int kind)
{
	// kind: 0 oak, 1 pine, 2 birch
	if (tree_blocked(x, sy)) return;
	int h = 4 + (int)math::floor(hash2(x, sy, seed, 50) * 5);
	if (kind == 1) h += 2;
	ItemId trunk = kind == 2 ? ITEM_BIRCHLOG : ITEM_LOG;
	for (int i = 1; i <= h; i++) (void)place_block_impl(x, sy - i * GRID, trunk, false, true);
	int top = sy - h * GRID;
	if (kind == 1)
	{
		int[4] widths = { 3, 2, 2, 1 };
		for (int layer = 1; layer <= 4; layer++)
		{
			int w = widths[layer - 1];
			int ly = top - (4 - layer) * GRID;
			for (int ox = -w; ox <= w; ox++)
			{
				(void)place_block_impl(x + ox * GRID, ly, ITEM_PINELEAVES, false, true);
			}
		}
		(void)place_block_impl(x, top - 4 * GRID, ITEM_PINELEAVES, false, true);
	}
	else
	{
		for (int ox = -2; ox <= 2; ox++)
		{
			for (int oy = -2; oy <= 2; oy++)
			{
				int dist = math::abs(ox) + math::abs(oy);
				if (dist < 4 && !(math::abs(ox) == 2 && oy == 2))
				{
					(void)place_block_impl(x + ox * GRID, top + oy * GRID, ITEM_LEAVES, false, true);
				}
			}
		}
		(void)place_block_impl(x, top - 3 * GRID, ITEM_LEAVES, false, true);
	}
}

fn void gen_cactus(int x, int sy, int seed)
{
	int h = 2 + (int)math::floor(hash2(x, sy, seed, 60) * 3);
	for (int i = 1; i <= h; i++) (void)place_block_impl(x, sy - i * GRID, ITEM_CACTUS, false, true);
}

fn void gen_ruin(int cx, int sy, int seed)
{
	int w = 4 + (int)math::floor(hash2(cx, sy, seed, 70) * 3);
	for (int ox = 0; ox <= w; ox++)
	{
		(void)place_block_impl(cx + ox * GRID, sy, ITEM_COBBLE, false, true);
		if (ox == 0 || ox == w)
		{
			for (int oy = 1; oy <= 3; oy++)
			{
				(void)place_block_impl(cx + ox * GRID, sy - oy * GRID, ITEM_COBBLE, false, true);
			}
		}
	}
	(void)place_block_impl(cx + GRID, sy - 3 * GRID, ITEM_COBBLE, false, true);
	(void)place_block_impl(cx + (w - 1) * GRID, sy - 2 * GRID, ITEM_COBBLE, false, true);
	if (hash2(cx, sy, seed, 71) > 0.5f)
	{
		(void)place_block_impl(cx + 2 * GRID, sy - GRID, ITEM_CHEST, false, true);
	}
}

fn void generate_chunk_data(Chunk* chunk)
{
	g.generatingChunk = true;
	int seed = g.currentSeed;
	int first = chunk.firstTx;
	int last = chunk.lastTx;

	HashMap{long, bool} caves;
	HashMap{long, ItemId} caveOres;
	HashMap{long, ItemId} seams;
	caves.init(mem);
	caveOres.init(mem);
	seams.init(mem);
	defer caves.free();
	defer caveOres.free();
	defer seams.free();

	// Cave networks
	for (int col = first; col < last; col += GRID * 10)
	{
		if (hash1(col, seed, 80) > 0.4f)
		{
			int sy = surface_y(col, seed);
			int startY = sy + GRID * (6 + (int)math::floor(hash1(col, seed, 81) * 8));
			int dir = hash1(col, seed, 82) > 0.5f ? 1 : -1;
			int x = col;
			int y = startY;
			int len = 12 + (int)math::floor(hash1(col, seed, 83) * 22);
			for (int i = 1; i <= len; i++)
			{
				caves.set(tile_key(x, y), true);
				caves.set(tile_key(x + GRID, y), true);
				caves.set(tile_key(x, y + GRID), true);
				if (i % 7 == 0)
				{
					for (int ox = -2; ox <= 2; ox++)
					{
						for (int oy = -1; oy <= 1; oy++)
						{
							caves.set(tile_key(x + ox * GRID, y + oy * GRID), true);
						}
					}
					if (hash2(x, y, seed, 84) > 0.55f)
					{
						ItemId[6] ores = { ITEM_COAL, ITEM_COPPER, ITEM_IRON,
						                   ITEM_GOLD, ITEM_REDSTONE, ITEM_CRYSTAL };
						ItemId ore = ores[(int)math::floor(hash2(x, y, seed, 85) * 6) % 6];
						for (int ox = -1; ox <= 1; ox++)
						{
							for (int oy = -1; oy <= 1; oy++)
							{
								if (hash2(x + ox, y + oy, seed, 86) > 0.35f)
								{
									caveOres.set(tile_key(x + ox * GRID, y + oy * GRID), ore);
								}
							}
						}
					}
				}
				float turn = hash2(x, y, seed, 87 + i);
				if (turn < 0.25f)
				{
					y += GRID;
				}
				else if (turn > 0.75f)
				{
					y -= GRID;
				}
				if (turn > 0.4f && turn < 0.6f) dir = -dir;
				x += dir * GRID;
				int minY = surface_y(x, seed) + GRID * 4;
				if (y < minY) y = minY;
			}
		}
	}

	// Ore seams
	for (int col = first; col < last; col += GRID * 8)
	{
		int sy = surface_y(col, seed);
		for (int layer = 1; layer <= 4; layer++)
		{
			if (hash1(col + layer, seed, 90 + layer) > 0.35f)
			{
				int depth = sy + GRID * (5 + layer * 4 + (int)math::floor(hash1(col, seed, 91) * 3));
				ItemId[8] ores = { ITEM_COAL, ITEM_COAL, ITEM_COPPER, ITEM_IRON,
				                   ITEM_IRON, ITEM_GOLD, ITEM_REDSTONE, ITEM_CRYSTAL };
				int idx = layer + (int)math::floor(hash1(col, seed, 92) * 3);
				if (idx < 0) idx = 0;
				if (idx > 7) idx = 7;
				ItemId ore = ores[idx];
				int len = 3 + (int)math::floor(hash1(col, seed, 93) * 5);
				for (int i = 0; i <= len; i++)
				{
					seams.set(tile_key(col + i * GRID, depth), ore);
					if (hash1(col + i, seed, 94) > 0.5f)
					{
						seams.set(tile_key(col + i * GRID, depth + GRID), ore);
					}
				}
			}
		}
	}

	for (int col = first; col < last; col += GRID)
	{
		int sy = surface_y(col, seed);
		int biome = biome_at(col, seed);
		float moist = hash1(col, seed, 100);
		bool isPond = (biome == 3 || biome == 4) && moist > 0.78f
		           && hash1(col, seed, 101) > 0.7f;
		bool isLake = biome == 3 && moist > 0.85f;

		for (int y = sy; y <= sy + GRID * 32; y += GRID)
		{
			int depth = (y - sy) / GRID;
			ItemId btype = ITEM_STONE;

			if (depth < 1)
			{
				if (biome == 0)
				{
					btype = ITEM_SAND;
				}
				else if (biome == 2)
				{
					btype = ITEM_SNOW;
				}
				else
				{
					btype = ITEM_GRASS;
				}
			}
			else if (depth < 3)
			{
				btype = biome == 0 ? ITEM_SAND : ITEM_DIRT;
			}
			else if (depth < 5 && biome == 0)
			{
				btype = ITEM_SANDSTONE;
			}
			else if (depth > 18)
			{
				btype = ITEM_DEEPSTONE;
			}

			if (isPond && depth >= 1 && depth <= 3 && hash2(col, y, seed, 102) > 0.6f)
			{
				btype = ITEM_CLAY;
			}

			long sk = tile_key(col, y);
			if (try sid = seams.get(sk)) btype = sid;

			if (try cv = caves.get(sk))
			{
				if (depth > 3)
				{
					bool cave = cv;
					if (cave)
					{
						(void)place_block_impl(col, y, ITEM_CAVEBLOCK, true, true);
						if (try ore = caveOres.get(sk))
						{
							(void)place_block_impl(col, y, ore, false, true);
						}
						continue;
					}
				}
			}

			(void)place_block_impl(col, y, btype, false, true);
			if (depth >= 1)
			{
				(void)place_block_impl(col, y, depth > 14 ? ITEM_DEEPSTONE : ITEM_STONE, true, true);
			}
		}

		if (isPond || isLake)
		{
			int depthW = isLake ? 5 : 3;
			for (int wy = sy; wy <= sy + GRID * depthW; wy += GRID)
			{
				(void)remove_at(col, wy, false);
				(void)remove_at(col, wy, true);
				ItemId liquid = biome == 2 ? ITEM_ICE : ITEM_WATER;
				(void)place_block_impl(col, wy, liquid, false, true);
			}
		}

		if (!isPond && !isLake)
		{
			float r = hash1(col, seed, 110);
			bool space = hash1((int)math::floor((float)col / (float)(GRID * 3)), seed, 111) > 0.55f;
			if (biome == 0 && r > 0.88f)
			{
				gen_cactus(col, sy, seed);
			}
			else if (biome == 1 && r > 0.80f && space)
			{
				float roll = hash1(col, seed, 112);
				int kind = roll < 0.45f ? 1 : (roll < 0.75f ? 2 : 0);
				gen_tree(col, sy, seed, kind);
			}
			else if (biome == 4 && r > 0.90f && space)
			{
				gen_tree(col, sy, seed, 0);
			}
			else if (biome == 2 && r > 0.86f && space)
			{
				gen_tree(col, sy, seed, 1);
			}
			else if (biome == 3 && r > 0.87f && space)
			{
				gen_tree(col, sy, seed, 0);
				if (hash1(col, seed, 113) > 0.6f)
				{
					(void)place_block_impl(col + GRID, sy - GRID, ITEM_MUSHROOM, false, true);
				}
			}
			if (biome != 0 && hash1(col, seed, 114) > 0.93f)
			{
				(void)place_block_impl(col, sy - GRID, ITEM_MUSHROOM, false, true);
			}
			if (hash1((int)math::floor((float)col / (float)(GRID * 20)), seed, 115) > 0.92f
			    && col % (GRID * 20) < GRID)
			{
				gen_ruin(col, sy, seed);
			}
		}
	}

	g.generatingChunk = false;
}

fn Chunk* ensure_chunk_loaded(int index)
{
	if (try existing = g.chunks.get(index)) return existing;
	Chunk chunkValue;
	Chunk* chunk = malloc(@sizeof(chunkValue));
	if (!chunk) return null;
	*chunk = {};
	chunk.index = index;
	chunk.firstTx = index * CHUNK_W;
	chunk.lastTx = (index + 1) * CHUNK_W;
	chunk.fg.init(mem);
	chunk.bg.init(mem);
	g.chunks.set(index, chunk);
	g.activeChunk = chunk;
	generate_chunk_data(chunk);
	apply_edits(chunk);
	g.activeChunk = null;
	return chunk;
}

fn void unload_chunk(int index)
{
	if (try c = g.chunks.get(index))
	{
		// Remove first: freeing the maps can invalidate an iterator that is
		// still holding this entry (e.g. during a world reset).
		g.chunks.remove(index);
		if (g.activeChunk == c) g.activeChunk = null;
		c.fg.free();
		c.bg.free();
		free(c);
	}
}

fn void update_streaming()
{
	int center = chunk_index(tile_of(g.player.x));
	int radius = 2;
	if (g.streamValid && g.lastStreamCenter == center && g.lastStreamRadius == radius) return;
	g.lastStreamCenter = center;
	g.lastStreamRadius = radius;
	g.streamValid = true;
	for (int i = center - radius; i <= center + radius; i++) (void)ensure_chunk_loaded(i);
	List{int} remove;
	remove.init(mem);
	defer remove.free();
	foreach (c : g.chunks.iter())
	{
		if (c.key < center - radius - 1 || c.key > center + radius + 1) remove.push(c.key);
	}
	foreach (i : remove) unload_chunk(i);
}

fn int world_seed_random()
{
	return random::rand(99999) + 1;
}

fn void reset_world(int seed)
{
	if (seed <= 0) seed = world_seed_random();
	g.currentSeed = seed;
	// free_all_chunks() frees every chunk then clears the map once; removing
	// entries while iterating the map corrupts its buckets.
	free_all_chunks();
	g.activeChunk = null;
	g.generatingChunk = false;
	g.edits.clear();
	g.editsBg.clear();
	g.openDoors.clear();
	g.waterLevels.clear();
	// These helpers free the heap-allocated cells/entities before clearing.
	clear_logic_cells();
	clear_block_entities();
	g.drops.clear();
	g.particles.clear();
	g.floats.clear();
	g.enemies.clear();
	g.tntFuses.clear();
	g.lastStreamCenter = 0;
	g.lastStreamRadius = 0;
	g.streamValid = false;
	g.miningActive = false;
	g.miningProgress = 0;
	g.timeOfDay = 0.28f;
	g.bloodMoon = false;
	// Close every modal so no cached cell/coordinate points into the old world.
	return_held_stack();
	g.boardOpen = false;
	g.programOpen = false;
	g.signalSourceOpen = false;
	g.cmdOpen = false;
	g.chatOpen = false;
	g.inventoryOpen = false;
	g.stationOpen = false;
	g.paused = false;
	g.uiActiveField = -1;

	if (!g.playerCreated) player_create();
	g.player.x = 0;
	g.player.y = (float)(-GRID * 10);
	g.player.vx = 0; g.player.vy = 0;
	g.player.health = g.player.maxHealth;
	g.player.hunger = g.player.maxHunger;
	g.player.flying = false;
	g.player.climbing = false;
	g.player.hot = 0;
	g.player.spawnX = 0;
	g.player.spawnY = (float)(-GRID * 10);
	g.player.fallSpeed = 0;

	inv_clear();
	if (g.creativeMode)
	{
		player_fill_creative();
	}
	else
	{
		(void)add_inv(ITEM_WOODPICKAXE, 1);
		(void)add_inv(ITEM_WOODSWORD, 1);
		(void)add_inv(ITEM_TORCH, 12);
		(void)add_inv(ITEM_PLANKS, 30);
		(void)add_inv(ITEM_WORKBENCH, 1);
	}

	(void)ensure_chunk_loaded(0);
	(void)ensure_chunk_loaded(-1);
	(void)ensure_chunk_loaded(1);

	int sy = surface_y(0, g.currentSeed);
	g.player.y = (float)(sy - g.player.h - 2);
	g.player.spawnX = g.player.x;
	g.player.spawnY = g.player.y;
	g.cameraX = g.player.x + (float)g.player.w / 2;
	g.cameraY = g.player.y + (float)g.player.h / 2;

	char[160] buf;
	zfmt(&buf, "Seed %d - smooth world", g.currentSeed);
	show_msg((ZString)&buf[0], 3);
}

// Compatibility name used by main.
fn void world_reset(int seed)
{
	reset_world(seed);
}
