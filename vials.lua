-- vials
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
-- k1 (hold) start
-- if playing hold k1 for
-- PATTERN ALT
--
-- k2 change position
-- k3 (hold) TRACK ALT
--
-- e1 change tempo
-- e2 change track
-- e3 change decimal
--
-- k1 (hold) + k2 stops
-- k1 (hold) + k3 resets
-- k2 (hold) + k3 mute
-- k3 (hold) + k2 rotates binary sequence
-- k3 (hold) + e3 probability
--
--
-- GRID (top-left clockwise)
--
-- sample triggers
-- track mutes
-- reverb sends (y5 kill all)
--
-- 4x4 segment looper
-- nav to left and below
--
-- phone pad decimal input
--
-- track and segment navigation
-- hold centre after first entry
-- from phone pad for XX, XXX
--
-- rotate sequence left or right
--
-- reset all tracks to 0
-- play/stop
--
-- >>FX SECTION<<
-- above = reverb
-- rev level
-- random short
-- random mid
-- random long
-- enc edit view - HOLD
-- level, size, damp
-- controlled by encs 1,2,3
--
-- below = echo
-- echo in
-- echo edit view - HOLD
-- level, rate and fbk
-- controlled by encs 1,2,3
-- randomise echo
-- kill echo
--
-- binary input x1-x8, y7
-- row below makes nil
-- whats above
--
-- bug reports to @nattog
-- thanks!
--

engine.name = "Ack"

ack = require "ack/lib/ack"
local BeatClock = require "beatclock"
local ControlSpec = require "controlspec"
hs = include "awake/lib/halfsecond"

local g = grid.connect()

local clk = BeatClock.new()
local m = midi.connect()
m.event = function(data)
  clk:process_midi(data)
end
-- screen values
local color = 3
local value_color = color + 5
local number = 0
local screen_x = 0
local screen_y = 0
local word_font = 1
local number_font = 23

-- key setup
local key1_hold = false
local key2_hold = false
local key3_hold = false
local calc_hold = false
local calc_input = {}
local binary_input = {nil, nil, nil, nil, nil, nil, nil}
local loop = {0, 0, 0, 0}

-- sequence vars
local selected = 0
local decimal_value = 0
track = 1
local bpm = 120

local playing = false
local reset = false
local positions = {0, 0, 0, 0}
local meta_position = 0
local probs = {100, 100, 100, 100}
local mutes = {0, 0, 0, 0}
local rotations = {0, 0, 0, 0}
local track_divs = {1, 1, 1, 1}
local div_options = {1, 2, 3, 4, 6, 8, 12, 16}
sequences = {}
local steps = {{0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}, {0, 0, 0, 0}}

local delay_view = false
local delay_in = true

local reverb_view = false

local function start()
  playing = true
  just_started = true
  clk:start()
end

local function note_off()
  if params:get("send_midi") == 1 then
    local i
    for i = 1, 127 do
      m:note_off(i)
    end
  end
end

local function stop()
  clk:stop()
  playing = false
  local i
  note_off()
  meta_position = 0
  print("stop")
  vials_save()
end

local function reset_pattern()
  clk:reset()
  external = true
  positions = {0, 0, 0, 0}
  meta_position = 0
  note_off()
end

local function reset_positions()
  meta_position = 0
  just_started = true
  positions = {0, 0, 0, 0}
  note_off()
end

local function split(s, delimiter)
  result = {}
  for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
    table.insert(result, match)
  end
  return result
end

local function clock_divider(track)
  div = div_options[track_divs[track]]
  return div
end

local function rotate(m, dir)
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

function count()
  local t
  meta_position = (meta_position % 16) + 1
  grid_redraw()
  note_off()
  local divs = {}
  for t = 1, 4 do
    divs[t] = clock_divider(t)
  end
  for t = 1, 4 do
    local counter = meta_position % divs[t]
    if (counter > 0 and just_started) or counter == 0 then
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
          if params:get("send_midi") == 1 then
            m:note_on(params:get(t .. ":_midi_note"), 100, params:get("midi_chan"))
          end
        end
      end
      if params:get("send_midi") == 1 then
        m:note_off(params:get(t .. ":_midi_note"), 100, params:get("midi_chan"))
      end
    end
  end
  if not delay_view then
    redraw()
  end
  just_started = false
end

local function dec_to_bin(num)
  local total = 0
  local modifier = 0
  local value = ""
  while math.pow(2, modifier) <= num do
    modifier = modifier + 1
  end
  for i = modifier, 1, -1 do
    if math.pow(2, i - 1) + total <= num then
      total = total + math.pow(2, i - 1)
      value = value .. "1"
    else
      value = value .. "0"
    end
  end
  return value
end

local function binary_string(track)
  local x = ""
  for i = 1, #steps[track] do
    if steps[track][i] ~= nil and steps[track][i] ~= 0 then
      local y = dec_to_bin(steps[track][i])
      x = x .. y
    end
  end
  return x
end

local function split_str(str)
  local tab = {}
  for i = 1, string.len(str) do
    tab[i] = tonumber(string.sub(str, i, i))
  end
  return tab
end

local function calc_binary_input()
  local bin_rep = tostring(dec_to_bin(decimal_value))
  binary_input = split_str(bin_rep)
end

local function loop_on(chan)
  local x
  bin = dec_to_bin(steps[chan][loop[chan]])
  if rotations[track] > #bin then
    rotations[track] = 0
  end
  x = tostring(bin)
  sequences[chan] = split_str(x)
  redraw()
end

function generate_sequence(track)
  local seq_string = binary_string(track)
  local seq_tab
  if loop[track] == 0 then
    seq_tab = split_str(seq_string)
  else
    local x = dec_to_bin(steps[track][loop[track]])
    seq_tab = split_str(x)
  end
  local seq_rotates = rotate(seq_tab, rotations[track])
  return seq_rotates
end

local function change_focus()
  decimal_value = steps[track][selected + 1]
  calc_binary_input()
  calc_input = {}
end

local function loop_off()
  sequences[track] = generate_sequence(track)
  redraw()
end

function change_selected(inp)
  selected = (selected + inp) % 4
  change_focus()
  grid_redraw()
end

function change_decimal(d)
  decimal_value = ((steps[track][selected + 1] + d) % 256)
  steps[track][selected + 1] = decimal_value
  if loop[track] == 0 then
    sequences[track] = generate_sequence(track)
  elseif loop[track] == selected + 1 then
    loop_on(track)
  end
  calc_binary_input()
  grid_redraw()
end

local function concatenate_table(t)
  local x = ""
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

local function check_nil(t)
  local iter
  for iter = 1, #t do
    if t[iter] ~= nil then
      return false
    end
  end
  return true
end

local function position_vis()
  local phase
  if loop[track] > 0 then
    phrase = dec_to_bin(steps[track][loop[track]])
  else
    phrase = binary_string(track)
  end

  -- rotate!!
  local temp = {}
  phrase:gsub(
    ".",
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
  screen.level(value_color)
  screen.text(string.sub(phrase, positions[track], positions[track]))
  screen.level(color)
  screen.text(string.sub(phrase, positions[track] + 1, #phrase))
end

function redraw()
  if not delay_view and not reverb_view then
    screen.clear()
    screen.level(color)
    screen.font_face(word_font)
    screen.font_size(8)
    screen.move(0, 10)
    screen.text("bpm ")
    screen.level(value_color)
    if external then
      screen.font_face(1)
      screen.text("ext")
    else
      screen.font_face(number_font)
      screen.text(params:get("bpm"))
    end

    screen.move(80, 10)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("track ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(track)
    if mutes[track] == 1 then
      screen.font_face(word_font)
      screen.text("m")
    end
    screen.move(0, 20)
    screen.font_size(6)
    screen.font_face(15)
    screen.level(color)
    position_vis()
    screen.move((rotations[track] + 0.2) * 3.9999, 21)
    screen.text("_")
    screen.font_face(number_font)
    screen.font_size(8)
    screen_y = 32
    screen.move(0, screen_y)
    for i = 1, #steps do
      for j = 1, #steps[i] do
        if i == track then
          screen.level(value_color)
        end
        screen.text(steps[i][j])
        if i == track then
          if j == selected + 1 then
            screen.font_size(6)
            screen.text("*")
            screen.font_size(8)
          end
        end
        screen.level(color)
        screen_x = screen_x + 20
        screen.move(screen_x, screen_y)
      end
      screen_x = 0
      screen_y = screen_y + 10
      screen.move(screen_x, screen_y)
    end
    screen.move(80, 32)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("div ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(div_options[track_divs[track]])
    screen.move(80, 42)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("prob ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(probs[track])
    screen.font_face(word_font)
    screen.text("%")
    screen.move(80, 52)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("binary")
    screen.move(80, 62)
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(dec_to_bin(decimal_value))
    screen.update()
  elseif delay_view then
    screen.clear()
    screen_x = (15 * params:get("delay_rate"))
    screen_y = 10
    screenL = math.ceil(params:get("delay") * 10) + 3
    for i = 1, (params:get("delay_feedback") * 40) + 1 do
      screen.font_face(11)
      screen.level(screenL)
      screen.font_size(15)
      screen.move(screen_x, screen_y)
      screen.text("e c h o ")
      screen_x = screen_x + 10
      screen_y = screen_y + 12 * params:get("delay_rate")
      if screenL > 0 then
        screenL = screenL - 1
      end
    end
    screen.update()
  elseif reverb_view then
    screen.clear()
    screen.line_width(2)
    screen.level(15 - (math.ceil(params:get("reverb_damp") * 15)))
    screen.rect(0, 80, params:get("reverb_room_size") * 125, -80 - params:get("reverb_level"))
    screen.fill()
    screen.update()
  end
end

function key(n, z)
  --key 1 === START/STOP
  if n == 1 and z == 1 then
    key1_hold = true
    if not playing then
      start()
    end
  end

  if n == 1 and z == 0 then
    key1_hold = false
  end

  -- reset
  if n == 3 and z == 1 and key1_hold then
    reset_positions()
  end

  -- stop

  if n == 2 and z == 1 and key1_hold then
    stop()
    reset_positions()
  end

  --key 2 CHANGE SLOT
  if n == 2 and z == 1 and not key1_hold and not key3_hold then
    key2_hold = true
    change_selected(z)
  elseif n == 2 and z == 0 then
    key2_hold = false
  end

  --key 3 ALT MODE
  if n == 3 and z == 1 then
    key3_hold = true
  elseif n == 3 and z == 0 then
    key3_hold = false
  end

  -- ROTATE
  if n == 2 and z == 1 and key3_hold then
    rotations[track] = rotations[track] + 1
    if loop[track] > 0 then
      if rotations[track] >= #dec_to_bin(steps[track][loop[track]]) then
        rotations[track] = 0
      end
    else
      if rotations[track] >= #(sequences[track]) then
        rotations[track] = 0
      end
    end
    sequences[track] = generate_sequence(track)
  end

  -- RESET
  if n == 3 and z == 1 and not key2_hold then
    key3_hold = true
  end

  -- MUTE TRACK
  if n == 3 and z == 1 and key2_hold then
    if mutes[track] == 0 then
      mutes[track] = 1
    elseif mutes[track] == 1 then
      mutes[track] = 0
    end
  end

  redraw()
end

function enc(n, d)
  if not delay_view and not reverb_view then
    -- change track
    if n == 2 and not key3_hold then
      track = track + d
      if track == 0 then
        track = 4
      end
      if track == 5 then
        track = 1
      end
      change_focus()
    end

    -- change decimal
    if n == 3 then
      if not key3_hold then
        change_decimal(d)
      elseif key3_hold then
        probs[track] = (probs[track] + d) % 101
      end
    end

    -- change bpm
    if n == 1 then
      params:delta("bpm", d)
    end

    if n == 2 and key3_hold then
      local div_amt = track_divs[track]
      if div_amt <= #div_options then
        if div_amt == 1 and d == -1 then
          track_divs[track] = 1
        elseif div_amt == 8 and d == 1 then
          track_divs[track] = 8
        else
          track_divs[track] = div_amt + d
        end
      end
    end
    redraw()
    grid_redraw()
  elseif delay_view then
    if n == 1 then
      params:delta("delay", d)
    elseif n == 2 then
      params:delta("delay_rate", d)
    elseif n == 3 then
      params:delta("delay_feedback", d)
    end
    redraw()
  elseif reverb_view then
    if n == 1 then
      params:delta("reverb_level", d)
    elseif n == 2 then
      params:delta("reverb_room_size", d)
    elseif n == 3 then
      params:delta("reverb_damp", d)
    end
    redraw()
  end
end

-- GRID FUNCTIONS

function grid_redraw()
  if g == nil then
    return
  end

  local iter
  -- binary pattern leds
  for iter = 1, 8 do
    if binary_input[iter] == 1 then
      g:led(iter, 7, 15)
    elseif binary_input[iter] == 0 then
      g:led(iter, 7, 7)
    elseif binary_input[iter] == nil then
      g:led(iter, 7, 2)
    elseif iter > #binary_input then
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
  if not playing then
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
  if not delay_view then
    g:led(11, 8, 3)
  else
    g:led(11, 8, 15)
  end
  if delay_in then
    g:led(10, 8, 15)
  else
    g:led(10, 8, 3)
  end
  g:led(12, 8, 3)
  g:led(13, 8, 3)

  -- reverb
  g:led(10, 7, 3)
  g:led(11, 7, 3)
  g:led(12, 7, 3)
  g:led(13, 7, 3)
  g:led(14, 7, 3)
  local inrev
  for inrev = 1, 4 do
    g:led(3, inrev, 3)
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
  if calc_hold then
    g:led(15, 2, 15)
  elseif not calc_hold then
    g:led(15, 2, 3)
  end
  g:refresh()
end

local function calculate_minus(y)
  if y == 1 then
    return 9
  elseif y == 2 then
    return 6
  else
    return 3
  end
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
    if not playing then
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
    calc_input = {}
    decimal_value = steps[track][selected + 1]
    binary_input = split_str(dec_to_bin(decimal_value))
  end
  if y == 5 and x > 4 and x < 9 then
    selected = x - 5
    calc_input = {}
    decimal_value = steps[track][selected + 1]
    binary_input = split_str(dec_to_bin(decimal_value))
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
  end

  -- delay
  if x == 11 and y == 8 then
    if z == 1 then
      delay_view = true
      params:set("delay", 1)
    else
      delay_view = false
    end
    grid_redraw()
    redraw()
  end

  if x == 10 and y == 8 and z == 1 then
    if delay_in then
      audio.level_eng_cut(0)
      delay_in = false
    else
      delay_in = true
      audio.level_eng_cut(z)
    end
  end

  if x == 12 and y == 8 and z == 1 then
    params:set("delay_rate", (math.random(200)) / 100)
    params:set("delay_feedback", (math.random(100)) / 100)
  end

  if x == 13 and y == 8 and z == 1 then
    delay_view = false
    params:set("delay", 0)
    grid_redraw()
    redraw()
  end

  -- reverb
  if x == 3 and y < 5 and z == 1 then
    if params:get(y .. "_reverb_send") == -60.0 then
      params:set(y .. "_reverb_send", 0)
    else
      params:set(y .. "_reverb_send", -60.0)
    end
  elseif x == 3 and y == 5 and z == 1 then
    local mute_rev_in
    for mute_rev_in = 1, 4 do
      params:set(mute_rev_in .. "_reverb_send", -60.0)
    end
  end

  if y == 7 and z == 1 then
    if x == 10 then -- reverb level
      if params:get("reverb_level") > -20.0 then
        params:set("reverb_level", -80.0)
      else
        params:set("reverb_level", -10.0)
      end
    elseif x == 11 then -- short spaces
      params:set("reverb_room_size", math.random(25) / 100)
      params:set("reverb_damp", math.random(75, 100) / 100)
    elseif x == 12 then -- mid spaces
      params:set("reverb_room_size", math.random(25, 75) / 100)
      params:set("reverb_damp", math.random(40, 80) / 100)
    elseif x == 13 then -- long spaces
      params:set("reverb_room_size", math.random(75, 100) / 100)
      params:set("reverb_damp", math.random(30, 80) / 100)
    end
  end
  if x == 14 and y == 7 then
    if z == 1 then -- reverbView
      reverb_view = true
      redraw()
    else
      reverb_view = false
    end
  end

  -- turn to nil a binary bit
  if x <= 8 and y == 8 and z == 1 then
    local iter
    for iter = x, #binary_input do
      binary_input[iter] = nil
    end
    if check_nil(binary_input) ~= true then
      binary = concatenate_table(binary_input)
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
    if check_nil(binary_input) then
      binary_input[x] = 1
      for bina = x + 1, #binary_input do
        binary_input[bina] = 0
      end
    else
      local index_1 = table_index(binary_input)
      if binary_input[x] == nil or binary_input[x] == 0 then
        if x < index_1 then
          binary_input[x] = 1
          local j_iter
          for j_iter = x + 1, index_1 - 1 do
            if binary_input[j_iter] == nil then
              binary_input[j_iter] = 0
            end
          end
        elseif x > index_1 then
          binary_input[x] = 1
          local k_iter
          for k_iter = index_1 + 1, x - 1 do
            if binary_input[k_iter] == nil then
              binary_input[k_iter] = 0
            end
          end
        end
      elseif binary_input[x] == 1 then
        local ind1 = first_index(binary_input)
        if x == ind1 then
          if tally(binary_input) == 1 then
            make_nil(binary_input, ind1)
            decimal_value = 0
          else
            binary_input[x] = nil
            local indexx = first_index(binary_input)
            local n_iter
            for n_iter = x + 1, indexx - 1 do
              binary_input[n_iter] = nil
            end
          end
        elseif x > ind1 then
          binary_input[x] = 0
        end
      end
    end
    local binary = concatenate_table(binary_input)
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
    change_focus()
  end
  if x == 15 and y == 3 and z == 1 then
    track = track + z
    if track == 5 then
      track = 1
    end
    change_focus()
  end
  if x == 14 and y == 2 and z == 1 then
    selected = (selected - z) % 4
    decimal_value = steps[track][selected + 1]
    binary_input = split_str(dec_to_bin(decimal_value))
  end
  if x == 16 and y == 2 and z == 1 then
    selected = (selected + z) % 4
    decimal_value = steps[track][selected + 1]
    binary_input = split_str(dec_to_bin(decimal_value))
  end

  -- calculator misc
  if x == 15 and y == 2 and z == 1 then
    if not calc_hold then
      calc_hold = true
    elseif calc_hold then
      calc_hold = false
    end
    g:refresh()
  end

  -- calculator
  if z == 1 and x >= 10 and x < 13 and y <= 4 then
    local y_reducer = calculate_minus(y)
    if not calc_hold then
      calc_input = {}
      final_input = ""
      if y == 4 then
        calc_input[1] = 0
      else
        calc_input[1] = x - y_reducer
      end
    elseif calc_hold then
      if y == 4 then
        calc_input[#calc_input + 1] = 0
      else
        calc_input[#calc_input + 1] = x - y_reducer
      end
    end
    final_input = final_input .. calc_input[1]
    if #final_input == 3 then
      calc_hold = false
    end
    if tonumber(final_input) > 255 then
      final_input = calc_input[1]
    end
    calc_input = {}
    steps[track][selected + 1] = tonumber(final_input)
    decimal_value = steps[track][selected + 1]
    if loop[track] == 0 then
      sequences[track] = generate_sequence(track)
    elseif selected + 1 == loop[track] then
      loop_on(track)
    end
    calc_binary_input()
    redraw()
  elseif z == 0 and x >= 10 and x < 13 and y < 5 then
    g:led(x, y, 3)
    if x == 10 and y == 4 then
      g:led(x, y, 0)
    else
      if x == 12 and y == 4 then
        g:led(x, y, 0)
      end
      g:refresh()
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
  vials_save()
  note_off()
end

-- -----------------------------
-- save the set data to storage.
-- -----------------------------
function vials_save()
  local file = io.open(_path.data .. "vials.data", "w+")
  io.output(file)
  io.write("v1" .. "\n")
  for x = 1, 4 do
    for y = 1, 4 do
      io.write(steps[x][y] .. "\n")
    end
  end
  for z = 1, 4 do
    io.write(rotations[z] .. "\n")
    io.write(track_divs[z] .. "\n")
    io.write(probs[z] .. "\n")
  end
  io.write()
  io.close(file)
end

-- -------------------------------
-- load the set data from storage.
-- -------------------------------
function vials_load()
  local file = io.open(_path.data .. "vials.data", "r")

  if file then
    print("datafile found")
    io.input(file)
    if io.read() == "v1" then
      for x = 1, 4 do
        for y = 1, 4 do
          steps[x][y] = tonumber(io.read()) or 0
        end
      end
      for z = 1, 4 do
        rotations[z] = tonumber(io.read()) or 0
        track_divs[z] = tonumber(io.read()) or 1
        probs[z] = tonumber(io.read()) or 100
      end
    else
      print("invalid data file")
    end
    io.close(file)
  end
end

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
  params:add_number("midi_chan", "midi chan", 1, 16, 1)
  params:add_option("send_midi", "send midi", {"no", "yes"}, 1)

  params:add_separator()
  for channel = 1, 4 do
    params:add_number(channel .. ":_midi_note", channel .. ": midi note", 1, 127, 32 + channel)

    ack.add_channel_params(channel)
    params:add_separator()
  end
  ack.add_effects_params()

  for i = 1, 4 do
    sequences[i] = generate_sequence(track)
    track = track + 1
  end
  track = 1

  -- hs
  hs.init()
  params:set("delay", 0)

  vials_load()
  local init_t
  for init_t = 1, 4 do
    sequences[init_t] = generate_sequence(init_t)
  end
  change_focus()
  grid_redraw()
end
