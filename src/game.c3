// TerraBlock core state, item/block/tool data and shared helpers.
module minecraft;
import rl;
import std::collections::list;
import std::collections::map;
import std::core::string;
import std::io, std::io::file;
import std::math, std::math::random;
import perlin;

// ---------------------------------------------------------------------------
// Constants
// ---------------------------------------------------------------------------
const int GRID = 32;
const int CHUNK_TILES = 32;
const int CHUNK_W = CHUNK_TILES * GRID;
const int SEA = GRID * 3;
const int INVENTORY_SLOTS = 100;
const int HOTBAR_SLOTS = 10;
const int MAX_DROPS = 140;
const int MAX_ENEMIES = 14;
const int TICKS_PER_SECOND = 20;
const float DAY_LEN = 520.0f;
const float TORCH_RADIUS = 7.0f * GRID;

// Item ids.  0 is always empty.
alias ItemId = int;
const ItemId ITEM_NONE = 0;

// Blocks
const ItemId ITEM_GRASS = 1;
const ItemId ITEM_DIRT = 2;
const ItemId ITEM_STONE = 3;
const ItemId ITEM_DEEPSTONE = 4;
const ItemId ITEM_LOG = 5;
const ItemId ITEM_LEAVES = 6;
const ItemId ITEM_PINELEAVES = 7;
const ItemId ITEM_GOLD = 8;
const ItemId ITEM_IRON = 9;
const ItemId ITEM_COPPER = 10;
const ItemId ITEM_REDSTONE = 11;
const ItemId ITEM_COAL = 12;
const ItemId ITEM_SAND = 13;
const ItemId ITEM_SANDSTONE = 14;
const ItemId ITEM_GLASS = 15;
const ItemId ITEM_WATER = 16;
const ItemId ITEM_ICE = 17;
const ItemId ITEM_TNT = 18;
const ItemId ITEM_PLANKS = 19;
const ItemId ITEM_PINEPLANKS = 20;
const ItemId ITEM_CAVEBLOCK = 21;
const ItemId ITEM_WORKBENCH = 22;
const ItemId ITEM_FURNACE = 23;
const ItemId ITEM_TORCH = 24;
const ItemId ITEM_BRICK = 25;
const ItemId ITEM_COBBLE = 26;
const ItemId ITEM_CLAY = 27;
const ItemId ITEM_SNOW = 28;
const ItemId ITEM_CACTUS = 29;
const ItemId ITEM_MUSHROOM = 30;
const ItemId ITEM_CRYSTAL = 31;
const ItemId ITEM_PLATFORM = 32;
const ItemId ITEM_CHEST = 33;
const ItemId ITEM_LADDER = 34;
const ItemId ITEM_DOOR = 35;
const ItemId ITEM_BOOKSHELF = 36;
const ItemId ITEM_ANVIL = 37;
const ItemId ITEM_ROPE = 38;
const ItemId ITEM_BED = 39;
const ItemId ITEM_GRAVEL = 40;
const ItemId ITEM_BIRCHLOG = 41;
const ItemId ITEM_BIRCHPLANKS = 42;
const ItemId ITEM_WIRE = 43;
const ItemId ITEM_WIRE4 = 44;
const ItemId ITEM_WIRE8 = 45;
const ItemId ITEM_WIRE16 = 46;
const ItemId ITEM_WIRE32 = 47;
const ItemId ITEM_ANDGATE = 48;
const ItemId ITEM_ORGATE = 49;
const ItemId ITEM_XORGATE = 50;
const ItemId ITEM_NOTGATE = 51;
const ItemId ITEM_NANDGATE = 52;
const ItemId ITEM_NORGATE = 53;
const ItemId ITEM_CIRCUITBOARD16 = 54;
const ItemId ITEM_CIRCUITBOARD32 = 55;
const ItemId ITEM_CIRCUITBOARD64 = 56;
const ItemId ITEM_LEVER4 = 57;
const ItemId ITEM_LEVER8 = 58;
const ItemId ITEM_LEVER16 = 59;
const ItemId ITEM_LEVER32 = 60;
const ItemId ITEM_BUTTON4 = 61;
const ItemId ITEM_BUTTON8 = 62;
const ItemId ITEM_BUTTON16 = 63;
const ItemId ITEM_BUTTON32 = 64;
const ItemId ITEM_LEVER = 65;
const ItemId ITEM_BUTTON = 66;
const ItemId ITEM_PROGRAMMABLE = 67;
const ItemId ITEM_DISPLAY = 68;
const ItemId ITEM_LAMP = 69;
const ItemId ITEM_ANALOGLAMP = 70;
const ItemId ITEM_SIGNALSOURCE = 71;

// Tools
const ItemId ITEM_WOODPICKAXE = 72;
const ItemId ITEM_STONEPICKAXE = 73;
const ItemId ITEM_IRONPICKAXE = 74;
const ItemId ITEM_GOLDPICKAXE = 75;
const ItemId ITEM_CRYSTALPICK = 76;
const ItemId ITEM_WOODAXE = 77;
const ItemId ITEM_STONEAXE = 78;
const ItemId ITEM_IRONAXE = 79;
const ItemId ITEM_WOODSWORD = 80;
const ItemId ITEM_STONESWORD = 81;
const ItemId ITEM_IRONSWORD = 82;
const ItemId ITEM_GOLDSWORD = 83;
const ItemId ITEM_CRYSTALSWORD = 84;
const ItemId ITEM_WOODHAMMER = 85;
const ItemId ITEM_STONEHAMMER = 86;
const ItemId ITEM_WRENCH = 87;

// Item-only
const ItemId ITEM_IRONBAR = 88;
const ItemId ITEM_COPPERBAR = 89;
const ItemId ITEM_GOLDBAR = 90;
const ItemId ITEM_GEL = 91;
const ItemId ITEM_STRING = 92;
const ItemId ITEM_PAPER = 93;
const ItemId ITEM_BOOK = 94;
const ItemId ITEM_COOKEDMUSHROOM = 95;
const ItemId ITEM_APPLE = 96;
const int ITEM_COUNT = 97;

// Game states
const int GS_MENU = 0;
const int GS_WORLD_SELECT = 1;
const int GS_WORLD_CREATE = 2;
const int GS_MODS = 3;
const int GS_PLAYING = 4;

// Tools
enum ToolKind : int
{
	NONE,
	ANY,
	PICKAXE,
	AXE,
	SWORD,
	HAMMER,
	WRENCH,
}

enum InteractKind : int
{
	NONE,
	WORKBENCH,
	FURNACE,
	CHEST,
	ANVIL,
	DOOR,
	BED,
	LOGIC,
	CIRCUITBOARD,
	PROGRAMMABLE,
	SIGNALSOURCE,
}

enum StationKind : int
{
	HAND,
	WORKBENCH,
	ANVIL,
}

enum EnemyKind : int
{
	SLIME,
	BAT,
	ZOMBIE,
	BLOOD,
}

enum BlockEntityKind : int
{
	CHEST,
	FURNACE,
	PLATFORM,
}

// ---------------------------------------------------------------------------
// Structs
// ---------------------------------------------------------------------------
struct BlockDef
{
	ZString name;
	Color   color;
	float   hard;
	ToolKind tool;
	ItemId  drop;
	bool    valid;
	bool    solid;
	bool    nonCollide;
	bool    liquid;
	bool    platform;
	bool    climb;
	bool    falls;
	bool    light;
	float   alpha;
	InteractKind interact;
}

struct ToolDef
{
	ZString name;
	float   power;
	float   speed;
	ToolKind type;
	Color   color;
	int     dmg;
	bool    valid;
}

struct ItemDef
{
	ZString name;
	Color   color;
	bool    valid;
}

struct Ingredient
{
	ItemId id;
	int    count;
}

struct Recipe
{
	int        cat;
	StationKind station;
	ZString    name;
	Ingredient[2] ingredients;
	int        ingCount;
	ItemId     result;
	int        resultCount;
}

struct SmeltRecipe
{
	ItemId inId;
	ItemId outId;
	int    outN;
	int    fuel;
}

struct Stack
{
	ItemId id;
	int    count;
}

struct Consumable
{
	ItemId id;
	int    hp;
	int    hunger;
}

struct Player
{
	float x, y, vx, vy;
	int   w, h;
	bool  onGround;
	float speed, jump, grav;
	float health, maxHealth, hurt, fallSpeed;
	float hunger, maxHunger;
	Stack[INVENTORY_SLOTS] inv;
	int   hot;
	int   facing;
	float spawnX, spawnY;
	bool  climbing, flying;
	double lastJump;
}

struct TileRef
{
	ItemId id;
	bool   exists;
}

struct Chunk
{
	int index;
	int firstTx, lastTx;
	HashMap{long, ItemId} fg;
	HashMap{long, ItemId} bg;
}

struct WorldEdit
{
	int    tx, ty;
	ItemId id;
	bool   bg;
	bool   has;
}

struct Drop
{
	float x, y, vx, vy;
	ItemId id;
	int   count;
	float life, bob;
}

struct Particle
{
	float x, y, vx, vy;
	float life, max;
	Color color;
	float size;
}

struct FloatText
{
	float x, y, vy;
	float life, max;
	char[32] text;
	Color color;
}

struct Enemy
{
	int   id;
	float x, y, w, h, vx, vy;
	float health, max, dmg, speed;
	float atkCd, hurt;
	EnemyKind kind;
	bool  flying;
	bool  onGround;
}

struct TntFuse
{
	int   tx, ty;
	float timer;
}

// Logic
struct Pin
{
	int dir;   // 0 off, 1 in, 2 out, 3 inout
	int bits;
}

struct BoardCell
{
	ItemId type;
	int    bitWidth;
	uint   value;
	int    timer;
	int    x, y;
}

struct Board
{
	int w, h;
	Pin[4] pins; // N,S,E,W
	uint[4] sides; // N,S,E,W
	HashMap{long, BoardCell} cells;
}

struct LogicCell
{
	ItemId type;
	int    x, y;
	int    bitWidth;
	uint   value;
	int    timer;
	uint[2] outputs; // E,S
	bool   hasBoard;
	Board  board;
	char[2048] code;
	int    codeLen;
	bool   codeValid;
	char[160] codeError;
}

struct BlockEntity
{
	BlockEntityKind kind;
	int x, y;
	Stack[20] slots;
	Stack input, fuel, output;
	int progress, fuelTime, maxFuelTime;
	int position; // 0 top, 1 middle, 2 bottom
}

struct SaveEntry
{
	int seed;
	int mode; // 0 survival, 1 creative
	bool hostiles;
	char[32] modified;
}

struct ModEntry
{
	char[64] folder;
	char[64] name;
	char[64] version;
	char[128] description;
	bool isDatapack;
}

struct TextureOverride
{
	char[32] kind;
	char[48] id;
	char[160] path;
}

// ---------------------------------------------------------------------------
// Global state
// ---------------------------------------------------------------------------
struct State
{
	// world
	HashMap{int, Chunk*} chunks;
	HashMap{long, WorldEdit} edits;
	HashMap{long, WorldEdit} editsBg;
	HashMap{long, bool} openDoors;
	HashMap{long, int} waterLevels;
	HashMap{long, LogicCell*} logic;
	HashMap{long, BlockEntity*} entities;
	int  currentSeed;
	float timeOfDay;
	bool bloodMoon;
	int  bloodMoonChecked;
	int  lastStreamCenter;
	int  lastStreamRadius;
	bool streamValid;
	bool generatingChunk;
	Chunk* activeChunk;

	// player / camera
	Player player;
	bool   playerCreated;
	float  cameraX, cameraY;

	// entities
	List{Drop} drops;
	List{Particle} particles;
	List{FloatText} floats;
	List{Enemy} enemies;
	List{TntFuse} tntFuses;
	int nextEnemyId;

	// UI / flow
	int   gameState;
	bool  creativeMode;
	bool  hostilesEnabled;
	bool  paused;
	bool  debugMode;
	bool  ghostMode;
	bool  backgroundMode;
	bool  inventoryOpen;
	bool  stationOpen;
	bool  boardOpen;
	bool  programOpen;
	bool  signalSourceOpen;
	bool  cmdOpen;
	bool  chatOpen;
	int   stationTab;
	int   stationFurnaceX, stationFurnaceY;
	bool  stationFurnaceValid;
	int   stationChestX, stationChestY;
	bool  stationChestValid;
	int   craftCategory;
	int   craftScroll;
	int   boardCellX, boardCellY;
	int   boardSelected;
	int   boardPinSide;
	int   boardPinDir;
	int   boardPinBits;
	int   programCellX, programCellY;
	int   signalCellX, signalCellY;
	int   uiActiveField;
	char[64] fieldSeed;
	int   fieldSeedLen;
	char[64] fieldHost;
	int   fieldHostLen;
	char[64] fieldPort;
	int   fieldPortLen;
	char[64] fieldName;
	int   fieldNameLen;
	char[2048] programText;
	int   programTextLen;
	char[64] signalText;
	int   signalTextLen;
	char[160] commandText;
	int   commandLen;
	char[8][160] commandLog;
	Color[8] commandLogColor;
	int   commandLogCount;
	char[160] chatText;
	int   chatTextLen;
	int   chatScroll;
	float messageTimer;
	char[512] messageText;
	float blockActionTimer;
	float miningProgress;
	int   miningX, miningY;
	bool  miningBg;
	bool  miningActive;
	bool  hasTooltip;
	char[160] tooltipText;
	int   tooltipX, tooltipY;

	// inventory
	Stack held;
	bool  hasHeld;

	// settings
	int  worldMode; // 0 survival, 1 creative
	bool worldHostiles;

	// UI screens
	int  menuSubstate; // 0 main, 1 multiplayer, 2 touch grass
	int  selectedWorldSeed;
	bool saveListDirty;
	List{SaveEntry} saves;
	List{ModEntry} mods;
	List{TextureOverride} textureOverrides;

	// tick
	int   tickCount;
	float tickAccumulator;
}

State g;

BlockDef[ITEM_COUNT] blockDefs;
ToolDef[ITEM_COUNT] toolDefs;
ItemDef[ITEM_COUNT] itemDefs;
ZString[ITEM_COUNT] itemNames;
bool[ITEM_COUNT] itemIsBlock;
bool[ITEM_COUNT] itemIsTool;
bool[ITEM_COUNT] itemIsItemOnly;

// Recipes
const int MAX_RECIPES = 96;
Recipe[MAX_RECIPES] recipes;
int recipeCount;
SmeltRecipe[16] smeltRecipes;
int smeltRecipeCount;

ZString[] craftCategories = { "Basic", "Tools", "Weapons", "Blocks", "Stations", "Logic", "Misc" };

// ---------------------------------------------------------------------------
// Small helpers
// ---------------------------------------------------------------------------
fn Color rgb(int r, int g, int b)
{
	return (Color) { (char)r, (char)g, (char)b, (char)255 };
}

fn Color rgba(int r, int g, int b, int a)
{
	return (Color) { (char)r, (char)g, (char)b, (char)a };
}

fn Color shade(Color c, float f)
{
	return (Color) { (char)(int)(c.r * f), (char)(int)(c.g * f),
	                 (char)(int)(c.b * f), c.a };
}

fn Color with_alpha(Color c, int a)
{
	return (Color) { c.r, c.g, c.b, (char)a };
}

fn long tile_key(int tx, int ty)
{
	return ((long)(uint)tx << 32) | (uint)ty;
}

fn int key_x(long k)
{
	return (int)(k >> 32);
}

fn int key_y(long k)
{
	return (int)(k & 0xFFFFFFFF);
}

fn int tile_of(float px)
{
	return (int)math::floor(px / (float)GRID);
}

fn int snap_i(float px)
{
	return tile_of(px) * GRID;
}

fn float hash2(int x, int y, int seed, int salt)
{
	uint n = (uint)x * 374761393u + (uint)y * 668265263u
	       + (uint)seed * 1274126177u + (uint)salt * 2246822519u;
	n = n * 1103515245u + 12345u;
	return (float)(n % 100000u) / 100000.0f;
}

fn float hash1(int x, int seed, int salt)
{
	return hash2(x, 0, seed, salt);
}

fn int irandom(int n)
{
	return random::rand(n);
}

fn float frandom()
{
	return (float)random::rand(1000000) / 1000000.0f;
}

fn float fmin(float a, float b) { return a < b ? a : b; }
fn float fmax(float a, float b) { return a > b ? a : b; }
fn float clampf(float v, float lo, float hi) { return v < lo ? lo : (v > hi ? hi : v); }
fn int mini(int a, int b) { return a < b ? a : b; }
fn int maxi(int a, int b) { return a > b ? a : b; }

fn int chunk_index(int tx)
{
	if (tx >= 0) return tx / CHUNK_W;
	return -((-tx + CHUNK_W - 1) / CHUNK_W);
}

fn void copy_cstr(char* dst, usz cap, ZString src)
{
	if (!src || cap == 0) { if (cap) dst[0] = 0; return; }
	usz i = 0;
	while (i + 1 < cap && src[i] != 0)
	{
		dst[i] = src[i];
		i++;
	}
	dst[i] = 0;
}

// bformat returns a String without writing a terminator. This wrapper keeps
// the buffer usable as a ZString (all UI/text code expects null-terminated C strings).
macro ZString zfmt(char[] buf, String fmt, args...) @format(1)
{
	String s = string::bformat(buf, fmt, ...args);
	if (s.len < buf.len)
	{
		buf[s.len] = 0;
	}
	else if (buf.len > 0)
	{
		buf[buf.len - 1] = 0;
	}
	return (ZString)buf.ptr;
}

fn void show_msg(ZString text, float duration)
{
	copy_cstr(&g.messageText, g.messageText.len, text);
	g.messageTimer = duration > 0 ? duration : 2.2f;
}

fn int total_slots()
{
	return g.creativeMode ? INVENTORY_SLOTS : 50;
}

fn void inv_clear()
{
	for (int i = 0; i < INVENTORY_SLOTS; i++) g.player.inv[i] = { 0, 0 };
}

fn bool add_inv(ItemId id, int count)
{
	if (id <= 0 || id >= ITEM_COUNT) return false;
	if (count <= 0) count = 1;
	int total = total_slots();
	if (is_tool(id))
	{
		for (int i = 0; i < total; i++)
		{
			if (g.player.inv[i].id == 0)
			{
				g.player.inv[i] = { id, 1 };
				return true;
			}
		}
		return false;
	}
	for (int i = 0; i < total; i++)
	{
		if (g.player.inv[i].id == id)
		{
			g.player.inv[i].count += count;
			return true;
		}
	}
	for (int i = 0; i < total; i++)
	{
		if (g.player.inv[i].id == 0)
		{
			g.player.inv[i] = { id, count };
			return true;
		}
	}
	return false;
}

fn bool rem_inv(ItemId id, int count)
{
	if (count <= 0) count = 1;
	int total = total_slots();
	for (int i = 0; i < total; i++)
	{
		Stack* s = &g.player.inv[i];
		if (s.id == id && s.count > 0)
		{
			if (s.count > count) { s.count -= count; return true; }
			if (s.count == count) { *s = { 0, 0 }; return true; }
		}
	}
	return false;
}

fn int count_inv(ItemId id)
{
	int n = 0;
	int total = total_slots();
	for (int i = 0; i < total; i++)
	{
		if (g.player.inv[i].id == id) n += g.player.inv[i].count;
	}
	return n;
}

fn ItemId selected_id()
{
	int hot = g.player.hot;
	if (hot < 0) hot = 0;
	if (hot >= HOTBAR_SLOTS) hot = HOTBAR_SLOTS - 1;
	Stack* s = &g.player.inv[hot];
	return (s.id > 0 && s.count > 0) ? s.id : 0;
}

fn ToolDef* equipped_tool()
{
	return tool_def(selected_id());
}

fn bool near_station(ItemId type)
{
	float reach = (float)(GRID * 5);
	float px = g.player.x + (float)g.player.w / 2.0f;
	float py = g.player.y + (float)g.player.h / 2.0f;
	foreach (c : g.chunks.iter())
	{
		Chunk* ch = c.value;
		if (!ch) continue;
		foreach (e : ch.fg.iter())
		{
			if (e.value != type) continue;
			int bx = key_x(e.key);
			int by = key_y(e.key);
			float dx = (float)bx + (float)GRID / 2.0f - px;
			float dy = (float)by + (float)GRID / 2.0f - py;
			if (dx * dx + dy * dy < reach * reach) return true;
		}
	}
	return false;
}

fn bool can_craft(Recipe* r)
{
	for (int i = 0; i < r.ingCount; i++)
	{
		if (count_inv(r.ingredients[i].id) < r.ingredients[i].count) return false;
	}
	return true;
}

fn void return_held_stack()
{
	if (!g.hasHeld) return;
	int total = total_slots();
	if (!is_tool(g.held.id))
	{
		for (int i = 0; i < total; i++)
		{
			if (g.player.inv[i].id == g.held.id)
			{
				g.player.inv[i].count += g.held.count;
				g.hasHeld = false;
				g.held = { 0, 0 };
				return;
			}
		}
	}
	for (int i = 0; i < total; i++)
	{
		if (g.player.inv[i].id == 0)
		{
			g.player.inv[i] = g.held;
			g.hasHeld = false;
			g.held = { 0, 0 };
			return;
		}
	}
	g.hasHeld = false;
	g.held = { 0, 0 };
}

fn int max_stack(ItemId id)
{
	return is_tool(id) ? 1 : 999;
}

fn bool is_non_collide(ItemId id, int tx, int ty)
{
	if (id == ITEM_DOOR)
	{
		if (try v = g.openDoors.get(tile_key(tx, ty))) return v;
		return false;
	}
	BlockDef* d = block_def(id);
	return d && d.nonCollide;
}

fn int consumable_hp(ItemId id)
{
	switch (id)
	{
		case ITEM_MUSHROOM: return 10;
		case ITEM_COOKEDMUSHROOM: return 25;
		case ITEM_APPLE: return 15;
		case ITEM_GEL: return 5;
		default: return 0;
	}
}

fn int consumable_hunger(ItemId id)
{
	switch (id)
	{
		case ITEM_MUSHROOM: return 12;
		case ITEM_COOKEDMUSHROOM: return 40;
		case ITEM_APPLE: return 20;
		case ITEM_GEL: return 4;
		default: return 0;
	}
}

// ---------------------------------------------------------------------------
// Item / block queries
// ---------------------------------------------------------------------------
fn bool is_block(ItemId id)
{
	return id > 0 && id < ITEM_COUNT && itemIsBlock[id];
}

fn bool is_tool(ItemId id)
{
	return id > 0 && id < ITEM_COUNT && itemIsTool[id];
}

fn bool is_item(ItemId id)
{
	return id > 0 && id < ITEM_COUNT && (itemIsBlock[id] || itemIsTool[id] || itemIsItemOnly[id]);
}

fn BlockDef* block_def(ItemId id)
{
	if (id <= 0 || id >= ITEM_COUNT || !blockDefs[id].valid) return null;
	return &blockDefs[id];
}

fn ToolDef* tool_def(ItemId id)
{
	if (id <= 0 || id >= ITEM_COUNT || !toolDefs[id].valid) return null;
	return &toolDefs[id];
}

fn ZString item_name(ItemId id)
{
	if (id <= 0 || id >= ITEM_COUNT) return "Air";
	if (itemNames[id]) return itemNames[id];
	return "Unknown";
}

fn Color item_color(ItemId id)
{
	if (id <= 0 || id >= ITEM_COUNT) return rgb(128, 128, 128);
	if (blockDefs[id].valid) return blockDefs[id].color;
	if (toolDefs[id].valid) return toolDefs[id].color;
	if (itemDefs[id].valid) return itemDefs[id].color;
	return rgb(128, 128, 128);
}

fn bool is_wire(ItemId id)
{
	return id == ITEM_WIRE || id == ITEM_WIRE4 || id == ITEM_WIRE8
	    || id == ITEM_WIRE16 || id == ITEM_WIRE32;
}

fn bool is_gate(ItemId id)
{
	return id == ITEM_ANDGATE || id == ITEM_ORGATE || id == ITEM_XORGATE
	    || id == ITEM_NOTGATE || id == ITEM_NANDGATE || id == ITEM_NORGATE;
}

fn bool is_lever(ItemId id)
{
	return id == ITEM_LEVER || id == ITEM_LEVER4 || id == ITEM_LEVER8
	    || id == ITEM_LEVER16 || id == ITEM_LEVER32;
}

fn bool is_button(ItemId id)
{
	return id == ITEM_BUTTON || id == ITEM_BUTTON4 || id == ITEM_BUTTON8
	    || id == ITEM_BUTTON16 || id == ITEM_BUTTON32;
}

fn bool is_board(ItemId id)
{
	return id == ITEM_CIRCUITBOARD16 || id == ITEM_CIRCUITBOARD32 || id == ITEM_CIRCUITBOARD64;
}

fn bool is_logic(ItemId id)
{
	return is_wire(id) || is_lever(id) || is_button(id) || is_gate(id) || is_board(id)
	    || id == ITEM_LAMP || id == ITEM_ANALOGLAMP || id == ITEM_DISPLAY
	    || id == ITEM_PROGRAMMABLE || id == ITEM_SIGNALSOURCE;
}

fn int logic_bits(ItemId id)
{
	switch (id)
	{
		case ITEM_WIRE4: return 4;
		case ITEM_WIRE8: return 8;
		case ITEM_WIRE16: return 16;
		case ITEM_WIRE32: return 32;
		case ITEM_LEVER4: return 4;
		case ITEM_LEVER8: return 8;
		case ITEM_LEVER16: return 16;
		case ITEM_LEVER32: return 32;
		case ITEM_BUTTON4: return 4;
		case ITEM_BUTTON8: return 8;
		case ITEM_BUTTON16: return 16;
		case ITEM_BUTTON32: return 32;
		case ITEM_ANALOGLAMP: return 4;
		case ITEM_DISPLAY: return 8;
		case ITEM_PROGRAMMABLE: return 8;
		case ITEM_SIGNALSOURCE: return 8;
		default: return 1;
	}
}

fn uint mask_bits(int bits)
{
	if (bits >= 32) return 0xFFFFFFFFu;
	return (1u << bits) - 1u;
}

fn uint bnot_bits(uint v, int bits)
{
	return (~v) & mask_bits(bits);
}

// ---------------------------------------------------------------------------
// Data initialisation
// ---------------------------------------------------------------------------
fn void set_block(ItemId id, ZString name, int r, int g, int b, float hard,
                  ToolKind tool, ItemId drop, bool solid, float alpha)
{
	blockDefs[id].name = name;
	blockDefs[id].color = rgb(r, g, b);
	blockDefs[id].hard = hard;
	blockDefs[id].tool = tool;
	blockDefs[id].drop = drop;
	blockDefs[id].valid = true;
	blockDefs[id].solid = solid;
	blockDefs[id].alpha = alpha;
	itemNames[id] = name;
	itemIsBlock[id] = true;
}

fn void set_tool(ItemId id, ZString name, float power, float speed, ToolKind type,
                 int r, int g, int b, int dmg)
{
	toolDefs[id].name = name;
	toolDefs[id].power = power;
	toolDefs[id].speed = speed;
	toolDefs[id].type = type;
	toolDefs[id].color = rgb(r, g, b);
	toolDefs[id].dmg = dmg;
	toolDefs[id].valid = true;
	itemNames[id] = name;
	itemIsTool[id] = true;
}

fn void set_item(ItemId id, ZString name, int r, int g, int b)
{
	itemDefs[id].name = name;
	itemDefs[id].color = rgb(r, g, b);
	itemDefs[id].valid = true;
	itemNames[id] = name;
	itemIsItemOnly[id] = true;
}

fn void add_recipe(int cat, StationKind station, ZString name,
                   ItemId a, int an, ItemId b, int bn, ItemId result, int rn)
{
	if (recipeCount >= MAX_RECIPES) return;
	Recipe* r = &recipes[recipeCount++];
	r.cat = cat;
	r.station = station;
	r.name = name;
	r.ingredients[0] = { a, an };
	if (b != ITEM_NONE)
	{
		r.ingredients[1] = { b, bn };
		r.ingCount = 2;
	}
	else
	{
		r.ingCount = 1;
	}
	r.result = result;
	r.resultCount = rn;
}

fn void add_smelt(ItemId inId, ItemId outId, int outN, int fuel)
{
	if (smeltRecipeCount >= 16) return;
	smeltRecipes[smeltRecipeCount++] = { inId, outId, outN, fuel };
}

fn void init_data()
{
	// Blocks
	set_block(ITEM_GRASS, "Grass", 87, 179, 66, 0.55f, ToolKind.ANY, ITEM_DIRT, true, 1.0f);
	set_block(ITEM_DIRT, "Dirt", 138, 92, 51, 0.45f, ToolKind.ANY, ITEM_DIRT, true, 1.0f);
	set_block(ITEM_STONE, "Stone", 133, 133, 140, 1.40f, ToolKind.PICKAXE, ITEM_STONE, true, 1.0f);
	set_block(ITEM_DEEPSTONE, "Deep Stone", 97, 97, 107, 2.00f, ToolKind.PICKAXE, ITEM_STONE, true, 1.0f);
	set_block(ITEM_LOG, "Log", 112, 69, 31, 0.95f, ToolKind.AXE, ITEM_LOG, false, 1.0f);
	set_block(ITEM_LEAVES, "Leaves", 51, 133, 46, 0.15f, ToolKind.ANY, ITEM_LEAVES, false, 1.0f);
	set_block(ITEM_PINELEAVES, "Pine Leaves", 31, 102, 56, 0.15f, ToolKind.ANY, ITEM_LEAVES, false, 1.0f);
	set_block(ITEM_GOLD, "Gold Ore", 240, 194, 36, 2.10f, ToolKind.PICKAXE, ITEM_GOLD, true, 1.0f);
	set_block(ITEM_IRON, "Iron Ore", 184, 148, 122, 1.70f, ToolKind.PICKAXE, ITEM_IRON, true, 1.0f);
	set_block(ITEM_COPPER, "Copper Ore", 199, 122, 71, 1.50f, ToolKind.PICKAXE, ITEM_COPPER, true, 1.0f);
	set_block(ITEM_REDSTONE, "Redstone Ore", 209, 36, 36, 1.70f, ToolKind.PICKAXE, ITEM_REDSTONE, true, 1.0f);
	set_block(ITEM_COAL, "Coal Ore", 41, 41, 46, 1.50f, ToolKind.PICKAXE, ITEM_COAL, true, 1.0f);
	set_block(ITEM_SAND, "Sand", 224, 204, 107, 0.35f, ToolKind.ANY, ITEM_SAND, true, 1.0f);
	set_block(ITEM_SANDSTONE, "Sandstone", 199, 173, 102, 1.00f, ToolKind.PICKAXE, ITEM_SANDSTONE, true, 1.0f);
	set_block(ITEM_GLASS, "Glass", 173, 214, 240, 0.25f, ToolKind.ANY, ITEM_GLASS, true, 0.50f);
	set_block(ITEM_WATER, "Water", 46, 107, 209, 0.0f, ToolKind.ANY, ITEM_NONE, false, 0.50f);
	set_block(ITEM_ICE, "Ice", 179, 217, 242, 0.40f, ToolKind.ANY, ITEM_ICE, true, 0.70f);
	set_block(ITEM_TNT, "TNT", 209, 46, 36, 0.70f, ToolKind.ANY, ITEM_TNT, true, 1.0f);
	set_block(ITEM_PLANKS, "Planks", 179, 133, 71, 0.75f, ToolKind.AXE, ITEM_PLANKS, true, 1.0f);
	set_block(ITEM_PINEPLANKS, "Pine Planks", 140, 107, 71, 0.80f, ToolKind.AXE, ITEM_PINEPLANKS, true, 1.0f);
	set_block(ITEM_CAVEBLOCK, "Cave", 5, 5, 8, 0.0f, ToolKind.ANY, ITEM_NONE, false, 1.0f);
	set_block(ITEM_WORKBENCH, "Workbench", 148, 102, 51, 0.90f, ToolKind.AXE, ITEM_WORKBENCH, true, 1.0f);
	set_block(ITEM_FURNACE, "Furnace", 102, 102, 112, 1.20f, ToolKind.PICKAXE, ITEM_FURNACE, true, 1.0f);
	set_block(ITEM_TORCH, "Torch", 240, 189, 56, 0.08f, ToolKind.ANY, ITEM_TORCH, false, 1.0f);
	set_block(ITEM_BRICK, "Brick", 158, 82, 56, 1.30f, ToolKind.PICKAXE, ITEM_BRICK, true, 1.0f);
	set_block(ITEM_COBBLE, "Cobblestone", 122, 122, 128, 1.20f, ToolKind.PICKAXE, ITEM_COBBLE, true, 1.0f);
	set_block(ITEM_CLAY, "Clay", 173, 133, 102, 0.50f, ToolKind.ANY, ITEM_CLAY, true, 1.0f);
	set_block(ITEM_SNOW, "Snow", 235, 240, 250, 0.20f, ToolKind.ANY, ITEM_SNOW, true, 1.0f);
	set_block(ITEM_CACTUS, "Cactus", 64, 158, 71, 0.40f, ToolKind.ANY, ITEM_CACTUS, false, 1.0f);
	set_block(ITEM_MUSHROOM, "Mushroom", 217, 77, 71, 0.05f, ToolKind.ANY, ITEM_MUSHROOM, false, 1.0f);
	set_block(ITEM_CRYSTAL, "Crystal", 140, 89, 230, 2.40f, ToolKind.PICKAXE, ITEM_CRYSTAL, true, 1.0f);
	set_block(ITEM_PLATFORM, "Platform", 153, 115, 64, 0.50f, ToolKind.AXE, ITEM_PLATFORM, false, 1.0f);
	set_block(ITEM_CHEST, "Chest", 166, 107, 38, 0.80f, ToolKind.AXE, ITEM_CHEST, true, 1.0f);
	set_block(ITEM_LADDER, "Ladder", 140, 97, 46, 0.40f, ToolKind.AXE, ITEM_LADDER, false, 1.0f);
	set_block(ITEM_DOOR, "Door", 128, 82, 36, 0.70f, ToolKind.AXE, ITEM_DOOR, false, 1.0f);
	set_block(ITEM_BOOKSHELF, "Bookshelf", 122, 82, 46, 0.70f, ToolKind.AXE, ITEM_BOOKSHELF, true, 1.0f);
	set_block(ITEM_ANVIL, "Anvil", 89, 89, 97, 1.80f, ToolKind.PICKAXE, ITEM_ANVIL, true, 1.0f);
	set_block(ITEM_ROPE, "Rope", 179, 153, 89, 0.10f, ToolKind.ANY, ITEM_ROPE, false, 1.0f);
	set_block(ITEM_BED, "Bed", 191, 64, 77, 0.60f, ToolKind.AXE, ITEM_BED, true, 1.0f);
	set_block(ITEM_GRAVEL, "Gravel", 140, 133, 122, 0.40f, ToolKind.ANY, ITEM_GRAVEL, true, 1.0f);
	set_block(ITEM_BIRCHLOG, "Birch Log", 184, 173, 148, 0.95f, ToolKind.AXE, ITEM_BIRCHLOG, false, 1.0f);
	set_block(ITEM_BIRCHPLANKS, "Birch Planks", 204, 184, 140, 0.80f, ToolKind.AXE, ITEM_BIRCHPLANKS, true, 1.0f);

	// Logic blocks
	set_block(ITEM_WIRE, "Wire", 153, 51, 51, 0.5f, ToolKind.ANY, ITEM_WIRE, false, 1.0f);
	set_block(ITEM_WIRE4, "Wire 4-bit", 153, 51, 51, 0.5f, ToolKind.ANY, ITEM_WIRE4, false, 1.0f);
	set_block(ITEM_WIRE8, "Wire 8-bit", 153, 51, 51, 0.5f, ToolKind.ANY, ITEM_WIRE8, false, 1.0f);
	set_block(ITEM_WIRE16, "Wire 16-bit", 153, 51, 51, 0.5f, ToolKind.ANY, ITEM_WIRE16, false, 1.0f);
	set_block(ITEM_WIRE32, "Wire 32-bit", 153, 51, 51, 0.5f, ToolKind.ANY, ITEM_WIRE32, false, 1.0f);
	set_block(ITEM_ANDGATE, "AND Gate", 102, 179, 230, 0.5f, ToolKind.ANY, ITEM_ANDGATE, false, 1.0f);
	set_block(ITEM_ORGATE, "OR Gate", 102, 179, 230, 0.5f, ToolKind.ANY, ITEM_ORGATE, false, 1.0f);
	set_block(ITEM_XORGATE, "XOR Gate", 102, 179, 230, 0.5f, ToolKind.ANY, ITEM_XORGATE, false, 1.0f);
	set_block(ITEM_NOTGATE, "NOT Gate", 102, 179, 230, 0.5f, ToolKind.ANY, ITEM_NOTGATE, false, 1.0f);
	set_block(ITEM_NANDGATE, "NAND Gate", 102, 179, 230, 0.5f, ToolKind.ANY, ITEM_NANDGATE, false, 1.0f);
	set_block(ITEM_NORGATE, "NOR Gate", 102, 179, 230, 0.5f, ToolKind.ANY, ITEM_NORGATE, false, 1.0f);
	set_block(ITEM_CIRCUITBOARD16, "Circuit Board 16", 71, 122, 71, 1.50f, ToolKind.AXE, ITEM_CIRCUITBOARD16, true, 1.0f);
	set_block(ITEM_CIRCUITBOARD32, "Circuit Board 32", 61, 107, 61, 2.00f, ToolKind.AXE, ITEM_CIRCUITBOARD32, true, 1.0f);
	set_block(ITEM_CIRCUITBOARD64, "Circuit Board 64", 51, 92, 51, 2.50f, ToolKind.AXE, ITEM_CIRCUITBOARD64, true, 1.0f);
	set_block(ITEM_LEVER4, "Lever 4-bit", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_LEVER4, false, 1.0f);
	set_block(ITEM_LEVER8, "Lever 8-bit", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_LEVER8, false, 1.0f);
	set_block(ITEM_LEVER16, "Lever 16-bit", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_LEVER16, false, 1.0f);
	set_block(ITEM_LEVER32, "Lever 32-bit", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_LEVER32, false, 1.0f);
	set_block(ITEM_BUTTON4, "Button 4-bit", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_BUTTON4, false, 1.0f);
	set_block(ITEM_BUTTON8, "Button 8-bit", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_BUTTON8, false, 1.0f);
	set_block(ITEM_BUTTON16, "Button 16-bit", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_BUTTON16, false, 1.0f);
	set_block(ITEM_BUTTON32, "Button 32-bit", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_BUTTON32, false, 1.0f);
	set_block(ITEM_LEVER, "Lever", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_LEVER, false, 1.0f);
	set_block(ITEM_BUTTON, "Button", 128, 128, 128, 0.5f, ToolKind.ANY, ITEM_BUTTON, false, 1.0f);
	set_block(ITEM_PROGRAMMABLE, "Programmable Circuit", 36, 56, 92, 1.60f, ToolKind.AXE, ITEM_PROGRAMMABLE, true, 1.0f);
	set_block(ITEM_DISPLAY, "Display", 20, 26, 36, 0.80f, ToolKind.ANY, ITEM_DISPLAY, true, 1.0f);
	set_block(ITEM_LAMP, "Lamp", 230, 210, 90, 0.5f, ToolKind.ANY, ITEM_LAMP, false, 1.0f);
	set_block(ITEM_ANALOGLAMP, "Analog Lamp", 210, 160, 80, 0.5f, ToolKind.ANY, ITEM_ANALOGLAMP, false, 1.0f);
	set_block(ITEM_SIGNALSOURCE, "Signal Source", 51, 89, 166, 0.6f, ToolKind.ANY, ITEM_SIGNALSOURCE, false, 1.0f);

	// Flags
	blockDefs[ITEM_LOG].nonCollide = true;
	blockDefs[ITEM_BIRCHLOG].nonCollide = true;
	blockDefs[ITEM_LEAVES].nonCollide = true;
	blockDefs[ITEM_PINELEAVES].nonCollide = true;
	blockDefs[ITEM_WATER].nonCollide = true;
	blockDefs[ITEM_WATER].liquid = true;
	blockDefs[ITEM_CAVEBLOCK].nonCollide = true;
	blockDefs[ITEM_TORCH].nonCollide = true;
	blockDefs[ITEM_TORCH].light = true;
	blockDefs[ITEM_CACTUS].nonCollide = true;
	blockDefs[ITEM_MUSHROOM].nonCollide = true;
	blockDefs[ITEM_PLATFORM].nonCollide = true;
	blockDefs[ITEM_PLATFORM].platform = true;
	blockDefs[ITEM_LADDER].nonCollide = true;
	blockDefs[ITEM_LADDER].climb = true;
	blockDefs[ITEM_DOOR].nonCollide = true;
	blockDefs[ITEM_ROPE].nonCollide = true;
	blockDefs[ITEM_ROPE].climb = true;
	blockDefs[ITEM_SAND].falls = true;
	blockDefs[ITEM_GRAVEL].falls = true;

	// Interactions
	blockDefs[ITEM_WORKBENCH].interact = InteractKind.WORKBENCH;
	blockDefs[ITEM_FURNACE].interact = InteractKind.FURNACE;
	blockDefs[ITEM_CHEST].interact = InteractKind.CHEST;
	blockDefs[ITEM_ANVIL].interact = InteractKind.ANVIL;
	blockDefs[ITEM_DOOR].interact = InteractKind.DOOR;
	blockDefs[ITEM_BED].interact = InteractKind.BED;
	blockDefs[ITEM_CIRCUITBOARD16].interact = InteractKind.CIRCUITBOARD;
	blockDefs[ITEM_CIRCUITBOARD32].interact = InteractKind.CIRCUITBOARD;
	blockDefs[ITEM_CIRCUITBOARD64].interact = InteractKind.CIRCUITBOARD;
	blockDefs[ITEM_PROGRAMMABLE].interact = InteractKind.PROGRAMMABLE;
	blockDefs[ITEM_SIGNALSOURCE].interact = InteractKind.SIGNALSOURCE;
	for (int i = ITEM_WIRE; i <= ITEM_SIGNALSOURCE; i++)
	{
		if (is_lever(i) || is_button(i)) blockDefs[i].interact = InteractKind.LOGIC;
	}

	// Tools
	set_tool(ITEM_WOODPICKAXE, "Wood Pickaxe", 1.0f, 1.00f, ToolKind.PICKAXE, 140, 97, 46, 2);
	set_tool(ITEM_STONEPICKAXE, "Stone Pickaxe", 1.5f, 1.30f, ToolKind.PICKAXE, 140, 140, 148, 3);
	set_tool(ITEM_IRONPICKAXE, "Iron Pickaxe", 2.2f, 1.60f, ToolKind.PICKAXE, 184, 148, 122, 4);
	set_tool(ITEM_GOLDPICKAXE, "Gold Pickaxe", 2.6f, 1.90f, ToolKind.PICKAXE, 240, 194, 36, 4);
	set_tool(ITEM_CRYSTALPICK, "Crystal Pick", 3.2f, 2.20f, ToolKind.PICKAXE, 140, 89, 230, 5);
	set_tool(ITEM_WOODAXE, "Wood Axe", 1.0f, 1.10f, ToolKind.AXE, 140, 97, 46, 3);
	set_tool(ITEM_STONEAXE, "Stone Axe", 1.5f, 1.35f, ToolKind.AXE, 140, 140, 148, 4);
	set_tool(ITEM_IRONAXE, "Iron Axe", 2.1f, 1.55f, ToolKind.AXE, 184, 148, 122, 5);
	set_tool(ITEM_WOODSWORD, "Wood Sword", 1.0f, 1.0f, ToolKind.SWORD, 140, 97, 46, 8);
	set_tool(ITEM_STONESWORD, "Stone Sword", 1.0f, 1.0f, ToolKind.SWORD, 140, 140, 148, 12);
	set_tool(ITEM_IRONSWORD, "Iron Sword", 1.0f, 1.0f, ToolKind.SWORD, 184, 148, 122, 16);
	set_tool(ITEM_GOLDSWORD, "Gold Sword", 1.0f, 1.0f, ToolKind.SWORD, 240, 194, 36, 14);
	set_tool(ITEM_CRYSTALSWORD, "Crystal Sword", 1.0f, 1.0f, ToolKind.SWORD, 140, 89, 230, 22);
	set_tool(ITEM_WOODHAMMER, "Wood Hammer", 1.0f, 0.90f, ToolKind.HAMMER, 140, 97, 46, 5);
	set_tool(ITEM_STONEHAMMER, "Stone Hammer", 1.4f, 1.05f, ToolKind.HAMMER, 140, 140, 148, 7);
	set_tool(ITEM_WRENCH, "Wrench", 1.0f, 1.0f, ToolKind.WRENCH, 191, 191, 204, 2);

	// Item-only
	set_item(ITEM_IRONBAR, "Iron Bar", 191, 191, 204);
	set_item(ITEM_COPPERBAR, "Copper Bar", 217, 140, 77);
	set_item(ITEM_GOLDBAR, "Gold Bar", 242, 209, 64);
	set_item(ITEM_GEL, "Gel", 102, 217, 115);
	set_item(ITEM_STRING, "String", 230, 230, 217);
	set_item(ITEM_PAPER, "Paper", 235, 230, 209);
	set_item(ITEM_BOOK, "Book", 115, 77, 140);
	set_item(ITEM_COOKEDMUSHROOM, "Cooked Mushroom", 179, 115, 64);
	set_item(ITEM_APPLE, "Apple", 217, 51, 46);

	// ------------------------------------------------------------------
	// Crafting recipes
	// ------------------------------------------------------------------
	add_recipe(0, StationKind.HAND, "Planks", ITEM_LOG, 1, ITEM_NONE, 0, ITEM_PLANKS, 4);
	add_recipe(0, StationKind.HAND, "Pine Planks", ITEM_LOG, 1, ITEM_NONE, 0, ITEM_PINEPLANKS, 4);
	add_recipe(0, StationKind.HAND, "Torch", ITEM_COAL, 1, ITEM_LOG, 1, ITEM_TORCH, 4);
	add_recipe(0, StationKind.HAND, "Workbench", ITEM_PLANKS, 8, ITEM_NONE, 0, ITEM_WORKBENCH, 1);
	add_recipe(0, StationKind.HAND, "Platform", ITEM_PLANKS, 1, ITEM_NONE, 0, ITEM_PLATFORM, 2);
	add_recipe(0, StationKind.HAND, "Ladder", ITEM_PLANKS, 2, ITEM_NONE, 0, ITEM_LADDER, 2);
	add_recipe(0, StationKind.HAND, "Rope", ITEM_STRING, 3, ITEM_NONE, 0, ITEM_ROPE, 3);
	add_recipe(0, StationKind.HAND, "Gel Torch", ITEM_GEL, 1, ITEM_TORCH, 1, ITEM_TORCH, 3);
	add_recipe(0, StationKind.WORKBENCH, "Bed", ITEM_PLANKS, 6, ITEM_STRING, 2, ITEM_BED, 1);
	add_recipe(0, StationKind.HAND, "Birch Planks", ITEM_BIRCHLOG, 1, ITEM_NONE, 0, ITEM_BIRCHPLANKS, 4);

	add_recipe(1, StationKind.WORKBENCH, "Wood Pickaxe", ITEM_PLANKS, 6, ITEM_LOG, 2, ITEM_WOODPICKAXE, 1);
	add_recipe(1, StationKind.WORKBENCH, "Stone Pickaxe", ITEM_STONE, 8, ITEM_LOG, 2, ITEM_STONEPICKAXE, 1);
	add_recipe(1, StationKind.WORKBENCH, "Iron Pickaxe", ITEM_IRONBAR, 8, ITEM_LOG, 2, ITEM_IRONPICKAXE, 1);
	add_recipe(1, StationKind.WORKBENCH, "Gold Pickaxe", ITEM_GOLDBAR, 8, ITEM_LOG, 2, ITEM_GOLDPICKAXE, 1);
	add_recipe(1, StationKind.WORKBENCH, "Crystal Pick", ITEM_CRYSTAL, 10, ITEM_IRONBAR, 4, ITEM_CRYSTALPICK, 1);
	add_recipe(1, StationKind.WORKBENCH, "Wood Axe", ITEM_PLANKS, 5, ITEM_LOG, 2, ITEM_WOODAXE, 1);
	add_recipe(1, StationKind.WORKBENCH, "Stone Axe", ITEM_STONE, 6, ITEM_LOG, 2, ITEM_STONEAXE, 1);
	add_recipe(1, StationKind.WORKBENCH, "Iron Axe", ITEM_IRONBAR, 6, ITEM_LOG, 2, ITEM_IRONAXE, 1);
	add_recipe(1, StationKind.WORKBENCH, "Wood Hammer", ITEM_PLANKS, 6, ITEM_LOG, 2, ITEM_WOODHAMMER, 1);
	add_recipe(1, StationKind.WORKBENCH, "Stone Hammer", ITEM_STONE, 7, ITEM_LOG, 2, ITEM_STONEHAMMER, 1);
	add_recipe(1, StationKind.WORKBENCH, "Wrench", ITEM_PLANKS, 3, ITEM_NONE, 0, ITEM_WRENCH, 1);

	add_recipe(2, StationKind.WORKBENCH, "Wood Sword", ITEM_PLANKS, 4, ITEM_LOG, 1, ITEM_WOODSWORD, 1);
	add_recipe(2, StationKind.WORKBENCH, "Stone Sword", ITEM_STONE, 5, ITEM_LOG, 1, ITEM_STONESWORD, 1);
	add_recipe(2, StationKind.WORKBENCH, "Iron Sword", ITEM_IRONBAR, 6, ITEM_LOG, 1, ITEM_IRONSWORD, 1);
	add_recipe(2, StationKind.WORKBENCH, "Gold Sword", ITEM_GOLDBAR, 6, ITEM_LOG, 1, ITEM_GOLDSWORD, 1);
	add_recipe(2, StationKind.WORKBENCH, "Crystal Sword", ITEM_CRYSTAL, 8, ITEM_IRONBAR, 3, ITEM_CRYSTALSWORD, 1);

	add_recipe(3, StationKind.WORKBENCH, "Glass", ITEM_SAND, 2, ITEM_NONE, 0, ITEM_GLASS, 1);
	add_recipe(3, StationKind.WORKBENCH, "Brick Wall", ITEM_BRICK, 2, ITEM_NONE, 0, ITEM_BRICK, 1);
	add_recipe(3, StationKind.WORKBENCH, "Cobblestone", ITEM_STONE, 1, ITEM_NONE, 0, ITEM_COBBLE, 1);
	add_recipe(3, StationKind.WORKBENCH, "Sandstone", ITEM_SAND, 4, ITEM_NONE, 0, ITEM_SANDSTONE, 1);
	add_recipe(3, StationKind.WORKBENCH, "Bookshelf", ITEM_PLANKS, 6, ITEM_BOOK, 3, ITEM_BOOKSHELF, 1);
	add_recipe(3, StationKind.WORKBENCH, "Door", ITEM_PLANKS, 6, ITEM_NONE, 0, ITEM_DOOR, 1);
	add_recipe(3, StationKind.WORKBENCH, "Chest", ITEM_PLANKS, 8, ITEM_IRONBAR, 2, ITEM_CHEST, 1);
	add_recipe(3, StationKind.HAND, "Snow Block", ITEM_SNOW, 2, ITEM_NONE, 0, ITEM_SNOW, 1);
	add_recipe(3, StationKind.WORKBENCH, "Ice Brick", ITEM_ICE, 2, ITEM_NONE, 0, ITEM_ICE, 1);

	add_recipe(4, StationKind.WORKBENCH, "Furnace", ITEM_STONE, 12, ITEM_COAL, 3, ITEM_FURNACE, 1);
	add_recipe(4, StationKind.WORKBENCH, "Anvil", ITEM_IRONBAR, 8, ITEM_NONE, 0, ITEM_ANVIL, 1);

	add_recipe(6, StationKind.HAND, "String", ITEM_LEAVES, 4, ITEM_NONE, 0, ITEM_STRING, 1);
	add_recipe(6, StationKind.HAND, "Paper", ITEM_LOG, 1, ITEM_NONE, 0, ITEM_PAPER, 2);
	add_recipe(6, StationKind.WORKBENCH, "Book", ITEM_PAPER, 3, ITEM_STRING, 1, ITEM_BOOK, 1);
	add_recipe(6, StationKind.HAND, "TNT", ITEM_SAND, 2, ITEM_COAL, 2, ITEM_TNT, 1);

	add_recipe(5, StationKind.WORKBENCH, "AND Gate", ITEM_IRONBAR, 1, ITEM_REDSTONE, 1, ITEM_ANDGATE, 1);
	add_recipe(5, StationKind.WORKBENCH, "OR Gate", ITEM_IRONBAR, 1, ITEM_REDSTONE, 1, ITEM_ORGATE, 1);
	add_recipe(5, StationKind.WORKBENCH, "XOR Gate", ITEM_IRONBAR, 1, ITEM_REDSTONE, 2, ITEM_XORGATE, 1);
	add_recipe(5, StationKind.WORKBENCH, "NOT Gate", ITEM_IRONBAR, 1, ITEM_REDSTONE, 1, ITEM_NOTGATE, 1);
	add_recipe(5, StationKind.WORKBENCH, "NAND Gate", ITEM_IRONBAR, 1, ITEM_REDSTONE, 2, ITEM_NANDGATE, 1);
	add_recipe(5, StationKind.WORKBENCH, "NOR Gate", ITEM_IRONBAR, 1, ITEM_REDSTONE, 2, ITEM_NORGATE, 1);
	add_recipe(5, StationKind.WORKBENCH, "Wire", ITEM_COPPERBAR, 1, ITEM_STRING, 1, ITEM_WIRE, 4);
	add_recipe(5, StationKind.WORKBENCH, "Wire 4-bit", ITEM_COPPERBAR, 1, ITEM_STRING, 1, ITEM_WIRE4, 4);
	add_recipe(5, StationKind.WORKBENCH, "Wire 8-bit", ITEM_COPPERBAR, 2, ITEM_STRING, 1, ITEM_WIRE8, 4);
	add_recipe(5, StationKind.WORKBENCH, "Wire 16-bit", ITEM_COPPERBAR, 3, ITEM_STRING, 1, ITEM_WIRE16, 4);
	add_recipe(5, StationKind.WORKBENCH, "Wire 32-bit", ITEM_COPPERBAR, 4, ITEM_STRING, 1, ITEM_WIRE32, 4);
	add_recipe(5, StationKind.WORKBENCH, "Circuit Board 16", ITEM_IRONBAR, 4, ITEM_REDSTONE, 4, ITEM_CIRCUITBOARD16, 1);
	add_recipe(5, StationKind.WORKBENCH, "Circuit Board 32", ITEM_IRONBAR, 8, ITEM_REDSTONE, 8, ITEM_CIRCUITBOARD32, 1);
	add_recipe(5, StationKind.WORKBENCH, "Circuit Board 64", ITEM_IRONBAR, 16, ITEM_REDSTONE, 16, ITEM_CIRCUITBOARD64, 1);
	add_recipe(5, StationKind.WORKBENCH, "Lever 4-bit", ITEM_PLANKS, 2, ITEM_COPPERBAR, 1, ITEM_LEVER4, 1);
	add_recipe(5, StationKind.WORKBENCH, "Lever 8-bit", ITEM_PLANKS, 2, ITEM_COPPERBAR, 2, ITEM_LEVER8, 1);
	add_recipe(5, StationKind.WORKBENCH, "Lever 16-bit", ITEM_PLANKS, 2, ITEM_COPPERBAR, 3, ITEM_LEVER16, 1);
	add_recipe(5, StationKind.WORKBENCH, "Lever 32-bit", ITEM_PLANKS, 2, ITEM_COPPERBAR, 4, ITEM_LEVER32, 1);
	add_recipe(5, StationKind.WORKBENCH, "Button 4-bit", ITEM_PLANKS, 1, ITEM_COPPERBAR, 1, ITEM_BUTTON4, 1);
	add_recipe(5, StationKind.WORKBENCH, "Button 8-bit", ITEM_PLANKS, 1, ITEM_COPPERBAR, 2, ITEM_BUTTON8, 1);
	add_recipe(5, StationKind.WORKBENCH, "Button 16-bit", ITEM_PLANKS, 1, ITEM_COPPERBAR, 3, ITEM_BUTTON16, 1);
	add_recipe(5, StationKind.WORKBENCH, "Button 32-bit", ITEM_PLANKS, 1, ITEM_COPPERBAR, 4, ITEM_BUTTON32, 1);
	add_recipe(5, StationKind.WORKBENCH, "Display", ITEM_IRONBAR, 1, ITEM_GLASS, 2, ITEM_DISPLAY, 1);
	add_recipe(5, StationKind.WORKBENCH, "Lever", ITEM_PLANKS, 2, ITEM_NONE, 0, ITEM_LEVER, 1);
	add_recipe(5, StationKind.WORKBENCH, "Button", ITEM_PLANKS, 1, ITEM_NONE, 0, ITEM_BUTTON, 1);
	add_recipe(5, StationKind.WORKBENCH, "Programmable Circuit", ITEM_IRONBAR, 6, ITEM_REDSTONE, 8, ITEM_PROGRAMMABLE, 1);
	add_recipe(5, StationKind.WORKBENCH, "Lamp", ITEM_IRONBAR, 1, ITEM_REDSTONE, 1, ITEM_LAMP, 1);
	add_recipe(5, StationKind.WORKBENCH, "Analog Lamp", ITEM_COPPERBAR, 2, ITEM_REDSTONE, 2, ITEM_ANALOGLAMP, 1);
	add_recipe(5, StationKind.WORKBENCH, "Signal Source", ITEM_IRONBAR, 2, ITEM_REDSTONE, 4, ITEM_SIGNALSOURCE, 1);

	// Smelting
	add_smelt(ITEM_SAND, ITEM_GLASS, 1, 1);
	add_smelt(ITEM_IRON, ITEM_IRONBAR, 1, 2);
	add_smelt(ITEM_COPPER, ITEM_COPPERBAR, 1, 2);
	add_smelt(ITEM_GOLD, ITEM_GOLDBAR, 1, 3);
	add_smelt(ITEM_CLAY, ITEM_BRICK, 1, 1);
	add_smelt(ITEM_COBBLE, ITEM_STONE, 1, 1);
	add_smelt(ITEM_LOG, ITEM_COAL, 1, 1);
	add_smelt(ITEM_MUSHROOM, ITEM_COOKEDMUSHROOM, 1, 1);
}

fn void state_init()
{
	g.chunks.init(mem);
	g.edits.init(mem);
	g.editsBg.init(mem);
	g.openDoors.init(mem);
	g.waterLevels.init(mem);
	g.logic.init(mem);
	g.entities.init(mem);
	g.drops.init(mem);
	g.particles.init(mem);
	g.floats.init(mem);
	g.enemies.init(mem);
	g.tntFuses.init(mem);
	g.saves.init(mem);
	g.mods.init(mem);
	g.textureOverrides.init(mem);

	g.currentSeed = 1;
	g.timeOfDay = 0.28f;
	g.gameState = GS_MENU;
	g.menuSubstate = 0;
	g.nextEnemyId = 1;
	g.playerCreated = false;
	g.worldMode = 0;
	g.worldHostiles = true;
	g.hostilesEnabled = true;
	g.stationTab = 0;
	g.craftCategory = 0;
	g.boardSelected = ITEM_WIRE;
	g.boardPinSide = 0;
	g.boardPinDir = 1;
	g.boardPinBits = 1;
	g.saveListDirty = true;
	g.streamValid = false;
	g.fieldSeed[0] = 0;
	g.fieldSeedLen = 0;
	g.fieldSeedLen = 0;
	g.messageText[0] = 0;
	g.messageTimer = 0;
	g.chatText[0] = 0;
	g.chatTextLen = 0;
	g.chatScroll = 0;
	g.uiActiveField = -1;
}
