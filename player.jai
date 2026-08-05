Player :: struct
{
    position: Vector3;
    target: Vector3;
    has_target: bool;
    speed: float = 2.5;
    radius: float = 0.35;   // collision radius on the ground plane
    height: float = 1.0;
    path: [MAX_PATH] Vector3;   // planned route (cell-center waypoints)
    path_count: s32;
    path_index: s32;
    
    pattern: Card_Pattern;
    pattern_mesh: Mesh;
    pattern_model: Model;
    pattern_texture: Texture2D;

    hp: s32 = 3;
    freeze_time: float = 0.0; 
}

player_make :: (spawn: Vector3) -> Player
{
    player: Player;
    player.position = spawn;
    player.pattern_mesh = GenMeshPlane(2.5, 2.5, 1, 1);
    player.pattern_model = LoadModelFromMesh(player.pattern_mesh);
    return player;
}

find_nearest_walkable :: (grid: BoardGrid, ix: s32, iz: s32, max_radius: s32) -> s32, s32
{
    for r : 0 .. max_radius
    {
        for oi : -r .. r
        {
            for oj : -r .. r
            {
                if abs(oi) != r && abs(oj) != r continue;   // only the ring cells
                nx := ix + oi;
                nz := iz + oj;
                if nx < 0 || nx >= BOARD_SIZE || nz < 0 || nz >= BOARD_SIZE continue;
                if !board_cell_blocked(grid, nx, nz) return nx, nz;
            }
        }
    }
    return ix, iz; // fallback: keep the original cell
}

player_set_target :: (player: *Player, grid: BoardGrid, target: Vector3)
{
    // Snap the clicked point to a walkable cell in case it landed on a wall
    tx := world_to_cell(target.x);
    tz := world_to_cell(target.z);
    (tx, tz) = find_nearest_walkable(grid, tx, tz, 8);

    sx := world_to_cell(player.position.x);
    sz := world_to_cell(player.position.z);

    player.path_count = path_find(grid, sx, sz, tx, tz, *player.path);
    if player.path_count == 0
    {
        player.has_target = false;
        return;
    }

    player.path_count = smooth_path(grid, player.position, *player.path, player.path_count, player.radius);

    goal_center := player.path[player.path_count - 1];
    anchor := player.position;
    if player.path_count >= 2 anchor = player.path[player.path_count - 2];
    final_stop := target;
    if !line_of_sight(grid, anchor, target, player.radius)
    {
        final_stop = goal_center;
    }
    player.path[player.path_count - 1] = Vector3.{ final_stop.x, 0.0, final_stop.z };

    player.path_index = 0;
    player.target = player.path[player.path_count - 1];
    player.has_target = true;
}

player_update :: (player: *Player, dt: float)
{
    if player.freeze_time > 0.0 return;   // frozen by a trap
    if !player.has_target return;

    step := player.speed * dt;

    while step > 0.0 && player.path_index < player.path_count
    {
        waypoint := player.path[player.path_index];
        dx := waypoint.x - player.position.x;
        dz := waypoint.z - player.position.z;
        dist := sqrt(dx * dx + dz * dz);

        if dist < 0.001
        {
            player.path_index += 1;
            continue;
        }

        if step >= dist
        {
            player.position.x = waypoint.x;
            player.position.z = waypoint.z;
            step -= dist;
            player.path_index += 1;
        }
        else
        {
            player.position.x += dx / dist * step;
            player.position.z += dz / dist * step;
            step = 0.0;
        }
    }

    if player.path_index >= player.path_count
    {
        player.has_target = false;
    }
}

player_set_target_from_ray :: (player: *Player, grid: BoardGrid, ray: Ray) -> bool
{
    denom := ray.direction.y;
    if abs(denom) < 0.0001 return false;   // ray is parallel to the ground

    t := -ray.position.y / denom;
    if t <= 0.0 return false;

    hit_x := ray.position.x + ray.direction.x * t;
    hit_z := ray.position.z + ray.direction.z * t;

    // Ignore clicks outside the board
    if abs(hit_x) > BOARD_HALF || abs(hit_z) > BOARD_HALF return false;

    player_set_target(player, grid, Vector3.{ hit_x, 0.0, hit_z });
    return true;
}

player_draw :: (player: Player)
{   
    if player.freeze_time > 0.0
    {
        DrawCube(player.position, 0.8, player.height, 0.8, PURPLE);
        DrawCubeWires(player.position, 0.8, player.height, 0.8, DARKBLUE);
    }
    else
    {
        DrawCube(player.position, 0.8, player.height, 0.8, BLUE);
        DrawCubeWires(player.position, 0.8, player.height, 0.8, DARKBLUE);
    }
    
    BeginBlendMode(.BLEND_ALPHA_PREMULTIPLY);
    DrawModel(player.pattern_model, .{player.position.x, player.position.y-0.49, player.position.z}, 1.0, WHITE);
    EndBlendMode();

    if player.has_target
    {
        // Draw the planned route so it's clear where the player is going for debug purpose
        prev := player.position;
        for i : 0 .. player.path_count - 1
        {
            w := player.path[i];
            DrawLine3D(prev, w, SKYBLUE);
            prev = w;
        }
        DrawSphere(player.target, 0.18, GREEN);
    }
}
