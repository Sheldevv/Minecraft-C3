// TerraBlock entry point: window, fixed-rate world ticks, input and rendering.
module minecraft;
import rl, perlin;
import std::math;
import std::math::random;
import std::core::string;

fn void trace(rl::TraceLogLevel logLevel, ZString text)
{
	rl::traceLog(logLevel, text);
}

fn void load(String[] args)
{
	init_data();
	state_init();
	net_init();
	perlin::init();
	random::srand((ulong)(rl::getTime() * 1000000000.0) + 1);
	discover_resources();
	player_create();
	find_worlds();

	rl::setTargetFPS(60);
	rl::setExitKey(rl::KEY_NULL);
	rl::hideCursor();
	rl::setWindowTitle("TerraBlock");

	Image icon = rl::loadImage("player-32x32.png");
	if (icon.data)
	{
		rl::setWindowIcon(icon);
		rl::unloadImage(icon);
	}

	// CLI shortcuts: --seed <n> [--creative] or --host <port> [--seed <n>].
	int cliSeed = 0;
	int cliPort = 0;
	bool cliCreative = false;
	String cliJoin = "";
	String cliName = "Player";
	for (int i = 1; i < (int)args.len; i++)
	{
		String arg = args[i];
		if (arg.starts_with("--seed") && i + 1 < (int)args.len)
		{
			cliSeed = args[i + 1].to_int() ?? 0;
			i++;
		}
		else if (arg.starts_with("--host") && i + 1 < (int)args.len)
		{
			cliPort = args[i + 1].to_int() ?? NET_PORT;
			i++;
		}
		else if (arg.starts_with("--join") && i + 1 < (int)args.len)
		{
			cliJoin = args[i + 1];
			i++;
		}
		else if (arg.starts_with("--name") && i + 1 < (int)args.len)
		{
			cliName = args[i + 1];
			i++;
		}
		else if (arg.starts_with("--creative"))
		{
			cliCreative = true;
		}
	}
	if (cliJoin.len > 0)
	{
		if (!net_client_connect(cliJoin.zstr_tcopy(),
		                        cliPort > 0 ? cliPort : NET_PORT,
		                        cliName.zstr_tcopy()))
		{
			g.menuSubstate = 1;
		}
	}
	else if (cliPort > 0)
	{
		(void)net_server_start(cliPort, cliSeed > 0 ? cliSeed : world_seed_random(), "Host");
	}
	else if (cliSeed > 0)
	{
		g.creativeMode = cliCreative;
		g.worldMode = cliCreative ? 1 : 0;
		g.hostilesEnabled = true;
		g.currentSeed = cliSeed;
		reset_world(cliSeed);
		g.gameState = GS_PLAYING;
		g.paused = false;
	}
}

fn void handle_key(rl::KeyboardKey key)
{
	bool ctrl = rl::isKeyDown(rl::KEY_LEFT_CONTROL) || rl::isKeyDown(rl::KEY_RIGHT_CONTROL);

	// Escape: unwind one layer at a time, then pause.
	if (key == rl::KEY_ESCAPE)
	{
		if (g.gameState == GS_MENU && g.menuSubstate == 1)
		{
			g.menuSubstate = 0;
			g.uiActiveField = -1;
			return;
		}
		if (g.gameState == GS_MODS)
		{
			g.gameState = GS_MENU;
			uiModSelected = -1;
			g.uiActiveField = -1;
			return;
		}
		if (g.boardOpen)
		{
			g.boardOpen = false;
			g.uiActiveField = -1;
			return;
		}
		if (g.programOpen)
		{
			logic_close_program();
			g.uiActiveField = -1;
			return;
		}
		if (g.signalSourceOpen)
		{
			g.signalSourceOpen = false;
			g.uiActiveField = -1;
			return;
		}
		if (g.cmdOpen)
		{
			g.cmdOpen = false;
			g.uiActiveField = -1;
			return;
		}
		if (g.chatOpen)
		{
			g.chatOpen = false;
			ui_field_set(8, "");
			g.uiActiveField = -1;
			return;
		}
		if (g.gameState != GS_PLAYING) return;
		if (g.inventoryOpen || g.stationOpen)
		{
			return_held_stack();
			g.inventoryOpen = false;
			g.stationOpen = false;
			g.uiActiveField = -1;
			return;
		}
		g.paused = !g.paused;
		g.uiActiveField = -1;
		return;
	}

	// Enter: submit or insert a newline in the program editor.
	if (key == rl::KEY_ENTER || key == rl::KEY_KP_ENTER)
	{
		if (g.cmdOpen)
		{
			ui_command_submit();
			return;
		}
		if (g.chatOpen)
		{
			net_send_chat((ZString)&g.chatText[0]);
			ui_field_set(8, "");
			g.chatOpen = false;
			g.uiActiveField = -1;
			return;
		}
		if (g.signalSourceOpen)
		{
			logic_apply_signal();
			g.uiActiveField = -1;
			return;
		}
		if (g.programOpen)
		{
			if (ctrl)
			{
				logic_close_program();
				g.uiActiveField = -1;
			}
			else if (g.uiActiveField == 6)
			{
				ui_text_append('\n');
			}
			return;
		}
		if (g.gameState == GS_WORLD_CREATE && g.uiActiveField == 1)
		{
			ui_start_new_world();
			return;
		}
		return;
	}

	// Text fields consume ordinary keys while focused.
	if (g.uiActiveField >= 0)
	{
		if (key == rl::KEY_TAB && g.uiActiveField == 6)
		{
			ui_text_append(' ');
			ui_text_append(' ');
			ui_text_append(' ');
			ui_text_append(' ');
		}
		return;
	}

	if (g.boardOpen)
	{
		if (key == rl::KEY_E) g.boardOpen = false;
		return;
	}
	if (g.programOpen || g.signalSourceOpen || g.cmdOpen || g.chatOpen || g.paused)
	{
		return;
	}
	if (g.gameState != GS_PLAYING)
	{
		if (g.gameState == GS_WORLD_SELECT && key == rl::KEY_ESCAPE)
		{
			g.gameState = GS_MENU;
		}
		return;
	}

	// Gameplay keys.
	if (key == rl::KEY_P)
	{
		g.paused = true;
		return;
	}
	if (key == rl::KEY_F3)
	{
		g.debugMode = rl::isKeyDown(rl::KEY_F4) ? g.debugMode : !g.debugMode;
		if (rl::isKeyDown(rl::KEY_F4)) g.ghostMode = !g.ghostMode;
		return;
	}
	if (key == rl::KEY_F5)
	{
		if (net_is_active()) {show_msg("Multiplayer worlds are server-hosted", 2);}
		else {(void)save_world();}
		return;
	}
	if (key == rl::KEY_F9)
	{
		if (net_is_active()) {show_msg("Multiplayer worlds cannot be loaded here", 2);}
		else {(void)load_world(g.currentSeed);}
		return;
	}
	if (key == rl::KEY_SLASH)
	{
		g.cmdOpen = true;
		ui_field_set(7, "/");
		g.uiActiveField = 7;
		return;
	}
	if (key == rl::KEY_T)
	{
		if (!net_is_connected())
		{
			show_msg("Join a server to use chat", 1.5f);
		}
		else
		{
			g.chatOpen = true;
			ui_field_set(8, "");
			g.uiActiveField = 8;
			g.chatScroll = 0;
		}
		return;
	}
	if (key == rl::KEY_E || key == rl::KEY_TAB)
	{
		if (g.stationOpen)
		{
			return_held_stack();
			g.stationOpen = false;
		}
		else
		{
			if (g.inventoryOpen) return_held_stack();
			g.inventoryOpen = !g.inventoryOpen;
		}
		return;
	}
	if (key == rl::KEY_C)
	{
		if (g.stationOpen)
		{
			return_held_stack();
			g.stationOpen = false;
		}
		else
		{
			ui_open_station();
		}
		return;
	}
	if (key == rl::KEY_F)
	{
		player_do_interact();
		if (g.programOpen)
		{
			g.uiActiveField = 6;
		}
		else if (g.signalSourceOpen)
		{
			g.uiActiveField = 5;
		}
		else
		{
			g.uiActiveField = -1;
		}
		return;
	}
	if (key == rl::KEY_Q)
	{
		(void)player_try_eat();
		return;
	}
	if (key == rl::KEY_B)
	{
		g.backgroundMode = !g.backgroundMode;
		show_msg(g.backgroundMode ? "Background layer" : "Foreground layer", 1.1f);
		return;
	}
	if (key == rl::KEY_SPACE || key == rl::KEY_W || key == rl::KEY_UP)
	{
		player_jump_or_drop();
		return;
	}
	if (key == rl::KEY_R)
	{
		if (g.inventoryOpen || g.stationOpen) return;
		if (net_is_active())
		{
			show_msg("World reset is server-controlled", 2);
		}
		else
		{
			reset_world(world_seed_random());
		}
		return;
	}

	if (key >= rl::KEY_ZERO && key <= rl::KEY_NINE)
	{
		int digit = key - rl::KEY_ZERO;
		g.player.hot = digit == 0 ? 9 : digit - 1;
	}
}

fn void handle_wheel()
{
	float wheel = rl::getMouseWheelMove();
	if (wheel == 0) return;
	if (g.chatOpen)
	{
		g.chatScroll = maxi(0, g.chatScroll + (wheel > 0 ? -1 : 1));
		return;
	}
	if (g.gameState == GS_PLAYING)
	{
		if (g.stationOpen)
		{
			ui_station_wheel(wheel);
		}
		else if (!ui_overlay_open() && g.uiActiveField < 0)
		{
			ui_hotbar_scroll(wheel);
		}
	}
}

fn void update(float dt)
{
	if (dt <= 0 || dt > 0.25f) dt = 1.0f / 60.0f;

	ui_process_char_input();
	ui_process_backspace();

	// One-shot key presses (checked against all known keys).
	for (int key = 32; key < 350; key++)
	{
		if (rl::isKeyPressed((rl::KeyboardKey)key))
		{
			handle_key((rl::KeyboardKey)key);
		}
	}
	handle_wheel();
	net_update(dt);

	if (uiQuitRequested) return;
	if (g.gameState != GS_PLAYING || g.paused) return;

	g.timeOfDay = g.timeOfDay + dt / DAY_LEN;
	g.timeOfDay = g.timeOfDay - (float)math::floor((double)g.timeOfDay);
	g.messageTimer = fmax(0.0f, g.messageTimer - dt);
	update_blood_moon();

	bool uiOpen = g.inventoryOpen || g.stationOpen || g.boardOpen
	            || g.programOpen || g.signalSourceOpen || g.cmdOpen || g.chatOpen;
	if (!uiOpen)
	{
		player_update(dt);
	}
	else
	{
		g.miningActive = false;
		g.miningProgress = 0;
	}

	float targetX = g.player.x + (float)g.player.w / 2.0f;
	float targetY = g.player.y + (float)g.player.h / 2.0f;
	float follow = fmin(1.0f, 9.0f * dt);
	g.cameraX = g.cameraX + (targetX - g.cameraX) * follow;
	g.cameraY = g.cameraY + (targetY - g.cameraY) * follow;

	update_streaming();
	update_drops(dt);
	update_particles(dt);
	update_floats(dt);
	update_enemies(dt);
	update_tnt(dt);

	// Fixed-rate systems: water, falling blocks, furnaces and circuits.
	g.tickAccumulator = fmin(1.0f, g.tickAccumulator + dt);
	float interval = 1.0f / (float)TICKS_PER_SECOND;
	while (g.tickAccumulator >= interval)
	{
		g.tickAccumulator -= interval;
		g.tickCount++;
		water_tick();
		update_falling_blocks();
		tick_furnaces();
		logic_tick();
	}

	if (uiOpen) return;

	// Held mouse button repeats block placement / mining.
	g.blockActionTimer -= dt;
	if (g.blockActionTimer <= 0)
	{
		if (rl::isMouseButtonDown(rl::MOUSE_BUTTON_LEFT)
		    || rl::isMouseButtonDown(rl::MOUSE_BUTTON_RIGHT))
		{
			float wx;
			float wy;
			screen_to_world(rl::getMouseX(), rl::getMouseY(), &wx, &wy);
			bool left = rl::isMouseButtonDown(rl::MOUSE_BUTTON_LEFT);
			mining_block_action(snap_i(wx), snap_i(wy), left ? 0 : 1);
			g.blockActionTimer = left ? 0.12f : 0.045f;
		}
		else
		{
			g.miningActive = false;
			g.miningProgress = 0;
		}
	}
}

fn void draw()
{
	int sw = rl::getScreenWidth();
	int sh = rl::getScreenHeight();
	ui_draw_frame(sw, sh);
}

fn int main(String[] args)
{
	rl::initWindow(1280, 720, "TerraBlock");
	defer rl::closeWindow();
	load(args);

	while (!rl::windowShouldClose() && !uiQuitRequested)
	{
		update(rl::getFrameTime());
		rl::@drawing()
		{
			draw();
		};
	}
	return 0;
}
