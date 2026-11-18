// Immediate-mode UI: menus, HUD, inventory, stations, logic editors, commands.
module minecraft;
import rl;
import std::collections::list;
import std::collections::map;
import std::core::string;
import std::math;
import std::io::file;

// ---------------------------------------------------------------------------
// Texture cache
// ---------------------------------------------------------------------------
struct UiTex
{
	Texture2D tex;
	int       state; // 0 untried, 1 missing, 2 loaded
}

UiTex[ITEM_COUNT] uiItemTex;
UiTex uiPlayerTex;
UiTex uiCursorTex;

fn void ui_texture_once(UiTex* slot, ZString path)
{
	slot.state = 1;
	if (!path || !file_exists(path)) return;
	Texture2D t = rl::loadTexture(path);
	if (t.id == 0) return;
	rl::setTextureFilter(t, rl::TEXTURE_FILTER_POINT);
	slot.tex = t;
	slot.state = 2;
}

fn bool file_exists(ZString path)
{
	return file::exists((String)path.str_view());
}

fn ZString ui_texture_name(ItemId id, ZString* kind)
{
	*kind = "blocks";
	switch (id)
	{
		case ITEM_GRASS: return "Grass";
		case ITEM_DIRT: return "Dirt";
		case ITEM_STONE: return "Stone";
		case ITEM_DEEPSTONE: return "DeepStone";
		case ITEM_LOG: return "Log";
		case ITEM_LEAVES: return "Leaves";
		case ITEM_PINELEAVES: return "PineLeaves";
		case ITEM_GOLD: return "Gold";
		case ITEM_IRON: return "Iron";
		case ITEM_COPPER: return "Copper";
		case ITEM_REDSTONE: return "Redstone";
		case ITEM_COAL: return "Coal";
		case ITEM_SAND: return "Sand";
		case ITEM_SANDSTONE: return "Sandstone";
		case ITEM_GLASS: return "Glass";
		case ITEM_WATER: return "Water";
		case ITEM_ICE: return "Ice";
		case ITEM_TNT: return "Tnt";
		case ITEM_PLANKS: return "BirchPlanks";
		case ITEM_PINEPLANKS: return "PinePlanks";
		case ITEM_BIRCHPLANKS: return "BirchPlanks";
		case ITEM_WORKBENCH: return "Workbench";
		case ITEM_FURNACE: return "Furnace";
		case ITEM_TORCH: return "Torch";
		case ITEM_BRICK: return "Brick";
		case ITEM_COBBLE: return "Cobble";
		case ITEM_CLAY: return "Clay";
		case ITEM_SNOW: return "Snow";
		case ITEM_CACTUS: return "Cactus";
		case ITEM_MUSHROOM: return "Mushroom";
		case ITEM_CRYSTAL: return "Crystal";
		case ITEM_LADDER: return "Ladder";
		case ITEM_DOOR: return "Door";
		case ITEM_BOOKSHELF: return "Bookshelf";
		case ITEM_ANVIL: return "Anvil";
		case ITEM_GRAVEL: return "Gravel";
		case ITEM_BIRCHLOG: return "BirchLog";

		case ITEM_WOODPICKAXE: *kind = "tools"; return "WoodPickaxe";
		case ITEM_STONEPICKAXE: *kind = "tools"; return "StonePickaxe";
		case ITEM_IRONPICKAXE: *kind = "tools"; return "IronPickaxe";
		case ITEM_GOLDPICKAXE: *kind = "tools"; return "GoldPickaxe";
		case ITEM_CRYSTALPICK: *kind = "tools"; return "CrystalPick";
		case ITEM_WOODAXE: *kind = "tools"; return "WoodAxe";
		case ITEM_STONEAXE: *kind = "tools"; return "StoneAxe";
		case ITEM_IRONAXE: *kind = "tools"; return "IronAxe";
		case ITEM_WOODSWORD: *kind = "tools"; return "WoodSword";
		case ITEM_STONESWORD: *kind = "tools"; return "StoneSword";
		case ITEM_IRONSWORD: *kind = "tools"; return "IronSword";
		case ITEM_GOLDSWORD: *kind = "tools"; return "GoldSword";
		case ITEM_CRYSTALSWORD: *kind = "tools"; return "CrystalSword";
		case ITEM_WOODHAMMER: *kind = "tools"; return "WoodHammer";
		case ITEM_STONEHAMMER: *kind = "tools"; return "StoneHammer";
		case ITEM_WRENCH: *kind = "tools"; return "Wrench";

		case ITEM_IRONBAR: *kind = "items"; return "IronBar";
		case ITEM_COPPERBAR: *kind = "items"; return "CopperBar";
		case ITEM_GOLDBAR: *kind = "items"; return "GoldBar";
		case ITEM_GEL: *kind = "items"; return "Gel";
		case ITEM_STRING: *kind = "items"; return "String";
		case ITEM_PAPER: *kind = "items"; return "Paper";
		case ITEM_BOOK: *kind = "items"; return "Book";
		case ITEM_COOKEDMUSHROOM: *kind = "items"; return "CookedMushroom";
		case ITEM_APPLE: *kind = "items"; return "Apple";
		default: return null;
	}
}

fn UiTex* ui_tex_for(ItemId id)
{
	if (id <= 0 || id >= ITEM_COUNT) return null;
	UiTex* slot = &uiItemTex[id];
	if (slot.state != 0) return slot;
	ZString kind;
	ZString name = ui_texture_name(id, &kind);
	if (!name)
	{
		slot.state = 1;
		return slot;
	}
	ZString override = texture_override_for(kind, name);
	if (override)
	{
		ui_texture_once(slot, override);
		return slot;
	}
	char[256] path;
	zfmt(&path, "assets/%s/%s.PNG", kind, name);
	if (file_exists((ZString)&path[0]))
	{
		ui_texture_once(slot, (ZString)&path[0]);
	}
	else
	{
		zfmt(&path, "assets/%s/%s.png", kind, name);
		ui_texture_once(slot, (ZString)&path[0]);
	}
	return slot;
}

fn void ui_draw_texture_fit(Texture2D t, float x, float y, float w, float h, Color tint)
{
	if (t.id == 0) return;
	rl::drawTexturePro(t,
		(Rectangle){ 0, 0, (float)t.width, (float)t.height },
		(Rectangle){ x, y, w, h },
		(Vector2){ 0, 0 }, 0, tint);
}

// ---------------------------------------------------------------------------
// Basic widgets
// ---------------------------------------------------------------------------
fn bool ui_in_rect(int x, int y, int w, int h)
{
	Vector2 m = rl::getMousePosition();
	return m.x >= (float)x && m.x <= (float)(x + w)
	    && m.y >= (float)y && m.y <= (float)(y + h);
}

fn bool ui_click()
{
	return rl::isMouseButtonPressed(rl::MOUSE_BUTTON_LEFT);
}

fn void ui_text_fit(ZString text, int x, int y, int w, int size, Color color)
{
	int tw = rl::measureText(text, size);
	rl::drawText(text, x + (w - tw) / 2, y, size, color);
}

fn void ui_text_right(ZString text, int x, int y, int w, int size, Color color)
{
	int tw = rl::measureText(text, size);
	rl::drawText(text, x + w - tw, y, size, color);
}

fn void ui_panel(int x, int y, int w, int h)
{
	rl::drawRectangle(x, y, w, h, rgba(9, 13, 21, 240));
	rl::drawRectangleLines(x, y, w, h, rgba(102, 153, 210, 115));
}

fn bool ui_button_ex(int x, int y, int w, int h, ZString label,
                     Color bg, Color hover, bool enabled)
{
	bool over = ui_in_rect(x, y, w, h);
	Color col = !enabled ? rgba(38, 38, 46, 160) : over ? hover : bg;
	rl::drawRectangle(x, y, w, h, col);
	rl::drawRectangleLines(x, y, w, h, enabled ? rgba(128, 178, 230, 140)
	                                          : rgba(90, 90, 100, 90));
	Color tc = enabled ? rgba(255, 255, 255, 242) : rgba(128, 128, 128, 220);
	ui_text_fit(label, x, y + (h - 20) / 2, w, 20, tc);
	return enabled && over && ui_click();
}

fn bool ui_button(int x, int y, int w, int h, ZString label)
{
	return ui_button_ex(x, y, w, h, label,
	                    rgba(36, 51, 82, 242), rgba(56, 107, 184, 255), true);
}

fn bool ui_button_green(int x, int y, int w, int h, ZString label)
{
	return ui_button_ex(x, y, w, h, label,
	                    rgba(38, 77, 51, 242), rgba(56, 115, 77, 255), true);
}

fn bool ui_button_red(int x, int y, int w, int h, ZString label)
{
	return ui_button_ex(x, y, w, h, label,
	                    rgba(56, 20, 26, 242), rgba(102, 31, 38, 255), true);
}

// ---------------------------------------------------------------------------
// Text fields
// ---------------------------------------------------------------------------
fn char* ui_field_buf(int id, int* cap, int* len)
{
	switch (id)
	{
		case 1: *cap = (int)g.fieldSeed.len; *len = g.fieldSeedLen; return &g.fieldSeed[0];
		case 2: *cap = (int)g.fieldHost.len; *len = g.fieldHostLen; return &g.fieldHost[0];
		case 3: *cap = (int)g.fieldPort.len; *len = g.fieldPortLen; return &g.fieldPort[0];
		case 4: *cap = (int)g.fieldName.len; *len = g.fieldNameLen; return &g.fieldName[0];
		case 5: *cap = (int)g.signalText.len; *len = g.signalTextLen; return &g.signalText[0];
		case 6: *cap = (int)g.programText.len; *len = g.programTextLen; return &g.programText[0];
		case 7: *cap = (int)g.commandText.len; *len = g.commandLen; return &g.commandText[0];
		case 8: *cap = (int)g.chatText.len; *len = g.chatTextLen; return &g.chatText[0];
		default: *cap = 0; *len = 0; return null;
	}
}

fn void ui_field_store_len(int id, int len)
{
	switch (id)
	{
		case 1: g.fieldSeedLen = len;
		case 2: g.fieldHostLen = len;
		case 3: g.fieldPortLen = len;
		case 4: g.fieldNameLen = len;
		case 5: g.signalTextLen = len;
		case 6: g.programTextLen = len;
		case 7: g.commandLen = len;
		case 8: g.chatTextLen = len;
		default:
	}
}

fn void ui_field_set(int id, ZString value)
{
	int cap;
	int len;
	char* buf = ui_field_buf(id, &cap, &len);
	if (!buf) return;
	copy_cstr(buf, (usz)cap, value ? value : "");
	ui_field_store_len(id, zstr_len((ZString)buf));
}

fn void ui_text_field(int id, int x, int y, int w, int h, ZString placeholder)
{
	int cap;
	int len;
	char* buf = ui_field_buf(id, &cap, &len);
	if (!buf) return;
	bool hovered = ui_in_rect(x, y, w, h);
	if (hovered && ui_click()) g.uiActiveField = id;
	bool focused = g.uiActiveField == id;

	rl::drawRectangle(x, y, w, h, focused ? rgba(20, 31, 46, 250)
	                                      : rgba(16, 21, 31, 230));
	rl::drawRectangleLines(x, y, w, h,
		focused ? rgba(128, 204, 255, 230) : rgba(77, 107, 140, 140));

	ZString shown = (ZString)buf;
	Color tc = rgba(255, 255, 255, 244);
	if (buf[0] == 0)
	{
		shown = placeholder ? placeholder : "";
		tc = rgba(115, 128, 140, 255);
	}
	rl::drawText(shown, x + 8, y + (h - 20) / 2, 20, tc);

	if (focused && ((int)(rl::getTime() * 2.0) % 2) == 0)
	{
		int cw = rl::measureText(shown, 20);
		if (buf[0] == 0) cw = 0;
		rl::drawRectangle(x + 8 + cw + 1, y + 7, 2, h - 14, rgba(230, 242, 255, 230));
	}
}

fn void ui_text_append(int cp)
{
	if (g.uiActiveField < 0) return;
	int cap;
	int len;
	char* buf = ui_field_buf(g.uiActiveField, &cap, &len);
	if (!buf) return;
	if (cp == '\n' || cp == '\t')
	{
		if (g.uiActiveField != 6) return;
	}
	else if (cp < 32 || cp > 126)
	{
		return;
	}
	if (len >= cap - 1) return;
	buf[len] = (char)cp;
	buf[len + 1] = 0;
	ui_field_store_len(g.uiActiveField, len + 1);
}

fn void ui_text_backspace()
{
	if (g.uiActiveField < 0) return;
	int cap;
	int len;
	char* buf = ui_field_buf(g.uiActiveField, &cap, &len);
	if (!buf || len <= 0) return;
	len--;
	buf[len] = 0;
	ui_field_store_len(g.uiActiveField, len);
}

fn void ui_focus(int id)
{
	g.uiActiveField = id;
}

fn bool ui_field_active()
{
	return g.uiActiveField >= 0;
}

// ---------------------------------------------------------------------------
// Item icons
// ---------------------------------------------------------------------------
fn void ui_icon(ItemId id, float cx, float cy, float size)
{
	if (id <= 0) return;
	UiTex* slot = ui_tex_for(id);
	if (slot && slot.state == 2)
	{
		float s = size;
		ui_draw_texture_fit(slot.tex, cx - s / 2, cy - s / 2, s, s, rl::WHITE);
		return;
	}

	Color col = item_color(id);
	float x = cx - size / 2;
	float y = cy - size / 2;
	if (is_block(id))
	{
		if (id == ITEM_WIRE || id == ITEM_WIRE4 || id == ITEM_WIRE8
		    || id == ITEM_WIRE16 || id == ITEM_WIRE32)
		{
			rl::drawRectangle((int)(cx - size * 0.35f), (int)(cy - 3), (int)(size * 0.7f), 6,
			                  rgba(194, 49, 49, 255));
			rl::drawRectangle((int)(cx - 3), (int)(cy - size * 0.35f), 6, (int)(size * 0.7f),
			                  rgba(194, 49, 49, 255));
			return;
		}
		if (id == ITEM_TORCH)
		{
			rl::drawRectangle((int)(cx - 2), (int)(cy), 5, (int)(size * 0.42f), rgb(112, 69, 31));
			rl::drawCircle((int)cx, (int)(cy - size * 0.18f), size * 0.18f, rgb(245, 207, 74));
			return;
		}
		if (is_lever(id) || is_button(id))
		{
			rl::drawRectangle((int)x, (int)(y + size * 0.55f), (int)size, (int)(size * 0.35f),
			                  rgb(92, 92, 102));
			rl::drawRectangle((int)(cx - 3), (int)(y + size * 0.2f), 6, (int)(size * 0.5f),
			                  col);
			return;
		}
		if (is_gate(id))
		{
			rl::drawRectangle((int)x, (int)y, (int)size, (int)size, rgba(45, 92, 133, 255));
			rl::drawRectangleLines((int)x, (int)y, (int)size, (int)size, rgba(160, 220, 255, 200));
			return;
		}
		if (id == ITEM_LAMP || id == ITEM_ANALOGLAMP)
		{
			rl::drawCircle((int)cx, (int)cy, size * 0.3f, rgb(238, 214, 93));
			return;
		}
		if (id == ITEM_DISPLAY)
		{
			rl::drawRectangle((int)x, (int)(y + size * 0.15f), (int)size, (int)(size * 0.7f),
			                  rgb(20, 26, 36));
			rl::drawRectangleLines((int)x, (int)(y + size * 0.15f), (int)size,
			                       (int)(size * 0.7f), rgba(90, 220, 160, 220));
			return;
		}
		float alpha = 1.0f;
		if (id == ITEM_WATER)
		{
			alpha = 0.65f;
		}
		else if (id == ITEM_GLASS)
		{
			alpha = 0.55f;
		}
		rl::drawRectangle((int)x, (int)y, (int)size, (int)size,
		                  with_alpha(col, (int)(255 * alpha)));
		if (id != ITEM_WATER && id != ITEM_GLASS)
		{
			rl::drawRectangle((int)x, (int)y, (int)size, (int)(size * 0.18f),
			                  with_alpha(shade(col, 1.25f), 255));
			rl::drawRectangleLines((int)x, (int)y, (int)size, (int)size,
			                       rgba(0, 0, 0, 70));
		}
		return;
	}

	if (is_tool(id))
	{
		ToolDef* td = tool_def(id);
		Color head = td ? td.color : col;
		if (td && td.type == ToolKind.SWORD)
		{
			rl::drawLineEx((Vector2){ x + size * 0.25f, y + size * 0.78f },
			               (Vector2){ x + size * 0.72f, y + size * 0.2f },
			               size * 0.12f, rgb(112, 69, 31));
			rl::drawRectangle((int)(x + size * 0.58f), (int)(y + size * 0.08f),
			                  (int)(size * 0.28f), (int)(size * 0.32f), head);
		}
		else if (td && td.type == ToolKind.HAMMER)
		{
			rl::drawLineEx((Vector2){ x + size * 0.3f, y + size * 0.8f },
			               (Vector2){ x + size * 0.62f, y + size * 0.28f },
			               size * 0.11f, rgb(112, 69, 31));
			rl::drawRectangle((int)(x + size * 0.45f), (int)(y + size * 0.08f),
			                  (int)(size * 0.44f), (int)(size * 0.25f), head);
		}
		else
		{
			rl::drawLineEx((Vector2){ x + size * 0.28f, y + size * 0.82f },
			               (Vector2){ x + size * 0.66f, y + size * 0.24f },
			               size * 0.11f, rgb(112, 69, 31));
			rl::drawRectangle((int)(x + size * 0.5f), (int)(y + size * 0.08f),
			                  (int)(size * 0.4f), (int)(size * 0.2f), head);
		}
		return;
	}

	// Item-only fallbacks.
	if (id == ITEM_STRING)
	{
		rl::drawLineEx((Vector2){ x + 3, y + size * 0.6f },
		               (Vector2){ x + size * 0.8f, y + size * 0.3f }, 2, col);
		return;
	}
	if (id == ITEM_PAPER || id == ITEM_BOOK)
	{
		rl::drawRectangle((int)(x + size * 0.16f), (int)(y + size * 0.1f),
		                  (int)(size * 0.68f), (int)(size * 0.8f), col);
		if (id == ITEM_BOOK)
		{
			rl::drawRectangle((int)(x + size * 0.16f), (int)(y + size * 0.1f),
			                  4, (int)(size * 0.8f), shade(col, 0.6f));
		}
		return;
	}
	if (id == ITEM_IRONBAR || id == ITEM_COPPERBAR || id == ITEM_GOLDBAR)
	{
		rl::drawRectangle((int)(x + size * 0.12f), (int)(y + size * 0.28f),
		                  (int)(size * 0.76f), (int)(size * 0.38f), col);
		rl::drawRectangle((int)(x + size * 0.2f), (int)(y + size * 0.36f),
		                  (int)(size * 0.5f), (int)(size * 0.08f), shade(col, 1.3f));
		return;
	}
	rl::drawCircle((int)cx, (int)cy, size * 0.32f, col);
	rl::drawCircleLines((int)cx, (int)cy, size * 0.32f, rgba(0, 0, 0, 90));
}

// ---------------------------------------------------------------------------
// World tile drawing
// ---------------------------------------------------------------------------
fn uint ui_cell_value(LogicCell* c)
{
	return c ? c.value : 0;
}

fn void ui_draw_tile(ItemId id, float x, float y, bool bg)
{
	if (id == ITEM_NONE) return;
	float cell = (float)GRID;
	Color col = item_color(id);
	int alpha = bg ? 150 : 255;

	if (id == ITEM_CAVEBLOCK)
	{
		rl::drawRectangle((int)x, (int)y, (int)cell, (int)cell, rgba(6, 6, 10, bg ? 255 : 255));
		return;
	}
	if (id == ITEM_WATER)
	{
		rl::drawRectangle((int)x, (int)y, (int)cell, (int)cell, rgba(46, 107, 209, bg ? 120 : 180));
		return;
	}
	if (id == ITEM_GLASS)
	{
		rl::drawRectangle((int)x, (int)y, (int)cell, (int)cell, rgba(173, 214, 240, bg ? 70 : 120));
		rl::drawRectangleLines((int)x, (int)y, (int)cell, (int)cell, rgba(220, 240, 255, 90));
		return;
	}
	if (id == ITEM_TORCH)
	{
		rl::drawRectangle((int)(x + cell * 0.42f), (int)(y + cell * 0.22f), (int)(cell * 0.16f),
		                  (int)(cell * 0.62f), rgb(112, 69, 31));
		rl::drawCircle((int)(x + cell * 0.5f), (int)(y + cell * 0.22f), cell * 0.16f,
		               rgb(245, 207, 74));
		return;
	}
	if (id == ITEM_LADDER || id == ITEM_ROPE)
	{
		rl::drawRectangle((int)(x + cell * 0.38f), (int)y, (int)(cell * 0.1f), (int)cell,
		                  with_alpha(col, alpha));
		rl::drawRectangle((int)(x + cell * 0.62f), (int)y, (int)(cell * 0.1f), (int)cell,
		                  with_alpha(col, alpha));
		return;
	}
	if (id == ITEM_PLATFORM)
	{
		BlockEntity* be = be_get((int)x, (int)y);
		float off = be ? platform_offset(be.position) : 0;
		rl::drawRectangle((int)x, (int)(y + off), (int)cell, 9,
		                  with_alpha(col, bg ? 160 : 255));
		rl::drawRectangleLines((int)x, (int)(y + off), (int)cell, 9,
		                       rgba(40, 30, 15, 150));
		return;
	}
	if (is_wire(id))
	{
		LogicCell* c = logic_get((int)x, (int)y);
		bool on = c && c.value != 0;
		Color wc = on ? rgb(255, 74, 74) : rgb(150, 47, 47);
		rl::drawRectangle((int)(x + cell * 0.42f), (int)y, (int)(cell * 0.16f), (int)cell,
		                  with_alpha(wc, bg ? 170 : 255));
		rl::drawRectangle((int)x, (int)(y + cell * 0.42f), (int)cell, (int)(cell * 0.16f),
		                  with_alpha(wc, bg ? 170 : 255));
		return;
	}
	if (is_gate(id))
	{
		LogicCell* c = logic_get((int)x, (int)y);
		bool on = c && c.value != 0;
		Color gc = on ? rgb(130, 230, 255) : rgb(54, 106, 150);
		rl::drawRectangle((int)(x + 2), (int)(y + cell * 0.2f), (int)(cell - 4),
		                  (int)(cell * 0.6f), with_alpha(gc, alpha));
		rl::drawRectangleLines((int)(x + 2), (int)(y + cell * 0.2f), (int)(cell - 4),
		                       (int)(cell * 0.6f), rgba(10, 20, 30, 160));
		return;
	}
	if (id == ITEM_LAMP || id == ITEM_ANALOGLAMP)
	{
		LogicCell* c = logic_get((int)x, (int)y);
		bool on = c && c.value != 0;
		rl::drawCircle((int)(x + cell * 0.5f), (int)(y + cell * 0.5f), cell * 0.3f,
		               on ? rgb(255, 238, 120) : rgb(122, 112, 70));
		return;
	}
	if (id == ITEM_DISPLAY)
	{
		LogicCell* c = logic_get((int)x, (int)y);
		rl::drawRectangle((int)(x + 2), (int)(y + 2), (int)(cell - 4), (int)(cell - 4),
		                  rgb(12, 18, 24));
		rl::drawRectangleLines((int)(x + 2), (int)(y + 2), (int)(cell - 4), (int)(cell - 4),
		                       rgba(90, 210, 160, 190));
		if (c)
		{
			char[24] buf;
			zfmt(&buf, "%d", (int)c.value);
			ui_text_fit((ZString)&buf[0], (int)x, (int)(y + cell * 0.32f), (int)cell, 14,
			            rgb(120, 255, 180));
		}
		return;
	}
	if (id == ITEM_SIGNALSOURCE)
	{
		LogicCell* c = logic_get((int)x, (int)y);
		rl::drawRectangle((int)(x + 2), (int)(y + 2), (int)(cell - 4), (int)(cell - 4),
		                  rgb(51, 89, 166));
		rl::drawRectangleLines((int)(x + 2), (int)(y + 2), (int)(cell - 4), (int)(cell - 4),
		                       rgba(140, 190, 255, 180));
		if (c)
		{
			char[24] buf;
			zfmt(&buf, "%d", (int)c.value);
			ui_text_fit((ZString)&buf[0], (int)x, (int)(y + cell * 0.32f), (int)cell, 14,
			            rgb(230, 240, 255));
		}
		return;
	}

	UiTex* slot = ui_tex_for(id);
	if (slot && slot.state == 2)
	{
		ui_draw_texture_fit(slot.tex, x, y, cell, cell,
		                    bg ? (Color){ 255, 255, 255, 150 } : rl::WHITE);
		return;
	}

	rl::drawRectangle((int)x, (int)y, (int)cell, (int)cell, with_alpha(col, alpha));
	if (id == ITEM_DOOR)
	{
		rl::drawRectangle((int)(x + cell * 0.2f), (int)y, (int)(cell * 0.6f), (int)cell,
		                  with_alpha(col, alpha));
		rl::drawCircle((int)(x + cell * 0.68f), (int)(y + cell * 0.55f), 2, rgb(40, 30, 15));
		return;
	}
	rl::drawRectangle((int)x, (int)y, (int)cell, (int)(cell * 0.15f),
	                  with_alpha(shade(col, 1.25f), alpha));
	rl::drawRectangleLines((int)x, (int)y, (int)cell, (int)cell, rgba(0, 0, 0, 70));
}

// ---------------------------------------------------------------------------
// Shared UI state (outside State so it is easy for main to query)
// ---------------------------------------------------------------------------
fn int clampi(int v, int lo, int hi)
{
	return v < lo ? lo : (v > hi ? hi : v);
}

bool  uiQuitRequested = false;
int   uiSkipChar = 0;
int   uiModSelected = -1;
int   uiBoardHoverX = -1;
int   uiBoardHoverY = -1;
int   uiBoardLastX = -1;
int   uiBoardLastY = -1;

fn bool ui_overlay_open()
{
	return g.inventoryOpen || g.stationOpen || g.boardOpen || g.programOpen
	    || g.signalSourceOpen || g.cmdOpen || g.chatOpen || g.paused;
}

// ---------------------------------------------------------------------------
// HUD
// ---------------------------------------------------------------------------
fn void ui_draw_hud(int sw, int sh)
{
	g.hasTooltip = false;

	// Health and hunger.
	int bw = 170;
	rl::drawRectangle(14, 14, bw, 18, rgba(20, 20, 26, 217));
	float pct = g.player.maxHealth > 0 ? g.player.health / g.player.maxHealth : 0;
	pct = clampf(pct, 0, 1);
	rl::drawRectangle(14, 14, (int)((float)bw * pct), 18,
	                  rgb((int)(230.0f - pct * 90.0f), (int)(30.0f + pct * 140.0f), 32));
	char[64] buf;
	zfmt(&buf, "HP %d / %d", (int)g.player.health, (int)g.player.maxHealth);
	rl::drawText((ZString)&buf[0], 20, 15, 20, rgba(255, 255, 255, 235));

	rl::drawRectangle(14, 38, bw, 14, rgba(20, 20, 26, 217));
	float hpct = g.player.maxHunger > 0 ? g.player.hunger / g.player.maxHunger : 0;
	hpct = clampf(hpct, 0, 1);
	rl::drawRectangle(14, 38, (int)((float)bw * hpct), 14, rgba(217, 140, 51, 255));
	zfmt(&buf, "Food %d / %d", (int)g.player.hunger, (int)g.player.maxHunger);
	rl::drawText((ZString)&buf[0], 20, 39, 20, rgba(255, 255, 255, 218));

	// Hotbar.
	int n = HOTBAR_SLOTS;
	int size = 42;
	int gap = 5;
	int total = n * size + (n - 1) * gap;
	int x0 = (sw - total) / 2;
	int y = sh - size - 12;
	for (int i = 0; i < n; i++)
	{
		int x = x0 + i * (size + gap);
		bool sel = i == g.player.hot;
		rl::drawRectangle(x, y, size, size,
		                  sel ? rgba(10, 15, 23, 245) : rgba(10, 15, 23, 199));
		rl::drawRectangleLines(x, y, size, size,
			sel ? rgba(255, 209, 64, 255) : rgba(89, 122, 140, 140));
		Stack* s = &g.player.inv[i];
		if (s.id > 0 && s.count > 0)
		{
			ui_icon(s.id, (float)(x + size / 2), (float)(y + size / 2 - 3), 26);
			if (s.count > 1)
			{
				zfmt(&buf, "%d", s.count);
				rl::drawText((ZString)&buf[0], x + 3, y + size - 16, 14, rl::WHITE);
			}
		}
		zfmt(&buf, "%d", (i + 1) % 10);
		rl::drawText((ZString)&buf[0], x + 3, y + 2, 13, rgba(140, 153, 165, 191));
	}

	// Selected item label.
	ItemId selId = selected_id();
	if (selId > 0)
	{
		Stack* s = &g.player.inv[g.player.hot];
		char[128] label;
		if (s.count > 1)
		{
			zfmt(&label, "%s  x%d", item_name(selId), s.count);
		}
		else
		{
			copy_cstr(&label, label.len, item_name(selId));
		}
		int tw = rl::measureText((ZString)&label[0], 18);
		int boxW = tw + 20;
		int boxX = sw / 2 - boxW / 2;
		int boxY = sh - 42 - 12 - 30;
		rl::drawRectangle(boxX, boxY, boxW, 24, rgba(13, 18, 26, 199));
		rl::drawRectangleLines(boxX, boxY, boxW, 24, rgba(102, 153, 210, 128));
		rl::drawText((ZString)&label[0], boxX + 10, boxY + 4, 18,
		             rgba(255, 255, 255, 242));
	}

	// Phase / mode labels.
	ZString phase = "Day";
	if (g.bloodMoon && (g.timeOfDay < 0.22f || g.timeOfDay > 0.78f))
	{
		phase = "BLOOD MOON";
	}
	else if (g.timeOfDay < 0.2f || g.timeOfDay > 0.85f)
	{
		phase = "Night";
	}
	else if (g.timeOfDay < 0.3f)
	{
		phase = "Dawn";
	}
	else if (g.timeOfDay > 0.7f)
	{
		phase = "Dusk";
	}
	Color phaseCol = g.bloodMoon ? rgb(255, 77, 77) : rgba(255, 255, 255, 217);
	ui_text_right(phase, sw - 14, 14, 130, 20, phaseCol);
	if (g.creativeMode) rl::drawText("CREATIVE", 14, 62, 18, rgba(153, 230, 255, 230));
	if (g.backgroundMode) ui_text_fit("BACKGROUND", 0, 100, sw, 20, rgba(140, 191, 255, 230));
	if (g.debugMode) rl::drawText("DEBUG", 14, 84, 16, rgba(255, 255, 255, 204));
	if (g.ghostMode) rl::drawText("GHOST", 90, 84, 16, rgba(200, 160, 255, 204));

	if (g.messageTimer > 0)
	{
		Color mc = rgba(255, 255, 166, (int)(255.0f * clampf(g.messageTimer, 0, 1)));
		ui_text_fit((ZString)&g.messageText[0], 0, sh - 140, sw, 18, mc);
	}

	// Mining progress bar, anchored to the block being mined.
	if (g.miningActive && g.miningProgress > 0)
	{
		ItemId btype = g.miningBg ? bg_at(g.miningX, g.miningY)
		                          : block_at(g.miningX, g.miningY);
		BlockDef* def = block_def(btype);
		float hard = def ? def.hard : 1.0f;
		if (hard <= 0) hard = 1.0f;
		float p = clampf(g.miningProgress / hard, 0, 1);
		float mx = (float)g.miningX + (float)GRID / 2.0f - g.cameraX + (float)sw / 2.0f;
		float my = (float)g.miningY - 12.0f - g.cameraY + (float)sh / 2.0f;
		rl::drawRectangle((int)mx - 18, (int)my, 36, 5, rgba(20, 20, 26, 217));
		rl::drawRectangle((int)mx - 18, (int)my, (int)(36 * p), 5, rgb(242, 209, 51));
	}

	if (g.debugMode)
	{
		zfmt(&buf,
			"xy:%.0f,%.0f chunks:%d drops:%d foes:%d fps:%d seed:%d t:%.2f",
			g.player.x, g.player.y, (int)g.chunks.count, (int)g.drops.size,
			(int)g.enemies.size, rl::getFPS(), g.currentSeed, g.timeOfDay);
		rl::drawText((ZString)&buf[0], 14, 104, 16, rgba(255, 255, 255, 204));
	}

	if (!ui_overlay_open() && !g.cmdOpen)
	{
		rl::drawText("E/Tab inventory  C station  F interact  LMB use  Q eat  B layer  F5 save  F9 load",
		             14, sh - 112, 12, rgba(255, 255, 255, 115));
	}
}

fn void ui_draw_tooltip()
{
	if (!g.hasTooltip) return;
	int w = rl::measureText((ZString)&g.tooltipText[0], 16) + 12;
	rl::drawRectangle(g.tooltipX, g.tooltipY, w, 22, rgba(13, 18, 26, 242));
	rl::drawRectangleLines(g.tooltipX, g.tooltipY, w, 22, rgba(128, 179, 230, 153));
	rl::drawText((ZString)&g.tooltipText[0], g.tooltipX + 6, g.tooltipY + 3, 16, rl::WHITE);
}

// ---------------------------------------------------------------------------
// Main / world menus
// ---------------------------------------------------------------------------
fn void ui_draw_menu(int sw, int sh)
{
	rl::drawRectangle(0, 0, sw, sh, rgb(10, 15, 26));
	rl::drawRectangle(0, (int)(sh * 0.20f), sw, 2, rgba(26, 41, 61, 128));
	rl::drawRectangle(0, (int)(sh * 0.80f), sw, 2, rgba(26, 41, 61, 128));

	int sub = g.menuSubstate;
	if (sub == 2)
	{
		// Touch grass easter egg.
		rl::drawRectangle(0, 0, sw, sh, rgb(26, 89, 26));
		for (int i = 1; i <= 60; i++)
		{
			int x = (i * 137) % sw;
			int y = (i * 89) % sh;
			rl::drawRectangle(x, y, 4, 18, rgba(38, 140, 38, 179));
		}
		ui_text_fit("Touch Grass", 0, (int)(sh * 0.30f), sw, 40, rgb(242, 255, 230));
		ui_text_fit("You chose the fourth option.", 0, (int)(sh * 0.42f), sw, 22,
		            rgb(217, 242, 217));
		ui_text_fit("Step outside. Feel the sun. Pet a dog.", 0, (int)(sh * 0.42f) + 32,
		            sw, 22, rgb(217, 242, 217));
		ui_text_fit("The blocks will still be here when you get back.", 0,
		            (int)(sh * 0.42f) + 64, sw, 22, rgb(217, 242, 217));
		if (ui_button(sw / 2 - 90, (int)(sh * 0.70f), 180, 44, "Back to Menu"))
		{
			g.menuSubstate = 0;
		}
		return;
	}

	ui_text_fit("TERRABLOCK", 0, (int)(sh * 0.13f), sw, 52, rgb(140, 242, 140));
	ui_text_fit("a Terraria-like sandbox", 0, (int)(sh * 0.13f) + 48, sw, 20,
	            rgba(153, 179, 204, 204));

	if (sub == 1)
	{
		rl::drawRectangle(0, 0, sw, sh, rgba(0, 0, 0, 153));
		int pw = mini(500, sw - 40);
		int ph = mini(370, sh - 40);
		int px = sw / 2 - pw / 2;
		int py = sh / 2 - ph / 2;
		ui_panel(px, py, pw, ph);
		ui_text_fit("Join Multiplayer Server", px, py + 18, pw, 24,
		            rgba(230, 242, 255, 255));
		int left = px + 28;
		int fw = pw - 56;
		rl::drawText("Server address", left, py + 66, 18, rgba(204, 219, 235, 230));
		ui_text_field(2, left, py + 86, fw, 32, "127.0.0.1");
		rl::drawText("Port", left, py + 132, 18, rgba(204, 219, 235, 230));
		ui_text_field(3, left, py + 152, fw, 32, "22120");
		rl::drawText("Player name", left, py + 198, 18, rgba(204, 219, 235, 230));
		ui_text_field(4, left, py + 218, fw, 32, "Player");
		ZString status = net_status();
		if (status[0] != 0)
		{
			ui_text_fit(status, px, py + 266, pw, 16, rgba(255, 166, 140, 255));
		}
		else
		{
			ui_text_fit("Chat: T   |   Host runs a built-in TCP server.",
			            px, py + 266, pw, 16, rgba(153, 179, 204, 204));
		}
		if (ui_button(px + 28, py + ph - 48, 110, 34, "Back"))
		{
			g.menuSubstate = 0;
			g.uiActiveField = -1;
		}
		int port = NET_PORT;
		(void)ui_parse_int((ZString)&g.fieldPort[0], &port);
		if (ui_button_green(px + 148, py + ph - 48, 110, 34, "Host"))
		{
			int seed = 0;
			(void)ui_parse_int((ZString)&g.fieldSeed[0], &seed);
			(void)net_server_start(port, seed > 0 ? seed : world_seed_random(),
			                       (ZString)&g.fieldName[0]);
			g.uiActiveField = -1;
		}
		if (ui_button(px + pw - 138, py + ph - 48, 110, 34,
		              netClientOpen ? "Cancel" : "Join"))
		{
			if (netClientOpen)
			{
				net_close_client();
				net_set_status("");
			}
			else
			{
				(void)net_client_connect((ZString)&g.fieldHost[0], port,
				                         (ZString)&g.fieldName[0]);
			}
			g.uiActiveField = -1;
		}
		return;
	}

	int bw = 260;
	int bh = 46;
	int gap = 12;
	int bx = sw / 2 - bw / 2;
	int by = (int)(sh * 0.40f);
	if (ui_button(bx, by, bw, bh, "Single Player"))
	{
		g.gameState = GS_WORLD_SELECT;
		g.saveListDirty = true;
		g.uiActiveField = -1;
	}
	if (ui_button(bx, by + (bh + gap), bw, bh, "Multiplayer"))
	{
		g.menuSubstate = 1;
		ui_field_set(2, "127.0.0.1");
		ui_field_set(3, "22120");
		ui_field_set(4, "Player");
		g.uiActiveField = -1;
	}
	if (ui_button(bx, by + (bh + gap) * 2, bw, bh, "Mods"))
	{
		g.gameState = GS_MODS;
		uiModSelected = -1;
		g.uiActiveField = -1;
	}
	if (ui_button_red(bx, by + (bh + gap) * 3, bw, bh, "Touch Grass"))
	{
		g.menuSubstate = 2;
		g.uiActiveField = -1;
	}
	ui_text_fit("v0.4 C3/Raylib port — F5 save, F9 load", 0, sh - 28, sw, 16,
	            rgba(102, 128, 153, 153));
}

fn void ui_draw_world_select(int sw, int sh)
{
	if (g.saveListDirty) find_worlds();
	rl::drawRectangle(0, 0, sw, sh, rgb(10, 15, 26));
	ui_text_fit("Select World", 0, 30, sw, 34, rgb(140, 242, 140));

	int pw = mini(720, sw - 80);
	int ph = sh - 180;
	int px = sw / 2 - pw / 2;
	int py = 90;
	ui_panel(px, py, pw, ph);
	rl::drawText("Seed", px + 20, py + 14, 18, rgba(140, 166, 199, 230));
	rl::drawText("Mode", px + 200, py + 14, 18, rgba(140, 166, 199, 230));
	rl::drawText("Modified", px + 320, py + 14, 18, rgba(140, 166, 199, 230));
	rl::drawText("Actions", px + 540, py + 14, 18, rgba(140, 166, 199, 230));
	rl::drawRectangle(px + 12, py + 36, pw - 24, 1, rgba(102, 140, 179, 89));

	int rowH = 44;
	int maxRows = (ph - 60) / rowH;
	int deleteSeed = -1;
	int rows = mini((int)g.saves.size, maxRows);
	for (int i = 0; i < rows; i++)
	{
		SaveEntry* w = &g.saves[i];
		int ry = py + 50 + i * rowH;
		rl::drawRectangle(px + 12, ry, pw - 24, rowH - 6,
		                  ui_in_rect(px + 12, ry, pw - 24, rowH - 6)
		                      ? rgba(26, 36, 56, 230) : rgba(15, 23, 36, 179));
		char[32] buf;
		zfmt(&buf, "%d", w.seed);
		rl::drawText((ZString)&buf[0], px + 20, ry + 10, 18, rgba(255, 255, 255, 230));
		rl::drawText(w.mode == 1 ? "creative" : "survival", px + 200, ry + 10, 18,
		             w.mode == 1 ? rgb(153, 230, 255) : rgb(255, 230, 153));
		rl::drawText(w.modified[0] ? (ZString)&w.modified[0] : "-", px + 320, ry + 10,
		             18, rgba(179, 204, 230, 217));
		if (ui_button(px + 540, ry + 4, 60, rowH - 14, "Play"))
		{
			g.currentSeed = w.seed;
			g.creativeMode = w.mode == 1;
			g.worldMode = w.mode;
			g.hostilesEnabled = w.hostiles;
			if (load_world(w.seed))
			{
				g.gameState = GS_PLAYING;
				g.paused = false;
				g.inventoryOpen = false;
				g.stationOpen = false;
				g.uiActiveField = -1;
			}
		}
		if (ui_button_red(px + 608, ry + 4, 60, rowH - 14, "Del"))
		{
			deleteSeed = w.seed;
		}
	}
	if (g.saves.size == 0)
	{
		ui_text_fit("No worlds yet. Create one!", px, py + ph / 2 - 20, pw, 20,
		            rgba(153, 166, 179, 179));
	}
	if (deleteSeed > 0) delete_world(deleteSeed);

	int by = py + ph + 16;
	if (ui_button(px, by, 140, 42, "Back"))
	{
		g.gameState = GS_MENU;
		g.menuSubstate = 0;
	}
	if (ui_button_green(sw / 2 - 90, by, 180, 42, "New World"))
	{
		g.gameState = GS_WORLD_CREATE;
		// Never carry the previous world's seed into a new one.
		ui_field_set(1, "");
		g.uiActiveField = -1;
	}
	if (ui_button(px + pw - 140, by, 140, 42, "Refresh"))
	{
		g.saveListDirty = true;
	}
}

fn void ui_start_new_world()
{
	int seed = 0;
	if (g.fieldSeedLen > 0)
	{
		for (int i = 0; i < g.fieldSeedLen && i < (int)g.fieldSeed.len; i++)
		{
			char c = g.fieldSeed[i];
			if (c >= '0' && c <= '9')
			{
				seed = seed * 10 + (c - '0');
			}
		}
	}
	if (seed <= 0) seed = world_seed_random();
	g.currentSeed = seed;
	g.creativeMode = g.worldMode == 1;
	g.hostilesEnabled = g.worldHostiles;
	reset_world(seed);
	g.gameState = GS_PLAYING;
	g.paused = false;
	g.inventoryOpen = false;
	g.stationOpen = false;
	g.boardOpen = false;
	g.programOpen = false;
	g.signalSourceOpen = false;
	g.cmdOpen = false;
	g.uiActiveField = -1;
}

fn void ui_draw_world_create(int sw, int sh)
{
	rl::drawRectangle(0, 0, sw, sh, rgb(10, 15, 26));
	ui_text_fit("Create World", 0, 40, sw, 34, rgb(140, 242, 140));
	int pw = mini(520, sw - 40);
	int ph = mini(400, sh - 40);
	int px = sw / 2 - pw / 2;
	int py = sh / 2 - ph / 2;
	ui_panel(px, py, pw, ph);
	int sx = px + 40;
	int sy = py + 40;
	if (g.fieldSeedLen == 0)
	{
		char[32] seedBuf;
		zfmt(&seedBuf, "%d", world_seed_random());
		ui_field_set(1, (ZString)&seedBuf[0]);
	}
	rl::drawText("Seed", sx, sy, 18, rgba(217, 230, 242, 242));
	rl::drawText("(blank = random)", sx + 200, sy, 15, rgba(128, 153, 179, 179));
	ui_text_field(1, sx, sy + 22, pw - 80, 34, "e.g. 12345");
	int my = sy + 80;
	rl::drawText("Game mode", sx, my, 18, rgba(217, 230, 242, 242));
	if (ui_button_ex(sx, my + 22, 130, 38, "Survival",
	                 g.worldMode == 0 ? rgba(51, 97, 140, 255) : rgba(26, 36, 51, 242),
	                 rgba(56, 107, 184, 255), true))
	{
		g.worldMode = 0;
	}
	if (ui_button_ex(sx + 140, my + 22, 130, 38, "Creative",
	                 g.worldMode == 1 ? rgba(51, 97, 140, 255) : rgba(26, 36, 51, 242),
	                 rgba(56, 107, 184, 255), true))
	{
		g.worldMode = 1;
	}
	int hy = my + 90;
	rl::drawText("Hostile mobs", sx, hy, 18, rgba(217, 230, 242, 242));
	if (ui_button_ex(sx, hy + 22, 130, 38, g.worldHostiles ? "On" : "Off",
	                 g.worldHostiles ? rgba(51, 128, 64, 255) : rgba(89, 51, 51, 255),
	                 rgba(56, 115, 77, 255), true))
	{
		g.worldHostiles = !g.worldHostiles;
	}
	int by = py + ph - 60;
	if (ui_button(sx, by, 130, 42, "Back"))
	{
		g.gameState = GS_WORLD_SELECT;
		g.saveListDirty = true;
		g.uiActiveField = -1;
	}
	if (ui_button_green(px + pw - 40 - 180, by, 180, 42, "Create World"))
	{
		ui_start_new_world();
	}
}

fn void ui_draw_mods(int sw, int sh)
{
	rl::drawRectangle(0, 0, sw, sh, rgb(10, 15, 26));
	ui_text_fit("Mods & Data Packs", 0, 30, sw, 34, rgb(140, 242, 140));
	int pw = mini(820, sw - 60);
	int ph = sh - 180;
	int px = sw / 2 - pw / 2;
	int py = 80;
	ui_panel(px, py, pw, ph);
	rl::drawText("Icon", px + 20, py + 14, 17, rgba(140, 166, 199, 230));
	rl::drawText("Name", px + 80, py + 14, 17, rgba(140, 166, 199, 230));
	rl::drawText("Type", px + 380, py + 14, 17, rgba(140, 166, 199, 230));
	rl::drawText("Version", px + 480, py + 14, 17, rgba(140, 166, 199, 230));
	rl::drawRectangle(px + 12, py + 36, pw - 24, 1, rgba(102, 140, 179, 89));

	int rowH = 60;
	int maxRows = (ph - 60) / rowH;
	int n = mini((int)g.mods.size, maxRows);
	for (int i = 0; i < n; i++)
	{
		ModEntry* m = &g.mods[i];
		int ry = py + 46 + i * rowH;
		rl::drawRectangle(px + 12, ry, pw - 24, rowH - 6,
		                  ui_in_rect(px + 12, ry, pw - 24, rowH - 6)
		                      ? rgba(26, 36, 56, 230) : rgba(15, 23, 36, 179));
		rl::drawRectangle(px + 20, ry + 10, 32, 32, rgba(46, 61, 82, 230));
		rl::drawRectangleLines(px + 20, ry + 10, 32, 32, rgba(102, 140, 179, 140));
		rl::drawText((ZString)&m.name[0], px + 68, ry + 8, 18,
		             rgba(255, 255, 255, 242));
		rl::drawText((ZString)&m.description[0], px + 68, ry + 28, 15,
		             rgba(153, 179, 204, 204));
		rl::drawText(m.isDatapack ? "datapack" : "mod", px + 380, ry + 14, 17,
		             m.isDatapack ? rgb(255, 217, 153) : rgb(179, 230, 255));
		rl::drawText((ZString)&m.version[0], px + 480, ry + 14, 17,
		             rgba(179, 204, 230, 217));
		if (uiModSelected < 0 && ui_button(px + pw - 180, ry + 12, 100, 32, "Details"))
		{
			uiModSelected = i;
		}
	}
	if (g.mods.size == 0)
	{
		ui_text_fit("No mods or data packs installed.\nDrop a folder into mods/ or data/ and restart.",
		            px, py + ph / 2 - 20, pw, 18, rgba(153, 166, 179, 179));
	}
	ui_text_fit("Lua scripts are not executed; texture overrides are applied.",
	            px, py + ph - 26, pw, 15, rgba(166, 179, 191, 179));
	int by = py + ph + 16;
	if (ui_button(px, by, 140, 42, "Back"))
	{
		g.gameState = GS_MENU;
		g.menuSubstate = 0;
		uiModSelected = -1;
	}
	if (ui_button(px + 160, by, 220, 42, "Refresh List"))
	{
		discover_resources();
		uiModSelected = -1;
	}

	if (uiModSelected >= 0 && uiModSelected < (int)g.mods.size)
	{
		ModEntry* m = &g.mods[uiModSelected];
		rl::drawRectangle(0, 0, sw, sh, rgba(0, 0, 0, 166));
		int dw = mini(500, sw - 40);
		int dh = mini(320, sh - 40);
		int dx = sw / 2 - dw / 2;
		int dy = sh / 2 - dh / 2;
		ui_panel(dx, dy, dw, dh);
		ui_text_fit((ZString)&m.name[0], dx, dy + 18, dw, 26, rgb(230, 217, 128));
		char[128] sub;
		zfmt(&sub, "%s  ·  v%s", m.isDatapack ? "datapack" : "mod",
		                (ZString)&m.version[0]);
		ui_text_fit((ZString)&sub[0], dx, dy + 50, dw, 18, rgba(179, 217, 242, 230));
		ui_text_fit(m.description[0] ? (ZString)&m.description[0] : "(no description)",
		            dx + 30, dy + 90, dw - 60, 17, rgba(217, 230, 242, 217));
		zfmt(&sub, "Folder: %s", (ZString)&m.folder[0]);
		ui_text_fit((ZString)&sub[0], dx + 30, dy + 170, dw - 60, 16,
		            rgba(153, 179, 204, 179));
		ui_text_fit("Enable/disable and per-mod config land in a future update.",
		            dx + 30, dy + 200, dw - 60, 15, rgba(153, 179, 204, 179));
		if (ui_button(dx + dw / 2 - 70, dy + dh - 54, 140, 36, "Close"))
		{
			uiModSelected = -1;
		}
	}
}

fn void ui_draw_pause(int sw, int sh)
{
	rl::drawRectangle(0, 0, sw, sh, rgba(0, 0, 0, 153));
	ui_text_fit("PAUSED", 0, sh / 2 - 130, sw, 44, rl::WHITE);
	int bw = 220;
	int bh = 42;
	int bx = sw / 2 - bw / 2;
	int by = sh / 2 - 70;
	if (ui_button(bx, by, bw, bh, "Resume"))
	{
		g.paused = false;
		g.uiActiveField = -1;
	}
	if (ui_button_ex(bx, by + (bh + 10), bw, bh, "Save World",
	                 rgba(36, 51, 82, 242), rgba(56, 107, 184, 255),
	                 !net_is_active()))
	{
		(void)save_world();
	}
	if (ui_button_ex(bx, by + (bh + 10) * 2, bw, bh, "Load World",
	                 rgba(36, 51, 82, 242), rgba(56, 107, 184, 255),
	                 !net_is_active()))
	{
		if (load_world(g.currentSeed))
		{
			g.paused = false;
		}
	}
	if (ui_button_red(bx, by + (bh + 10) * 3, bw, bh, "Main Menu"))
	{
		return_held_stack();
		g.paused = false;
		if (netClientOpen) net_close_client();
		if (netServerActive) net_server_stop();
		g.gameState = GS_MENU;
		g.menuSubstate = 0;
		g.saveListDirty = true;
		g.uiActiveField = -1;
	}
	ui_text_fit("P / Esc resume  ·  R new world  ·  F5 save  ·  F9 load",
	            0, by + (bh + 10) * 4 + 12, sw, 16, rgba(204, 217, 230, 204));
}

// ---------------------------------------------------------------------------
// Inventory slots
// ---------------------------------------------------------------------------
fn bool ui_held_active()
{
	return g.hasHeld && g.held.id > 0 && g.held.count > 0;
}

fn void ui_clear_if_empty(Stack* s)
{
	if (s.count <= 0 || s.id <= 0) *s = { 0, 0 };
}

fn void ui_click_stack(Stack* cur, bool readonly, bool right)
{
	if (!cur) return;

	if (readonly)
	{
		if (ui_held_active() || cur.id <= 0 || cur.count <= 0) return;
		if (!right)
		{
			g.held = *cur;
			g.hasHeld = true;
			*cur = { 0, 0 };
			return;
		}
		int half = (cur.count + 1) / 2;
		if (half >= cur.count)
		{
			g.held = *cur;
			g.hasHeld = true;
			*cur = { 0, 0 };
		}
		else
		{
			g.held = { cur.id, half };
			g.hasHeld = true;
			cur.count -= half;
		}
		return;
	}

	if (!right)
	{
		if (ui_held_active() && cur.id == g.held.id && !is_tool(cur.id))
		{
			int space = max_stack(cur.id) - cur.count;
			if (space > 0)
			{
				int move = mini(space, g.held.count);
				cur.count += move;
				g.held.count -= move;
				ui_clear_if_empty(&g.held);
				if (g.held.count <= 0) g.hasHeld = false;
				return;
			}
		}
		Stack tmp = *cur;
		*cur = g.held;
		ui_clear_if_empty(cur);
		g.held = tmp;
		ui_clear_if_empty(&g.held);
		g.hasHeld = g.held.id > 0 && g.held.count > 0;
		return;
	}

	if (ui_held_active() && cur.id <= 0)
	{
		cur.id = g.held.id;
		cur.count = 1;
		g.held.count--;
		ui_clear_if_empty(&g.held);
		if (g.held.count <= 0) g.hasHeld = false;
		return;
	}
	if (ui_held_active() && cur.id == g.held.id)
	{
		cur.count++;
		g.held.count--;
		ui_clear_if_empty(&g.held);
		if (g.held.count <= 0) g.hasHeld = false;
		return;
	}
	if (!ui_held_active() && cur.id > 0)
	{
		int half = (cur.count + 1) / 2;
		if (half >= cur.count)
		{
			g.held = *cur;
			g.hasHeld = true;
			*cur = { 0, 0 };
		}
		else
		{
			g.held = { cur.id, half };
			g.hasHeld = true;
			cur.count -= half;
		}
	}
}

fn void ui_slot(Stack* s, int x, int y, int size, bool readonly)
{
	bool hover = ui_in_rect(x, y, size, size);
	rl::drawRectangle(x, y, size, size,
	                  hover ? rgba(41, 46, 56, 242) : rgba(18, 23, 31, 242));
	rl::drawRectangleLines(x, y, size, size,
	                       readonly ? rgba(217, 179, 89, 140) : rgba(82, 107, 133, 140));
	if (s && s.id > 0 && s.count > 0)
	{
		ui_icon(s.id, (float)(x + size / 2), (float)(y + size / 2 - 2),
		        (float)(size * 60 / 100));
		if (s.count > 1)
		{
			char[16] buf;
			zfmt(&buf, "%d", s.count);
			rl::drawText((ZString)&buf[0], x + 3, y + size - 15, 14, rl::WHITE);
		}
		if (hover)
		{
			g.hasTooltip = true;
			if (s.count > 1)
			{
				zfmt(&g.tooltipText, "%s x%d", item_name(s.id), s.count);
			}
			else
			{
				copy_cstr(&g.tooltipText, g.tooltipText.len, item_name(s.id));
			}
			Vector2 m = rl::getMousePosition();
			g.tooltipX = (int)m.x + 12;
			g.tooltipY = (int)m.y + 12;
		}
	}
	if (hover)
	{
		if (ui_click())
		{
			ui_click_stack(s, readonly, false);
		}
		else if (rl::isMouseButtonPressed(rl::MOUSE_BUTTON_RIGHT))
		{
			ui_click_stack(s, readonly, true);
		}
	}
}

fn int ui_inv_rows()
{
	int total = total_slots();
	int rows = (total - HOTBAR_SLOTS + 9) / 10;
	return rows + 1;
}

fn int ui_draw_inv_grid(int px, int py, int slotSize, int gap)
{
	int total = total_slots();
	int invRows = ui_inv_rows() - 1;
	int idx = HOTBAR_SLOTS;
	for (int r = 0; r < invRows; r++)
	{
		for (int c = 0; c < 10; c++)
		{
			if (idx >= total) break;
			ui_slot(&g.player.inv[idx], px + c * (slotSize + gap),
			        py + r * (slotSize + gap), slotSize, false);
			idx++;
		}
	}
	int sepY = py + invRows * (slotSize + gap) - gap / 2 - 1;
	rl::drawRectangle(px, sepY, 10 * slotSize + 9 * gap, 2, rgba(128, 179, 230, 64));
	for (int i = 0; i < HOTBAR_SLOTS; i++)
	{
		ui_slot(&g.player.inv[i], px + i * (slotSize + gap),
		        py + invRows * (slotSize + gap), slotSize, false);
	}
	return ui_inv_rows() * (slotSize + gap) - gap;
}

fn void ui_draw_inventory(int sw, int sh)
{
	rl::drawRectangle(0, 0, sw, sh, rgba(3, 4, 8, 184));
	int rows = ui_inv_rows();
	int slotSize = 42;
	int gap = 4;
	int avail = sh - 40 - 40 - 30;
	if (rows * (slotSize + gap) > avail && rows > 0)
	{
		slotSize = maxi(26, mini(slotSize, avail / rows - gap));
	}
	int innerW = 10 * slotSize + 9 * gap;
	int pad = 20;
	int header = 40;
	int footer = 30;
	int pw = innerW + pad * 2;
	int ph = header + rows * (slotSize + gap) - gap + footer;
	int px = (sw - pw) / 2;
	int py = maxi(20, (sh - ph) / 2);
	ui_panel(px, py, pw, ph);
	rl::drawText(g.creativeMode ? "INVENTORY  -  creative" : "INVENTORY",
	             px + pad, py + 12, 20, rgb(115, 217, 255));
	ui_text_right("Tab / Esc close", px + pad, py + 12, pw - pad * 2, 16,
	              rgba(166, 179, 191, 230));
	ui_draw_inv_grid(px + pad, py + header, slotSize, gap);
	rl::drawText("L-click move  R-click split  hover for details", px + pad,
	             py + ph - footer + 6, 15, rgba(153, 166, 179, 217));
}

// ---------------------------------------------------------------------------
// Station (crafting / furnace / chest)
// ---------------------------------------------------------------------------
fn void ui_detect_stations(bool* craft, bool* furnace, bool* chest)
{
	*craft = g.creativeMode;
	*furnace = g.creativeMode;
	*chest = false;
	g.stationFurnaceValid = false;
	g.stationChestValid = false;
	float reach = (float)(GRID * 5);
	float px = g.player.x + (float)g.player.w / 2.0f;
	float py = g.player.y + (float)g.player.h / 2.0f;
	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		foreach (e : ch.fg.iter())
		{
			int bx = key_x(e.key);
			int by = key_y(e.key);
			float dx = (float)bx + (float)GRID / 2.0f - px;
			float dy = (float)by + (float)GRID / 2.0f - py;
			if (dx * dx + dy * dy >= reach * reach) continue;
			ItemId id = e.value;
			if (id == ITEM_WORKBENCH || id == ITEM_ANVIL)
			{
				*craft = true;
			}
			else if (id == ITEM_FURNACE)
			{
				*furnace = true;
				if (!g.stationFurnaceValid)
				{
					g.stationFurnaceX = bx;
					g.stationFurnaceY = by;
					g.stationFurnaceValid = true;
				}
			}
			else if (id == ITEM_CHEST)
			{
				*chest = true;
				if (!g.stationChestValid)
				{
					g.stationChestX = bx;
					g.stationChestY = by;
					g.stationChestValid = true;
				}
			}
		}
	}
}

fn void ui_open_station()
{
	bool craft;
	bool furnace;
	bool chest;
	ui_detect_stations(&craft, &furnace, &chest);
	if (!craft && !furnace && !chest)
	{
		show_msg("No station nearby (Workbench / Furnace / Chest / Anvil)", 2);
		return;
	}
	return_held_stack();
	g.stationOpen = true;
	g.inventoryOpen = false;
	if (craft)
	{
		g.stationTab = 1;
	}
	else if (furnace)
	{
		g.stationTab = 2;
	}
	else
	{
		g.stationTab = 3;
	}
}

fn void ui_draw_crafting(int px, int py, int cw, int contentH)
{
	int catW = cw / 7;
	for (int i = 0; i < 7; i++)
	{
		bool sel = i == g.craftCategory;
		if (ui_button_ex(px + i * catW + 1, py, catW - 3, 28, craftCategories[i],
		                 sel ? rgba(51, 107, 158, 255) : rgba(26, 36, 51, 242),
		                 rgba(56, 107, 184, 255), true))
		{
			g.craftCategory = i;
			g.craftScroll = 0;
		}
	}

	bool haveWb = near_station(ITEM_WORKBENCH);
	bool haveAnvil = near_station(ITEM_ANVIL);
	Recipe*[MAX_RECIPES] list;
	int count = 0;
	for (int i = 0; i < recipeCount; i++)
	{
		Recipe* r = &recipes[i];
		if (r.cat != g.craftCategory) continue;
		bool stationOk = g.creativeMode || r.station == StationKind.HAND
		    || (r.station == StationKind.WORKBENCH && haveWb)
		    || (r.station == StationKind.ANVIL && haveAnvil);
		if (stationOk)
		{
			list[count++] = r;
			if (count >= MAX_RECIPES) break;
		}
	}
	if (count == 0)
	{
		ui_text_fit("No recipes available - stand near a Workbench or Anvil",
		            px, py + 80, cw, 18, rgba(140, 153, 173, 217));
		return;
	}
	int rowH = 36;
	int maxV = (contentH - 42) / (rowH + 4);
	if (maxV < 1) maxV = 1;
	g.craftScroll = clampi(g.craftScroll, 0, maxi(0, count - maxV));
	int listY = py + 38;
	for (int i = 0; i < maxV; i++)
	{
		int ri = i + g.craftScroll;
		if (ri >= count) break;
		Recipe* r = list[ri];
		int ry = listY + i * (rowH + 4);
		bool can = can_craft(r);
		Vector2 m = rl::getMousePosition();
		bool hover = (int)m.x >= px && (int)m.x <= px + cw
		          && (int)m.y >= ry && (int)m.y <= ry + rowH;
		rl::drawRectangle(px, ry, cw, rowH,
		                  !can ? rgba(13, 15, 20, 230)
		                       : hover ? rgba(36, 51, 71, 255) : rgba(23, 31, 46, 242));
		if (hover && can)
		{
			rl::drawRectangleLines(px, ry, cw, rowH, rgba(128, 191, 255, 128));
		}
		int ix = px + 10;
		char[48] buf;
		for (int j = 0; j < r.ingCount; j++)
		{
			int have = count_inv(r.ingredients[j].id);
			ui_icon(r.ingredients[j].id, (float)(ix + 8), (float)(ry + rowH / 2), 16);
			zfmt(&buf, "%d", r.ingredients[j].count);
			rl::drawText((ZString)&buf[0], ix + 18, ry + 9, 16,
			             have >= r.ingredients[j].count ? rgb(128, 230, 128)
			                                            : rgb(242, 102, 102));
			ix += 44;
		}
		rl::drawText("->", ix + 4, ry + 9, 16, rgba(179, 191, 204, 255));
		ui_icon(r.result, (float)(ix + 34), (float)(ry + rowH / 2), 18);
		zfmt(&buf, "x%d %s", r.resultCount, r.name);
		rl::drawText((ZString)&buf[0], ix + 50, ry + 9, 16, rl::WHITE);
		if (hover && can && ui_click())
		{
			for (int j = 0; j < r.ingCount; j++)
			{
				(void)rem_inv(r.ingredients[j].id, r.ingredients[j].count);
			}
			(void)add_inv(r.result, r.resultCount);
			zfmt(&buf, "Crafted %dx %s", r.resultCount, item_name(r.result));
			show_msg((ZString)&buf[0], 1.2f);
		}
	}
	if (count > maxV)
	{
		rl::drawText("scroll: mouse wheel", px, py + contentH - 14, 15,
		             rgba(128, 153, 179, 179));
	}
}

fn void ui_draw_furnace(int px, int py, int cw, int cell)
{
	if (!g.stationFurnaceValid)
	{
		ui_text_fit("No furnace in range", px, py + 40, cw, 18,
		            rgba(179, 191, 217, 230));
		return;
	}
	BlockEntity* ent = be_get(g.stationFurnaceX, g.stationFurnaceY);
	if (!ent)
	{
		ui_text_fit("Furnace data missing", px, py + 40, cw, 18,
		            rgba(179, 191, 217, 230));
		return;
	}
	int sx = px + 20;
	int sy = py + 30;
	ui_text_fit("Input", sx, sy - 18, cell, 15, rgba(179, 191, 217, 230));
	ui_slot(&ent.input, sx, sy, cell, false);
	ui_text_fit("Fuel", sx, sy + cell + 8, cell, 15, rgba(179, 191, 217, 230));
	ui_slot(&ent.fuel, sx, sy + cell + 26, cell, false);
	int outX = sx + cell * 3 + 30;
	ui_text_fit("Output", outX, sy - 18, cell, 15, rgba(179, 191, 217, 230));
	ui_slot(&ent.output, outX, sy, cell, true);

	int ax = sx + cell + 20;
	int ay = sy + cell / 2 - 8;
	rl::drawRectangle(ax, ay, 50, 16, rgba(38, 51, 64, 230));
	float p = clampf((float)ent.progress / 200.0f, 0, 1);
	rl::drawRectangle(ax, ay, (int)(50 * p), 16, rgb(242, 191, 77));
	int gx = sx;
	int gy = sy + cell + 30 + cell + 8;
	int gw = cell * 4 + 30;
	rl::drawRectangle(gx, gy, gw, 10, rgba(26, 31, 41, 230));
	float fp = ent.maxFuelTime > 0 ? clampf((float)ent.fuelTime / (float)ent.maxFuelTime, 0, 1) : 0;
	rl::drawRectangle(gx, gy, (int)((float)gw * fp), 10, rgb(242, 115, 51));
}

fn void ui_draw_chest(int px, int py, int cw, int cell)
{
	if (!g.stationChestValid)
	{
		ui_text_fit("No chest in range", px, py + 40, cw, 18,
		            rgba(179, 191, 217, 230));
		return;
	}
	BlockEntity* ent = be_get(g.stationChestX, g.stationChestY);
	if (!ent)
	{
		ui_text_fit("Chest data missing", px, py + 40, cw, 18,
		            rgba(179, 191, 217, 230));
		return;
	}
	int gap = 4;
	for (int i = 0; i < 20; i++)
	{
		int col = i % 10;
		int row = i / 10;
		ui_slot(&ent.slots[i], px + col * (cell + gap), py + row * (cell + gap),
		        cell, false);
	}
}

fn void ui_draw_station(int sw, int sh)
{
	bool craft;
	bool furnace;
	bool chest;
	ui_detect_stations(&craft, &furnace, &chest);
	if (!craft && !furnace && !chest)
	{
		g.stationOpen = false;
		show_msg("No station in reach", 1.2f);
		return;
	}
	if (g.stationTab < 1 || g.stationTab > 3) g.stationTab = 1;
	if ((g.stationTab == 1 && !craft) || (g.stationTab == 2 && !furnace)
	    || (g.stationTab == 3 && !chest))
	{
		g.stationTab = craft ? 1 : (furnace ? 2 : 3);
	}

	rl::drawRectangle(0, 0, sw, sh, rgba(3, 4, 8, 184));
	int rows = ui_inv_rows();
	int pad = 16;
	int header = 36;
	int footer = 26;
	int gap = 10;
	int contentH = clampi(sh / 3, 190, 320);
	int avail = sh - 30 - header - footer - gap - contentH;
	int invSlot = clampi(avail / maxi(rows, 1) - 4, 24, 42);
	int invGap = 4;
	int innerW = maxi(10 * invSlot + 9 * invGap, 10 * 42 + 9 * 4);
	int pw = maxi(480, innerW) + pad * 2;
	int invH = rows * (invSlot + invGap) - invGap;
	int ph = header + contentH + gap + invH + footer;
	if (ph > sh - 20)
	{
		ph = sh - 20;
		contentH = maxi(120, ph - header - gap - invH - footer);
	}
	int px = (sw - pw) / 2;
	int py = maxi(10, (sh - ph) / 2);
	ui_panel(px, py, pw, ph);
	rl::drawText("STATION", px + pad, py + 12, 20, rgb(115, 217, 255));
	ui_text_right("E / Esc close", px + pad, py + 12, pw - pad * 2, 16,
	              rgba(166, 179, 191, 230));

	int tabY = py + header;
	int tabW = (pw - pad * 2) / 3;
	int tabH = 30;
	bool[3] enabled = { craft, furnace, chest };
	ZString[3] labels = { "Crafting", "Furnace", "Chest" };
	for (int i = 0; i < 3; i++)
	{
		int tx = px + pad + i * tabW;
		bool sel = g.stationTab == i + 1;
		if (ui_button_ex(tx + 1, tabY, tabW - 3, tabH, labels[i],
		                 sel ? rgba(46, 82, 140, 255) : rgba(26, 36, 51, 242),
		                 rgba(56, 107, 184, 255), enabled[i]))
		{
			g.stationTab = i + 1;
		}
	}
	int cx = px + pad;
	int cy = tabY + 42;
	int cw = pw - pad * 2;
	if (contentH < 120) contentH = 120;
	if (g.stationTab == 1)
	{
		ui_draw_crafting(cx, cy, cw, contentH);
	}
	else if (g.stationTab == 2)
	{
		ui_draw_furnace(cx, cy, cw, 42);
	}
	else
	{
		ui_draw_chest(cx, cy, cw, 40);
	}
	int ipy = cy + contentH + gap;
	ui_draw_inv_grid(px + pad, ipy, invSlot, invGap);
	rl::drawText("L-click move  R-click split", px + pad, py + ph - footer + 6, 15,
	             rgba(153, 166, 179, 217));
}

fn void ui_station_wheel(float amount)
{
	if (!g.stationOpen || g.stationTab != 1 || amount == 0) return;
	g.craftScroll = maxi(0, g.craftScroll + (amount > 0 ? -1 : 1));
}

// ---------------------------------------------------------------------------
// Circuit board editor
// ---------------------------------------------------------------------------
fn Color ui_board_color(ItemId id)
{
	if (is_wire(id)) return rgb(153, 51, 51);
	if (is_lever(id)) return rgb(230, 191, 77);
	if (is_button(id)) return rgb(230, 128, 77);
	if (is_gate(id)) return rgb(102, 179, 230);
	if (id == ITEM_LAMP || id == ITEM_ANALOGLAMP) return rgb(255, 242, 102);
	return rgb(128, 128, 128);
}

fn void ui_draw_board_cell(BoardCell* c, int x, int y, int cellSize)
{
	Color col = ui_board_color(c.type);
	float glow = c.value != 0 ? 1.0f : 0.35f;
	rl::drawRectangle(x + 1, y + 1, cellSize - 2, cellSize - 2, with_alpha(col, (int)(255 * glow)));
	rl::drawRectangleLines(x + 1, y + 1, cellSize - 2, cellSize - 2, rgba(255, 255, 255, 89));
	if (cellSize < 8) return;
	int cx = x + cellSize / 2;
	int cy = y + cellSize / 2;
	if (is_wire(c.type))
	{
		int thick = maxi(1, cellSize / 5);
		rl::drawRectangle(x + 1, cy - thick / 2, cellSize - 2, thick,
		                  c.value != 0 ? rgb(255, 74, 74) : rgb(92, 36, 36));
		rl::drawRectangle(cx - thick / 2, y + 1, thick, cellSize - 2,
		                  c.value != 0 ? rgb(255, 74, 74) : rgb(92, 36, 36));
	}
	else if (is_gate(c.type))
	{
		char[8] buf;
		copy_cstr(&buf, buf.len, item_name(c.type));
		if (zstr_len((ZString)&buf[0]) > 3) buf[3] = 0;
		ui_text_fit((ZString)&buf[0], x + 1, y + cellSize / 4, cellSize - 2, 14,
		            rgba(255, 255, 255, 230));
	}
	else if (c.type == ITEM_LAMP || c.type == ITEM_ANALOGLAMP)
	{
		rl::drawCircle(cx, cy, cellSize * 0.28f,
		               c.value != 0 ? rgb(255, 242, 128) : rgb(110, 102, 64));
	}
}

fn void ui_draw_board_editor(int sw, int sh)
{
	if (!g.boardOpen) return;
	Board* board = logic_board_get(g.boardCellX, g.boardCellY);
	if (!board)
	{
		g.boardOpen = false;
		return;
	}

	rl::drawRectangle(0, 0, sw, sh, rgba(5, 8, 13, 247));
	char[80] title;
	zfmt(&title, "CIRCUIT BOARD - %dx%d", board.w, board.h);
	ui_text_fit((ZString)&title[0], 0, 15, sw, 28, rgb(140, 230, 255));
	ui_text_fit("LMB place  RMB remove  E close", 0, 36, sw, 16,
	            rgba(166, 179, 191, 230));

	ItemId[14] paletteIds = {
		ITEM_WIRE, ITEM_WIRE4, ITEM_WIRE8, ITEM_WIRE16, ITEM_WIRE32,
		ITEM_LEVER, ITEM_BUTTON, ITEM_ANDGATE, ITEM_ORGATE, ITEM_XORGATE,
		ITEM_NOTGATE, ITEM_NANDGATE, ITEM_NORGATE, ITEM_LAMP
	};
	ZString[14] paletteNames = {
		"Wire 1", "Wire 4", "Wire 8", "Wire 16", "Wire 32",
		"Lever", "Button", "AND", "OR", "XOR", "NOT", "NAND", "NOR", "Lamp"
	};

	// Palette.
	int palX = 20;
	int palY = 70;
	int palW = 150;
	int palH = sh - 130;
	rl::drawRectangle(palX, palY, palW, palH, rgba(15, 23, 33, 242));
	rl::drawRectangleLines(palX, palY, palW, palH, rgba(102, 153, 210, 115));
	for (int i = 0; i < 14; i++)
	{
		int y = palY + 10 + i * 30;
		if (y > sh - 70) break;
		int bx = palX + 8;
		int bw = palW - 16;
		bool sel = g.boardSelected == paletteIds[i];
		bool hov = ui_in_rect(bx, y, bw, 26);
		rl::drawRectangle(bx, y, bw, 26,
		                  sel ? rgba(51, 107, 158, 242)
		                      : hov ? rgba(36, 51, 82, 242) : rgba(23, 33, 48, 217));
		rl::drawRectangleLines(bx, y, bw, 26,
		                       sel ? rgba(153, 230, 255, 255) : rgba(128, 153, 179, 153));
		rl::drawText(paletteNames[i], bx + 8, y + 5, 16, rl::WHITE);
		if (hov && ui_click())
		{
			g.boardSelected = paletteIds[i];
		}
	}

	// Grid.
	int pinPanelW = 220;
	int gridX = palX + palW + 20;
	int gridY = palY;
	int gridW = sw - gridX - pinPanelW - 20;
	int gridH = sh - 130;
	if (gridW < 100) gridW = 100;
	if (gridH < 100) gridH = 100;
	rl::drawRectangle(gridX, gridY, gridW, gridH, rgba(8, 13, 20, 255));
	rl::drawRectangleLines(gridX, gridY, gridW, gridH, rgba(77, 128, 191, 102));
	int cellSize = maxi(4, mini(gridW / board.w, gridH / board.h) - 1);
	int totalW = cellSize * board.w;
	int totalH = cellSize * board.h;
	int ox = gridX + (gridW - totalW) / 2;
	int oy = gridY + (gridH - totalH) / 2;
	for (int gx = 0; gx <= board.w; gx++)
	{
		int x = ox + gx * cellSize;
		rl::drawLine(x, oy, x, oy + totalH, rgba(38, 64, 89, 89));
	}
	for (int gy = 0; gy <= board.h; gy++)
	{
		int y = oy + gy * cellSize;
		rl::drawLine(ox, y, ox + totalW, y, rgba(38, 64, 89, 89));
	}

	// Pin markers.
	ZString[4] sideNames = { "N", "S", "E", "W" };
	for (int side = 0; side < 4; side++)
	{
		int bx;
		int by;
		logic_board_pin_coords(board, side, &bx, &by);
		int dir = board.pins[side].dir;
		Color pc = dir == PIN_IN ? rgb(77, 179, 102)
		         : dir == PIN_OUT ? rgb(204, 89, 89)
		         : dir == PIN_INOUT ? rgb(204, 179, 77) : rgb(102, 102, 102);
		int x = ox + bx * cellSize;
		int y = oy + by * cellSize;
		rl::drawRectangle(x, y, cellSize, cellSize, with_alpha(pc, 89));
		rl::drawRectangleLines(x + 1, y + 1, cellSize - 2, cellSize - 2, with_alpha(pc, 242));
		if (cellSize >= 12)
		{
			rl::drawText(sideNames[side], x + 1, y + 1, 10, rl::WHITE);
		}
	}

	foreach (c : board.cells.iter())
	{
		BoardCell* cell = &c.value;
		ui_draw_board_cell(cell, ox + cell.x * cellSize, oy + cell.y * cellSize, cellSize);
	}

	// Hover / placement.
	Vector2 m = rl::getMousePosition();
	uiBoardHoverX = -1;
	uiBoardHoverY = -1;
	if ((int)m.x >= ox && (int)m.x < ox + totalW
	    && (int)m.y >= oy && (int)m.y < oy + totalH)
	{
		int bx = ((int)m.x - ox) / cellSize;
		int by = ((int)m.y - oy) / cellSize;
		uiBoardHoverX = bx;
		uiBoardHoverY = by;
		rl::drawRectangle(ox + bx * cellSize, oy + by * cellSize, cellSize, cellSize,
		                  rgba(255, 242, 128, 64));
		if (ui_click())
		{
			logic_board_place_cell(g.boardCellX, g.boardCellY, bx, by, g.boardSelected);
			uiBoardLastX = bx;
			uiBoardLastY = by;
		}
		else if (rl::isMouseButtonPressed(rl::MOUSE_BUTTON_RIGHT))
		{
			logic_board_remove_cell(g.boardCellX, g.boardCellY, bx, by);
			uiBoardLastX = bx;
			uiBoardLastY = by;
		}
	}

	// Pins panel.
	int pinX = gridX + gridW + 20;
	int pinY = palY;
	int pinH = palH;
	rl::drawRectangle(pinX, pinY, pinPanelW, pinH, rgba(15, 23, 33, 242));
	rl::drawRectangleLines(pinX, pinY, pinPanelW, pinH, rgba(102, 153, 210, 115));
	rl::drawText("PINS", pinX + 12, pinY + 10, 20, rgb(140, 230, 255));
	rl::drawText("direction / bits / value", pinX + 12, pinY + 30, 15,
	             rgba(166, 191, 217, 217));
	for (int side = 0; side < 4; side++)
	{
		Pin* pin = &board.pins[side];
		int rowY = pinY + 54 + side * 44;
		rl::drawText(sideNames[side], pinX + 12, rowY + 10, 18, rl::WHITE);
		ZString[4] dirNames = { "off", "in", "out", "inout" };
		int dirLabel = clampi(pin.dir, 0, 3);
		int dx = pinX + 30;
		int dy = rowY + 4;
		int dw = 70;
		int dh = 28;
		Color dcol = dirLabel == PIN_IN ? rgb(51, 115, 71)
		           : dirLabel == PIN_OUT ? rgb(128, 56, 56)
		           : dirLabel == PIN_INOUT ? rgb(115, 102, 51) : rgb(38, 38, 46);
		rl::drawRectangle(dx, dy, dw, dh,
		                  ui_in_rect(dx, dy, dw, dh) ? shade(dcol, 1.2f) : dcol);
		rl::drawText(dirNames[dirLabel], dx, dy + 8, 16,
		             rgba(255, 255, 255, 217));
		if (ui_in_rect(dx, dy, dw, dh) && ui_click())
		{
			logic_board_cycle_pin_dir(g.boardCellX, g.boardCellY, side);
		}
		int bx = pinX + 108;
		int by = rowY + 4;
		int bw = 44;
		int bh = 28;
		rl::drawRectangle(bx, by, bw, bh,
		                  ui_in_rect(bx, by, bw, bh)
		                      ? rgba(51, 77, 115, 255) : rgba(31, 46, 71, 242));
		char[16] bitsBuf;
		zfmt(&bitsBuf, "%d", pin.bits);
		ui_text_fit((ZString)&bitsBuf[0], bx, by + 8, bw, 16,
		            rgba(255, 255, 255, 217));
		if (ui_in_rect(bx, by, bw, bh) && ui_click())
		{
			logic_board_cycle_pin_bits(g.boardCellX, g.boardCellY, side);
		}
		char[32] valBuf;
		zfmt(&valBuf, "=%d", (int)board.sides[side]);
		rl::drawText((ZString)&valBuf[0], pinX + 158, rowY + 10, 16,
		             board.sides[side] != 0 ? rgb(102, 255, 102)
		                                    : rgba(153, 166, 179, 217));
	}
	rl::drawText("Pins connect the board to the outside world.", pinX + 12,
	             pinY + pinH - 90, 15, rgba(153, 179, 204, 191));
}

// ---------------------------------------------------------------------------
// Programmable circuit editor
// ---------------------------------------------------------------------------
fn void ui_draw_numbered_lines(char* text, int len, int x, int y, int lineH, int maxLines)
{
	int start = 0;
	int line = 1;
	char[256] buf;
	for (int i = 0; i <= len; i++)
	{
		if (i == len || text[i] == '\n')
		{
			if (line > maxLines) return;
			int n = i - start;
			if (n > (int)buf.len - 1) n = (int)buf.len - 1;
			for (int j = 0; j < n; j++) buf[j] = text[start + j];
			buf[n] = 0;
			char[16] num;
			zfmt(&num, "%02d", line);
			rl::drawText((ZString)&num[0], x + 12, y + (line - 1) * lineH, 16,
			             rgba(89, 140, 184, 255));
			rl::drawText((ZString)&buf[0], x + 48, y + (line - 1) * lineH, 16,
			             rgba(224, 237, 250, 255));
			line++;
			start = i + 1;
		}
	}
}

fn void ui_draw_program_editor(int sw, int sh)
{
	if (!g.programOpen) return;
	rl::drawRectangle(0, 0, sw, sh, rgba(5, 8, 15, 247));
	ui_text_fit("PROGRAMMABLE CIRCUIT", 0, 25, sw, 28, rgb(115, 209, 255));
	ui_text_fit("input.N / W / S / E  ->  return { E = value, S = value }",
	            0, 52, sw, 16, rgba(173, 194, 219, 255));
	ui_text_fit("Enter: new line   Ctrl+Enter: save & close   Esc: close",
	            0, 72, sw, 16, rgba(166, 179, 191, 204));
	int x = 54;
	int y = 110;
	int w = sw - 108;
	int h = sh - 190;
	if (w < 100) w = 100;
	if (h < 100) h = 100;
	rl::drawRectangle(x, y, w, h, rgba(10, 18, 31, 255));
	rl::drawRectangleLines(x, y, w, h, rgba(56, 107, 158, 255));
	ui_draw_numbered_lines(&g.programText[0], g.programTextLen, x, y + 12, 20,
	                       (h - 24) / 20);
	LogicCell* cell = logic_get(g.programCellX, g.programCellY);
	if (cell && cell.codeError[0] != 0)
	{
		char[256] msg;
		zfmt(&msg, "Last run error: %s", (ZString)&cell.codeError[0]);
		ui_text_fit((ZString)&msg[0], 54, sh - 65, sw - 108, 16, rgb(255, 102, 89));
	}
}

fn void ui_draw_signal_editor(int sw, int sh)
{
	if (!g.signalSourceOpen) return;
	rl::drawRectangle(0, 0, sw, sh, rgba(0, 0, 0, 166));
	int pw = mini(460, sw - 40);
	int ph = 200;
	int px = sw / 2 - pw / 2;
	int py = sh / 2 - ph / 2;
	ui_panel(px, py, pw, ph);
	ui_text_fit("SIGNAL SOURCE", px, py + 18, pw, 24, rgb(140, 230, 255));
	ui_text_fit("Enter a decimal value (masked to the cell bit width).",
	            px, py + 48, pw, 16, rgba(166, 191, 217, 230));
	ui_text_field(5, px + 40, py + 80, pw - 80, 36, "0");
	if (ui_button(px + 40, py + 138, 140, 40, "Apply"))
	{
		logic_apply_signal();
		g.uiActiveField = -1;
	}
	if (ui_button(px + pw - 180, py + 138, 140, 40, "Cancel"))
	{
		g.signalSourceOpen = false;
		g.uiActiveField = -1;
	}
}

// ---------------------------------------------------------------------------
// Command overlay
// ---------------------------------------------------------------------------
fn void ui_command_log(ZString text, Color color)
{
	if (g.commandLogCount >= 8)
	{
		for (int i = 0; i < 7; i++)
		{
			copy_cstr(&g.commandLog[i], g.commandLog[i].len, (ZString)&g.commandLog[i + 1][0]);
			g.commandLogColor[i] = g.commandLogColor[i + 1];
		}
		g.commandLogCount = 7;
	}
	copy_cstr(&g.commandLog[g.commandLogCount], g.commandLog[g.commandLogCount].len, text);
	g.commandLogColor[g.commandLogCount] = color;
	g.commandLogCount++;
}

fn bool ui_parse_int(ZString text, int* out)
{
	if (!text) return false;
	int i = 0;
	bool neg = false;
	if (text[0] == '-')
	{
		neg = true;
		i = 1;
	}
	else if (text[0] == '+')
	{
		i = 1;
	}
	if (text[i] == 0) return false;
	int v = 0;
	for (; text[i] != 0; i++)
	{
		if (text[i] < '0' || text[i] > '9') return false;
		v = v * 10 + (text[i] - '0');
	}
	*out = neg ? -v : v;
	return true;
}

fn bool ui_parse_float(ZString text, float* out)
{
	if (!text) return false;
	int i = 0;
	bool neg = false;
	if (text[0] == '-')
	{
		neg = true;
		i = 1;
	}
	else if (text[0] == '+')
	{
		i = 1;
	}
	double v = 0;
	double frac = 0;
	bool dot = false;
	bool anyDigit = false;
	for (; text[i] != 0; i++)
	{
		char c = text[i];
		if (c == '.')
		{
			if (dot) return false;
			dot = true;
			continue;
		}
		if (c < '0' || c > '9') return false;
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
	if (!anyDigit) return false;
	int digits = 0;
	for (int j = i - 1; j >= 0; j--)
	{
		if (text[j] == '.') break;
		digits++;
	}
	while (digits > 0)
	{
		frac /= 10;
		digits--;
	}
	*out = (float)(neg ? -(v + frac) : (v + frac));
	return true;
}

fn char ui_lower(char c)
{
	return c >= 'A' && c <= 'Z' ? (char)(c + 32) : c;
}

fn bool ui_norm_equal(ZString a, ZString b)
{
	if (!a || !b) return false;
	int i = 0;
	int j = 0;
	while (a[i] != 0 && b[j] != 0)
	{
		while (a[i] == ' ' || a[i] == '_' || a[i] == '-') i++;
		while (b[j] == ' ' || b[j] == '_' || b[j] == '-') j++;
		if (a[i] == 0 || b[j] == 0) break;
		if (ui_lower(a[i]) != ui_lower(b[j])) return false;
		i++;
		j++;
	}
	while (a[i] == ' ' || a[i] == '_' || a[i] == '-') i++;
	while (b[j] == ' ' || b[j] == '_' || b[j] == '-') j++;
	return a[i] == 0 && b[j] == 0;
}

fn ItemId ui_find_item(ZString name)
{
	if (!name) return ITEM_NONE;
	int numeric = 0;
	if (ui_parse_int(name, &numeric) && numeric > 0 && numeric < ITEM_COUNT)
	{
		return numeric;
	}
	for (ItemId id = 1; id < ITEM_COUNT; id++)
	{
		if (!is_item(id)) continue;
		if (ui_norm_equal(item_name(id), name)) return id;
	}
	return ITEM_NONE;
}

fn void ui_command_execute(ZString line)
{
	if (!line || line[0] == 0) return;
	char[160] storage;
	copy_cstr(&storage, storage.len, line);
	ZString[16] args;
	int argc = 0;
	char* p = &storage[0];
	while (*p != 0 && argc < 16)
	{
		while (*p == ' ' || *p == '\t') p++;
		if (*p == 0) break;
		args[argc] = (ZString)p;
		argc++;
		while (*p != 0 && *p != ' ' && *p != '\t') p++;
		if (*p != 0)
		{
			*p = 0;
			p++;
		}
	}
	if (argc == 0) return;
	ZString cmd = args[0];
	while (cmd[0] == '/') cmd = (ZString)((usz)cmd + 1);

	if (ui_norm_equal(cmd, "give"))
	{
		if (argc < 2)
		{
			ui_command_log("Usage: /give <item> [count]", rgb(255, 153, 128));
			return;
		}
		ItemId id = ui_find_item(args[1]);
		if (id == ITEM_NONE)
		{
			char[128] msg;
			zfmt(&msg, "Unknown item: %s", args[1]);
			ui_command_log((ZString)&msg[0], rgb(255, 128, 128));
			return;
		}
		int count = 1;
		if (argc >= 3 && !ui_parse_int(args[2], &count)) count = 1;
		if (count < 1) count = 1;
		if (add_inv(id, count))
		{
			char[128] msg;
			zfmt(&msg, "Gave %dx %s", count, item_name(id));
			ui_command_log((ZString)&msg[0], rgb(153, 255, 153));
		}
		else
		{
			ui_command_log("Inventory full", rgb(255, 153, 128));
		}
	}
	else if (ui_norm_equal(cmd, "gamemode"))
	{
		if (argc < 2)
		{
			ui_command_log("Usage: /gamemode <survival|creative>", rgb(255, 153, 128));
			return;
		}
		if (ui_norm_equal(args[1], "c") || ui_norm_equal(args[1], "creative"))
		{
			g.creativeMode = true;
			player_fill_creative();
			ui_command_log("Creative mode", rgb(153, 230, 255));
		}
		else if (ui_norm_equal(args[1], "s") || ui_norm_equal(args[1], "survival"))
		{
			g.creativeMode = false;
			g.player.flying = false;
			ui_command_log("Survival mode", rgb(255, 230, 153));
		}
		else
		{
			ui_command_log("Usage: /gamemode <survival|creative>", rgb(255, 153, 128));
		}
	}
	else if (ui_norm_equal(cmd, "time"))
	{
		if (argc < 3 || !ui_norm_equal(args[1], "set"))
		{
			ui_command_log("Usage: /time set <value>", rgb(255, 153, 128));
			return;
		}
		float t = -1;
		if (ui_norm_equal(args[2], "day") || ui_norm_equal(args[2], "morning"))
		{
			t = 0.28f;
		}
		else if (ui_norm_equal(args[2], "noon"))
		{
			t = 0.5f;
		}
		else if (ui_norm_equal(args[2], "dusk"))
		{
			t = 0.75f;
		}
		else if (ui_norm_equal(args[2], "night"))
		{
			t = 0.9f;
		}
		else if (ui_norm_equal(args[2], "midnight"))
		{
			t = 0.0f;
		}
		else if (!ui_parse_float(args[2], &t))
		{
			t = -1;
		}
		if (t < 0)
		{
			char[128] msg;
			zfmt(&msg, "Unknown time: %s", args[2]);
			ui_command_log((ZString)&msg[0], rgb(255, 153, 128));
			return;
		}
		g.timeOfDay = t - (float)math::floor((double)t);
		char[96] msg;
		zfmt(&msg, "Time set to %.2f", g.timeOfDay);
		ui_command_log((ZString)&msg[0], rgb(179, 230, 255));
	}
	else if (ui_norm_equal(cmd, "tp"))
	{
		float x;
		float y;
		if (argc < 3 || !ui_parse_float(args[1], &x) || !ui_parse_float(args[2], &y))
		{
			ui_command_log("Usage: /tp <x> <y>", rgb(255, 153, 128));
			return;
		}
		g.player.x = x;
		g.player.y = y;
		g.player.vx = 0;
		g.player.vy = 0;
		char[96] msg;
		zfmt(&msg, "Teleported to %.0f, %.0f", x, y);
		ui_command_log((ZString)&msg[0], rgb(179, 230, 255));
	}
	else if (ui_norm_equal(cmd, "heal"))
	{
		g.player.health = g.player.maxHealth;
		g.player.hunger = g.player.maxHunger;
		ui_command_log("Healed to full", rgb(153, 255, 153));
	}
	else if (ui_norm_equal(cmd, "clear"))
	{
		inv_clear();
		if (g.hasHeld)
		{
			g.held = { 0, 0 };
			g.hasHeld = false;
		}
		ui_command_log("Inventory cleared", rgb(255, 230, 153));
	}
	else if (ui_norm_equal(cmd, "seed"))
	{
		char[96] msg;
		zfmt(&msg, "Seed: %d", g.currentSeed);
		ui_command_log((ZString)&msg[0], rgb(179, 230, 255));
	}
	else if (ui_norm_equal(cmd, "killall"))
	{
		int n = (int)g.enemies.size;
		g.enemies.clear();
		char[96] msg;
		zfmt(&msg, "Killed %d enemies", n);
		ui_command_log((ZString)&msg[0], rgb(255, 179, 179));
	}
	else if (ui_norm_equal(cmd, "help"))
	{
		ui_command_log("/give <item> [count]", rgb(230, 230, 179));
		ui_command_log("/gamemode <survival|creative>", rgb(230, 230, 179));
		ui_command_log("/time set <day|night|noon|0.0-1.0>", rgb(230, 230, 179));
		ui_command_log("/tp <x> <y>", rgb(230, 230, 179));
		ui_command_log("/heal  /clear  /seed  /killall", rgb(230, 230, 179));
	}
	else
	{
		char[128] msg;
		zfmt(&msg, "Unknown command: %s", cmd);
		ui_command_log((ZString)&msg[0], rgb(255, 128, 128));
	}
}

fn void ui_command_submit()
{
	char[160] line;
	copy_cstr(&line, line.len, (ZString)&g.commandText[0]);
	ui_field_set(7, "");
	g.cmdOpen = false;
	g.uiActiveField = -1;
	ui_command_execute((ZString)&line[0]);
}

fn void ui_draw_commands(int sw, int sh)
{
	int lh = 20;
	int baseY = sh - 220;
	for (int i = 0; i < g.commandLogCount; i++)
	{
		int y = baseY + i * lh;
		int w = rl::measureText((ZString)&g.commandLog[i][0], 16) + 12;
		rl::drawRectangle(12, y, w, lh, rgba(0, 0, 0, 140));
		rl::drawText((ZString)&g.commandLog[i][0], 18, y + 2, 16, g.commandLogColor[i]);
	}
	if (!g.cmdOpen) return;
	int y = baseY + g.commandLogCount * lh + 4;
	rl::drawRectangle(12, y, sw - 24, lh + 6, rgba(0, 0, 0, 179));
	char[180] prompt;
	zfmt(&prompt, "> %s_", (ZString)&g.commandText[0]);
	rl::drawText((ZString)&prompt[0], 18, y + 4, 16, rl::WHITE);
}

// ---------------------------------------------------------------------------
// Input helpers
// ---------------------------------------------------------------------------
fn void ui_process_char_input()
{
	int cp;
	while ((cp = rl::getCharPressed()) != 0)
	{
		if (uiSkipChar > 0)
		{
			uiSkipChar--;
			continue;
		}
		// The '/' key that opens the command overlay can emit more than one
		// character event; keep exactly one leading slash in the prompt.
		if (g.cmdOpen && g.uiActiveField == 7 && g.commandLen == 1
		    && g.commandText[0] == '/' && cp == '/')
		{
			continue;
		}
		if (g.uiActiveField >= 0)
		{
			ui_text_append(cp);
		}
	}
}

fn void ui_process_backspace()
{
	if (rl::isKeyPressed(rl::KEY_BACKSPACE)
	    || rl::isKeyPressedRepeat(rl::KEY_BACKSPACE))
	{
		ui_text_backspace();
	}
}

fn void ui_hotbar_scroll(float amount)
{
	if (amount == 0) return;
	g.player.hot = (g.player.hot + (amount > 0 ? -1 : 1) + HOTBAR_SLOTS) % HOTBAR_SLOTS;
}

// ---------------------------------------------------------------------------
// World rendering
// ---------------------------------------------------------------------------
fn Color ui_sky_color()
{
	float t = g.timeOfDay;
	if (g.bloodMoon && (t < 0.22f || t > 0.78f)) return rgb(64, 13, 20);
	if (t < 0.2f)
	{
		float f = t / 0.2f;
		return rgb((int)(5 + f * 56), (int)(5 + f * 71), (int)(18 + f * 107));
	}
	if (t < 0.3f)
	{
		float f = (t - 0.2f) / 0.1f;
		return rgb((int)(61 + f * 77), (int)(77 + f * 102), (int)(125 + f * 92));
	}
	if (t < 0.7f) return rgb(133, 179, 224);
	if (t < 0.8f)
	{
		float f = (t - 0.7f) / 0.1f;
		return rgb((int)(133 - f * 46), (int)(179 - f * 82), (int)(224 - f * 122));
	}
	float f = (t - 0.8f) / 0.2f;
	return rgb((int)(87 - f * 82), (int)(97 - f * 92), (int)(102 - f * 84));
}

fn void ui_draw_player()
{
	Player* p = &g.player;
	int x = (int)(p.x - g.cameraX + (float)rl::getScreenWidth() / 2.0f);
	int y = (int)(p.y - g.cameraY + (float)rl::getScreenHeight() / 2.0f);
	Color shirt = g.ghostMode ? rgba(153, 128, 230, 150) : rgb(46, 102, 179);
	Color skin = g.ghostMode ? rgba(204, 191, 242, 150) : rgb(235, 188, 140);
	rl::drawRectangle(x + 4, y + 12, 24, 15, shirt);
	rl::drawRectangle(x + 5, y, 22, 13, skin);
	rl::drawRectangle(x + 4, y + 27, 10, 5, rgb(46, 56, 82));
	rl::drawRectangle(x + 18, y + 27, 10, 5, rgb(46, 56, 82));
	int eye = p.facing > 0 ? x + 18 : x + 10;
	rl::drawRectangle(eye, y + 5, 3, 3, rgb(20, 20, 28));
	if (p.hurt > 0)
	{
		rl::drawRectangleLines(x, y, p.w, p.h, rgba(255, 77, 77, 190));
	}
}

fn void ui_draw_enemy(Enemy* e)
{
	int x = (int)(e.x - g.cameraX + (float)rl::getScreenWidth() / 2.0f);
	int y = (int)(e.y - g.cameraY + (float)rl::getScreenHeight() / 2.0f);
	Color base;
	switch (e.kind)
	{
		case EnemyKind.BAT: base = rgb(140, 89, 153);
		case EnemyKind.ZOMBIE: base = rgb(102, 140, 89);
		case EnemyKind.BLOOD: base = rgb(191, 38, 51);
		default: base = rgb(89, 204, 89);
	}
	if (e.hurt > 0) base = shade(base, 1.4f);
	rl::drawRectangle(x, y, (int)e.w, (int)e.h, base);
	rl::drawRectangleLines(x, y, (int)e.w, (int)e.h, rgba(0, 0, 0, 89));
	int eyeY = y + (int)(e.h * 0.35f);
	rl::drawRectangle(x + (int)(e.w * 0.25f) - 2, eyeY, 4, 4, rl::WHITE);
	rl::drawRectangle(x + (int)(e.w * 0.65f) - 2, eyeY, 4, 4, rl::WHITE);
	rl::drawRectangle(x + (int)(e.w * 0.25f) - 1, eyeY + 1, 2, 2, rgb(0, 0, 0));
	rl::drawRectangle(x + (int)(e.w * 0.65f) - 1, eyeY + 1, 2, 2, rgb(0, 0, 0));
	if (e.health < e.max)
	{
		rl::drawRectangle(x, y - 5, (int)e.w, 3, rgba(0, 0, 0, 140));
		rl::drawRectangle(x, y - 5, (int)((float)e.w * clampf(e.health / e.max, 0, 1)), 3,
		                  rgb(217, 38, 38));
	}
}

fn void ui_draw_world(int sw, int sh)
{
	rl::clearBackground(ui_sky_color());
	float halfW = (float)sw / 2.0f;
	float halfH = (float)sh / 2.0f;
	float left = g.cameraX - halfW - (float)GRID;
	float right = g.cameraX + halfW + (float)GRID;
	float top = g.cameraY - halfH - (float)GRID;
	float bottom = g.cameraY + halfH + (float)GRID;

	// Background layer first.
	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		foreach (e : ch.bg.iter())
		{
			int bx = key_x(e.key);
			int by = key_y(e.key);
			if ((float)bx + GRID < left || (float)bx > right
			    || (float)by + GRID < top || (float)by > bottom) continue;
			ui_draw_tile(e.value, (float)bx - g.cameraX + halfW,
			             (float)by - g.cameraY + halfH, true);
		}
	}
	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		foreach (e : ch.fg.iter())
		{
			int bx = key_x(e.key);
			int by = key_y(e.key);
			if ((float)bx + GRID < left || (float)bx > right
			    || (float)by + GRID < top || (float)by > bottom) continue;
			ui_draw_tile(e.value, (float)bx - g.cameraX + halfW,
			             (float)by - g.cameraY + halfH, false);
		}
	}

	foreach (d : g.drops)
	{
		float bob = (float)math::sin((double)d.bob) * 3.0f;
		ui_icon(d.id, d.x - g.cameraX + halfW + 8, d.y - g.cameraY + halfH + 8 + bob, 15);
	}
	foreach (e : g.enemies)
	{
		ui_draw_enemy(&e);
	}
	foreach (p : g.particles)
	{
		float a = p.life / p.max;
		rl::drawRectangle((int)(p.x - g.cameraX + halfW), (int)(p.y - g.cameraY + halfH),
		                  (int)p.size, (int)p.size, with_alpha(p.color, (int)(255 * a)));
	}
	foreach (f : g.floats)
	{
		float a = fmin(1.0f, fmin(f.life / 0.35f, f.life / f.max + 0.4f));
		rl::drawText((ZString)&f.text[0], (int)(f.x - g.cameraX + halfW - 8),
		             (int)(f.y - g.cameraY + halfH), 16,
		             with_alpha(f.color, (int)(255 * a)));
	}
	ui_draw_player();
	for (int i = 0; i < net_remote_count(); i++)
	{
		NetPeer* rp = net_remote(i);
		if (rp) ui_draw_remote_player(rp);
	}

	if (!ui_overlay_open() && !g.cmdOpen)
	{
		float wx;
		float wy;
		screen_to_world(rl::getMouseX(), rl::getMouseY(), &wx, &wy);
		float sx = snap_i(wx) - g.cameraX + halfW;
		float sy = snap_i(wy) - g.cameraY + halfH;
		rl::drawRectangleLines((int)sx, (int)sy, GRID, GRID, rgba(255, 255, 255, 115));
	}

	// Night / torch light.
	bool isDark = g.timeOfDay < 0.22f || g.timeOfDay > 0.82f;
	if (isDark)
	{
		float baseDark = g.bloodMoon ? 0.38f : 0.55f;
		if (g.timeOfDay < 0.22f)
		{
			baseDark *= (0.22f - g.timeOfDay) / 0.22f;
		}
		else
		{
			baseDark *= (g.timeOfDay - 0.82f) / 0.18f;
		}
		float px = g.player.x + (float)g.player.w / 2.0f;
		float py = g.player.y + (float)g.player.h / 2.0f;
		float td = nearest_torch_dist(px, py);
		float light = td < TORCH_RADIUS ? (1.0f - td / TORCH_RADIUS) * 0.72f : 0.0f;
		float darkness = fmax(0.0f, baseDark - light);
		int alpha = (int)(255.0f * darkness);
		rl::drawRectangle(0, 0, sw, sh,
		                  g.bloodMoon ? rgba(64, 0, 10, alpha) : rgba(0, 0, 8, alpha));
	}
}

fn void ui_draw_cursor()
{
	int mx = rl::getMouseX();
	int my = rl::getMouseY();
	rl::drawLine(mx - 9, my, mx - 3, my, rgba(255, 255, 255, 217));
	rl::drawLine(mx + 3, my, mx + 9, my, rgba(255, 255, 255, 217));
	rl::drawLine(mx, my - 9, mx, my - 3, rgba(255, 255, 255, 217));
	rl::drawLine(mx, my + 3, mx, my + 9, rgba(255, 255, 255, 217));
	if (ui_held_active())
	{
		ui_icon(g.held.id, (float)(mx + 18), (float)(my + 18), 20);
		if (g.held.count > 1)
		{
			char[16] buf;
			zfmt(&buf, "%d", g.held.count);
			rl::drawText((ZString)&buf[0], mx + 24, my + 24, 14, rl::WHITE);
		}
	}
}

fn void ui_draw_remote_player(NetPeer* p)
{
	int x = (int)(p.x - g.cameraX + (float)rl::getScreenWidth() / 2.0f);
	int y = (int)(p.y - g.cameraY + (float)rl::getScreenHeight() / 2.0f);
	rl::drawRectangle(x + 4, y + 12, 24, 15, rgb(179, 92, 46));
	rl::drawRectangle(x + 5, y, 22, 13, rgb(235, 188, 140));
	int eye = p.facing > 0 ? x + 18 : x + 10;
	rl::drawRectangle(eye, y + 5, 3, 3, rgb(20, 20, 28));
	ui_text_fit((ZString)&p.name[0], x - 24, y - 20, 80, 14,
	            rgba(255, 255, 255, 230));
}

fn void ui_draw_chat(int sw, int sh)
{
	if (!net_is_connected()) return;
	int count = net_chat_count();
	int visible = 8;
	int start = maxi(0, count - visible - g.chatScroll);
	int y = 60;
	int x = 18;
	for (int i = start; i < count && i < start + visible; i++)
	{
		NetChatMsg* m = net_chat(i);
		if (!m) continue;
		char[220] line;
		zfmt(&line, "%s: %s", (ZString)&m.name[0], (ZString)&m.text[0]);
		int w = rl::measureText((ZString)&line[0], 16) + 12;
		rl::drawRectangle(x, y, w, 22, rgba(0, 0, 0, 166));
		rl::drawText((ZString)&line[0], x + 6, y + 3, 16, rgba(255, 255, 255, 242));
		y += 24;
	}
	if (!g.chatOpen) return;
	int inputY = sh - 170;
	rl::drawRectangle(12, inputY, sw - 24, 30, rgba(0, 0, 0, 217));
	char[200] prompt;
	zfmt(&prompt, "Chat: %s_", (ZString)&g.chatText[0]);
	rl::drawText((ZString)&prompt[0], 20, inputY + 7, 16, rl::WHITE);
}

fn void ui_draw_frame(int sw, int sh)
{
	if (g.gameState != GS_PLAYING)
	{
		switch (g.gameState)
		{
			case GS_WORLD_SELECT: ui_draw_world_select(sw, sh);
			case GS_WORLD_CREATE: ui_draw_world_create(sw, sh);
			case GS_MODS: ui_draw_mods(sw, sh);
			default: ui_draw_menu(sw, sh);
		}
		ui_draw_cursor();
		return;
	}

	if (g.boardOpen)
	{
		ui_draw_board_editor(sw, sh);
		ui_draw_cursor();
		return;
	}
	if (g.programOpen)
	{
		ui_draw_program_editor(sw, sh);
		ui_draw_cursor();
		return;
	}

	ui_draw_world(sw, sh);
	ui_draw_hud(sw, sh);
	if (g.stationOpen)
	{
		ui_draw_station(sw, sh);
	}
	if (g.inventoryOpen)
	{
		ui_draw_inventory(sw, sh);
	}
	ui_draw_signal_editor(sw, sh);
	ui_draw_commands(sw, sh);
	ui_draw_chat(sw, sh);
	if (g.paused)
	{
		ui_draw_pause(sw, sh);
	}
	ui_draw_tooltip();
	ui_draw_cursor();
}
