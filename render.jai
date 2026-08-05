render_cards :: (model: *Model, position: Vector3, color: Color = WHITE)
{
    rlDisableBackfaceCulling();
    model.transform = MatrixRotateX(90 * DEG2RAD);
    DrawModel(model, position, 1.0, color);
    model.transform = MatrixTranslate(-0.5, 0, 0.5) * MatrixMultiply(MatrixRotateZ(90 * DEG2RAD), MatrixRotateX(90 * DEG2RAD));
    DrawModel(model, position, 1.0, color);
    model.transform = MatrixTranslate(0.5, 0, 0.5) * MatrixMultiply(MatrixRotateZ(90 * DEG2RAD), MatrixRotateX(90 * DEG2RAD));
    DrawModel(model, position, 1.0, color);
    model.transform = MatrixTranslate(0, 0, 1) * MatrixRotateX(90 * DEG2RAD);
    DrawModel(model, position, 1.0, color);
    rlEnableBackfaceCulling();
}

render_walls :: (model: *Model)
{
    // Draw the maze walls: 2x2 card blocks every 4 cells (j = -1 is the top band)
    y: float = 0.75;
    for i : 0 .. 7
    {
        for j : -1 .. 6
        {
            bx := -14.5 + cast(float)(i * 4);
            bz := -11.0 + cast(float)(j * 4);

            for dz : 0 .. 1
            {
                for dx : 0 .. 1
                {
                    if !card_present(i, j, dx, dz) continue;   // opening in the maze
                    color := WHITE;
                    if card_is_center(i, j) color = WHITE;
                    render_cards(model, .{bx + cast(float) dx, y, bz + cast(float) dz}, color);
                }
            }
        }
    }
}

// Emits one chevron glyph (two thick 3D cylinder arms) shaped like <, >, ^, v.
emit_chevron :: (cx: float, cz: float, y: float, len: float, h: float, radius: float, dir: SpawnDir)
{
    half_len := len / 2.0;
    half_h := h / 2.0;

    vx := 0.0; vz := 0.0;     // vertex (the pointy end)
    a1x := 0.0; a1z := 0.0;   // arm 1 end
    a2x := 0.0; a2z := 0.0;   // arm 2 end

    if dir == .RIGHT_TO_LEFT
    {
        vx = cx - half_len;  vz = cz;
        a1x = cx + half_len; a1z = cz - half_h;
        a2x = cx + half_len; a2z = cz + half_h;
    }
    else if dir == .LEFT_TO_RIGHT
    {
        vx = cx + half_len;  vz = cz;
        a1x = cx - half_len; a1z = cz - half_h;
        a2x = cx - half_len; a2z = cz + half_h;
    }
    else if dir == .BOTTOM_TO_TOP
    {
        vx = cx;  vz = cz - half_len;
        a1x = cx - half_h; a1z = cz + half_len;
        a2x = cx + half_h; a2z = cz + half_len;
    }
    else
    {
        vx = cx;  vz = cz + half_len;
        a1x = cx - half_h; a1z = cz - half_len;
        a2x = cx + half_h; a2z = cz - half_len;
    }

    start := Vector3.{ vx, y, vz };
    arm1  := Vector3.{ a1x, y, a1z };
    arm2  := Vector3.{ a2x, y, a2z };

    DrawCylinderEx(start, arm1, radius, radius, 8, RED);
    DrawCylinderEx(start, arm2, radius, radius, 8, RED);
}

draw_wave_arrows :: (game: Game, grid: BoardGrid)
{
    if game.game_over return;

    remaining := game.spawn_timer.t_end - game.spawn_timer.t;
    if remaining > WAVE_WARNING_TIME || remaining <= 0.0 return;

    dir := wave_direction(game.next_wave);
    last := cast(s32)(BOARD_SIZE - 1);
    y := 0.6;

    if dir == .RIGHT_TO_LEFT || dir == .LEFT_TO_RIGHT
    {
        // Horizontal sweep: chevrons run along each clear row-lane
        iz: s32 = 0;
        while iz < BOARD_SIZE
        {
            if !row_clear(grid, iz) { iz += 1; continue; }

            iz_end := iz;
            while iz_end + 1 < BOARD_SIZE && row_clear(grid, iz_end + 1) { iz_end += 1; }

            lane_h := cast(float)(iz_end - iz + 1);
            lane_cz := (cell_to_world(iz) + cell_to_world(iz_end)) / 2.0;

            for ix : 0 .. last
            {
                emit_chevron(cell_to_world(ix), lane_cz, y, 0.9, lane_h, lane_h * 0.05, dir);
            }

            iz = iz_end + 1;
        }
    }
    else
    {
        // Vertical sweep: chevrons run along each clear column-lane
        ix: s32 = 0;
        while ix < BOARD_SIZE
        {
            if !column_clear(grid, ix) { ix += 1; continue; }

            ix_end := ix;
            while ix_end + 1 < BOARD_SIZE && column_clear(grid, ix_end + 1) { ix_end += 1; }

            lane_w := cast(float)(ix_end - ix + 1);
            lane_cx := (cell_to_world(ix) + cell_to_world(ix_end)) / 2.0;

            for iz : 0 .. last
            {
                emit_chevron(lane_cx, cell_to_world(iz), y, 0.9, lane_w, lane_w * 0.05, dir);
            }

            ix = ix_end + 1;
        }
    }
}