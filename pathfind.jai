// NOTE: BFS pathfinding over the board's walkable grid. Produces a route of cell-center waypoints the player can safely follow.

MAX_PATH :: 1024;

// NOTE: World coordinate of the center of a cell along one axis. Cell ix spans [ix-16, ix-15), so its center is at ix - 15.5.
cell_to_world :: (cell: s32) -> float
{
    return cast(float) cell - (BOARD_HALF - 0.5);
}

// NOTE: Breadth-first shortest path from (sx, sz) to (gx, gz). Writes waypoints (start cell excluded, goal cell included) into `out` and returns how many were written. Returns 0 if the goal is unreachable.
path_find :: (grid: BoardGrid, sx: s32, sz: s32, gx: s32, gz: s32, out: *[MAX_PATH] Vector3) -> s32
{
    count := 0;

    if board_cell_blocked(grid, sx, sz) return 0;
    if board_cell_blocked(grid, gx, gz) return 0;

    start := sz * BOARD_SIZE + sx;
    goal  := gz * BOARD_SIZE + gx;

    if start == goal
    {
        out.*[0] = Vector3.{ cell_to_world(gx), 0.0, cell_to_world(gz) };
        return 1;
    }

    N :: BOARD_SIZE * BOARD_SIZE;

    prev: [N] s32;
    visited: [N] bool;
    queue: [N] s32;

    for i : 0 .. N - 1 { prev[i] = -1; }

    head := 0;
    tail := 0;
    visited[start] = true;
    queue[tail] = start; tail += 1;

    found := false;

    while head < tail
    {
        cur := queue[head]; head += 1;
        cix := cur % BOARD_SIZE;
        ciz := cur / BOARD_SIZE;

        // East
        if cix + 1 < BOARD_SIZE
        {
            ni := ciz * BOARD_SIZE + (cix + 1);
            if !visited[ni] && !board_cell_blocked(grid, cix + 1, ciz)
            {
                visited[ni] = true;
                prev[ni] = cur;
                if ni == goal { found = true; break; }
                queue[tail] = ni; tail += 1;
            }
        }

        // West
        if cix - 1 >= 0
        {
            ni := ciz * BOARD_SIZE + (cix - 1);
            if !visited[ni] && !board_cell_blocked(grid, cix - 1, ciz)
            {
                visited[ni] = true;
                prev[ni] = cur;
                if ni == goal { found = true; break; }
                queue[tail] = ni; tail += 1;
            }
        }

        // South
        if ciz + 1 < BOARD_SIZE
        {
            ni := (ciz + 1) * BOARD_SIZE + cix;
            if !visited[ni] && !board_cell_blocked(grid, cix, ciz + 1)
            {
                visited[ni] = true;
                prev[ni] = cur;
                if ni == goal { found = true; break; }
                queue[tail] = ni; tail += 1;
            }
        }

        // North
        if ciz - 1 >= 0
        {
            ni := (ciz - 1) * BOARD_SIZE + cix;
            if !visited[ni] && !board_cell_blocked(grid, cix, ciz - 1)
            {
                visited[ni] = true;
                prev[ni] = cur;
                if ni == goal { found = true; break; }
                queue[tail] = ni; tail += 1;
            }
        }
    }

    if !found return 0;

    // Walk backwards from the goal to reconstruct the path (goal -> start)
    cur := goal;
    while cur != start
    {
        gix := cur % BOARD_SIZE;
        giz := cur / BOARD_SIZE;
        out.*[count] = Vector3.{ cell_to_world(gix), 0.0, cell_to_world(giz) };
        count += 1;
        cur = prev[cur];
    }

    // Reverse so the route goes start -> goal
    i := 0;
    j := count - 1;
    while i < j
    {
        tmp := out.*[i];
        out.*[i] = out.*[j];
        out.*[j] = tmp;
        i += 1;
        j -= 1;
    }

    return xx count;
}

line_of_sight :: (grid: BoardGrid, a: Vector3, b: Vector3, radius: float) -> bool
{
    dx := b.x - a.x;
    dz := b.z - a.z;
    dist := sqrt(dx * dx + dz * dz);

    steps := cast(s32) (dist / 0.25) + 1;
    for i : 0 .. steps
    {
        t := cast(float) i / cast(float) steps;
        if board_circle_collides(grid, a.x + dx * t, a.z + dz * t, radius) return false;
    }

    return true;
}

// NOTE: drops waypoints a straight line can skip, so the route has long free-flowing segments instead of a grid staircase.
smooth_path :: (grid: BoardGrid, start_pos: Vector3, out: *[MAX_PATH] Vector3, count: s32, radius: float) -> s32
{
    smoothed: [MAX_PATH] Vector3;
    smoothed_count: s32 = 1;
    smoothed[0] = start_pos;

    anchor := start_pos;
    i: s32 = 0;

    while i < count
    {
        // Farthest remaining waypoint visible in a straight line from the anchor
        j: s32 = count - 1;
        while j > i && !line_of_sight(grid, anchor, out.*[j], radius) { j -= 1; }

        smoothed[smoothed_count] = out.*[j];
        smoothed_count += 1;
        anchor = out.*[j];
        i = j + 1;
    }

    for k : 0 .. smoothed_count - 1
    {
        out.*[k] = smoothed[k];
    }

    return smoothed_count;
}
