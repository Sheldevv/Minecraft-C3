// Entities: drops, particles, enemies, TNT, water, block entities and mining.
module minecraft;
import rl;
import std::math;
import std::collections::list;
import std::collections::map;
import std::core::string;

// TNT tuning (mirrors the original Lua table).
const float TNT_FUSE = 1.4f;
const float TNT_PLAYER_DAMAGE = 70.0f;
const float TNT_ENEMY_DAMAGE = 100.0f;
const float TNT_MIN_FRAC = 0.30f;
const float TNT_ENTITY_RADIUS = 5.0f;
const float TNT_BLOCK_RADIUS = 3.0f;
const float TNT_BLAST_POWER = 3.0f;
const float TNT_KNOCKBACK = 320.0f;
const float TNT_CHAIN_DELAY = 0.22f;
const int WATER_PERIOD = 4;

// ---------------------------------------------------------------------------
// Drops
// ---------------------------------------------------------------------------
fn void spawn_drop(int x, int y, ItemId id, int count)
{
	if (g.drops.size >= MAX_DROPS) g.drops.remove_at(0);
	Drop d;
	d.x = (float)x + (float)GRID * 0.2f
	    + hash2(x, y, g.currentSeed, 1) * (float)GRID * 0.6f;
	d.y = (float)y + (float)GRID * 0.2f;
	d.vx = (hash2(x, y, g.currentSeed, 2) - 0.5f) * 90.0f;
	d.vy = -50.0f - hash2(x, y, g.currentSeed, 3) * 50.0f;
	d.id = id;
	d.count = count > 0 ? count : 1;
	d.life = 100.0f;
	d.bob = hash2(x, y, g.currentSeed, 4) * 6.28f;
	g.drops.push(d);
}

fn void update_drops(float dt)
{
	for (int i = (int)g.drops.size - 1; i >= 0; i--)
	{
		Drop* d = &g.drops[i];
		d.life = d.life - dt;
		d.bob = d.bob + dt * 3.0f;
		d.vy = d.vy + 620.0f * dt;
		d.x = d.x + d.vx * dt;
		d.y = d.y + d.vy * dt;
		d.vx = d.vx * (1.0f - 2.2f * dt);

		int gx = snap_i(d.x);
		int gy = snap_i(d.y) + GRID;
		ItemId below = block_at(gx, gy);
		if (below != 0)
		{
			BlockDef* bd = block_def(below);
			if (bd && bd.solid && !is_non_collide(below, gx, gy))
			{
				d.y = (float)gy - 8.0f;
				d.vy = 0;
				d.vx = d.vx * 0.82f;
			}
		}

		float dcx = d.x + 8.0f;
		float dcy = d.y + 8.0f;
		float pcx = g.player.x + (float)g.player.w / 2.0f;
		float pcy = g.player.y + (float)g.player.h / 2.0f;
		float adx = math::abs(dcx - pcx);
		float ady = math::abs(dcy - pcy);
		if (adx < 34.0f && ady < 62.0f)
		{
			int count = d.count;
			ItemId id = d.id;
			if (add_inv(id, count))
			{
				g.drops.remove_at(i);
				char[96] buf;
				zfmt(&buf, "+%d %s", count, item_name(id));
				show_msg((ZString)&buf[0], 1.1f);
			}
		}
		else if (d.life <= 0)
		{
			g.drops.remove_at(i);
		}
	}
}

// ---------------------------------------------------------------------------
// Particles / floating damage numbers
// ---------------------------------------------------------------------------
fn void spawn_parts(int x, int y, Color col, int n)
{
	if (n <= 0) n = 7;
	for (int i = 0; i < n; i++)
	{
		Particle p;
		p.x = (float)x + (float)GRID / 2.0f;
		p.y = (float)y + (float)GRID / 2.0f;
		p.vx = (frandom() - 0.5f) * 130.0f;
		p.vy = (frandom() - 0.5f) * 130.0f - 35.0f;
		p.life = 0.35f + frandom() * 0.4f;
		p.max = 0.6f;
		p.color = col;
		p.size = 2.0f + frandom() * 3.0f;
		g.particles.push(p);
	}
}

fn void update_particles(float dt)
{
	for (int i = (int)g.particles.size - 1; i >= 0; i--)
	{
		Particle* p = &g.particles[i];
		p.life = p.life - dt;
		p.x = p.x + p.vx * dt;
		p.y = p.y + p.vy * dt;
		p.vy = p.vy + 280.0f * dt;
		if (p.life <= 0) g.particles.remove_at(i);
	}
}

fn void spawn_damage_number(float x, float y, int amount, Color color)
{
	FloatText f;
	f.x = x;
	f.y = y;
	f.vy = -42.0f;
	f.life = 1.15f;
	f.max = 1.15f;
	f.color = color;
	zfmt(&f.text, "%d", amount);
	g.floats.push(f);
}

fn void update_floats(float dt)
{
	for (int i = (int)g.floats.size - 1; i >= 0; i--)
	{
		FloatText* f = &g.floats[i];
		f.life = f.life - dt;
		f.y = f.y + f.vy * dt;
		f.vy = f.vy + 28.0f * dt;
		if (f.life <= 0) g.floats.remove_at(i);
	}
}

// ---------------------------------------------------------------------------
// Enemies
// ---------------------------------------------------------------------------
fn void spawn_enemy(float x, float y, EnemyKind kind)
{
	if (g.enemies.size >= MAX_ENEMIES) return;
	Enemy e;
	e.id = g.nextEnemyId++;
	e.x = x;
	e.y = y;
	e.w = 28.0f;
	e.h = 26.0f;
	e.vx = 0;
	e.vy = 0;
	e.health = 18.0f;
	e.max = 18.0f;
	e.dmg = 5.0f;
	e.speed = 50.0f + frandom() * 35.0f;
	e.atkCd = 0;
	e.hurt = 0;
	e.kind = kind;
	e.flying = false;
	e.onGround = false;
	switch (kind)
	{
		case EnemyKind.BAT:
			e.w = 22.0f; e.h = 18.0f;
			e.health = 12.0f; e.max = 12.0f;
			e.dmg = 4.0f;
			e.speed = 90.0f;
			e.flying = true;
		case EnemyKind.ZOMBIE:
			e.w = 26.0f; e.h = 36.0f;
			e.health = 30.0f; e.max = 30.0f;
			e.dmg = 8.0f;
			e.speed = 40.0f;
		case EnemyKind.BLOOD:
			e.w = 30.0f; e.h = 30.0f;
			e.health = 40.0f; e.max = 40.0f;
			e.dmg = 12.0f;
			e.speed = 70.0f;
		default:
	}
	if (g.bloodMoon)
	{
		e.health = (float)(int)math::floor(e.health * 1.35f);
		e.max = e.health;
		e.dmg = (float)(int)math::floor(e.dmg * 1.25f);
		e.speed = e.speed * 1.12f;
	}
	g.enemies.push(e);
}

fn bool enemy_has_los(float x1, float y1, float x2, float y2)
{
	int steps = 14;
	for (int i = 1; i < steps; i++)
	{
		float t = (float)i / (float)steps;
		int gx = snap_i(x1 + (x2 - x1) * t);
		int gy = snap_i(y1 + (y2 - y1) * t);
		ItemId btype = block_at(gx, gy);
		if (btype != 0 && !is_non_collide(btype, gx, gy)) return false;
	}
	return true;
}

fn void update_enemies(float dt)
{
	if (!g.hostilesEnabled || g.creativeMode || !g.playerCreated) return;

	bool night = g.timeOfDay < 0.2f || g.timeOfDay > 0.82f;
	float spawnRate = g.bloodMoon ? 0.025f : (night ? 0.01f : 0.002f);
	int maxE = g.bloodMoon ? 14 : 8;

	if ((int)g.enemies.size < maxE && frandom() < spawnRate)
	{
		Player* p = &g.player;
		float sx = p.x + (frandom() > 0.5f ? 1.0f : -1.0f) * (380.0f + frandom() * 320.0f);
		int sy = surface_y(snap_i(sx), g.currentSeed);
		int roll = irandom(4);
		EnemyKind kind = EnemyKind.SLIME;
		if (roll == 2) {kind = EnemyKind.BAT;}
		else if (roll == 3) {kind = EnemyKind.ZOMBIE;}
		spawn_enemy(sx, (float)(sy - 50), kind);
	}

	Player* p = &g.player;
	for (int i = (int)g.enemies.size - 1; i >= 0; i--)
	{
		Enemy* e = &g.enemies[i];
		e.hurt = fmax(0.0f, e.hurt - dt);
		e.atkCd = fmax(0.0f, e.atkCd - dt);

		float cx = e.x + e.w / 2.0f;
		float cy = e.y + e.h / 2.0f;
		float pcx = p.x + (float)p.w / 2.0f;
		float pcy = p.y + (float)p.h / 2.0f;
		float dx = pcx - cx;
		float dy = pcy - cy;
		float dist = math::sqrt(dx * dx + dy * dy);

		if (dist < 520.0f && enemy_has_los(cx, cy, pcx, pcy))
		{
			e.vx = (dx > 0 ? 1.0f : -1.0f) * e.speed;
		}
		else
		{
			e.vx = 0;
		}

		if (e.flying)
		{
			e.vy = (dy > 0 ? 1.0f : -1.0f) * e.speed * 0.6f;
			e.x = e.x + e.vx * dt;
			e.y = e.y + e.vy * dt;
		}
		else
		{
			e.vy = e.vy + 920.0f * dt;

			if (math::abs(e.vx) > 1.0f && e.onGround)
			{
				float aheadX = e.x + (e.vx > 0 ? e.w + 2.0f : -2.0f);
				int aheadGy = snap_i(e.y + e.h) - 1;
				int aheadGx = snap_i(aheadX);
				ItemId wall = block_at(aheadGx, aheadGy);
				if (wall != 0)
				{
					BlockDef* wd = block_def(wall);
					if (!is_non_collide(wall, aheadGx, aheadGy)
					    && !(wd && wd.platform))
					{
						e.vy = -420.0f;
					}
				}
			}

			e.x = e.x + e.vx * dt;
			collide_body(&e.x, &e.y, &e.vx, &e.vy, e.w, e.h, &e.onGround, 0, false);
			e.y = e.y + e.vy * dt;
			collide_body(&e.x, &e.y, &e.vx, &e.vy, e.w, e.h, &e.onGround, 1, false);
		}

		bool adj = (dx * dx + dy * dy) < 34.0f * 34.0f;
		if (adj && e.atkCd <= 0 && e.hurt <= 0
		    && enemy_has_los(cx, cy, pcx, pcy))
		{
			p.health = fmax(0.0f, p.health - e.dmg);
			p.hurt = 0.4f;
			e.atkCd = 1.15f;
			char[64] buf;
			zfmt(&buf, "Hit -%d HP", (int)e.dmg);
			show_msg((ZString)&buf[0], 1.0f);
		}

		if (e.health <= 0)
		{
			spawn_drop((int)e.x, (int)e.y, ITEM_GEL, 1 + irandom(2));
			if (frandom() > 0.6f) spawn_drop((int)e.x, (int)e.y, ITEM_COAL, 1);
			g.enemies.remove_at(i);
		}
	}
}

fn void player_try_attack()
{
	ToolDef* tool = equipped_tool();
	int dmg = tool ? tool.dmg : 3;
	float reach = 52.0f;
	for (int i = 0; i < (int)g.enemies.size; i++)
	{
		Enemy* e = &g.enemies[i];
		float dx = (e.x + e.w / 2.0f) - (g.player.x + (float)g.player.w / 2.0f);
		float dy = (e.y + e.h / 2.0f) - (g.player.y + (float)g.player.h / 2.0f);
		if (dx * dx + dy * dy < reach * reach)
		{
			e.health = e.health - (float)dmg;
			e.hurt = 0.3f;
			e.vx = (dx > 0 ? 1.0f : -1.0f) * 130.0f;
			spawn_parts((int)e.x, (int)e.y, rgb(217, 51, 51), 5);
			spawn_damage_number(e.x + e.w / 2.0f, e.y, dmg, rgb(255, 204, 51));
			return;
		}
	}
}

// ---------------------------------------------------------------------------
// TNT
// ---------------------------------------------------------------------------
fn float tnt_falloff(float distTiles, float radius)
{
	if (distTiles >= radius) return 0;
	float t = 1.0f - distTiles / radius;
	return TNT_MIN_FRAC + (1.0f - TNT_MIN_FRAC) * t;
}

fn int tnt_damage_at(float maxDmg, float distTiles, float radius)
{
	float f = tnt_falloff(distTiles, radius);
	if (f <= 0) return 0;
	return (int)(maxDmg * f + 0.5f);
}

fn void tnt_ignite(int tx, int ty, float fuse)
{
	foreach (t : g.tntFuses)
	{
		if (t.tx == tx && t.ty == ty) return;
	}
	TntFuse f;
	f.tx = tx;
	f.ty = ty;
	f.timer = fuse > 0 ? fuse : TNT_FUSE;
	g.tntFuses.push(f);
	char[96] buf;
	zfmt(&buf, "TNT lit!  (%d / %d dmg)",
	                (int)TNT_PLAYER_DAMAGE, (int)TNT_ENEMY_DAMAGE);
	show_msg((ZString)&buf[0], 1.2f);
}

fn void tnt_damage_enemies_at(int tx, int ty)
{
	float cx = (float)tx + (float)GRID / 2.0f;
	float cy = (float)ty + (float)GRID / 2.0f;
	for (int i = 0; i < (int)g.enemies.size; i++)
	{
		Enemy* e = &g.enemies[i];
		float edx = (e.x + e.w / 2.0f) - cx;
		float edy = (e.y + e.h / 2.0f) - cy;
		float eDist = math::sqrt(edx * edx + edy * edy) / (float)GRID;
		int eDmg = tnt_damage_at(TNT_ENEMY_DAMAGE, eDist, TNT_ENTITY_RADIUS);
		if (eDmg > 0)
		{
			e.health = e.health - (float)eDmg;
			e.hurt = 0.4f;
			if (edx != 0) e.vx = e.vx + (edx > 0 ? 1.0f : -1.0f) * 180.0f;
			spawn_damage_number(e.x + e.w / 2.0f, e.y, eDmg, rgb(255, 179, 51));
		}
	}
}

fn void tnt_explode(int tx, int ty)
{
	float cx = (float)tx + (float)GRID / 2.0f;
	float cy = (float)ty + (float)GRID / 2.0f;
	spawn_parts(tx, ty, rgb(242, 115, 20), 28);
	spawn_parts(tx, ty, rgb(255, 217, 77), 12);

	List{long} toKill;
	List{long} chained;
	toKill.init(mem);
	chained.init(mem);
	defer toKill.free();
	defer chained.free();

	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		foreach (e : ch.fg.iter())
		{
			int bx = key_x(e.key);
			int by = key_y(e.key);
			float bdx = (float)bx + (float)GRID / 2.0f - cx;
			float bdy = (float)by + (float)GRID / 2.0f - cy;
			float distTiles = math::sqrt(bdx * bdx + bdy * bdy) / (float)GRID;
			if (e.value == ITEM_TNT && !(bx == tx && by == ty)
			    && distTiles <= TNT_BLOCK_RADIUS + 1.0f)
			{
				chained.push(e.key);
			}
			else if (distTiles < TNT_BLOCK_RADIUS)
			{
				BlockDef* def = block_def(e.value);
				float power = TNT_BLAST_POWER * tnt_falloff(distTiles, TNT_BLOCK_RADIUS);
				if (def && e.value != ITEM_CAVEBLOCK && def.hard < power)
				{
					toKill.push(e.key);
				}
			}
		}
	}

	foreach (k : toKill)
	{
		(void)destroy_block(key_x(k), key_y(k), false);
	}
	foreach (k : chained)
	{
		tnt_ignite(key_x(k), key_y(k), TNT_CHAIN_DELAY);
	}

	Player* p = &g.player;
	float pdx = (p.x + (float)p.w / 2.0f) - cx;
	float pdy = (p.y + (float)p.h / 2.0f) - cy;
	float pDist = math::sqrt(pdx * pdx + pdy * pdy) / (float)GRID;
	int pDmg = tnt_damage_at(TNT_PLAYER_DAMAGE, pDist, TNT_ENTITY_RADIUS);
	if (pDmg > 0)
	{
		p.health = fmax(0.0f, p.health - (float)pDmg);
		p.hurt = 0.5f;
		float kb = TNT_KNOCKBACK * (1.0f - pDist / TNT_ENTITY_RADIUS);
		if (pdx != 0 || pdy != 0)
		{
			float len = math::sqrt(pdx * pdx + pdy * pdy);
			p.vx = p.vx + (pdx / len) * kb;
			p.vy = p.vy + (pdy / len) * kb * 0.7f - 80.0f;
		}
		else
		{
			p.vy = p.vy - 180.0f;
		}
		spawn_damage_number(p.x + (float)p.w / 2.0f, p.y, pDmg, rgb(255, 71, 51));
		char[96] buf;
		zfmt(&buf, "TNT  -%d HP  (max %d)", pDmg, (int)TNT_PLAYER_DAMAGE);
		show_msg((ZString)&buf[0], 2.0f);
	}

	tnt_damage_enemies_at(tx, ty);
}

fn void update_tnt(float dt)
{
	for (int i = (int)g.tntFuses.size - 1; i >= 0; i--)
	{
		TntFuse* t = &g.tntFuses[i];
		t.timer = t.timer - dt;
		if (t.timer <= 0)
		{
			int tx = t.tx;
			int ty = t.ty;
			if (block_at(tx, ty) == ITEM_TNT)
			{
				(void)remove_at(tx, ty, false);
				remember_edit(tx, ty, false, 0);
				be_destroy(tx, ty);
			}
			tnt_explode(tx, ty);
			g.tntFuses.remove_at(i);
		}
	}
}

// ---------------------------------------------------------------------------
// Water flow
// ---------------------------------------------------------------------------
fn int water_level_at(int tx, int ty)
{
	if (try lvl = g.waterLevels.get(tile_key(tx, ty))) return lvl;
	return 0;
}

fn void water_set_level(int tx, int ty, int level)
{
	g.waterLevels.set(tile_key(tx, ty), level);
}

fn void water_try_flow(int tx, int ty, int level, HashMap{long, int}* pending)
{
	ItemId btype = block_at(tx, ty);
	if (btype != 0)
	{
		if (btype != ITEM_WATER) return;
		if (water_level_at(tx, ty) >= level) return;
	}
	long k = tile_key(tx, ty);
	bool better = true;
	if (try existing = pending.get(k))
	{
		if (existing >= level) better = false;
	}
	if (better) pending.set(k, level);
}

fn bool is_air_for_water(int tx, int ty)
{
	ItemId btype = block_at(tx, ty);
	if (btype == 0) return true;
	BlockDef* def = block_def(btype);
	return def && !def.solid && !def.liquid;
}

fn void water_tick()
{
	if (g.tickCount % WATER_PERIOD != 0) return;

	List{long} waters;
	List{long} decays;
	HashMap{long, int} pending;
	waters.init(mem);
	decays.init(mem);
	pending.init(mem);
	defer waters.free();
	defer decays.free();
	defer pending.free();

	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		foreach (e : ch.fg.iter())
		{
			if (e.value == ITEM_WATER) waters.push(e.key);
		}
	}

	foreach (k : waters)
	{
		int bx = key_x(k);
		int by = key_y(k);
		int lvl = water_level_at(bx, by);
		if (lvl == 0)
		{
			lvl = 8;
			water_set_level(bx, by, 8);
		}
		int belowY = by + GRID;
		bool acted = false;

		if (block_at(bx, belowY) == 0)
		{
			water_try_flow(bx, belowY, 8, &pending);
			acted = true;
		}

		if (!acted && lvl > 1 && lvl < 8)
		{
			int spread = lvl - 1;
			water_try_flow(bx - GRID, by, spread, &pending);
			water_try_flow(bx + GRID, by, spread, &pending);
		}

		if (!acted && lvl < 8)
		{
			bool leftWater = block_at(bx - GRID, by) == ITEM_WATER;
			bool rightWater = block_at(bx + GRID, by) == ITEM_WATER;
			bool aboveWater = block_at(bx, by - GRID) == ITEM_WATER;
			if (!leftWater && !rightWater && !aboveWater) decays.push(k);
		}
	}

	foreach (p : pending.iter())
	{
		int px = key_x(p.key);
		int py = key_y(p.key);
		if (!get_chunk(chunk_index(px))) continue;
		if (block_at(px, py) == 0)
		{
			if (!place_block(px, py, ITEM_WATER, false)) continue;
		}
		water_set_level(px, py, p.value);
	}

	foreach (k : decays)
	{
		int bx = key_x(k);
		int by = key_y(k);
		(void)remove_at(bx, by, false);
		g.waterLevels.remove(k);
		remember_edit(bx, by, false, 0);
	}
}

// ---------------------------------------------------------------------------
// Falling blocks (sand / gravel)
// ---------------------------------------------------------------------------
fn void update_falling_blocks()
{
	if (g.tickCount % 3 != 0) return;

	List{long} falling;
	falling.init(mem);
	defer falling.free();

	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		foreach (e : ch.fg.iter())
		{
			BlockDef* def = block_def(e.value);
			if (def && def.falls) falling.push(e.key);
		}
	}

	int n = 0;
	foreach (k : falling)
	{
		int bx = key_x(k);
		int by = key_y(k);
		ItemId btype = block_at(bx, by);
		BlockDef* def = block_def(btype);
		if (!def || !def.falls) continue;
		int belowY = by + GRID;
		ItemId below = block_at(bx, belowY);
		bool drop = below == 0;
		if (!drop)
		{
			BlockDef* bd = block_def(below);
			drop = is_non_collide(below, bx, belowY) || (bd && bd.liquid);
		}
		if (drop)
		{
			(void)remove_at(bx, by, false);
			remember_edit(bx, by, false, 0);
			(void)place_block(bx, belowY, btype, false);
			n++;
			if (n > 35) break;
		}
	}
}

// ---------------------------------------------------------------------------
// Block entities
// ---------------------------------------------------------------------------
fn BlockEntity* be_get(int tx, int ty)
{
	if (try e = g.entities.get(tile_key(tx, ty))) return e;
	return null;
}

fn BlockEntity* be_create(int tx, int ty, BlockEntityKind kind)
{
	long k = tile_key(tx, ty);
	if (try existing = g.entities.get(k)) return existing;
	BlockEntity beValue;
	BlockEntity* be = malloc(@sizeof(beValue));
	if (!be) return null;
	*be = {};
	be.kind = kind;
	be.x = tx;
	be.y = ty;
	be.position = 0;
	g.entities.set(k, be);
	return be;
}

fn void be_destroy(int tx, int ty)
{
	long k = tile_key(tx, ty);
	if (try e = g.entities.get(k))
	{
		g.entities.remove(k);
		free(e);
	}
}

fn float platform_offset(int position)
{
	switch (position)
	{
		case 1: return 12.0f;
		case 2: return (float)(GRID - 8);
		default: return 0.0f;
	}
}

fn SmeltRecipe* find_smelt_recipe(ItemId input)
{
	for (int i = 0; i < smeltRecipeCount; i++)
	{
		if (smeltRecipes[i].inId == input) return &smeltRecipes[i];
	}
	return null;
}

fn int fuel_ticks(ItemId id)
{
	switch (id)
	{
		case ITEM_COAL: return 1600;
		case ITEM_LOG: return 300;
		case ITEM_BIRCHLOG: return 300;
		case ITEM_PLANKS: return 300;
		case ITEM_PINEPLANKS: return 300;
		case ITEM_BIRCHPLANKS: return 300;
		case ITEM_TORCH: return 100;
		default: return 0;
	}
}

fn void tick_furnaces()
{
	List{long} stale;
	stale.init(mem);
	defer stale.free();

	foreach (e : g.entities.iter())
	{
		BlockEntity* ent = e.value;
		if (!ent || ent.kind != BlockEntityKind.FURNACE) continue;
		if (block_at(ent.x, ent.y) != ITEM_FURNACE)
		{
			stale.push(e.key);
			continue;
		}

		SmeltRecipe* rec = ent.input.id != 0 && ent.input.count > 0
		                  ? find_smelt_recipe(ent.input.id) : null;
		bool canSmelt = rec != null && (ent.output.id == 0
		    || (ent.output.id == rec.outId
		        && ent.output.count + rec.outN <= max_stack(rec.outId)));

		if (ent.fuelTime <= 0 && canSmelt && ent.fuel.id != 0 && ent.fuel.count > 0)
		{
			int ft = fuel_ticks(ent.fuel.id);
			if (ft > 0)
			{
				ent.maxFuelTime = ft;
				ent.fuelTime = ft;
				ent.fuel.count--;
				if (ent.fuel.count <= 0) ent.fuel = { 0, 0 };
			}
		}

		if (ent.fuelTime > 0 && canSmelt)
		{
			ent.fuelTime--;
			ent.progress++;
			if (ent.progress >= 200)
			{
				ent.progress = 0;
				ent.input.count--;
				if (ent.input.count <= 0) ent.input = { 0, 0 };
				if (ent.output.id != 0)
				{
					ent.output.count += rec.outN;
				}
				else
				{
					ent.output = { rec.outId, rec.outN };
				}
			}
		}
		else
		{
			ent.progress = maxi(0, ent.progress - 2);
		}
	}

	foreach (k : stale)
	{
		if (try ent = g.entities.get(k))
		{
			g.entities.remove(k);
			free(ent);
		}
	}
}

// ---------------------------------------------------------------------------
// Mining / placing / interaction
// ---------------------------------------------------------------------------
fn float mine_speed(ItemId btype)
{
	BlockDef* def = block_def(btype);
	if (!def || def.hard <= 0) return 99.0f;
	if (g.creativeMode) return 99.0f;
	ToolDef* tool = equipped_tool();
	float mult = 0.35f;
	if (tool)
	{
		if (def.tool == ToolKind.ANY || def.tool == tool.type
		    || (tool.type == ToolKind.HAMMER && def.tool != ToolKind.SWORD))
		{
			mult = tool.speed * (tool.power / fmax(def.hard, 0.4f));
		}
		else
		{
			mult = 0.22f;
		}
	}
	else if (def.tool == ToolKind.ANY)
	{
		mult = 0.65f;
	}
	return mult;
}

fn void mining_cancel()
{
	g.miningActive = false;
	g.miningProgress = 0;
	g.miningX = 0;
	g.miningY = 0;
}

fn void mining_block_action(int tx, int ty, int btn)
{
	int gx = tx;
	int gy = ty;
	float dx = (float)gx + (float)GRID / 2.0f
	         - (g.player.x + (float)g.player.w / 2.0f);
	float dy = (float)gy + (float)GRID / 2.0f
	         - (g.player.y + (float)g.player.h / 2.0f);
	if (dx * dx + dy * dy > 150.0f * 150.0f) return;

	if (btn == 0)
	{
		ItemId sel = selected_id();
		ItemId existing = block_at(gx, gy);

		if (sel != 0 && is_tool(sel) && tool_def(sel).type == ToolKind.SWORD)
		{
			player_try_attack();
			return;
		}

		if (sel == ITEM_WRENCH && existing == ITEM_PLATFORM)
		{
			BlockEntity* be = be_get(gx, gy);
			if (!be) be = be_create(gx, gy, BlockEntityKind.PLATFORM);
			be.position = (be.position + 1) % 3;
			ZString[3] names = { "top", "middle", "bottom" };
			char[64] buf;
			zfmt(&buf, "Platform: %s", names[be.position]);
			show_msg((ZString)&buf[0], 1.0f);
			return;
		}

		if (existing == ITEM_TNT && sel == ITEM_TORCH)
		{
			tnt_ignite(gx, gy, TNT_FUSE);
			return;
		}

		if (existing != 0)
		{
			BlockDef* edef = block_def(existing);
			if (edef && edef.interact != InteractKind.NONE)
			{
				interact_at(gx, gy);
				return;
			}
		}

		if (sel != 0 && is_block(sel) && sel != ITEM_CAVEBLOCK)
		{
			if (block_at(gx, gy) == 0)
			{
				if (g.creativeMode || rem_inv(sel, 1))
				{
					(void)place_block(gx, gy, sel, g.backgroundMode);
				}
				else
				{
					char[96] buf;
					zfmt(&buf, "No %s", item_name(sel));
					show_msg((ZString)&buf[0], 1.3f);
				}
			}
		}
	}
	else if (btn == 1)
	{
		ItemId btype = g.backgroundMode ? bg_at(gx, gy) : block_at(gx, gy);
		if (btype != 0 && btype != ITEM_CAVEBLOCK)
		{
			float spd = mine_speed(btype);
			if (g.miningActive && g.miningX == gx && g.miningY == gy
			    && g.miningBg == g.backgroundMode)
			{
				g.miningProgress += spd * 0.018f * 9.0f;
			}
			else
			{
				g.miningActive = true;
				g.miningX = gx;
				g.miningY = gy;
				g.miningBg = g.backgroundMode;
				g.miningProgress = spd * 0.12f;
			}
			BlockDef* def = block_def(btype);
			float hard = def ? def.hard : 1.0f;
			if (g.creativeMode || g.miningProgress >= hard)
			{
				(void)destroy_block(gx, gy, g.backgroundMode);
				mining_cancel();
			}
		}
		else
		{
			mining_cancel();
		}
	}
	else if (btn == 2)
	{
		ItemId targetId = block_at(gx, gy);
		if (targetId == 0) return;
		int total = total_slots();
		int found = -1;
		for (int i = 0; i < total; i++)
		{
			if (g.player.inv[i].id == targetId)
			{
				found = i;
				break;
			}
		}
		if (found < 0)
		{
			for (int i = 0; i < total; i++)
			{
				BlockDef* sdef = block_def(g.player.inv[i].id);
				if (sdef && sdef.drop == targetId)
				{
					found = i;
					break;
				}
			}
		}
		if (found < 0)
		{
			char[96] buf;
			zfmt(&buf, "Not in inventory: %s", item_name(targetId));
			show_msg((ZString)&buf[0], 1.2f);
			return;
		}
		if (found < HOTBAR_SLOTS)
		{
			g.player.hot = found;
		}
		else
		{
			Stack tmp = g.player.inv[g.player.hot];
			g.player.inv[g.player.hot] = g.player.inv[found];
			g.player.inv[found] = tmp;
		}
		char[96] buf;
		zfmt(&buf, "Selected %s", item_name(targetId));
		show_msg((ZString)&buf[0], 0.9f);
	}
}
