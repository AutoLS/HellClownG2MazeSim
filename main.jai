#import "raylib";
#import "Basic";
#import "Math";
#import "Random";
#import "Hash_Table";
#import "Reflection";
#load "render.jai";
#load "board.jai";
#load "pathfind.jai";
#load "player.jai";
#load "seto.jai";
#load "time.jai";
#load "game.jai";

main :: ()
{
    random_seed(cast,force(Some_Big_Time_Value)current_time_consensus());
    screenWidth: s32 = 1920;
    screenHeight: s32 = 1080;

    SetConfigFlags(.FLAG_WINDOW_RESIZABLE);

    InitWindow(screenWidth, screenHeight, "Kakul Saydon G2 Maze Sim");

    InitAudioDevice();
    bgm := LoadMusicStream("ast/BGM.mp3");
    bgm_volume := 0.8;
    bgm_pan: float = 0;
    SetMusicPan(bgm, bgm_pan);
    SetMusicVolume(bgm, bgm_volume);
    PlayMusicStream(bgm);

    camera: Camera3D;
    camera.position = Vector3.{ 10.0, 10.0, 10.0 }; 
    camera.target = Vector3.{ 0.0, 0.0, 0.0 };      
    camera.up = Vector3.{ 0.0, 1.0, 0.0 };          
    camera.fovy = 45.0;                             
    camera.projection = .CAMERA_PERSPECTIVE;        

    cubePosition: Vector3 = .{ 0.0, 0.0, 0.0 };

    //DisableCursor();

    SetTargetFPS(144); // TODO: User config at runtime?

    // TODO: Refactor these to texture storage 
    card_image := LoadImage("ast/2_of_spades.png");
    ImageFlipHorizontal(*card_image);
    card_texture := LoadTextureFromImage(*card_image);

    card_mesh := GenMeshPlane(1, 1.5, 1, 1);
    card := LoadModelFromMesh(card_mesh);
    card.materials[0].maps[MATERIAL_MAP_DIFFUSE].texture = card_texture;

    // Collision grid + player
    grid := board_build_grid();
    player := player_make(Vector3.{ 0.0, 0.5, 0.0 }); // Spawn in the middle of the board
    camera_mode := false; // true = free-look, false = click-to-move

    t: float;

    game := init_game(*player, grid);

    // Main game loop
    while (!WindowShouldClose())        // Detect window close button or ESC key
    {
        reset_temporary_storage();
        UpdateMusicStream(bgm);
        // Update
        if (IsWindowResized())
        {
            screenWidth = GetScreenWidth();
            screenHeight = GetScreenHeight();
        }

        if (camera_mode)
        {
            UpdateCamera(*camera, .CAMERA_FREE);
        }
        else
        {
            // Lock the camera onto the player
            camera.target = player.position;
            camera.position = Vector3.{ player.position.x, player.position.y + 5.0, player.position.z + 4.0 };
        }
        t += GetFrameTime();

        if (camera_mode && IsKeyPressed(.KEY_Z)) camera.target = Vector3.{ 0.0, 0.0, 0.0 };

        // Tab toggles between free-look camera and click-to-move mode
        if (IsKeyPressed(.KEY_TAB))
        {
            camera_mode = !camera_mode;
            if (camera_mode) DisableCursor();
            else EnableCursor();
        }

        if !camera_mode && (IsMouseButtonPressed(.MOUSE_BUTTON_RIGHT) || IsMouseButtonDown(.MOUSE_BUTTON_RIGHT))
        {
            ray := GetMouseRay(GetMousePosition(), camera);
            player_set_target_from_ray(*player, grid, ray);
        }

        update_game(*game, *player, grid, GetFrameTime());

        player_update(*player, GetFrameTime());

        BeginDrawing();

            ClearBackground(RAYWHITE);

            BeginMode3D(camera);

                DrawPlane(.{}, .{32, 32}, LIGHTGRAY);
                render_walls(*card);
 
                player_draw(player);
                draw_setos(game.setos);
                draw_traps(game.traps);
                draw_item(game);
                draw_exit(game.exit);
                draw_wave_arrows(game, grid);

                DrawGrid(32, 1.0);
            
            EndMode3D();

        // HUD
        DrawText("HP:", 10, 10, 30, BLACK);
        x: int = 60;
        for h : 0 .. player.hp - 1
        {
            DrawRectangle(cast(s32)x, 16, 22, 22, RED);
            x += 30;
        }

        DrawText("Items:", 10, 50, 30, BLACK);
        ix: int = 130;
        for c : 0 .. game.pickup_count - 1
        {
            DrawRectangle(cast(s32)ix, 56, 22, 22, GREEN);
            ix += 30;
        }

        draw_item_compass(game, player);
        draw_game_timer(game);
        draw_exit_compass(game, player);

        if (game.exit_hint)
        {
            DrawText("Need 3 items to exit!", 10, 210, 30, BLACK);
        }

        if (player.freeze_time > 0.0)
        {
            DrawText("TRAPPED!", 10, 90, 30, BLUE);
        }

        if (game.game_over)
        {
            if (game.game_won) DrawText("YOU WIN!", GetScreenWidth()/2 - 100, GetScreenHeight()/2 - 20, 40, GREEN);
            else DrawText("GAME OVER", GetScreenWidth()/2 - 120, GetScreenHeight()/2 - 20, 40, RED);
        }

        EndDrawing();
    }

    CloseWindow();  
}