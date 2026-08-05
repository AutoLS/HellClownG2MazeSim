// NOTE: Grid-based collision for the card-wall maze drawn in main.jai. The board is 32x32 cells (each 1 unit), centered at the origin: cell (ix, iz) covers x in [ix-16, ix-15),  z in [iz-16, iz-15)

BOARD_SIZE :: 32;
BOARD_HALF :: 16;

BoardGrid :: struct
{
    walls: [BOARD_SIZE * BOARD_SIZE] bool;
}

world_to_cell :: (v: float) -> s32
{
    return cast(s32) floor(v + BOARD_HALF);
}

board_mark_wall :: (grid: *BoardGrid, x: float, z: float)
{
    ix := world_to_cell(x);
    iz := world_to_cell(z);

    if ix >= 0 && ix < BOARD_SIZE && iz >= 0 && iz < BOARD_SIZE
    {
        grid.walls[iz * BOARD_SIZE + ix] = true;
    }
}

board_cell_blocked :: (grid: BoardGrid, ix: s32, iz: s32) -> bool
{
    if ix < 0 || ix >= BOARD_SIZE || iz < 0 || iz >= BOARD_SIZE return true;
    return grid.walls[iz * BOARD_SIZE + ix];
}

board_circle_collides :: (grid: BoardGrid, x: float, z: float, radius: float) -> bool
{
    x0 := world_to_cell(x - radius);
    x1 := world_to_cell(x + radius - 0.0001); // small epsilon avoids false hits on cell borders
    z0 := world_to_cell(z - radius);
    z1 := world_to_cell(z + radius - 0.0001);

    for iz : z0 .. z1
    {
        for ix : x0 .. x1
        {
            if board_cell_blocked(grid, ix, iz) return true;
        }
    }

    return false;
}

// NOTE: The maze is made of 2x2 card blocks placed every 4 cells. Four blocks are missing one card to carve openings. Returns whether the card at corner (dx, dz) of block (i, j) is present.
card_present :: (i: int, j: int, dx: int, dz: int) -> bool
{
    if i == 3 && j == 2 && dx == 1 && dz == 1 return false;
    if i == 4 && j == 2 && dx == 0 && dz == 1 return false;
    if i == 3 && j == 3 && dx == 1 && dz == 0 return false;
    if i == 4 && j == 3 && dx == 0 && dz == 0 return false;
    return true;
}

card_is_center :: (i: int, j: int) -> bool
{
    return (i == 3 || i == 4) && (j == 2 || j == 3);
}

board_build_grid :: () -> BoardGrid
{
    grid: BoardGrid;
    for *w : grid.walls { << w = false; }

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
                    if card_present(i, j, dx, dz)
                    {
                        board_mark_wall(*grid, bx + cast(float) dx, bz + cast(float) dz);
                    }
                }
            }
        }
    }

    return grid;
}
