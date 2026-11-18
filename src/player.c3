// Player creation, physics, hunger and interaction.
module minecraft;
import rl;
import std::math;
import std::core::string;

// ---------------------------------------------------------------------------
// Construction
// ---------------------------------------------------------------------------
fn void player_create()
{
	Player* p = &g.player;
	*p = {};
	p.w = 32;
	p.h = 32;
	p.speed = 198.0f;
	p.jump = 445.0f;
	p.grav = 1280.0f;
	p.health = 100.0f;
	p.maxHealth = 100.0f;
	p.hunger = 100.0f;
	p.maxHunger = 100.0f;
	p.facing = 1;
	g.playerCreated = true;
}

fn void player_fill_creative()
{
	inv_clear();
	int slot = 0;
	for (ItemId id = 1; id < ITEM_COUNT; id++)
	{
		if (id == ITEM_CAVEBLOCK) continue;
		if (!is_block(id) && !is_tool(id) && !is_item(id)) continue;
		if (slot >= INVENTORY_SLOTS) break;
		g.player.inv[slot] = { id, is_tool(id) ? 1 : 999 };
		slot++;
	}
	g.player.hot = 0;
	char[160] buf;
	zfmt(&buf, "Creative inventory loaded (%d items)", slot);
	show_msg((ZString)&buf[0], 2.5f);
}

// ---------------------------------------------------------------------------
// Generic tile collision (player and enemies)
// ---------------------------------------------------------------------------
fn void collide_body(float* px, float* py, float* pvx, float* pvy,
                     float pw, float ph, bool* onGround, int axis, bool dropThrough)
{
	float ox = *px;
	float oy = *py;
	int left = snap_i(ox) - GRID;
	int right = (int)(ox + pw) + GRID;
	int top = snap_i(oy) - GRID;
	int bot = (int)(oy + ph) + GRID;
	*onGround = false;

	for (int x = left; x <= right; x += GRID)
	{
		for (int y = top; y <= bot; y += GRID)
		{
			ItemId btype = block_at(x, y);
			if (btype == 0) continue;
			BlockDef* def = block_def(btype);
			if (!def) continue;

			if (def.platform)
			{
				if (axis == 1 && *pvy >= 0 && !dropThrough)
				{
					BlockEntity* be = be_get(x, y);
					int pos = be ? be.position : 0;
					float platTop = (float)y + platform_offset(pos);
					float feet = oy + ph;
					if (feet >= platTop - 2.0f && feet <= platTop + 12.0f)
					{
						if (ox < (float)(x + GRID) && ox + pw > (float)x)
						{
							*py = platTop - ph;
							*onGround = true;
							*pvy = 0;
						}
					}
				}
				continue;
			}

			if (is_non_collide(btype, x, y)) continue;

			if (ox < (float)(x + GRID) && ox + pw > (float)x &&
			    oy < (float)(y + GRID) && oy + ph > (float)y)
			{
				if (axis == 0)
				{
					if (*pvx > 0)
					{
						*px = (float)x - pw;
					}
					else if (*pvx < 0)
					{
						*px = (float)x + (float)GRID;
					}
					*pvx = 0;
				}
				else
				{
					if (*pvy > 0)
					{
						*py = (float)y - ph;
						*onGround = true;
						*pvy = 0;
					}
					else if (*pvy < 0)
					{
						*py = (float)y + (float)GRID;
						*pvy = 0;
					}
				}
			}
		}
	}
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------
fn bool player_on_climbable()
{
	Player* p = &g.player;
	float cx = p.x + (float)p.w / 2.0f;
	float cy = p.y + (float)p.h / 2.0f;
	int gx = snap_i(cx);
	int gy = snap_i(cy);
	for (int ox = -GRID; ox <= GRID; ox += GRID)
	{
		for (int oy = -GRID; oy <= GRID; oy += GRID)
		{
			ItemId btype = block_at(gx + ox, gy + oy);
			if (btype == 0) continue;
			BlockDef* def = block_def(btype);
			if (!def || !def.climb) continue;
			int bx = gx + ox;
			int by = gy + oy;
			if (p.x < (float)(bx + GRID) && p.x + (float)p.w > (float)bx &&
			    p.y < (float)(by + GRID) && p.y + (float)p.h > (float)by)
			{
				return true;
			}
		}
	}
	return false;
}

fn bool player_in_water()
{
	Player* p = &g.player;
	float cx = p.x + (float)p.w / 2.0f;
	float cy = p.y + (float)p.h * 0.6f;
	ItemId btype = block_at(snap_i(cx), snap_i(cy));
	if (btype == 0) return false;
	BlockDef* def = block_def(btype);
	return def && def.liquid;
}

fn float nearest_torch_dist(float px, float py)
{
	float best = 1.0e9f;
	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		foreach (e : ch.fg.iter())
		{
			if (e.value != ITEM_TORCH) continue;
			float dx = (float)(key_x(e.key) + GRID / 2) - px;
			float dy = (float)(key_y(e.key) + GRID / 2) - py;
			float d = dx * dx + dy * dy;
			if (d < best) best = d;
		}
	}
	return math::sqrt(best);
}

// ---------------------------------------------------------------------------
// Interaction
// ---------------------------------------------------------------------------
fn void screen_to_world(int sx, int sy, float* wx, float* wy)
{
	*wx = g.cameraX + (float)sx - (float)rl::getScreenWidth() / 2.0f;
	*wy = g.cameraY + (float)sy - (float)rl::getScreenHeight() / 2.0f;
}

fn bool block_is_interactive(ItemId id)
{
	BlockDef* def = block_def(id);
	return def && def.interact != InteractKind.NONE;
}

fn bool player_find_interactable(int* outX, int* outY)
{
	float reach = (float)(GRID * 5);
	float px = g.player.x + (float)g.player.w / 2.0f;
	float py = g.player.y + (float)g.player.h / 2.0f;
	float bestD = reach * reach;
	bool found = false;
	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		foreach (e : ch.fg.iter())
		{
			if (!block_is_interactive(e.value)) continue;
			int bx = key_x(e.key);
			int by = key_y(e.key);
			float dx = (float)bx + (float)GRID / 2.0f - px;
			float dy = (float)by + (float)GRID / 2.0f - py;
			float d = dx * dx + dy * dy;
			if (d < bestD)
			{
				bestD = d;
				*outX = bx;
				*outY = by;
				found = true;
			}
		}
	}
	return found;
}

fn bool player_find_interaction_target(int* outX, int* outY)
{
	float wx;
	float wy;
	screen_to_world(rl::getMouseX(), rl::getMouseY(), &wx, &wy);
	int gx = snap_i(wx);
	int gy = snap_i(wy);
	ItemId hovered = block_at(gx, gy);
	if (hovered != 0 && block_is_interactive(hovered))
	{
		float px = g.player.x + (float)g.player.w / 2.0f;
		float py = g.player.y + (float)g.player.h / 2.0f;
		float dx = (float)gx + (float)GRID / 2.0f - px;
		float dy = (float)gy + (float)GRID / 2.0f - py;
		float reach = (float)(GRID * 5);
		if (dx * dx + dy * dy < reach * reach)
		{
			*outX = gx;
			*outY = gy;
			return true;
		}
	}
	return player_find_interactable(outX, outY);
}

fn void interact_at(int tx, int ty)
{
	ItemId id = block_at(tx, ty);
	BlockDef* def = block_def(id);
	if (!def || def.interact == InteractKind.NONE) return;

	switch (def.interact)
	{
		case InteractKind.DOOR:
			long k = tile_key(tx, ty);
			bool open = false;
			if (try v = g.openDoors.get(k)) open = v;
			g.openDoors.set(k, !open);
			show_msg(!open ? "Door opened" : "Door closed", 1.0f);
		case InteractKind.BED:
			g.player.spawnX = (float)tx;
			g.player.spawnY = (float)ty - (float)g.player.h;
			show_msg("Spawn set", 1.5f);
			if (g.timeOfDay < 0.2f || g.timeOfDay > 0.8f)
			{
				if (g.bloodMoon)
				{
					show_msg("Can't sleep during Blood Moon!", 2.5f);
				}
				else
				{
					g.timeOfDay = 0.28f;
					show_msg("Slept until morning", 2.0f);
				}
			}
		case InteractKind.WORKBENCH:
		case InteractKind.ANVIL:
		case InteractKind.FURNACE:
		case InteractKind.CHEST:
			g.stationOpen = true;
			g.inventoryOpen = false;
			g.stationFurnaceValid = false;
			g.stationChestValid = false;
			if (def.interact == InteractKind.FURNACE)
			{
				g.stationFurnaceX = tx;
				g.stationFurnaceY = ty;
				g.stationFurnaceValid = true;
				(void)be_create(tx, ty, BlockEntityKind.FURNACE);
				g.stationTab = 2;
			}
			else if (def.interact == InteractKind.CHEST)
			{
				g.stationChestX = tx;
				g.stationChestY = ty;
				g.stationChestValid = true;
				(void)be_create(tx, ty, BlockEntityKind.CHEST);
				g.stationTab = 3;
			}
			else
			{
				g.stationTab = 1;
			}
		case InteractKind.LOGIC:
			logic_player_toggle(tx, ty);
		case InteractKind.CIRCUITBOARD:
			logic_open_board(tx, ty);
		case InteractKind.PROGRAMMABLE:
			logic_open_program(tx, ty);
		case InteractKind.SIGNALSOURCE:
			logic_open_signal(tx, ty);
		default:
	}
}

fn void player_do_interact()
{
	int tx;
	int ty;
	if (!player_find_interaction_target(&tx, &ty))
	{
		show_msg("Nothing to use nearby", 1.2f);
		return;
	}
	interact_at(tx, ty);
}

fn bool player_try_eat()
{
	ItemId id = selected_id();
	int hp = consumable_hp(id);
	int hunger = consumable_hunger(id);
	if (hp == 0 && hunger == 0)
	{
		show_msg("Select food (Mushroom, Apple, Gel...)", 1.5f);
		return false;
	}
	if (g.player.health >= g.player.maxHealth && g.player.hunger >= g.player.maxHunger)
	{
		show_msg("Already full", 1.2f);
		return false;
	}
	if (!rem_inv(id, 1)) return false;
	g.player.health = fmin(g.player.maxHealth, g.player.health + (float)hp);
	g.player.hunger = fmin(g.player.maxHunger, g.player.hunger + (float)hunger);
	char[96] buf;
	zfmt(&buf, "+%d HP  +%d food", hp, hunger);
	show_msg((ZString)&buf[0], 1.4f);
	return true;
}

fn void update_blood_moon()
{
	bool isNight = g.timeOfDay < 0.18f || g.timeOfDay > 0.82f;
	if (isNight)
	{
		int cycle = (int)(rl::getTime() / (double)DAY_LEN);
		if (g.bloodMoonChecked != cycle)
		{
			g.bloodMoonChecked = cycle;
			if (cycle % 8 == 0 && hash1(cycle, g.currentSeed, 200) < 0.03f)
			{
				g.bloodMoon = true;
				show_msg("A Blood Moon is rising...", 4.0f);
			}
			else
			{
				g.bloodMoon = false;
			}
		}
	}
	else
	{
		g.bloodMoon = false;
	}
}

// ---------------------------------------------------------------------------
// Update
// ---------------------------------------------------------------------------
fn void player_update(float dt)
{
	Player* p = &g.player;
	p.hurt = fmax(0.0f, p.hurt - dt);

	if (!g.creativeMode) p.flying = false;

	if (!g.creativeMode)
	{
		float drain = 0.05f + math::abs(p.vx) / p.speed * 0.08f;
		p.hunger = fmax(0.0f, p.hunger - dt * drain);
		if (p.hunger <= 0)
		{
			p.health = fmax(0.0f, p.health - dt * 1.0f);
		}
		if (p.hunger > 55.0f && p.health < p.maxHealth)
		{
			p.health = fmin(p.maxHealth, p.health + dt * 2.0f);
			p.hunger = fmax(0.0f, p.hunger - dt * 1.2f);
		}
	}

	float move = 0;
	if (rl::isKeyDown(rl::KEY_A) || rl::isKeyDown(rl::KEY_LEFT)) move -= 1;
	if (rl::isKeyDown(rl::KEY_D) || rl::isKeyDown(rl::KEY_RIGHT)) move += 1;
	p.vx = move * p.speed;
	if (move != 0) p.facing = (int)move;

	bool upHeld = rl::isKeyDown(rl::KEY_W) || rl::isKeyDown(rl::KEY_UP)
	           || rl::isKeyDown(rl::KEY_SPACE);
	bool downHeld = rl::isKeyDown(rl::KEY_S) || rl::isKeyDown(rl::KEY_DOWN);

	bool climbing = player_on_climbable();
	p.climbing = climbing;
	bool inWater = player_in_water();

	if (g.creativeMode && p.flying)
	{
		p.vy = 0;
		if (upHeld) p.vy = -240.0f;
		if (downHeld) p.vy = 240.0f;
		p.fallSpeed = 0;
	}
	else if (climbing && !g.ghostMode)
	{
		p.vy = 0;
		if (upHeld) p.vy = -120.0f;
		if (downHeld) p.vy = 120.0f;
		p.fallSpeed = 0;
	}
	else if (g.ghostMode)
	{
		p.vy = 0;
		if (upHeld) p.y -= 210.0f * dt;
		if (downHeld) p.y += 210.0f * dt;
	}
	else if (inWater)
	{
		p.vy = p.vy + p.grav * 0.18f * dt;
		p.vy = p.vy * (1.0f - 2.4f * dt);
		if (upHeld)
		{
			p.vy = fmax(-160.0f, p.vy - 900.0f * dt);
		}
		else if (downHeld)
		{
			p.vy = fmin(160.0f, p.vy + 600.0f * dt);
		}
		p.vx = p.vx * 0.72f;
		p.fallSpeed = 0;
	}
	else
	{
		p.vy = p.vy + p.grav * dt;
		if (p.vy > 0) p.fallSpeed = p.vy;
	}

	p.x = p.x + p.vx * dt;
	if (!g.ghostMode) collide_body(&p.x, &p.y, &p.vx, &p.vy,
	                               (float)p.w, (float)p.h, &p.onGround, 0, false);

	p.y = p.y + p.vy * dt;
	if (!g.ghostMode)
	{
		float wasFalling = p.fallSpeed;
		collide_body(&p.x, &p.y, &p.vx, &p.vy,
		             (float)p.w, (float)p.h, &p.onGround, 1, downHeld);
		if (p.onGround && !g.creativeMode && wasFalling > 560.0f)
		{
			int dmg = (int)((wasFalling - 560.0f) / 75.0f);
			if (dmg > 0)
			{
				p.health = fmax(0.0f, p.health - (float)dmg);
				char[64] buf;
				zfmt(&buf, "Fall -%d", dmg);
				show_msg((ZString)&buf[0], 1.4f);
			}
		}
		if (p.onGround)
		{
			p.fallSpeed = 0;
			p.lastJump = 0;
		}
	}

	if (p.health <= 0)
	{
		show_msg("You died - returning to spawn", 3.0f);
		p.health = p.maxHealth;
		p.hunger = p.maxHunger;
		p.x = p.spawnX;
		p.y = p.spawnY;
		p.vx = 0;
		p.vy = 0;
	}
}

fn void player_jump_or_drop()
{
	Player* p = &g.player;
	double now = rl::getTime();

	if (g.creativeMode)
	{
		if (p.onGround)
		{
			p.vy = -p.jump;
			p.onGround = false;
			p.lastJump = now;
			return;
		}
		if (p.lastJump > 0 && (now - p.lastJump) < 0.35)
		{
			p.flying = !p.flying;
			p.vy = 0;
			p.lastJump = 0;
			show_msg(p.flying ? "Fly: ON   (W up / S down)" : "Fly: OFF", 1.6f);
			return;
		}
		p.lastJump = now;
		return;
	}

	if (!p.onGround || g.ghostMode || p.climbing) return;
	if (rl::isKeyDown(rl::KEY_S) || rl::isKeyDown(rl::KEY_DOWN))
	{
		p.y += 4.0f;
		p.onGround = false;
	}
	else
	{
		p.vy = -p.jump;
		p.onGround = false;
	}
}
