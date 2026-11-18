// Redstone-like logic: wires, gates, boards, programmable circuits.
module minecraft;
import std::math;
import std::collections::list;
import std::collections::map;
import std::core::string;

const int PIN_OFF = 0;
const int PIN_IN = 1;
const int PIN_OUT = 2;
const int PIN_INOUT = 3;

const int SIDE_N = 0;
const int SIDE_S = 1;
const int SIDE_E = 2;
const int SIDE_W = 3;

fn int side_dx(int side)
{
	switch (side)
	{
		case SIDE_E: return 1;
		case SIDE_W: return -1;
		default: return 0;
	}
}

fn int side_dy(int side)
{
	switch (side)
	{
		case SIDE_N: return -1;
		case SIDE_S: return 1;
		default: return 0;
	}
}

fn LogicCell* logic_get(int tx, int ty)
{
	if (try c = g.logic.get(tile_key(tx, ty))) return c;
	return null;
}

// ---------------------------------------------------------------------------
// Cell lifecycle
// ---------------------------------------------------------------------------
fn void logic_free_cell(LogicCell* cell)
{
	if (!cell) return;
	if (cell.hasBoard) cell.board.cells.free();
	free(cell);
}

fn LogicCell* logic_cell_default(ItemId type, int tx, int ty)
{
	LogicCell cellValue;
	LogicCell* c = malloc(@sizeof(cellValue));
	if (!c) return null;
	*c = {};
	c.type = type;
	c.x = tx;
	c.y = ty;
	c.bitWidth = logic_bits(type);
	c.value = 0;
	c.timer = 0;
	c.outputs[0] = 0;
	c.outputs[1] = 0;
	if (is_board(type))
	{
		int size = 16;
		if (type == ITEM_CIRCUITBOARD32) {size = 32;}
		else if (type == ITEM_CIRCUITBOARD64) {size = 64;}
		c.hasBoard = true;
		c.board.w = size;
		c.board.h = size;
		c.board.cells.init(mem);
		c.board.pins[SIDE_N] = { PIN_IN, 1 };
		c.board.pins[SIDE_S] = { PIN_OUT, 1 };
		c.board.pins[SIDE_E] = { PIN_IN, 1 };
		c.board.pins[SIDE_W] = { PIN_OUT, 1 };
	}
	else if (type == ITEM_DISPLAY)
	{
		c.bitWidth = 8;
	}
	else if (type == ITEM_PROGRAMMABLE)
	{
		c.bitWidth = 8;
		ZString def = "-- E and S are output sides; N and W are usual inputs\n"
		              "return { E = input.W, S = input.N }";
		copy_cstr(&c.code, c.code.len, def);
		int n = 0;
		while (n < c.code.len && c.code[n] != 0) n++;
		c.codeLen = n;
	}
	else if (type == ITEM_SIGNALSOURCE)
	{
		c.bitWidth = 8;
	}
	return c;
}

fn void logic_on_place_block(int tx, int ty, ItemId id)
{
	if (!is_logic(id)) return;
	long k = tile_key(tx, ty);
	if (try existing = g.logic.get(k))
	{
		if (existing.type == id) return;
		g.logic.remove(k);
		logic_free_cell(existing);
	}
	LogicCell* c = logic_cell_default(id, tx, ty);
	if (!c) return;
	g.logic.set(k, c);
}

fn void logic_on_destroy_block(int tx, int ty)
{
	long k = tile_key(tx, ty);
	if (try c = g.logic.get(k))
	{
		g.logic.remove(k);
		logic_free_cell(c);
	}
}

fn void logic_clear()
{
	foreach (c : g.logic.iter())
	{
		logic_free_cell(c.value);
	}
	g.logic.clear();
}

// ---------------------------------------------------------------------------
// Interactions
// ---------------------------------------------------------------------------
fn void logic_player_toggle(int tx, int ty)
{
	LogicCell* c = logic_get(tx, ty);
	if (!c) return;
	if (is_lever(c.type))
	{
		c.value = c.value == 0 ? mask_bits(c.bitWidth) : 0;
		show_msg(c.value != 0 ? "Lever ON" : "Lever OFF", 0.8f);
	}
	else if (is_button(c.type))
	{
		c.timer = 20;
		c.value = mask_bits(c.bitWidth);
	}
}

fn void logic_open_board(int tx, int ty)
{
	LogicCell* c = logic_get(tx, ty);
	if (!c || !is_board(c.type)) return;
	g.boardOpen = true;
	g.boardCellX = tx;
	g.boardCellY = ty;
	g.boardSelected = ITEM_WIRE;
	g.uiActiveField = -1;
}

fn Board* logic_board_get(int tx, int ty)
{
	LogicCell* c = logic_get(tx, ty);
	if (!c || !c.hasBoard) return null;
	return &c.board;
}

fn void logic_board_pin_coords(Board* b, int side, int* bx, int* by)
{
	switch (side)
	{
		case SIDE_N:
			*bx = b.w / 2;
			*by = 0;
		case SIDE_S:
			*bx = b.w / 2;
			*by = b.h - 1;
		case SIDE_E:
			*bx = b.w - 1;
			*by = b.h / 2;
		default:
			*bx = 0;
			*by = b.h / 2;
	}
}

fn void logic_board_cycle_pin_dir(int tx, int ty, int side)
{
	Board* b = logic_board_get(tx, ty);
	if (!b || side < 0 || side > 3) return;
	b.pins[side].dir = (b.pins[side].dir + 1) % 4;
}

fn void logic_board_cycle_pin_bits(int tx, int ty, int side)
{
	Board* b = logic_board_get(tx, ty);
	if (!b || side < 0 || side > 3) return;
	int bits = b.pins[side].bits;
	if (bits == 1) {bits = 4;}
	else if (bits == 4) {bits = 8;}
	else if (bits == 8) {bits = 16;}
	else if (bits == 16) {bits = 32;}
	else {bits = 1;}
	b.pins[side].bits = bits;
}

fn void logic_board_place_cell(int tx, int ty, int bx, int by, ItemId type)
{
	Board* b = logic_board_get(tx, ty);
	if (!b) return;
	if (bx < 0 || by < 0 || bx >= b.w || by >= b.h) return;
	BoardCell c;
	c.type = type;
	c.bitWidth = logic_bits(type);
	c.value = 0;
	c.timer = 0;
	c.x = bx;
	c.y = by;
	b.cells.set(tile_key(bx, by), c);
}

fn void logic_board_remove_cell(int tx, int ty, int bx, int by)
{
	Board* b = logic_board_get(tx, ty);
	if (!b) return;
	b.cells.remove(tile_key(bx, by));
}

// ---------------------------------------------------------------------------
// Programmable circuit evaluator
// ---------------------------------------------------------------------------
struct ExprParser
{
	char* src;
	int   len;
	int   pos;
	bool  failed;
	char[160] error;
	uint[4] inputs;
}

fn bool zstreq(ZString a, ZString b)
{
	if (!a || !b) return false;
	usz i = 0;
	while (a[i] != 0 && b[i] != 0)
	{
		if (a[i] != b[i]) return false;
		i++;
	}
	return a[i] == 0 && b[i] == 0;
}

fn int zstr_len(ZString s)
{
	if (!s) return 0;
	int n = 0;
	while (s[n] != 0) n++;
	return n;
}

fn void parser_error(ExprParser* p, ZString msg)
{
	if (p.failed) return;
	p.failed = true;
	copy_cstr(&p.error, p.error.len, msg);
}

fn void parser_skip(ExprParser* p)
{
	while (p.pos < p.len)
	{
		char c = p.src[p.pos];
		if (c == ' ' || c == '\t' || c == '\n' || c == '\r' || c == ';')
		{
			p.pos++;
			continue;
		}
		if (c == '-' && p.pos + 1 < p.len && p.src[p.pos + 1] == '-')
		{
			p.pos += 2;
			while (p.pos < p.len && p.src[p.pos] != '\n') p.pos++;
			continue;
		}
		break;
	}
}

fn bool parser_consume(ExprParser* p, char c)
{
	parser_skip(p);
	if (p.pos < p.len && p.src[p.pos] == c)
	{
		p.pos++;
		return true;
	}
	return false;
}

fn void parser_expect(ExprParser* p, char c, ZString msg)
{
	if (!parser_consume(p, c)) parser_error(p, msg);
}

fn bool parser_ident(ExprParser* p, char[32]* out)
{
	parser_skip(p);
	if (p.pos >= p.len) return false;
	char c = p.src[p.pos];
	if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_')) return false;
	int n = 0;
	while (p.pos < p.len)
	{
		c = p.src[p.pos];
		if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z')
		    || (c >= '0' && c <= '9') || c == '_')) break;
		if (n < 31)
		{
			(*out)[n] = c;
			n++;
		}
		p.pos++;
	}
	(*out)[n] = 0;
	return true;
}

fn long parser_number(ExprParser* p)
{
	parser_skip(p);
	if (p.pos >= p.len)
	{
		parser_error(p, "Expected a number");
		return 0;
	}
	bool hex = false;
	if (p.src[p.pos] == '0' && p.pos + 1 < p.len
	    && (p.src[p.pos + 1] == 'x' || p.src[p.pos + 1] == 'X'))
	{
		hex = true;
		p.pos += 2;
	}
	long v = 0;
	int digits = 0;
	while (p.pos < p.len)
	{
		char c = p.src[p.pos];
		int d = -1;
		if (c >= '0' && c <= '9') {d = c - '0';}
		else if (hex && c >= 'a' && c <= 'f') {d = 10 + (c - 'a');}
		else if (hex && c >= 'A' && c <= 'F') {d = 10 + (c - 'A');}
		else {break;}
		v = v * (hex ? 16 : 10) + (long)d;
		digits++;
		p.pos++;
	}
	if (digits == 0) parser_error(p, "Expected a number");
	return v;
}

fn long expr_call_arg(ExprParser* p)
{
	long v = expr_add(p);
	return v;
}

fn long expr_primary(ExprParser* p)
{
	parser_skip(p);
	if (p.failed) return 0;
	if (p.pos >= p.len)
	{
		parser_error(p, "Unexpected end of program");
		return 0;
	}
	char c = p.src[p.pos];
	if (c == '(')
	{
		p.pos++;
		long v = expr_add(p);
		parser_expect(p, ')', "Expected ')'");
		return v;
	}
	if (c >= '0' && c <= '9') return parser_number(p);
	if (!((c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') || c == '_'))
	{
		parser_error(p, "Unexpected character");
		return 0;
	}

	char[32] name;
	if (!parser_ident(p, &name))
	{
		parser_error(p, "Expected an identifier");
		return 0;
	}
	ZString id = (ZString)&name[0];

	if (zstreq(id, "input"))
	{
		parser_expect(p, '.', "Expected input.N/W/S/E");
		char[32] side;
		if (!parser_ident(p, &side))
		{
			parser_error(p, "Expected input side");
			return 0;
		}
		if (zstreq((ZString)&side[0], "N")) return p.inputs[SIDE_N];
		if (zstreq((ZString)&side[0], "S")) return p.inputs[SIDE_S];
		if (zstreq((ZString)&side[0], "E")) return p.inputs[SIDE_E];
		if (zstreq((ZString)&side[0], "W")) return p.inputs[SIDE_W];
		parser_error(p, "Unknown input side");
		return 0;
	}
	if (zstreq(id, "true")) return 1;
	if (zstreq(id, "false")) return 0;

	// Function calls.
	if (!parser_consume(p, '('))
	{
		parser_error(p, "Unknown identifier");
		return 0;
	}
	long a = expr_call_arg(p);
	long b = 0;
	bool hasB = false;
	if (parser_consume(p, ','))
	{
		b = expr_call_arg(p);
		hasB = true;
	}
	parser_expect(p, ')', "Expected ')'");

	if (zstreq(id, "band")) return (long)((uint)a & (uint)b);
	if (zstreq(id, "bor")) return (long)((uint)a | (uint)b);
	if (zstreq(id, "bxor")) return (long)((uint)a ^ (uint)b);
	if (zstreq(id, "bnot"))
	{
		int bits = hasB ? (int)b : 32;
		return (long)bnot_bits((uint)a, bits);
	}
	if (zstreq(id, "mask")) return (long)mask_bits((int)a);
	if (zstreq(id, "min")) return a < b ? a : b;
	if (zstreq(id, "max")) return a > b ? a : b;
	if (zstreq(id, "floor") || zstreq(id, "abs"))
	{
		if (zstreq(id, "abs")) return a < 0 ? -a : a;
		return a;
	}
	parser_error(p, "Unknown function");
	return 0;
}

fn long expr_unary(ExprParser* p)
{
	parser_skip(p);
	if (p.pos < p.len && p.src[p.pos] == '-')
	{
		p.pos++;
		return -expr_unary(p);
	}
	if (p.pos < p.len && p.src[p.pos] == '+')
	{
		p.pos++;
		return expr_unary(p);
	}
	return expr_primary(p);
}

fn long expr_mul(ExprParser* p)
{
	long v = expr_unary(p);
	while (!p.failed)
	{
		parser_skip(p);
		if (p.pos >= p.len) break;
		char c = p.src[p.pos];
		if (c != '*' && c != '/' && c != '%') break;
		p.pos++;
		long r = expr_unary(p);
		if (c == '*') {v = v * r;}
		else if (c == '/')
		{
			if (r == 0)
			{
				parser_error(p, "Division by zero");
				return 0;
			}
			v = v / r;
		}
		else
		{
			if (r == 0)
			{
				parser_error(p, "Division by zero");
				return 0;
			}
			v = v % r;
		}
	}
	return v;
}

fn long expr_add(ExprParser* p)
{
	long v = expr_mul(p);
	while (!p.failed)
	{
		parser_skip(p);
		if (p.pos >= p.len) break;
		char c = p.src[p.pos];
		if (c != '+' && c != '-') break;
		p.pos++;
		long r = expr_mul(p);
		if (c == '+') {v = v + r;}
		else {v = v - r;}
	}
	return v;
}

fn uint parser_clamp_value(long v)
{
	if (v < 0) return 0;
	if (v > 255) return 255;
	return (uint)v;
}

// Returns true and fills outputs when the program parses and evaluates.
fn bool logic_eval_source(ZString source, int sourceLen, uint[4] inputs,
                          uint* outE, uint* outS, char* error, usz errorCap)
{
	*outE = 0;
	*outS = 0;
	ExprParser p;
	p.src = (char*)source;
	p.len = sourceLen;
	p.pos = 0;
	p.failed = false;
	p.error[0] = 0;
	p.inputs = inputs;

	parser_skip(&p);
	char[32] kw;
	if (!parser_ident(&p, &kw) || !zstreq((ZString)&kw[0], "return"))
	{
		parser_error(&p, "Program must start with return { ... }");
		copy_cstr(error, errorCap, (ZString)&p.error[0]);
		return false;
	}
	parser_expect(&p, '{', "Expected '{'");
	uint e = 0;
	uint s = 0;
	while (!p.failed)
	{
		parser_skip(&p);
		if (parser_consume(&p, '}')) break;
		char[32] key;
		if (!parser_ident(&p, &key))
		{
			parser_error(&p, "Expected E, S or out");
			break;
		}
		parser_expect(&p, '=', "Expected '='");
		long v = expr_add(&p);
		uint uv = parser_clamp_value(v);
		if (zstreq((ZString)&key[0], "E")) {e = uv;}
		else if (zstreq((ZString)&key[0], "S")) {s = uv;}
		else if (zstreq((ZString)&key[0], "out")) { e = uv; s = uv; }
		else
		{
			parser_error(&p, "Expected E, S or out");
			break;
		}
		parser_skip(&p);
		if (parser_consume(&p, '}')) break;
		if (!parser_consume(&p, ','))
		{
			parser_error(&p, "Expected ',' or '}'");
			break;
		}
	}
	if (p.failed)
	{
		copy_cstr(error, errorCap, (ZString)&p.error[0]);
		return false;
	}
	*outE = e;
	*outS = s;
	return true;
}

fn void logic_run_program(LogicCell* cell, uint[4] inputs)
{
	if (cell.codeLen <= 0)
	{
		cell.value = 0;
		cell.outputs[0] = 0;
		cell.outputs[1] = 0;
		cell.codeValid = false;
		copy_cstr(&cell.codeError, cell.codeError.len, "Program is empty");
		return;
	}
	uint e;
	uint s;
	if (logic_eval_source((ZString)&cell.code[0], cell.codeLen, inputs, &e, &s,
	                      &cell.codeError, cell.codeError.len))
	{
		cell.outputs[0] = e;
		cell.outputs[1] = s;
		cell.value = e | s;
		cell.codeValid = true;
	}
	else
	{
		cell.outputs[0] = 0;
		cell.outputs[1] = 0;
		cell.value = 0;
		cell.codeValid = false;
	}
}

fn void logic_open_program(int tx, int ty)
{
	LogicCell* c = logic_get(tx, ty);
	if (!c || c.type != ITEM_PROGRAMMABLE) return;
	g.programOpen = true;
	g.programCellX = tx;
	g.programCellY = ty;
	copy_cstr(&g.programText, g.programText.len, (ZString)&c.code[0]);
	g.programTextLen = zstr_len((ZString)&g.programText[0]);
	g.uiActiveField = -1;
}

fn void logic_save_program()
{
	LogicCell* c = logic_get(g.programCellX, g.programCellY);
	if (!c || c.type != ITEM_PROGRAMMABLE) return;
	int n = g.programTextLen;
	if (n > 2047) n = 2047;
	for (int i = 0; i < n; i++) c.code[i] = g.programText[i];
	c.code[n] = 0;
	c.codeLen = n;
	c.codeValid = false;
	uint[4] zero = { 0, 0, 0, 0 };
	logic_run_program(c, zero);
}

fn void logic_close_program()
{
	if (g.programOpen) logic_save_program();
	g.programOpen = false;
}

fn void logic_open_signal(int tx, int ty)
{
	LogicCell* c = logic_get(tx, ty);
	if (!c || c.type != ITEM_SIGNALSOURCE) return;
	g.signalSourceOpen = true;
	g.signalCellX = tx;
	g.signalCellY = ty;
	zfmt(&g.signalText, "%d", (int)c.value);
	g.signalTextLen = zstr_len((ZString)&g.signalText[0]);
	g.uiActiveField = -1;
}

fn uint parse_decimal_uint(ZString text, int len)
{
	uint v = 0;
	for (int i = 0; i < len; i++)
	{
		char c = text[i];
		if (c >= '0' && c <= '9')
		{
			v = v * 10u + (uint)(c - '0');
			if (v > 0xFFFFFFFFu) v = 0xFFFFFFFFu;
		}
	}
	return v;
}

fn void logic_apply_signal()
{
	LogicCell* c = logic_get(g.signalCellX, g.signalCellY);
	if (!c || c.type != ITEM_SIGNALSOURCE) return;
	uint v = parse_decimal_uint((ZString)&g.signalText[0], g.signalTextLen);
	c.value = v & mask_bits(c.bitWidth);
	char[64] buf;
	zfmt(&buf, "Signal set to %d", (int)c.value);
	show_msg((ZString)&buf[0], 1.2f);
	g.signalSourceOpen = false;
}

// ---------------------------------------------------------------------------
// Propagation
// ---------------------------------------------------------------------------
fn uint logic_read_value_towards(LogicCell* neighbor, int dx, int dy)
{
	if (!neighbor) return 0;
	if (neighbor.hasBoard)
	{
		int side = -1;
		if (dx == 0 && dy == -1) {side = SIDE_N;}
		else if (dx == 0 && dy == 1) {side = SIDE_S;}
		else if (dx == -1 && dy == 0) {side = SIDE_W;}
		else if (dx == 1 && dy == 0) {side = SIDE_E;}
		if (side >= 0) return neighbor.board.sides[side];
		return 0;
	}
	return neighbor.value;
}

fn void logic_flood_wire(int startX, int startY, uint srcValue, int bits)
{
	List{long} stack;
	HashMap{long, bool} visited;
	stack.init(mem);
	visited.init(mem);
	defer stack.free();
	defer visited.free();
	stack.push(tile_key(startX, startY));

	while (stack.size > 0)
	{
		long k = stack.pop() !!;
		bool seen = false;
		if (try v = visited.get(k)) seen = v;
		if (seen) continue;
		visited.set(k, true);

		int tx = key_x(k);
		int ty = key_y(k);
		LogicCell* c = logic_get(tx, ty);
		if (!c || !is_wire(c.type) || c.bitWidth != bits) continue;
		c.value = c.value | srcValue;
		stack.push(tile_key(tx + GRID, ty));
		stack.push(tile_key(tx - GRID, ty));
		stack.push(tile_key(tx, ty + GRID));
		stack.push(tile_key(tx, ty - GRID));
	}
}

fn void logic_propagate_from(LogicCell* cell)
{
	int bits = cell.bitWidth > 0 ? cell.bitWidth : 1;

	if (cell.hasBoard)
	{
		for (int side = 0; side < 4; side++)
		{
			uint v = cell.board.sides[side];
			Pin pin = cell.board.pins[side];
			if ((pin.dir == PIN_OUT || pin.dir == PIN_INOUT) && v > 0)
			{
				int dx = side_dx(side);
				int dy = side_dy(side);
				LogicCell* nb = logic_get(cell.x + dx * GRID, cell.y + dy * GRID);
				if (nb && is_wire(nb.type) && nb.bitWidth == pin.bits)
				{
					logic_flood_wire(nb.x, nb.y, v & mask_bits(pin.bits), pin.bits);
				}
			}
		}
		return;
	}

	if (cell.type == ITEM_PROGRAMMABLE)
	{
		uint[2] outs = { cell.outputs[0], cell.outputs[1] };
		int[2] dirs = { SIDE_E, SIDE_S };
		for (int i = 0; i < 2; i++)
		{
			uint v = outs[i];
			int dx = side_dx(dirs[i]);
			int dy = side_dy(dirs[i]);
			LogicCell* nb = logic_get(cell.x + dx * GRID, cell.y + dy * GRID);
			if (v > 0 && nb && is_wire(nb.type) && nb.bitWidth == bits)
			{
				logic_flood_wire(nb.x, nb.y, v & mask_bits(bits), bits);
			}
		}
		return;
	}

	uint v = cell.value;
	if (v == 0) return;
	bool gate = is_gate(cell.type);
	for (int side = 0; side < 4; side++)
	{
		if (gate && side != SIDE_E && side != SIDE_S) continue;
		int dx = side_dx(side);
		int dy = side_dy(side);
		LogicCell* nb = logic_get(cell.x + dx * GRID, cell.y + dy * GRID);
		if (nb && is_wire(nb.type) && nb.bitWidth == bits)
		{
			logic_flood_wire(nb.x, nb.y, v, bits);
		}
	}
}

fn void logic_compute_gate(LogicCell* cell)
{
	int bits = cell.bitWidth > 0 ? cell.bitWidth : 1;
	uint maskV = mask_bits(bits);
	uint lv = 0;
	uint tv = 0;

	LogicCell* west = logic_get(cell.x - GRID, cell.y);
	LogicCell* north = logic_get(cell.x, cell.y - GRID);
	if (west && west.bitWidth == bits) lv = logic_read_value_towards(west, 1, 0);
	if (north && north.bitWidth == bits) tv = logic_read_value_towards(north, 0, 1);

	uint out = 0;
	switch (cell.type)
	{
		case ITEM_ANDGATE: out = lv & tv;
		case ITEM_ORGATE: out = lv | tv;
		case ITEM_XORGATE: out = lv ^ tv;
		case ITEM_NOTGATE: out = bnot_bits(lv, bits);
		case ITEM_NANDGATE: out = bnot_bits(lv & tv, bits);
		case ITEM_NORGATE: out = bnot_bits(lv | tv, bits);
		default: out = 0;
	}
	cell.value = out & maskV;
}

// ---------------------------------------------------------------------------
// Circuit board simulation
// ---------------------------------------------------------------------------
fn void board_flood_local(Board* board, int sx, int sy, uint srcValue, int bits)
{
	List{long} stack;
	HashMap{long, bool} visited;
	stack.init(mem);
	visited.init(mem);
	defer stack.free();
	defer visited.free();
	stack.push(tile_key(sx, sy));

	while (stack.size > 0)
	{
		long k = stack.pop() !!;
		bool seen = false;
		if (try v = visited.get(k)) seen = v;
		if (seen) continue;
		visited.set(k, true);

		if (try c = board.cells.get_ref(k))
		{
			if (is_wire(c.type) && c.bitWidth == bits)
			{
				c.value = c.value | srcValue;
				int bx = key_x(k);
				int by = key_y(k);
				stack.push(tile_key(bx + 1, by));
				stack.push(tile_key(bx - 1, by));
				stack.push(tile_key(bx, by + 1));
				stack.push(tile_key(bx, by - 1));
			}
		}
	}
}

fn void board_propagate_local(Board* board, BoardCell* cell)
{
	int bits = cell.bitWidth > 0 ? cell.bitWidth : 1;
	uint v = cell.value;
	if (v == 0) return;
	bool gate = is_gate(cell.type);
	for (int side = 0; side < 4; side++)
	{
		if (gate && side != SIDE_E && side != SIDE_S) continue;
		int dx = side_dx(side);
		int dy = side_dy(side);
		long k = tile_key(cell.x + dx, cell.y + dy);
		if (try nb = board.cells.get_ref(k))
		{
			if (is_wire(nb.type) && nb.bitWidth == bits)
			{
				board_flood_local(board, nb.x, nb.y, v, bits);
			}
		}
	}
}

fn uint board_read_neighbor(Board* board, BoardCell* cell, int dx, int dy)
{
	long k = tile_key(cell.x + dx, cell.y + dy);
	if (try nb = board.cells.get_ref(k)) return nb.value;
	return 0;
}

fn void board_compute_gate(Board* board, BoardCell* cell)
{
	int bits = cell.bitWidth > 0 ? cell.bitWidth : 1;
	uint maskV = mask_bits(bits);
	uint lv = board_read_neighbor(board, cell, -1, 0);
	uint tv = board_read_neighbor(board, cell, 0, -1);
	uint out = 0;
	switch (cell.type)
	{
		case ITEM_ANDGATE: out = lv & tv;
		case ITEM_ORGATE: out = lv | tv;
		case ITEM_XORGATE: out = lv ^ tv;
		case ITEM_NOTGATE: out = bnot_bits(lv, bits);
		case ITEM_NANDGATE: out = bnot_bits(lv & tv, bits);
		case ITEM_NORGATE: out = bnot_bits(lv | tv, bits);
		default: out = 0;
	}
	cell.value = out & maskV;
}

fn void logic_tick_board(LogicCell* ent)
{
	if (!ent.hasBoard) return;
	Board* board = &ent.board;

	// Button timers on the board.
	foreach (c : board.cells.iter())
	{
		long k = c.key;
		if (try bc = board.cells.get_ref(k))
		{
			if (is_button(bc.type) && bc.timer > 0)
			{
				bc.timer -= 2;
				if (bc.timer <= 0)
				{
					bc.timer = 0;
					bc.value = 0;
				}
			}
		}
	}

	// 1. Clear transient wire values.
	foreach (c : board.cells.iter())
	{
		long k = c.key;
		if (try bc = board.cells.get_ref(k))
		{
			if (is_wire(bc.type)) bc.value = 0;
		}
	}

	// 2. Seed input pins from neighboring world logic.
	for (int side = 0; side < 4; side++)
	{
		Pin pin = board.pins[side];
		if (pin.dir != PIN_IN && pin.dir != PIN_INOUT) continue;
		int dx = side_dx(side);
		int dy = side_dy(side);
		LogicCell* neighbor = logic_get(ent.x + dx * GRID, ent.y + dy * GRID);
		uint val = neighbor ? logic_read_value_towards(neighbor, -dx, -dy) : 0;
		val = val & mask_bits(pin.bits);
		int px;
		int py;
		logic_board_pin_coords(board, side, &px, &py);
		if (try cell = board.cells.get_ref(tile_key(px, py)))
		{
			cell.value = val;
			if (is_wire(cell.type) && cell.bitWidth == pin.bits && val > 0)
			{
				board_flood_local(board, px, py, val, pin.bits);
			}
		}
	}

	// 3. Seed propagation from local sources.
	foreach (c : board.cells.iter())
	{
		long k = c.key;
		if (try bc = board.cells.get_ref(k))
		{
			if (is_lever(bc.type) || is_button(bc.type))
			{
				board_propagate_local(board, bc);
			}
		}
	}

	// 4. Gates, three passes.
	for (int pass = 0; pass < 3; pass++)
	{
		foreach (c : board.cells.iter())
		{
			long k = c.key;
			if (try bc = board.cells.get_ref(k))
			{
				if (is_gate(bc.type)) board_compute_gate(board, bc);
			}
		}
		foreach (c : board.cells.iter())
		{
			long k = c.key;
			if (try bc = board.cells.get_ref(k))
			{
				if (is_gate(bc.type)) board_propagate_local(board, bc);
			}
		}
	}

	// 5. Lamps.
	foreach (c : board.cells.iter())
	{
		long k = c.key;
		if (try bc = board.cells.get_ref(k))
		{
			if (bc.type != ITEM_LAMP && bc.type != ITEM_ANALOGLAMP) continue;
			uint best = 0;
			for (int side = 0; side < 4; side++)
			{
				uint v = board_read_neighbor(board, bc, side_dx(side), side_dy(side));
				if (v > best) best = v;
			}
			bc.value = best;
		}
	}

	// 6. Write output pins.
	for (int side = 0; side < 4; side++)
	{
		Pin pin = board.pins[side];
		if (pin.dir == PIN_OUT || pin.dir == PIN_INOUT)
		{
			int px;
			int py;
			logic_board_pin_coords(board, side, &px, &py);
			uint sum = 0;
			if (try cell = board.cells.get_ref(tile_key(px, py)))
			{
				if (cell.value > 0) sum = cell.value;
			}
			BoardCell pinCell = {};
			pinCell.x = px;
			pinCell.y = py;
			for (int d = 0; d < 4; d++)
			{
				uint v = board_read_neighbor(board, &pinCell, side_dx(d), side_dy(d));
				if (v > 0) sum = sum | v;
			}
			board.sides[side] = sum & mask_bits(pin.bits);
		}
		else
		{
			board.sides[side] = 0;
		}
	}
}

fn void logic_tick_programmable(LogicCell* cell)
{
	uint[4] inputs = { 0, 0, 0, 0 };
	for (int side = 0; side < 4; side++)
	{
		int dx = side_dx(side);
		int dy = side_dy(side);
		LogicCell* nb = logic_get(cell.x + dx * GRID, cell.y + dy * GRID);
		inputs[side] = nb ? logic_read_value_towards(nb, -dx, -dy) : 0;
	}
	logic_run_program(cell, inputs);
}

// ---------------------------------------------------------------------------
// Main tick
// ---------------------------------------------------------------------------
fn void logic_tick()
{
	if (g.tickCount % 2 != 0) return;
	if (!g.playerCreated) return;

	// Button timers.
	foreach (c : g.logic.iter())
	{
		LogicCell* cell = c.value;
		if (is_button(cell.type) && cell.timer > 0)
		{
			cell.timer -= 2;
			if (cell.timer <= 0)
			{
				cell.timer = 0;
				cell.value = 0;
			}
		}
	}

	// Purge orphaned cells only in loaded chunks, and reset wire values.
	List{long} orphans;
	orphans.init(mem);
	defer orphans.free();
	foreach (c : g.logic.iter())
	{
		LogicCell* cell = c.value;
		int ci = chunk_index(cell.x);
		if (!get_chunk(ci)) continue;
		if (block_at(cell.x, cell.y) != cell.type)
		{
			orphans.push(c.key);
		}
		else if (is_wire(cell.type))
		{
			cell.value = 0;
		}
	}
	foreach (k : orphans)
	{
		if (try cell = g.logic.get(k))
		{
			g.logic.remove(k);
			logic_free_cell(cell);
		}
	}

	// Boards compute internal state and sides.
	foreach (c : g.logic.iter())
	{
		LogicCell* cell = c.value;
		if (cell.hasBoard) logic_tick_board(cell);
	}

	// Sources.
	foreach (c : g.logic.iter())
	{
		LogicCell* cell = c.value;
		if (is_lever(cell.type) || is_button(cell.type)
		    || cell.type == ITEM_SIGNALSOURCE || cell.hasBoard)
		{
			logic_propagate_from(cell);
		}
	}

	// Gates, three settling passes.
	for (int pass = 0; pass < 3; pass++)
	{
		foreach (c : g.logic.iter())
		{
			LogicCell* cell = c.value;
			if (is_gate(cell.type)) logic_compute_gate(cell);
		}
		foreach (c : g.logic.iter())
		{
			LogicCell* cell = c.value;
			if (is_gate(cell.type)) logic_propagate_from(cell);
		}
	}

	// Programmable circuits evaluate after inputs settle.
	foreach (c : g.logic.iter())
	{
		LogicCell* cell = c.value;
		if (cell.type == ITEM_PROGRAMMABLE) logic_tick_programmable(cell);
	}
	foreach (c : g.logic.iter())
	{
		LogicCell* cell = c.value;
		if (cell.type == ITEM_PROGRAMMABLE) logic_propagate_from(cell);
	}

	// Lamps read the best signal from any neighbor.
	foreach (c : g.logic.iter())
	{
		LogicCell* cell = c.value;
		if (cell.type != ITEM_LAMP && cell.type != ITEM_ANALOGLAMP) continue;
		uint best = 0;
		for (int side = 0; side < 4; side++)
		{
			int dx = side_dx(side);
			int dy = side_dy(side);
			LogicCell* nb = logic_get(cell.x + dx * GRID, cell.y + dy * GRID);
			if (!nb) continue;
			if (nb.type == ITEM_LAMP || nb.type == ITEM_ANALOGLAMP) continue;
			uint v = logic_read_value_towards(nb, -dx, -dy);
			if (v > best) best = v;
		}
		cell.value = best;
	}

	// Displays read any emitting neighbor.
	foreach (c : g.logic.iter())
	{
		LogicCell* cell = c.value;
		if (cell.type != ITEM_DISPLAY) continue;
		uint best = 0;
		for (int side = 0; side < 4; side++)
		{
			int dx = side_dx(side);
			int dy = side_dy(side);
			LogicCell* nb = logic_get(cell.x + dx * GRID, cell.y + dy * GRID);
			if (!nb) continue;
			uint v = logic_read_value_towards(nb, -dx, -dy);
			if (v > best) best = v;
		}
		cell.value = best;
	}
}
