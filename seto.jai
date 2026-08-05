SETO_SPEED  :: 3.0;
SETO_HEIGHT :: 2.0;
SETO_WIDTH  :: 1.0;
SETO_RADIUS :: 0.5;

SpawnDir :: enum
{
    RIGHT_TO_LEFT;
    BOTTOM_TO_TOP;
    LEFT_TO_RIGHT;
    TOP_TO_BOTTOM;
}

Seto :: struct
{
    position: Vector3;
    destination: Vector3;
    speed: float = SETO_SPEED;
    height: float = SETO_HEIGHT;
    radius: float = SETO_RADIUS;
    width_x: float = SETO_WIDTH;   
    width_z: float = SETO_WIDTH;   
    active: bool;
    touched: bool;
}

// Moves the seto toward its destination; deactivates once it arrives (despawn).
update_seto :: (using seto: *Seto, dt: float)
{
    if !active return;

    dx := destination.x - position.x;
    dz := destination.z - position.z;
    dist := sqrt(dx * dx + dz * dz);

    if dist < 0.001
    {
        active = false; 
        return;
    }

    step := speed * dt;
    if step > dist step = dist;

    position.x += dx / dist * step;
    position.z += dz / dist * step;
}

// True if the entire row (all columns) has no walls
row_clear :: (grid: BoardGrid, iz: s32) -> bool
{
    for ix : 0 .. cast(s32)(BOARD_SIZE - 1)
    {
        if board_cell_blocked(grid, ix, iz) return false;
    }
    return true;
}

// True if the entire column (all rows) has no walls
column_clear :: (grid: BoardGrid, ix: s32) -> bool
{
    for iz : 0 .. cast(s32)(BOARD_SIZE - 1)
    {
        if board_cell_blocked(grid, ix, iz) return false;
    }
    return true;
}

//NOTE: Spawns one seto per clear row/column lane. Consecutive clear rows/columns are grouped into a single lane for simplicity sake
spawn_seto_wave :: (setos: *[..] Seto, grid: BoardGrid, dir: SpawnDir)
{
    y: float = SETO_HEIGHT / 2.0; // center the cube so it stands on the ground
    last := cast(s32)(BOARD_SIZE - 1);

    if dir == .RIGHT_TO_LEFT || dir == .LEFT_TO_RIGHT
    {
        // Horizontal sweep
        iz: s32 = 0;
        while iz < BOARD_SIZE
        {
            if !row_clear(grid, iz) { iz += 1; continue; }

            iz_end := iz;
            while iz_end + 1 < BOARD_SIZE && row_clear(grid, iz_end + 1) { iz_end += 1; }

            lane_width := iz_end - iz + 1; // 1 or 2 cells
            lane_cz := (cell_to_world(iz) + cell_to_world(iz_end)) / 2.0;

            seto: Seto;
            if dir == .RIGHT_TO_LEFT
            {
                seto.position    = Vector3.{ cell_to_world(last), y, lane_cz };
                seto.destination = Vector3.{ cell_to_world(0), y, lane_cz };
            }
            else
            {
                seto.position    = Vector3.{ cell_to_world(0), y, lane_cz };
                seto.destination = Vector3.{ cell_to_world(last), y, lane_cz };
            }
            seto.width_x = SETO_WIDTH;
            seto.width_z = cast(float) lane_width;
            seto.radius = cast(float) lane_width / 2.0;
            seto.active = true;
            array_add(setos, seto);

            iz = iz_end + 1;
        }
    }
    else
    {
        // Vertical sweep
        ix: s32 = 0;
        while ix < BOARD_SIZE
        {
            if !column_clear(grid, ix) { ix += 1; continue; }

            ix_end := ix;
            while ix_end + 1 < BOARD_SIZE && column_clear(grid, ix_end + 1) { ix_end += 1; }

            lane_width := ix_end - ix + 1;
            lane_cx := (cell_to_world(ix) + cell_to_world(ix_end)) / 2.0;

            seto: Seto;
            if dir == .BOTTOM_TO_TOP
            {
                seto.position    = Vector3.{ lane_cx, y, cell_to_world(last) };
                seto.destination = Vector3.{ lane_cx, y, cell_to_world(0) };
            }
            else
            {
                seto.position    = Vector3.{ lane_cx, y, cell_to_world(0) };
                seto.destination = Vector3.{ lane_cx, y, cell_to_world(last) };
            }
            seto.width_x = cast(float) lane_width;
            seto.width_z = SETO_WIDTH;
            seto.radius = cast(float) lane_width / 2.0;
            seto.active = true;
            array_add(setos, seto);

            ix = ix_end + 1;
        }
    }
}

draw_setos :: (setos: [..] Seto)
{
    for seto : setos
    {
        if !seto.active continue;
        DrawCube(seto.position, seto.width_x, seto.height, seto.width_z, RED);
        DrawCubeWires(seto.position, seto.width_x, seto.height, seto.width_z, BLACK);
    }
}