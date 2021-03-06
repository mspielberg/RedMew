-- Map by grilledham & Jayefuu

-- Set scenario generation cliffs to none.
-- Load blueprint from scenarios\RedMew\map_gen\data\presets\tetris\
-- Obtain items using silent commands from scenarios\RedMew\map_gen\data\presets\tetris\
-- Place the blueprint on the island south of spawn
-- Teleport to centre of island and run the second command in tetris_theme_items_command.txt
-- Excellent tetris themed music generated from midi files, credit to mgabor of miditorio.com

local b = require 'map_gen.shared.builders'
local math = require 'utils.math'
local degrees = math.rad
local ore_seed1 = 7000
local ore_seed2 = ore_seed1 * 2

local Random = require 'map_gen.shared.random'
local random = Random.new(ore_seed1, ore_seed2)

local function value(base, mult, pow)
    return function(x, y)
        local d_sq = x * x + y * y
        return base + mult * d_sq ^ (pow / 2) -- d ^ pow
    end
end

-- Removes vanilla resources when called
local function no_resources(x, y, world, tile)
    for _, e in ipairs(
        world.surface.find_entities_filtered(
            {type = 'resource', area = {{world.x, world.y}, {world.x + 1, world.y + 1}}}
        )
    ) do
        e.destroy()
    end
    return tile
end

local names = {
    'biter-spawner',
    'spitter-spawner'
}

-- removes spawners when called
local function no_spawners(x, y, world, tile)
    for _, e in ipairs(
        world.surface.find_entities_filtered(
            {force = 'enemy', name = names, position = {world.x, world.y}}
        )
    ) do
        e.destroy()
    end
    return tile
end

local m_t_width = 12 -- map size in number of tiles
local t_width = 16 -- tile width
local t_h_width = t_width / 2

-- https://wiki.factorio.com/Data.raw#tile for the tile types you can send to this function
local function two_tone_square(inner, outer) -- r_tile is a bool flag to show if it should have chance of resources on it
    local outer_tile = b.any {b.rectangle(t_width, t_width)}
    outer_tile = b.change_tile(outer_tile, true, outer)
    local inner_tile = b.any {b.rectangle(t_width - 2, t_width - 2)}
    inner_tile = b.change_tile(inner_tile, true, inner)
    local land_tile = b.any {inner_tile, outer_tile}

    return land_tile
end

local tet_bounds = b.rectangle(t_width * 4)
tet_bounds = b.translate(tet_bounds, t_width, t_width)
local function tetrify(pattern, block)
    for r = 1, 4 do
        local row = pattern[r]
        for c = 1, 4 do
            if row[c] == 1 then
                row[c] = block
            else
                row[c] = b.empty_shape()
            end
        end
    end
    local grid = b.grid_pattern(pattern, 4, 4, t_width, t_width)
    grid = b.translate(grid, -t_width / 2, -t_width / 2)
    grid = b.choose(tet_bounds, grid, b.empty_shape)
    grid = b.translate(grid, -t_width, -t_width)
    --grid = b.translate(grid, -t_width, t_width * 2)
    return grid
end

local tet_O =
    tetrify(
    {
        {0, 0, 0, 0},
        {0, 1, 1, 0},
        {0, 1, 1, 0},
        {0, 0, 0, 0}
    },
    two_tone_square('dirt-7', 'sand-1')
)

local tet_I =
    tetrify(
    {
        {0, 1, 0, 0},
        {0, 1, 0, 0},
        {0, 1, 0, 0},
        {0, 1, 0, 0}
    },
    two_tone_square('grass-2', 'sand-1')
)

local tet_J =
    tetrify(
    {
        {0, 0, 0, 0},
        {0, 0, 1, 0},
        {0, 0, 1, 0},
        {0, 1, 1, 0}
    },
    two_tone_square('grass-1', 'sand-1')
)

local tet_L =
    tetrify(
    {
        {0, 0, 0, 0},
        {0, 1, 0, 0},
        {0, 1, 0, 0},
        {0, 1, 1, 0}
    },
    two_tone_square('dirt-4', 'sand-1')
)

local tet_S =
    tetrify(
    {
        {0, 0, 0, 0},
        {0, 1, 1, 0},
        {1, 1, 0, 0},
        {0, 0, 0, 0}
    },
    two_tone_square('grass-4', 'sand-1')
)

local tet_Z =
    tetrify(
    {
        {0, 0, 0, 0},
        {1, 1, 0, 0},
        {0, 1, 1, 0},
        {0, 0, 0, 0}
    },
    two_tone_square('grass-3', 'sand-1')
)

local tet_T =
    tetrify(
    {
        {0, 0, 0, 0},
        {0, 1, 0, 0},
        {1, 1, 1, 0},
        {0, 0, 0, 0}
    },
    two_tone_square('red-desert-2', 'sand-1')
)

local tetriminos = {tet_I, tet_O, tet_T, tet_S, tet_Z, tet_J, tet_L}
local tetriminos_count = #tetriminos

local quarter = math.tau / 4

local p_cols = 1 --m_t_width / 4
local p_rows = 50
local pattern = {}

for _ = 1, p_rows do
    local row = {}
    table.insert(pattern, row)
    for _ = 1, p_cols do
        --m_t_width
        --t_width
        -- map_width = m_t_width*t_width
        local i = random:next_int(1, tetriminos_count * 1.5)
        local shape = tetriminos[i] or b.empty_shape

        local angle = random:next_int(0, 3) * quarter
        shape = b.rotate(shape, angle)

        --local y_offset = random:next_int(-2, 2) * t_width
        local x_offset = random:next_int(-10, 8) * t_width
        shape = b.translate(shape, x_offset, 0)

        table.insert(row, shape)
    end
end

local tetriminos_shape = b.grid_pattern(pattern, p_cols, p_rows, t_width * 24, t_width * 4)
tetriminos_shape = b.translate(tetriminos_shape, t_width, -t_width)

local ore_shape = b.rectangle(t_width * 0.8)
local oil_shape = b.throttle_world_xy(ore_shape, 1, 4, 1, 4)

local ores = {
    {b.resource(ore_shape, 'iron-ore', value(250, 0.75, 1.15)), 10},
    {b.resource(ore_shape, 'copper-ore', value(200, 0.75, 1.15)), 6},
    {b.resource(ore_shape, 'stone', value(350, 0.4, 1.075)), 3},
    {b.resource(ore_shape, 'coal', value(200, 0.8, 1.075)), 5},
    {b.resource(b.scale(ore_shape, 0.5), 'uranium-ore', value(300, 0.3, 1.05)), 2},
    {b.resource(oil_shape, 'crude-oil', value(120000, 50, 1.15)), 1},
    {b.empty_shape, 100}
}

local total_weights = {}
local t = 0
for _, v in pairs(ores) do
    t = t + v[2]
    table.insert(total_weights, t)
end

p_cols = 50
p_rows = 50

pattern = {}

for _ = 1, p_rows do
    local row = {}
    table.insert(pattern, row)
    for _ = 1, p_cols do
        local i = random:next_int(1, t)

        local index = table.binary_search(total_weights, i)
        if (index < 0) then
            index = bit32.bnot(index)
        end

        local shape = ores[index][1]
        table.insert(row, shape)
    end
end

local worm_names = {
    'small-worm-turret',
    'medium-worm-turret',
    'big-worm-turret'
}

local max_worm_chance = 1 / 128
local worm_chance_factor = 1 / (192 * 512)

local function worms(_, _, world)
    local wx, wy = world.x, world.y
    local d = math.sqrt(wx * wx + wy * wy)

    local worm_chance = d - 128

    if worm_chance > 0 then
        worm_chance = worm_chance * worm_chance_factor
        worm_chance = math.min(worm_chance, max_worm_chance)

        if math.random() < worm_chance then
            if d < 256 then
                return {name = 'small-worm-turret'}
            else
                local max_lvl
                local min_lvl
                if d < 512 then
                    max_lvl = 2
                    min_lvl = 1
                else
                    max_lvl = 3
                    min_lvl = 2
                end
                local lvl = math.random() ^ (512 / d) * max_lvl
                lvl = math.ceil(lvl)
                lvl = math.clamp(lvl, min_lvl, 3)
                return {name = worm_names[lvl]}
            end
        end
    end
end

-- Starting area
local start_patch = b.rectangle(t_width * 0.8)
    local start_iron_patch =
        b.resource(
        b.translate(start_patch, -t_width/2, -t_width/2),
        'iron-ore',
        function()
            return 1500
        end
    )
    local start_copper_patch =
        b.resource(
        b.translate(start_patch, t_width/2, -t_width/2),
        'copper-ore',
        function()
            return 1200
        end
    )
    local start_stone_patch =
        b.resource(
        b.translate(start_patch, t_width/2, t_width/2),
        'stone',
        function()
            return 900
        end
    )
    local start_coal_patch =
        b.resource(
        b.translate(start_patch, -t_width/2, t_width/2),
        'coal',
        function()
            return 1350
        end
    )
local start_resources = b.any({start_iron_patch, start_copper_patch, start_stone_patch, start_coal_patch})
local tet_O_start = b.apply_entity(tet_O, start_resources)

local starting_area = b.any{
    b.translate(tet_I,t_width,-t_width*2),
    b.translate(tet_O_start,t_width*2,-t_width),
    b.translate(tet_T,-t_width,-t_width),
    b.translate(tet_Z,-t_width*6,-t_width),
    b.translate(tet_L,-t_width*8,-t_width*2)
}

tetriminos_shape = b.any{tetriminos_shape, starting_area}
ores = b.grid_pattern_overlap(pattern, p_cols, p_rows, t_width, t_width)
ores = b.translate(ores, t_h_width, t_h_width)

tetriminos_shape = b.apply_entity(tetriminos_shape, ores)           -- add ores to tetriminoes
tetriminos_shape = b.apply_effect(tetriminos_shape, no_spawners)    -- remove spawners to help pathing
tetriminos_shape = b.apply_entity(tetriminos_shape, worms)          -- add worms

local water_tile = two_tone_square('water', 'deepwater')
local half_sea_width = m_t_width * t_width - t_width
local function sea_bounds(x, y)
    return x > -half_sea_width and x < half_sea_width and y < 0
end

local sea = b.single_grid_pattern(water_tile, t_width, t_width)
sea = b.translate(sea, t_h_width, -t_h_width)
sea = b.choose(sea_bounds, sea, b.empty_shape)

local map = b.choose(sea_bounds, tetriminos_shape, b.empty_shape)
map = b.if_else(map, sea)

local half_border_width = half_sea_width + t_width
local function border_bounds(x, y)
    return x > -half_border_width and x < half_border_width and y < t_width
end

border_bounds = b.subtract(border_bounds, sea_bounds)
local border = b.change_tile(border_bounds, true, 'sand-1')
map = b.add(map, border)
local music_island = b.translate(b.rotate(tet_I,degrees(90)),0, 2*t_width)
map = b.add(map,music_island)
map = b.translate(map, 0, -t_width / 2)


map = b.apply_effect(map, no_resources)

return map
