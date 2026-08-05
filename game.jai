FIRST_WAVE_DELAY     :: 15.0;   
WAVE_SPACING         :: 5.0;     
WAVE_WARNING_TIME    :: 1.5;     
GAMEOVER_TIME        :: 2.0;     
GAME_TIME            :: 150.0;   
EXIT_SPAWN_TIME      :: 90.0;    

TRAP_COUNT           :: 15;   
TRAP_SIZE            :: 2.0;  
TRAP_HEIGHT          :: 0.2;  
TRAP_FREEZE_TIME     :: 5.0;  
TRAP_SPAWN_CLEARANCE :: 3.0;  

Card_Pattern :: enum u32
{
    Diamond;
    Clover;
    Heart;
    Spade;
}

Trap :: struct
{
    position: Vector3;   // world center of the 2x2 tile
    active: bool;        
    triggered: bool;     
}

// A candidate 2x2 trap spot before placement
Trap_Candidate :: struct
{
    world: Vector3;   // world center of the 2x2 tile
    ox: s32;          // top-left cell column
    oz: s32;          // top-left cell row
}

Maze_Exit :: struct
{
    position: Vector3;
    active: bool;

    pattern: Card_Pattern;
    pattern_mesh: Mesh;
    pattern_model: Model;
    pattern_texture: Texture2D;
} 

Game :: struct
{
    setos: [..] Seto;          
    spawn_timer: Timer;        
    next_wave: s32;            
    travel_time: float;        
    game_over: bool;
    gameover_timer: Timer;
    traps: [..] Trap;
    item_pos: Vector3;
    item_active: bool;
    pickup_count: s32;
    exit: Maze_Exit;
    game_won: bool;
    game_time_left: float;
    exit_hint: bool;

    texture_storage: Table(string, Texture2D);
}

begin_cycle :: (using game: *Game, grid: BoardGrid)
{
    array_reset_keeping_memory(*setos);   // remove all enemies, keep the allocated buffer
    next_wave = 0;
    game_over = false;
    game_won = false;
    spawn_traps(game, grid);
    pickup_count = 0;
    exit.active = false;
    game_time_left = GAME_TIME;
    exit_hint = false;
    spawn_item(game, grid);
    start_countdown(*spawn_timer, FIRST_WAVE_DELAY);
}

reset_game :: (game: *Game, player: *Player, grid: BoardGrid)
{
    begin_cycle(game, grid);

    player.hp = 3;
    player.freeze_time = 0.0;
    player.position = Vector3.{ 0.0, 0.5, 0.0 };
    player.target = Vector3.{ 0.0, 0.0, 0.0 };
    player.has_target = false;
    player.path_count = 0;
    player.path_index = 0;

    assign_player_pattern(game, player);
}

assign_player_pattern :: (game: *Game, player: *Player)
{
    player.pattern = cast(Card_Pattern)random_get_within_range(0, 3.99);

    success, pattern_texture := table_find_new(*game.texture_storage, enum_value_to_name(player.pattern));
    player.pattern_texture = pattern_texture; 
    player.pattern_model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = player.pattern_texture;
}

init_game :: (player: *Player, grid: BoardGrid) -> Game
{
    game: Game;
    game.travel_time = (BOARD_SIZE - 1) / SETO_SPEED;
    game.gameover_timer = create_timer(GAMEOVER_TIME, false);

    // The exit is a flat 2x2 tile that shows the player's card pattern
    game.exit.pattern_mesh = GenMeshPlane(2.0, 2.0, 1, 1);
    game.exit.pattern_model = LoadModelFromMesh(game.exit.pattern_mesh);

    begin_cycle(*game, grid);

    for i : 0 .. enum_highest_value(Card_Pattern)
    {
        name := enum_value_to_name(cast(Card_Pattern)i);
        texture := LoadTexture(temp_c_string(tprint("ast/%.png", name)));
        table_add(*game.texture_storage, name, texture);
    }
    
    assign_player_pattern(*game, player);

    return game;
}

// Simple countdown helper (timer counts up to t_end, then completes)
start_countdown :: (timer: *Timer, seconds: float)
{
    timer.t_end = seconds;
    timer.t = 0.0;
    timer.complete = false;
    timer.active = true;
}

wave_direction :: (wave: s32) -> SpawnDir
{
    if wave == 0 return .RIGHT_TO_LEFT;
    else if wave == 1 return .BOTTOM_TO_TOP;
    else if wave == 2 return .LEFT_TO_RIGHT;
    else return .TOP_TO_BOTTOM;
}

spawn_wave :: (game: *Game, grid: BoardGrid, wave: s32)
{
    spawn_seto_wave(*game.setos, grid, wave_direction(wave));
}

collect_open_spots :: (grid: BoardGrid) -> [..] Trap_Candidate
{
    spots: [..] Trap_Candidate;

    for iz : 0 .. cast(s32)(BOARD_SIZE - 2)
    {
        for ix : 0 .. cast(s32)(BOARD_SIZE - 2)
        {
            if board_cell_blocked(grid, ix,     iz)     continue;
            if board_cell_blocked(grid, ix + 1, iz)     continue;
            if board_cell_blocked(grid, ix,     iz + 1) continue;
            if board_cell_blocked(grid, ix + 1, iz + 1) continue;

            in_wall_row := !row_clear(grid, iz) && !row_clear(grid, iz + 1);
            in_wall_col := !column_clear(grid, ix) && !column_clear(grid, ix + 1);
            if !(in_wall_row || in_wall_col) continue;

            // Make sure to not spawn on the center area
            bx := cast(float) ix + 0.5;
            bz := cast(float) iz + 0.5;
            dx := bx - 16.0;
            dz := bz - 16.0;
            if sqrt(dx * dx + dz * dz) < TRAP_SPAWN_CLEARANCE continue;

            cand: Trap_Candidate;
            cand.world = Vector3.{ cell_to_world(ix) + 0.5, 0.0, cell_to_world(iz) + 0.5 };
            cand.ox = ix;
            cand.oz = iz;
            array_add(*spots, cand);
        }
    }

    return spots;
}

spot_overlaps_trap :: (game: *Game, wx: float, wz: float) -> bool
{
    for trap : game.traps
    {
        if !trap.active continue;
        if abs(wx - trap.position.x) < 2.0 && abs(wz - trap.position.z) < 2.0 return true;
    }
    return false;
}

find_random_spot :: (game: *Game, grid: BoardGrid) -> (bool, Vector3)
{
    spots := collect_open_spots(grid);

    // Fisher-Yates shuffle
    for i : 0 .. spots.count - 1
    {
        j := cast(s32) random_get_within_range(cast(float) i, cast(float) spots.count);
        if j >= spots.count j = cast(s32)(spots.count - 1);
        if j < cast(s32) i j = cast(s32) i;

        tmp := spots[i];
        spots[i] = spots[j];
        spots[j] = tmp;
    }

    found := false;
    result: Vector3;
    for cand : spots
    {
        if spot_overlaps_trap(game, cand.world.x, cand.world.z) continue;
        result = cand.world;
        found = true;
        break;
    }

    array_reset(*spots);
    return found, result;
}

spawn_traps :: (game: *Game, grid: BoardGrid)
{
    array_reset_keeping_memory(*game.traps);

    candidates := collect_open_spots(grid);

    // Fisher-Yates shuffle
    for i : 0 .. candidates.count - 1
    {
        j := cast(s32) random_get_within_range(cast(float) i, cast(float) candidates.count);
        if j >= candidates.count j = cast(s32)(candidates.count - 1);
        if j < cast(s32) i j = cast(s32) i;

        tmp := candidates[i];
        candidates[i] = candidates[j];
        candidates[j] = tmp;
    }

    // Skip any spot that would overlap or touch an existing trap
    placed: [..] Trap_Candidate;
    for cand : candidates
    {
        if placed.count >= TRAP_COUNT break;

        too_close := false;
        for p : placed
        {
            // Blocks closer than 3 cells on both axes overlap or sit side by side
            if abs(p.ox - cand.ox) <= 2 && abs(p.oz - cand.oz) <= 2
            {
                too_close = true;
                break;
            }
        }
        if too_close continue;

        array_add(*placed, cand);

        trap: Trap;
        trap.position = Vector3.{ cand.world.x, TRAP_HEIGHT / 2.0, cand.world.z };
        trap.active = true;
        array_add(*game.traps, trap);
    }

    array_reset(*candidates);
    array_reset(*placed);
}

update_traps :: (game: *Game, player: *Player, grid: BoardGrid, dt: float)
{
    if player.freeze_time > 0.0
    {
        player.freeze_time -= dt;
        if player.freeze_time <= 0.0
        {
            player.freeze_time = 0.0;
            for *trap : game.traps
            {
                if trap.triggered
                {
                    trap.active = false;
                    trap.triggered = false;
                }
            }
        }
    }

    if player.freeze_time <= 0.0
    {
        for *trap : game.traps
        {
            if !trap.active || trap.triggered continue;

            dx := trap.position.x - player.position.x;
            dz := trap.position.z - player.position.z;
            r := TRAP_SIZE / 2.0 + player.radius;
            if dx * dx + dz * dz < r * r
            {
                trap.triggered = true;
                player.hp -= 1;
                player.freeze_time = TRAP_FREEZE_TIME;
                reset_pickups(game, grid);   // touching a trap resets item progress
                break;   // one trap per trigger
            }
        }
    }
}

draw_traps :: (traps: [..] Trap)
{
    for trap : traps
    {
        if !trap.active continue;
        DrawCube(trap.position, TRAP_SIZE, TRAP_HEIGHT, TRAP_SIZE, PINK);
    }
}

spawn_item :: (game: *Game, grid: BoardGrid)
{
    found, pos := find_random_spot(game, grid);
    if !found
    {
        game.item_active = false;
        return;
    }
    game.item_pos = Vector3.{ pos.x, 0.25, pos.z };
    game.item_active = true;
}

spawn_exit :: (game: *Game, player: *Player, grid: BoardGrid)
{
    found, pos := find_random_spot(game, grid);
    if !found return;

    game.exit.position = Vector3.{ pos.x, 0.1, pos.z };
    game.exit.active = true;

    game.exit.pattern = player.pattern;
    success, tex := table_find_new(*game.texture_storage, enum_value_to_name(game.exit.pattern));
    game.exit.pattern_texture = tex;
    game.exit.pattern_model.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = game.exit.pattern_texture;
}

update_item :: (game: *Game, player: *Player, grid: BoardGrid)
{
    if !game.item_active return;

    dx := game.item_pos.x - player.position.x;
    dz := game.item_pos.z - player.position.z;
    r := 0.2 + player.radius;   // item half-size + player radius
    if dx * dx + dz * dz >= r * r return;

    game.pickup_count += 1;
    if game.pickup_count >= 3
    {
        game.item_active = false; 
    }
    else
    {
        spawn_item(game, grid); 
    }
}

update_exit :: (game: *Game, player: *Player)
{
    game.exit_hint = false;
    if !game.exit.active return;

    dx := game.exit.position.x - player.position.x;
    dz := game.exit.position.z - player.position.z;
    if abs(dx) < 1.0 && abs(dz) < 1.0
    {
        if game.pickup_count >= 3
        {
            game.game_over = true;
            game.game_won = true;
            start_countdown(*game.gameover_timer, GAMEOVER_TIME);
        }
        else
        {
            game.exit_hint = true;   // needs more items to enter
        }
    }
}

reset_pickups :: (game: *Game, grid: BoardGrid)
{
    game.pickup_count = 0;
    spawn_item(game, grid);
}

draw_item :: (game: Game)
{
    if !game.item_active return;
    DrawCube(game.item_pos, 0.4, 0.5, 0.4, GREEN);
    DrawCubeWires(game.item_pos, 0.4, 0.5, 0.4, DARKGREEN);
}

draw_exit :: (exit: Maze_Exit)
{
    if !exit.active return;
    //DrawCube(exit.position, 2.0, 0.2, 2.0, GREEN);
    BeginBlendMode(.BLEND_ALPHA_PREMULTIPLY);
    DrawModel(exit.pattern_model, .{ exit.position.x, exit.position.y + 0.05, exit.position.z }, 1.0, WHITE);
    EndBlendMode();
}

pattern_initial :: (pattern: Card_Pattern) -> u8
{
    if pattern == .Diamond return #char "D";
    else if pattern == .Clover return #char "C";
    else if pattern == .Heart return #char "H";
    else return #char "S";
}

// NOTE: 12 = north (top of the board), 3 = east, 6 = south, 9 = west.
clock_hour_at :: (x: float, z: float) -> s32
{
    angle := atan2(x, -z) * RAD2DEG;   // degrees clockwise from north
    if angle < 0.0 angle += 360.0;

    hour := cast(s32)((angle + 15.0) / 30.0);   // round to the nearest hour
    hour %= 12;
    if hour == 0 hour = 12;
    return hour;
}

item_clock_hour :: (game: *Game) -> s32
{
    return clock_hour_at(game.item_pos.x, game.item_pos.z);
}

exit_clock_hour :: (game: *Game) -> s32
{
    return clock_hour_at(game.exit.position.x, game.exit.position.z);
}

draw_exit_compass :: (game: Game, player: Player)
{
    if !game.exit.active return;

    buffer: [16] u8;
    count := 0;

    label := "Exit: ";
    for i : 0 .. label.count - 1
    {
        buffer[count] = label[i];
        count += 1;
    }

    buffer[count] = pattern_initial(player.pattern); count += 1;

    hour := exit_clock_hour(*game);
    if hour >= 10
    {
        buffer[count] = cast(u8)(cast(s32) #char "0" + hour / 10); count += 1;
    }
    buffer[count] = cast(u8)(cast(s32) #char "0" + hour % 10); count += 1;
    buffer[count] = 0;

    DrawText(*buffer[0], 10, 180, 30, BLACK);
}


draw_item_compass :: (game: Game, player: Player)
{
    if !game.item_active return;

    buffer: [8] u8;
    count := 0;

    buffer[count] = pattern_initial(player.pattern); count += 1;

    hour := item_clock_hour(*game);
    if hour >= 10
    {
        buffer[count] = cast(u8)(cast(s32) #char "0" + hour / 10); count += 1;
    }
    buffer[count] = cast(u8)(cast(s32) #char "0" + hour % 10); count += 1;
    buffer[count] = 0;

    DrawText(*buffer[0], 10, 120, 30, BLUE);
}

draw_game_timer :: (game: Game)
{
    seconds := cast(s32)(game.game_time_left + 0.5);
    if seconds < 0 seconds = 0;
    min := seconds / 60;
    sec_remain := seconds % 60;
    sec_remain_text := ifx sec_remain < 10 then tprint("0%", sec_remain) else tprint("%", sec_remain);
    DrawText(temp_c_string(tprint("Time: %:%", min, sec_remain_text)), 10, 150, 30, BLACK);
}

update_game :: (using game: *Game, player: *Player, grid: BoardGrid, dt: float)
{
    if game_over
    {
        process_timer(*gameover_timer, dt);
        if timer_completed(gameover_timer)
        {
            reset_game(game, player, grid);
        }
        return;
    }

    game_time_left -= dt;
    if game_time_left <= 0.0
    {
        game_time_left = 0.0;
        game_over = true;
        game_won = false;
        start_countdown(*gameover_timer, GAMEOVER_TIME);
        return;
    }

    if !exit.active && game_time_left <= EXIT_SPAWN_TIME
    {
        spawn_exit(game, player, grid);
    }

    process_timer(*spawn_timer, dt);
    if timer_completed(spawn_timer)
    {
        wave := next_wave;
        spawn_wave(game, grid, wave);

        next_wave = (wave + 1) % 4;
        delay := WAVE_SPACING;
        if wave == 1 delay = travel_time + WAVE_SPACING;
        else if wave == 3 delay = travel_time + WAVE_SPACING; // wait for wave 4, then new cycle
        start_countdown(*spawn_timer, delay);
    }

    update_traps(game, player, grid, dt);
    update_setos(game, player, grid, dt);
    update_item(game, player, grid);
    update_exit(game, player);
}

update_setos :: (game: *Game, player: *Player, grid: BoardGrid, dt: float)
{
    i := game.setos.count;
    while i > 0
    {
        i -= 1;
        seto: *Seto = *game.setos[i];

        if seto.active
        {
            update_seto(seto, dt);

            if seto.active && !seto.touched
            {
                dx := seto.position.x - player.position.x;
                dz := seto.position.z - player.position.z;
                r := player.radius + seto.radius;
                if dx * dx + dz * dz < r * r
                {
                    seto.touched = true;
                    player.hp -= 1;
                    reset_pickups(game, grid);   // touching a seto resets item progress
                    if player.hp <= 0
                    {
                        game.game_over = true;
                        start_countdown(*game.gameover_timer, GAMEOVER_TIME);
                    }
                }
            }
        }

        if !seto.active
        {
            // NOTE: Remove the inactive seto at index i (order-preserving shift). Iterating backwards means the shifted elements were already handled.
            for k : i .. game.setos.count - 2
            {
                game.setos[k] = game.setos[k + 1];
            }
            game.setos.count -= 1;
        }
    }
}