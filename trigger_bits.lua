-- trigger bits
-- a binary rhythmbox
-- v1.0 @nattog
--
--
-- - - - - - - - - - - - - - - - -
-- 4x4 slots of decimals
--
-- represented binary
--
-- concatenated into sequences
--
-- - - - - - - - - - - - - - - - -
-- k1 (hold) start/stop
-- k2 change position
-- k3 reset sequence
--
-- e1 change track
-- e2 change decimal
-- e3 change tempo
--
-- k2 (hold) + k3 mute
-- k3 (hold) + k2 rotates track
-- k3 (hold) + e3 probability

engine.name = 'Ack'

local ack = require 'ack/lib/ack'
local BeatClock = require 'beatclock'
local ControlSpec = require 'controlspec'
hs = include 'awake/lib/halfsecond'

local g = grid.connect()

local clk = BeatClock.new()
local clk_midi = midi.connect()
clk_midi.event = function(data)
  clk:process_midi(data)
end

local automatic = 0

-- screen values
local color = 3
local valueColor = color + 5
local number = 0
local screenX = 0
local screenY = 0
local wordFont = 15
local numberFont = 23

-- key setup
local KEY1_hold = false
local KEY2_hold = false
local KEY3_hold = false
local calc_hold = false
local hold_count = 0
local calc_input = {}
local binaryInput = {nil, nil, nil, nil, nil, nil, nil}
local loop = {0, 0, 0, 0}

-- sequence vars
selected = 0
decimal_value = 0
track = 1
local bpm = 120

local playing = false
local reset = false
local positions = {0, 0, 0, 0}
local meta_position = 0
local probs = {100, 100, 100, 100}
local mutes = {0, 0, 0, 0}
rotations = {0, 0, 0, 0}
local track_divs = {1, 1, 1, 1}
local div_options = {'1', '1/2', '1/3', '1/4', '1/6', '1/8', '1/12', '1/16', '1/24', '1/32', '1/48', '1/64'}

function init()
  -- clock setup
  clk.on_step = count
  clk.on_select_internal = function()
    clk:start()
    external = false
  end

  clk.on_select_external = reset_pattern
  external = false

  -- params
  clk:add_clock_params()
  params:add_separator()
  for channel = 1, 4 do
    ack.add_channel_params(channel)
  end
  ack.add_effects_params()

  for i = 1, 4 do
    sequences[i] = generate_sequence(track)
    track = track + 1
  end
  track = 1

  -- hs
  delay = 0
  hs.init()
  params:set('delay', delay)
  grid_redraw()
end

function reset_pattern()
  clk:reset()
  external = true
  positions = {0, 0, 0, 0}
end

function clock_divider(track)
  div = split(div_options[track_divs[track]], '/')
  return tonumber(div[#div])
end

function split(s, delimiter)
  result = {}
  for match in (s .. delimiter):gmatch('(.-)' .. delimiter) do
    table.insert(result, match)
  end
  return result
end

function count()
  local t
  meta_position = meta_position % 16 + 1
  grid_redraw()

  for t = 1, 4 do
    if meta_position % clock_divider(t) == 0 then
      -- wrap sequence
      if positions[t] >= #sequences[t] then
        positions[t] = 0
      end

      -- change position
      positions[t] = (positions[t] + 1)

      -- trigger note
      if sequences[t][positions[t]] == 1 then
        if math.random(100) <= probs[t] and mutes[t] == 0 then
          engine.trig(t - 1)
        end
      end
    end
  end
  redraw()
end

function dec_to_bin(num)
  local total = 0
  local modifier = 0
  local value = ''
  while math.pow(2, modifier) <= num do
    modifier = modifier + 1
  end
  for i = modifier, 1, -1 do
    if math.pow(2, i - 1) + total <= num then
      total = total + math.pow(2, i - 1)
      value = value .. '1'
    else
      value = value .. '0'
    end
  end
  return value
end

sequences = {}
steps = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}

function redraw()
  if delay == 0 then
    screen.clear()
    screen.level(color)
    screen.font_face(wordFont)
    screen.font_size(8)
    screen.move(0, 10)
    screen.text('bpm ')
    screen.level(valueColor)
    if external then
      screen.font_face(1)
      screen.text('ext')
    else
      screen.font_face(numberFont)
      screen.text(params:get('bpm'))
    end

    screen.move(80, 10)
    screen.level(color)
    screen.font_face(wordFont)
    screen.text('track ')
    screen.level(valueColor)
    screen.font_face(numberFont)
    screen.text(track)
    if mutes[track] == 1 then
      screen.font_face(wordFont)
      screen.text('m')
    end
    screen.move(0, 20)
    screen.font_size(6)
    screen.font_face(15)
    screen.level(color)
    position_vis()
    screen.move((rotations[track] + 0.2) * 3.9999, 21)
    screen.text('_')
    screen.font_face(numberFont)
    screen.font_size(8)
    screenY = 32
    screen.move(0, screenY)
    for i = 1, #steps do
      for j = 1, #steps[i] do
        if i == track then
          screen.level(valueColor)
        end
        screen.text(steps[i][j])
        if i == track then
          if j == selected + 1 then
            screen.font_size(6)
            screen.text('*')
            screen.font_size(8)
          end
        end
        screen.level(color)
        screenX = screenX + 20
        screen.move(screenX, screenY)
      end
      screenX = 0
      screenY = screenY + 10
      screen.move(screenX, screenY)
    end
    screen.move(80, 32)
    screen.level(color)
    screen.font_face(wordFont)
    screen.text('div ')
    screen.level(valueColor)
    screen.font_face(numberFont)
    screen.text(div_options[track_divs[track]])
    screen.move(80, 42)
    screen.level(color)
    screen.font_face(wordFont)
    screen.text('prob ')
    screen.level(valueColor)
    screen.font_face(numberFont)
    screen.text(probs[track])
    screen.move(80, 52)
    screen.level(color)
    screen.font_face(wordFont)
    screen.text('binary')
    screen.move(80, 62)
    screen.level(valueColor)
    screen.font_face(numberFont)
    screen.text(dec_to_bin(decimal_value))
    screen.update()
  elseif delay == 1 then
    screen.clear()
    for i = 1, math.random(50) do
      screen.font_face(math.random(40))
      screen.level(math.random(50))
      screen.font_size(math.random(20))
      screenX = math.random(125)
      screenY = math.random(80)
      screen.move(screenX, screenY)
      screen.text('echo')
    end
    screen.update()
  end
end

function position_vis()
  local phase
  if loop[track] > 0 then
    phrase = dec_to_bin(steps[track][loop[track]])
  else
    phrase = binaryString(track)
  end

  -- rotate!!
  local temp = {}
  phrase:gsub(
    '.',
    function(c)
      table.insert(temp, c)
    end
  )
  phrase_rotated = rotate(temp, rotations[track])
  phrase = concatenate_table(phrase_rotated)

  --
  if positions[track] > 0 then
    screen.text(string.sub(phrase, 1, positions[track] - 1))
  end
  screen.level(valueColor)
  screen.text(string.sub(phrase, positions[track], positions[track]))
  screen.level(color)
  screen.text(string.sub(phrase, positions[track] + 1, #phrase))
end

function start()
  playing = true
  clk:start()
end

function stop()
  clk:stop()
  playing = false
  meta_position = 0
  print('stop')
end

function reset_positions()
  meta_position = 0
  positions = {0, 0, 0, 0}
end

function change_selected(inp)
  selected = (selected + inp) % 4
  decimal_value = steps[track][selected + 1]
  calc_binary_input()
  grid_redraw()
end

function key(n, z)
  --key 1 === START/STOP
  if n == 1 and z == 1 and KEY3_hold == false then
    automatic = automatic + 1
    if automatic % 2 == 1 then
      start()
      KEY1_hold = true
    elseif automatic % 2 == 0 then
      KEY1_hold = true
    end
  end

  if n == 1 and z == 0 then
    KEY1_hold = false
  end

  -- reset
  if n == 3 and z == 1 and KEY1_hold == true then
    reset_positions()
  end

  -- stop

  if n == 2 and z == 1 and KEY1_hold == true then
    stop()
    reset_positions()
  end

  --key 2 CHANGE SLOT
  if n == 2 and z == 1 and KEY1_hold == false then
    KEY2_hold = true
    change_selected(z)
  elseif n == 2 and z == 0 then
    KEY2_hold = false
  end

  --key 3 ALT MODE
  if n == 3 and z == 1 then
    KEY3_hold = true
  elseif n == 3 and z == 0 then
    KEY3_hold = false
  end

  -- ROTATE
  if n == 2 and z == 1 and KEY3_hold == true then
    rotations[track] = rotations[track] + 1
    if rotations[track] == #sequences[track] then
      rotations[track] = 0
    end
    sequences[track] = generate_sequence(track)
  end

  -- RESET
  if n == 3 and z == 1 and KEY2_hold == false then
    KEY3_hold = true
  end

  -- MUTE TRACK
  if n == 3 and z == 1 and KEY2_hold == true then
    if mutes[track] == 0 then
      mutes[track] = 1
    elseif mutes[track] == 1 then
      mutes[track] = 0
    end
  end

  redraw()
end

function enc(n, d)
  if delay == 0 then
    -- change track
    if n == 2 and KEY3_hold == false then
      track = track + d
      if track == 0 then
        track = 4
      end
      if track == 5 then
        track = 1
      end
      decimal_value = steps[track][selected + 1]
      calc_binary_input()
    end

    -- change decimal
    if n == 3 then
      if KEY3_hold == false then
        change_decimal(d)
      elseif KEY3_hold == true then
        probs[track] = (probs[track] + d) % 101
      end
    end

    -- change bpm
    if n == 1 then
      params:delta('bpm', d)
    end

    if n == 2 and KEY3_hold == true then
      local div_amt = track_divs[track]
      if div_amt <= #div_options then
        if div_amt == 1 and d == -1 then
          track_divs[track] = 1
        elseif div_amt == 12 and d == 1 then
          track_divs[track] = 12
        else
          track_divs[track] = div_amt + d
        end
      end
    end
    redraw()
    grid_redraw()
  else
    if n == 1 then
      params:delta('delay', d)
    elseif n == 2 then
      params:delta('delay_rate', d)
    elseif n == 3 then
      params:delta('delay_feedback', d)
    end
  end
end

function change_decimal(d)
  decimal_value = ((steps[track][selected + 1] + d) % 256)
  steps[track][selected + 1] = decimal_value
  if loop[track] == 0 then
    sequences[track] = generate_sequence(track)
  end
  calc_binary_input()
  grid_redraw()
end

function calc_binary_input()
  local bin_rep = tostring(dec_to_bin(decimal_value))
  binaryInput = split_str(bin_rep)
end

function loop_on(chan)
  local x
  bin = dec_to_bin(steps[chan][loop[chan]])
  x = tostring(bin)
  sequences[chan] = split_str(x)
  redraw()
end

function loop_off()
  sequences[track] = generate_sequence(track)
  redraw()
end

function binaryString(track)
  local x = ''
  for i = 1, #steps[track] do
    if steps[track][i] ~= nil and steps[track][i] ~= 0 then
      local y = dec_to_bin(steps[track][i])
      x = x .. y
    end
  end
  return x
end

function split_str(str)
  local tab = {}
  for i = 1, string.len(str) do
    tab[i] = tonumber(string.sub(str, i, i))
  end
  return tab
end

function generate_sequence(track)
  local seq_string = binaryString(track)
  local seq_tab = split_str(seq_string)
  local seq_rotates = rotate(seq_tab, rotations[track])
  return seq_rotates
end

function rotate(m, dir)
  if dir > 0 then
    while dir ~= 0 do
      table.insert(m, 1, m[#m])
      table.remove(m, #m)
      dir = dir - 1
    end
  elseif dir < 0 then
    while dir ~= 0 do
      table.insert(m, m[#m], 1)
      table.remove(m, 1)
      dir = dir + 1
    end
  end
  return m
end

function concatenate_table(t)
  local x = ''
  local i
  for i = 1, #t do
    if t[i] ~= nil then
      local y = t[i]
      x = x .. y
    end
  end
  return x
end

local function table_index(t)
  local index = {}
  for k, v in pairs(t) do
    index[v] = k
  end
  return index[1]
end

local function first_index(t)
  local iter
  for iter = 1, #t do
    if t[iter] == 1 then
      return iter
    end
  end
end

local function make_nil(t, ind)
  local iter
  if ind > 1 then
    for iter = 1, ind - 1 do
      t[iter] = nil
    end
  else
    for iter = 1, #t do
      t[iter] = nil
    end
  end
  decimal_value = 0
  calc_binary_input()
  return t
end

local function tally(t)
  local freq = 0
  local iter
  for iter = 1, #t do
    if t[iter] == 1 then
      freq = freq + 1
    end
  end
  return freq
end

function check_nil(t)
  local iter
  for iter = 1, #t do
    if t[iter] ~= nil then
      return false
    end
  end
  return true
end

-- GRID FUNCTIONS

function grid_redraw()
  if g == nil then
    return
  end

  local iter
  -- binary pattern leds
  for iter = 1, 8 do
    if binaryInput[iter] == 1 then
      g:led(iter, 7, 15)
    elseif binaryInput[iter] == 0 then
      g:led(iter, 7, 7)
    elseif binaryInput[iter] == nil then
      g:led(iter, 7, 2)
    elseif iter > #binaryInput then
      g:led(iter, 7, 2)
    end
  end

  local t
  -- sample triggers
  for t = 1, 4 do
    g:led(1, t, 7)
  end

  -- clock indicator
  if meta_position % 4 == 0 then
    g:led(16, 8, 15)
  else
    g:led(16, 8, 5)
  end
  if playing == false then
    g:led(16, 8, 3)
  end

  -- reset
  g:led(16, 7, 5)

  -- track mutes
  local chan
  for chan = 1, 4 do
    if mutes[chan] == 0 then
      g:led(2, chan, 5)
    else
      g:led(2, chan, 15)
    end
  end

  -- delay
  if delay == 0 then
    g:led(11, 8, 3)
  else
    g:led(11, 8, 15)
  end

  -- 4x4 location
  local tr
  for tr = 1, 4 do
    if tr == track then
      g:led(4, tr, 5)
    else
      g:led(4, tr, 0)
    end
  end
  local sel
  for sel = 0, 3 do
    if sel == selected then
      g:led(sel + 5, 5, 5)
    else
      g:led(sel + 5, 5, 0)
    end
  end

  -- 4x4 grid
  local c
  for c = 1, 4 do
    for r = 5, 8 do
      g:led(r, c, 7)
    end
  end

  local y
  for y = 1, 4 do
    if loop[y] > 0 then
      g:led(loop[y] + 4, y, 15)
    end
  end

  -- navigation
  g:led(15, 1, 7)
  g:led(15, 3, 7)
  g:led(14, 2, 7)
  g:led(16, 2, 7)

  -- rotator
  g:led(14, 5, 5)
  g:led(16, 5, 5)

  --  calculator
  local u
  for u = 1, 3 do
    for v = 1, 3 do
      g:led(u + 9, v, 7)
    end
    g:led(11, 4, 7)
  end

  -- calc_hold
  g:led(15, 2, 3)
  g:refresh()
end

g.key = function(x, y, z)
  -- mute track
  if x == 2 and y < 5 and z == 1 then
    if mutes[y] == 0 then
      mutes[y] = 1
    else
      mutes[y] = 0
    end
  end

  -- start/stop
  if x == 16 and y == 8 and z == 1 then
    automatic = automatic + 1
    if playing == false then
      start()
    else
      stop()
    end
  end

  -- reset sequences
  if x == 16 and y == 7 and z == 1 then
    reset_positions()
  end

  -- track/selec nav
  if x == 4 and y < 5 then
    track = y
    decimal_value = steps[track][selected + 1]
    binaryInput = split_str(dec_to_bin(decimal_value))
  end
  if y == 5 and x > 4 and x < 9 then
    selected = x - 5
    decimal_value = steps[track][selected + 1]
    binaryInput = split_str(dec_to_bin(decimal_value))
  end
  -- loop
  if x >= 5 and x < 9 and y < 5 then
    if z == 1 then
      if loop[y] == x - 4 then
        loop[y] = 0
        loop_off(y)
      else
        loop[y] = x - 4
        loop_on(y)
      end
    end
    print('loop track' .. y .. ' = ' .. loop[y])
  end

  -- delay
  if x == 11 and y == 8 then
    if z == 1 then
      delay = 1
      params:set('delay', 0.7)
      params:set('delay_time', (math.random(100)) / 100)
      params:set('delay_feedback', (math.random(100)) / 100)
    else
      delay = 0
      params:set('delay', 0)
    end
    grid_redraw()
    redraw()
  end

  -- turn to nil a binary bit
  if x <= 8 and y == 8 and z == 1 then
    local iter
    for iter = x, #binaryInput do
      binaryInput[iter] = nil
    end
    if check_nil(binaryInput) ~= true then
      binary = concatenate_table(binaryInput)
      steps[track][selected + 1] = tonumber(binary, 2)
      decimal_value = steps[track][selected + 1]
    else
      steps[track][selected + 1] = 0
      decimal_value = 0
    end
    if loop[track] == 0 then
      sequences[track] = generate_sequence(track)
    elseif selected + 1 == loop[track] then
      loop_on(track)
    end
    grid_redraw()
  end

  -- binary input
  if x <= 8 and y == 7 and z == 1 then
    -- if array of nil
    if check_nil(binaryInput) == true then
      binaryInput[x] = 1
      for bina = x + 1, #binaryInput do
        binaryInput[bina] = 0
      end
    else
      local index_1 = table_index(binaryInput)
      if binaryInput[x] == nil or binaryInput[x] == 0 then
        if x < index_1 then
          binaryInput[x] = 1
          local j_iter
          for j_iter = x + 1, index_1 - 1 do
            if binaryInput[j_iter] == nil then
              binaryInput[j_iter] = 0
            end
          end
        elseif x > index_1 then
          binaryInput[x] = 1
          local k_iter
          for k_iter = index_1 + 1, x - 1 do
            if binaryInput[k_iter] == nil then
              binaryInput[k_iter] = 0
            end
          end
        end
      elseif binaryInput[x] == 1 then
        local ind1 = first_index(binaryInput)
        if x == ind1 then
          if tally(binaryInput) == 1 then
            make_nil(binaryInput, ind1)
            decimal_value = 0
          else
            binaryInput[x] = nil
            local indexx = first_index(binaryInput)
            print('new index ' .. indexx)
            local n_iter
            for n_iter = x + 1, indexx - 1 do
              binaryInput[n_iter] = nil
            end
          end
        elseif x > ind1 then
          binaryInput[x] = 0
        end
      end
    end
    local binary = concatenate_table(binaryInput)
    local newNumber = tonumber(binary, 2)
    if newNumber ~= nil then
      steps[track][selected + 1] = newNumber
    else
      steps[track][selected + 1] = 0
    end
    decimal_value = steps[track][selected + 1]
    if loop[track] == 0 then
      sequences[track] = generate_sequence(track)
    elseif selected + 1 == loop[track] then
      loop_on(track)
    end
    g:refresh()
  end

  -- nav
  if x == 15 and y == 1 and z == 1 then
    track = track - z
    if track == 0 then
      track = 4
    end
    decimal_value = steps[track][selected + 1]
    calc_binary_input()
  end
  if x == 15 and y == 3 and z == 1 then
    track = track + z
    if track == 5 then
      track = 1
    end
    decimal_value = steps[track][selected + 1]
    calc_binary_input()
  end
  if x == 14 and y == 2 and z == 1 then
    selected = (selected - z) % 4
    decimal_value = steps[track][selected + 1]
    binaryInput = split_str(dec_to_bin(decimal_value))
  end
  if x == 16 and y == 2 and z == 1 then
    selected = (selected + z) % 4
    decimal_value = steps[track][selected + 1]
    binaryInput = split_str(dec_to_bin(decimal_value))
  end

  if calc_hold == true then
    g:led(15, 2, 15)
  else
    g:led(15, 2, 3)
  end

  -- calculator misc
  if x == 15 and y == 2 then
    print(hold_count)
    if z == 1 then
      hold_count = hold_count + 1
    end
    if hold_count % 2 ~= 0 then
      calc_hold = true
    else
      calc_hold = false
    end
    g:refresh()
  end

  -- calculator
  if z == 1 and x >= 10 and x < 13 and y <= 4 then
    g:led(x, y, 15)
    if x == 10 and y == 4 then
      g:led(x, y, 0)
    else
      if x == 12 and y == 4 then
        g:led(x, y, 0)
      end
      g:refresh()
    end
    if calc_hold == false then
      calc_input = {}
      if y == 4 then
        calc_input[1] = 0
      else
        calc_input[1] = (x - y * 3)
      end
    else
      if calc_hold == true then
        if y == 4 then
          calc_input[#calc_input + 1] = 0
        else
          calc_input[#calc_input + 1] = x - y * 3
        end
      end
    end

    if calc_input[3] ~= nil then
      final_input = calc_input[1] .. calc_input[2] .. calc_input[3]
      g:led(15, 1, 3)
      g:refresh()
      calc_hold = false
      hold_count = 0
    else
      final_input = calc_input[1]
    end
    if tonumber(final_input) > 255 then
      final_input = calc_input[3]
    end
    steps[track][selected + 1] = tonumber(final_input)
    decimal_value = steps[track][selected + 1]
    if loop[track] == 0 then
      sequences[track] = generate_sequence(track)
    elseif selected + 1 == loop[track] then
      loop_on(track)
    end
    calc_binary_input()
    redraw()
  else
    if z == 0 and x >= 10 and x < 13 and y < 5 then
      g:led(x, y, 3)
      if x == 10 and y == 4 then
        g:led(x, y, 0)
      else
        if x == 12 and y == 4 then
          g:led(x, y, 0)
        end
        g:refresh()
      end

    -- print(x,y,z)
    end
  end

  -- rotator
  if x == 14 and y == 5 and z == 1 then
    rotations[track] = rotations[track] - 1
    if rotations[track] == -1 then
      rotations[track] = #sequences[track] - 1
    end
    sequences[track] = generate_sequence(track)
  elseif x == 16 and y == 5 and z == 1 then
    rotations[track] = rotations[track] + 1
    if rotations[track] >= #sequences[track] then
      rotations[track] = 0
    end
    sequences[track] = generate_sequence(track)
  end

  g:refresh()
  grid_redraw()
  redraw()

  -- trigger samples
  if x == 1 and y < 5 then
    if z == 1 then
      engine.trig(y - 1)
      g:led(x, y, 9)
    else
      g:led(x, y, 3)
    end
  end
end

function cleanup()
  clk:stop()
end
