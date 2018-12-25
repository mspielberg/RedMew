local Event = require 'utils.event'
local Token = require 'utils.token'
local Task = require 'utils.schedule'
local Global = require 'utils.global'
local Game = require 'utils.game'
local Debug = require 'utils.debug'
local Map = require 'map_gen.combined.tetris.shape'
local Tetrimino = require 'map_gen.combined.tetris.tetrimino'(Map)
local View = require 'map_gen.combined.tetris.view'
local InfinityChest = require 'map_gen.misc.infinite_storage_chest'
local states = require 'map_gen.combined.tetris.states'
local machine = require 'map_gen.combined.tetris.machine'


local tetriminos = {}

primitives = {
    tetri_spawn_y_position = -160,
    winner_option_index = 0,
    state = states.voting,
    next_vote_finished = 305,
    points = 0,
    down_substate = 0,
    stale_vote_turns = 0
}
local player_votes = {}
local options = {
    {
        button = View.button_enum.ccw_button,
        action_func_name = 'rotate',
        args = {false},
        transition = states.moving,
    },{
        button = View.button_enum.cw_button,
        action_func_name = 'rotate',
        args = {true},
        transition = states.moving,
    },{
        button = View.button_enum.left_button,
        action_func_name = 'move',
        args = {-1, 0},
        transition = states.moving,
    },{
        button = View.button_enum.down_button,
        transition = states.down,
    },{
        button = View.button_enum.right_button,
        action_func_name = 'move',
        args = {1, 0},
        transition = states.moving,
    },
}

local player_zoom = {}
Global.register(
    {
        tetriminos = tetriminos,
        primitives = primitives,
        player_votes = player_votes,
        player_zoom = player_zoom,
    },
    function(tbl)
        tetriminos = tbl.tetriminos
        primitives = tbl.primitives
        player_votes = tbl.player_votes
        player_zoom = tbl.player_zoom
    end
)

local point_table = {1, 3, 5, 8}
local tetris_tick_duration = 61 --ttick = tetris tick
local pause_after_n_ticks = 10
global.vote_delay = 10

local function calculate_winner()
    if machine.is_in(states.down) then --TODO: Fix
        return --Halt vote if in down mode
    end
    local vote_sum = {0,0,0,0,0}
    for _, vote in pairs(player_votes) do
        vote_sum[vote] = vote_sum[vote] + 1
    end

    local winners = {}
    local max = math.max(vote_sum[1], vote_sum[2], vote_sum[3], vote_sum[4], vote_sum[5])
    if max == 0 then
        Debug.print('No votes')
        return
    end
    for candidate, n_votes in ipairs(vote_sum) do
        if max == n_votes then
            table.insert(winners, candidate)
        end
    end
    local winner_option_index = winners[math.random(#winners)]
    primitives.winner_option_index = winner_option_index
    Debug.print('Calculated winner: ' .. winner_option_index)
end

local function player_vote(player, option_index)

    local old_vote = player_votes[player.index]
    if old_vote == option_index then 
        return 
    end
    local vote_button = nil
    local old_vote_button = nil

    if option_index then
        vote_button = options[option_index].button
    end

    if old_vote then
        old_vote_button = options[old_vote].button
    end

    player_votes[player.index] = option_index

    View.set_player_vote(player, vote_button, old_vote_button)

    Debug.print(string.format('%s voted for %s', player.name, vote_button))

    machine.transition(states.voting)

    calculate_winner()
end

for option_index, option in pairs(options) do
    View.bind_button(
        option.button,
        function(player)
            player_vote(player, option_index)
        end
    )
end
View.bind_button(
    View.button_enum.clear_button,
    function(player)
        Debug.print('clear')

        player_vote(player, nil) -- Clear player vote

        Debug.print('clear')
        local old_vote = player_votes[player.index]
        if old_vote then
            old_vote_button = options[old_vote].button
        end
        View.set_player_vote(player, nil, old_vote_button)
    end
)

View.bind_button(
    View.button_enum.zoom_button,
    function(player)
        local zoom = player_zoom[player.index] or 1
        if zoom == 1 then
            zoom = 0.13
        else
            zoom = 1
        end
        player.zoom = zoom
        player_zoom[player.index] = zoom
    end
)

local function spawn_new_tetrimino()
    table.insert(tetriminos, Tetrimino.new(game.surfaces.nauvis, {x = 0, y = primitives.tetri_spawn_y_position}))
end

local function collect_full_row_resources(tetri)

    local active_qchunks = Tetrimino.active_qchunks(tetri)
    local storage = {}

    local full_rows = {}
    local rows = {}
    for _, qchunk in ipairs(active_qchunks) do
        local q_y = qchunk.y
        if not rows[q_y] then
            rows[q_y] = true
            local y = tetri.position.y + 16 * q_y - 14
            local row_full = true
            for x = -178, 178, 16 do
                local tile = tetri.surface.get_tile(x, y)
                if tile.valid and tile.name == 'water' then
                    row_full = false
                    break
                end
            end

            if row_full then
                table.insert(full_rows, q_y)
                for _, patch in pairs(tetri.surface.find_entities_filtered{type = 'resource', area = {{-178, y}, {162, y + 12}}}) do
                    local total = storage[patch.name] or 0
                    storage[patch.name] = total + patch.amount
                    patch.destroy()
                end
            end
        end
    end

    if #full_rows > 0 then
        local points = point_table[#full_rows]

        for resource, amount in pairs(storage) do
            storage[resource] = amount * points
            if resource =='crude-oil' then
                storage[resource] = nil
                if #full_rows == 1 then
                    return
                end
            end
        end

        local x = tetri.position.x + active_qchunks[1].x * 16 - 9
        local y = tetri.position.y + active_qchunks[1].y * 16 - 9
        InfinityChest.create_chest(tetri.surface, {x, y}, storage)

        primitives.points = primitives.points + points * 100

        View.set_points(primitives.points)
    end
end

local function tetrimino_finished(tetri)
    local final_y_position = tetri.position.y
    if final_y_position < (primitives.tetri_spawn_y_position + 352) then
        primitives.tetri_spawn_y_position = final_y_position - 256
        game.forces.player.chart(tetri.surface, {{-192, final_y_position - 352},{160, final_y_position - 176}})
    end

    machine.transition(states.voting)

    collect_full_row_resources(tetri)

    spawn_new_tetrimino()
end

chart_area = Token.register(
    function(data)
        data.force.chart(data.surface, data.area)
    end
)

local switch_state = Token.register(
    function(data)
        machine.transition(data.state)
    end
)

local move_down = Token.register(
    function()
        for key, tetri in pairs(tetriminos) do
            if not Tetrimino.move(tetri, 0, 1) then
                tetrimino_finished(tetri) --If collided with ground fire finished event
                tetriminos[key] = nil
            end

            local pos = tetri.position
            Task.set_timeout_in_ticks(10, chart_area, {
                force = game.forces.player,
                surface = game.surfaces.nauvis,
                area = {
                    {pos.x - 32, pos.y - 32},
                    {pos.x + 64, pos.y + 64}
                }
            })
        end
    end
)

local function execute_vote_tick()

    if game.tick < primitives.next_vote_finished then return end

    Debug.print('Vote finalized')

    for key, tetri in pairs(tetriminos) do
        local winner = options[primitives.winner_option_index]
        if winner then
            machine.transition(winner.transition)
            primitives.stale_vote_turns = 0
        else 
            stale_vote_turns = primitives.stale_vote_turns
            if stale_vote_turns >= pause_after_n_ticks then
                machine.transition(states.pause)
            else 
                primitives.stale_vote_turns = stale_vote_turns + 1
            machine.transition(states.moving)
            end
        end
    end

    primitives.winner_option_index = 0
    for player_index, _ in ipairs(player_votes) do -- reset poll
        player_votes[player_index] = nil
    end
    View.reset_poll_buttons()
end

function execute_winner_action()
    for key, tetri in pairs(tetriminos) do --Execute voted action
        local winner = options[primitives.winner_option_index]
        --Execute voted action
        if winner then
            local action = Tetrimino[winner.action_func_name]
            if action then
                action(tetri, winner.args[1], winner.args[2])
            end
        end
    end

    Task.set_timeout_in_ticks(16, move_down)
    Task.set_timeout_in_ticks(26, switch_state, {state = states.voting})
end



spawn_new_tetrimino_token = Token.register(spawn_new_tetrimino)
Event.on_init(function()
    game.forces.player.chart(game.surfaces.nauvis, {{-192, -432}, {160, 0}})
    Task.set_timeout_in_ticks(2 * tetris_tick_duration - 15, spawn_new_tetrimino_token)
    View.enable_vote_buttons(true)
end)

Event.add(defines.events.on_tick, function(event)

    if machine.is_in(states.voting) then 
        local progress = (primitives.next_vote_finished - game.tick + 1)  / global.vote_delay / tetris_tick_duration
        if progress >= 0 and progress <= 1 then 
            View.set_progress(progress)
        else 
            Debug.print('Progress out of bounds: ' .. progress)
        end
    end
end)

local function execute_down_tick()
    local down_state = primitives.down_substate

    if down_state > 3 then 
        primitives.down_substate = 1
        machine.transition(states.voting)
        return
    end

    primitives.down_substate = down_state + 1

    Task.set_timeout_in_ticks(16, move_down)
end

machine.register_state_tick_action(states.voting, execute_vote_tick)

machine.register_state_tick_action(states.down, execute_down_tick)

machine.register_transition(states.moving, states.voting, function()
    View.enable_vote_buttons(true)
end)

machine.register_transition(states.down, states.voting, function()
    View.enable_vote_buttons(true)
end)

machine.register_transition(states.voting, states.down, function()
    primitives.next_vote_finished = (3 + global.vote_delay) * tetris_tick_duration + game.tick
    View.enable_vote_buttons(false)
end)

machine.register_transition(states.voting, states.moving, function()
    execute_winner_action()
    primitives.next_vote_finished = global.vote_delay * tetris_tick_duration + game.tick
    View.enable_vote_buttons(false)
end)

Event.on_nth_tick(tetris_tick_duration, machine.tick)

Event.add(defines.events.on_player_left_game, function(event)
    player_votes[event.player_index] = nil
end)

Event.add(defines.events.on_player_created, function(event)
    local player = Game.get_player_by_index(event.player_index)
    player.teleport{8,8}
end)
return Map.get_map()