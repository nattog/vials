-- vials
-- a binary rhythmbox
-- v1.1 @nattog
--
-- 4x4 decimal vials
-- represented binary
--
-- hold k1 to start
--
-- k2 change step
-- e1 change tempo
-- e2 change track
-- e3 change decimal
--
-- key combos, hold first
-- k1 + k2 resets
-- k1 + k3 stops
-- k2 + k3 mute track
-- k2 + e2 rotates binary sequence
-- k2 + e3 probability
-- k3 + e3 loads pattern
--
-- GRID (top-left clockwise)
-- sample triggers
-- track mutes
-- reverb sends (y5 kill all)
--
-- 4x4 segment looper
-- nav to left and below
-- param view
--
-- phone pad decimal input
-- hold right next to 3
-- for XX, XXX
--
-- shift seqs vertically
-- rotate seq horizontally
--
-- hold to load (top) or save (bottom)
--
-- seq reset
-- play/stop
--
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
--
-- PRs welcome
--

-- engine
engine.name = "Ack"
ack = require "ack/lib/ack"

-- libraries
vials_utils = include("lib/vials_utils")
Passthrough = include("lib/passthrough")
hs = include "awake/lib/halfsecond"

tab = require "tabutil"

-- connection
g = grid.connect()
m = midi.connect()

-- clock
clock_id = nil

-- hardware state
key1_hold = false
key2_hold = false
key3_hold = false
calc_hold = 0

-- screen variables
SCREEN_FRAMERATE = 15
screen_dirty = true
color = 3
value_color = color + 5
number = 0
screen_x = 0
screen_y = 0
word_font = 1
number_font = 23
rotate_dirty = false
param_view = 0
param_sel = 1
delay_view = 0
delay_in = 1
reverb_view = 0
loadsave_view = 0

looping = {state = false, x = 1, y = 1}
muting = {state = false, x = 1, y = 2}
paraming = {state = false, x = 1, y = 3}
reverbing = {state = false, x = 1, y = 4}
-- grid variables
GRID_FRAMERATE = 30
grid_dirty = true
g_off = 1
g_low = 3
g_mid = 5
g_high = 7
g_active = 14

-- sequence variables
vials = {}
playing = false
reset = false
binary_input = {nil, nil, nil, nil, nil, nil, nil}
calc_input = {}
note_off_queue = {34, 35, 36, 37}
vi = {}
for pat = 1, 15 do
  vi[pat] = {}
  for tr = 1, 4 do
    vi[pat][tr] = {
      pos = 0,
      prob = 100,
      mute = 0,
      seq = {0},
      steps = {0, 0, 0, 0},
      rotations = 0,
      division = 1,
      loop = 0
    }
  end
end
current_vials = 1
selected = 0
decimal_value = 0
track = 1
meta_position = 0
div_options = {1, 2, 3, 4, 6, 8, 12, 16}

-- aliases
mceil = math.ceil
rand = math.random

-- ui params
chan_params = {"_vol", "_speed", "_dist", "_filter_cutoff", "_filter_res", "_filter_env_mod"}
reverb_params = {"reverb_level", "reverb_room_size", "reverb_damp"}
delay_params = {"delay", "delay_rate", "delay_feedback"}

function pulse()
  while playing do
    clock.sync(1 / 4)
    count()
  end
end

function clock.transport.start()
  clock_id = clock.run(pulse)
end

function clock.transport.stop()
  clock.cancel(clock_id)
end

function start()
  playing = true
  clock.transport.start()
end

function note_off()
  if params:get("send_midi") == 1 then
    for i = 1, #note_off_queue do
      m:note_off(note_off_queue[i])
    end
  end
end

function reset_positions()
  meta_position = 0
  just_started = true
  for iter = 1, 4 do
    vials[iter].pos = 0
  end
  note_off()
end

function stop()
  playing = false
  clock.transport.stop()
  reset_positions()
  vials_save()
end

function reset_vials()
  for v = 1, 4 do
    vials[v] = {
      pos = 0,
      prob = 100,
      mute = 0,
      seq = {0},
      steps = {0, 0, 0, 0},
      rotations = 0,
      division = 1,
      loop = 0
    }
  end
  decimal_value = 0
  binary_input = {nil, nil, nil, nil, nil, nil, nil}
  screen_dirty = true
  grid_dirty = true
end

function reset_pattern()
  for iter = 1, 4 do
    vials[iter].pos = 0
  end
  meta_position = 0
  note_off()
end

function clock_divider(track)
  return vials[track].division
end

function count()
  local midi_send = (params:get("send_midi") == 1)
  meta_position = (meta_position % 16) + 1
  note_off()
  for t = 1, 4 do
    -- check division
    div = clock_divider(t)
    local counter = meta_position % div
    if (counter > 0 and just_started) or counter == 0 then
      -- wrap sequence when reaches length of seq
      if vials[t].pos >= #vials[t].seq then
        vials[t].pos = 0
      end
      -- change position
      vials[t].pos = (vials[t].pos + 1)
      local pos = vials[t].pos
      -- trigger note
      if vials[t].seq[pos] == 1 then
        if rand(100) <= vials[t].prob and vials[t].mute == 0 then
          engine.trig(t - 1)
          if midi_send then
            local note = params:get(t .. ":_midi_note")
            note_off_queue[t] = note
            m:note_on(note, 100, params:get("midi_chan"))
          end
        end
      end
    end
  end
  screen_dirty = true
  grid_dirty = true
  just_started = false
end

function binary_string(track)
  local str = ""
  for step = 1, 4 do
    if vials[track].steps[step] ~= nil and vials[track].steps[step] ~= 0 then
      str = str .. vials_utils.dec_to_bin(vials[track].steps[step])
    end
  end
  return str
end

function calc_binary_input()
  return vials_utils.split_str(tostring(vials_utils.dec_to_bin(decimal_value)))
end

function loop_on(t)
  local x
  local track = vials[t]
  bin = vials_utils.dec_to_bin(track.steps[track.loop])
  if vials[t].rotations > #bin then
    vials[t].rotations = 0
  end
  x = tostring(bin)
  vials[t].seq = vials_utils.split_str(x)
  screen_dirty = true
  grid_dirty = true
end

function generate_sequence(t)
  local seq_string = binary_string(t)
  local seq_tab
  if vials[t].loop == 0 then
    seq_tab = vials_utils.split_str(seq_string)
  else
    local x = vials_utils.dec_to_bin(vials[t].steps[vials[t].loop])
    seq_tab = vials_utils.split_str(x)
  end
  local seq_rotates = vials_utils.rotate(seq_tab, vials[t].rotations)
  return seq_rotates
end

function change_focus()
  decimal_value = vials[track].steps[selected + 1]
  binary_input = calc_binary_input()
  calc_input = {}
  screen_dirty = true
  grid_dirty = true
end

function loop_off(t)
  vials[t].loop = 0
  vials[t].seq = generate_sequence(t)
  screen_dirty = true
  grid_dirty = true
end

function change_selected(inp)
  selected = (selected + inp) % 4
  change_focus()
end

function change_decimal(d)
  local vial = vials[track]
  decimal_value = ((vial.steps[selected + 1] + d) % 256)
  vial.steps[selected + 1] = decimal_value
  if vial.loop == 0 then
    vials[track].seq = generate_sequence(track)
  elseif vial.loop == selected + 1 then
    loop_on(track)
  end
  binary_input = calc_binary_input()
  screen_dirty = true
  grid_dirty = true
end

function make_nil(t, ind)
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
  binary_input = calc_binary_input()
  return t
end

function position_vis()
  local phase
  if vials[track].loop > 0 then
    phrase = vials_utils.dec_to_bin(vials[track].steps[vials[track].loop])
  else
    phrase = binary_string(track)
  end
  local temp = {} -- rotate

  phrase:gsub(
    ".",
    function(c)
      table.insert(temp, c)
    end
  )
  phrase_rotated = vials_utils.rotate(temp, vials[track].rotations)
  phrase = vials_utils.concatenate_table(phrase_rotated)
  if vials[track].pos > 0 then
    screen.text(string.sub(phrase, 1, vials[track].pos - 1))
  end
  screen.level(value_color)
  screen.text(string.sub(phrase, vials[track].pos, vials[track].pos))
  screen.level(color)
  screen.text(string.sub(phrase, vials[track].pos + 1, #phrase))
end

function redraw()
  screen.clear()
  if delay_view == 0 and reverb_view == 0 and param_view == 0 then
    screen.level(color)
    screen.font_face(word_font)
    screen.font_size(8)
    screen.move(0, 10)
    screen.text("bpm ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(params:get("clock_tempo"))
    screen.move(80, 10)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("pattern ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(current_vials)
    screen.move(0, 20)
    screen.font_size(6)
    screen.font_face(15)
    screen.level(color)
    position_vis()
    screen.move((vials[track].rotations + 0.2) * 3.9999, 21)
    screen.text("_")
    screen.font_face(number_font)
    screen.font_size(8)
    screen_y = 24
    screen.move(0, screen_y)
    for row = 1, 4 do -- draw table
      for col = 1, 4 do
        screen.level(vials_utils.get_binary_density(vials[row].steps[col]))
        screen.rect(screen_x, screen_y, 15, 8)
        screen.fill()
        if row == track and col == selected + 1 then
          screen.level(2)
          screen.move(screen_x + 15, screen_y + 5)
          screen.font_size(6)
          screen.text("|")
          screen.font_size(8)
        end
        screen.level(color)
        screen_x = screen_x + 20
        screen.move(screen_x, screen_y)
      end
      screen_x = 0
      screen_y = screen_y + 10
      screen.move(screen_x, screen_y)
    end
    screen.move(80, 24)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("div ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(vials[track].division)
    if vials[track].mute == 1 then
      screen.font_face(word_font)
      screen.text("   m")
    end
    screen.move(80, 42)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("prob ")
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(vials[track].prob)
    screen.font_face(word_font)
    screen.text("%")
    screen.move(80, 52)
    screen.level(color)
    screen.font_face(word_font)
    screen.text("binary")
    screen.move(80, 62)
    screen.level(value_color)
    screen.font_face(number_font)
    screen.text(vials_utils.dec_to_bin(decimal_value))
    screen.update()
  elseif delay_view > 0 then
    screen_x = (15 * params:get("delay_rate"))
    screen_y = 10
    screenL = mceil(params:get("delay") * 10) + 3
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
  elseif reverb_view > 0 then
    screen.line_width(2)
    screen.level(15 - (mceil(params:get("reverb_damp") * 15)))
    screen.rect(0, 80, params:get("reverb_room_size") * 125, -80 - params:get("reverb_level"))
    screen.fill()
    screen.update()
  elseif param_view > 0 then
    local sample_name = vials_utils.split(params:get(param_view .. "_sample"), "/")
    screen.font_face(word_font)
    screen.move(5, 20)
    screen.text("track " .. param_view)
    screen.move(60, 20)
    screen.text(sample_name[#sample_name])
    if param_sel == 1 then
      screen.level(value_color)
    else
      screen.level(color)
    end
    screen.move(5, 40)
    screen.text("vol " .. vials_utils.round(params:get(param_view .. "_vol"), 3))
    screen.move(5, 50)
    screen.text("speed " .. vials_utils.round(params:get(param_view .. "_speed"), 3))
    screen.move(5, 60)
    screen.text("dist " .. params:get(param_view .. "_dist"))
    if param_sel == 2 then
      screen.level(value_color)
    else
      screen.level(color)
    end
    screen.move(60, 40)
    screen.text("cutoff " .. mceil(params:get(param_view .. "_filter_cutoff")))
    screen.move(60, 50)
    screen.text("res " .. vials_utils.round(params:get(param_view .. "_filter_res"), 3))
    screen.move(60, 60)
    screen.text("env amt " .. vials_utils.round(params:get(param_view .. "_filter_env_mod"), 2))
    screen.update()
  end
end

function key(n, z)
  if param_view == 0 then
    if n == 1 then --key 1 === START/STOP
      key1_hold = z == 1 and true or false
      if z == 1 then
        if not playing then
          start()
        end
      end
    end
    if z == 1 and key1_hold then
      reset_positions() -- resets
      if n == 3 then -- stop
        stop()
      end
    end
    if n == 2 then --key 2 CHANGE SLOT
      if z == 1 and not key1_hold and not key3_hold then
        key2_hold = true
        change_selected(z)
      elseif z == 0 then
        key2_hold = false
      end
    end
    if n == 3 then --key 3 ALT MODE
      if z == 1 then
        key3_hold = true
      else
        key3_hold = false
      end
    end
    if n == 2 and z == 1 and key3_hold then -- ROTATE
      rotate_track("right")
    end
    if n == 3 and z == 1 and key2_hold then -- MUTE TRACK
      vials[track].mute = 1 - vials[track].mute
    end
  else
    if z == 1 and n > 1 then
      param_sel = n - 1
    end
  end
  screen_dirty = true
  grid_dirty = true
end

function enc(n, d)
  if delay_view < 1 and reverb_view < 1 and param_view < 1 then
    if n == 2 and not key2_hold then -- change track
      track = util.clamp(track + d, 1, 4)
      change_focus()
    end
    if n == 3 then -- change decimal
      if not key2_hold and not key3_hold then
        change_decimal(d)
      elseif key2_hold then
        vials[track].prob = (vials[track].prob + d) % 101
      elseif key3_hold then
        current_vials = util.clamp(current_vials + d, 1, 15)
        load_save(current_vials, 1)
      end
    end
    if n == 1 and params:string("clock_source") == "internal" then -- change internal bpm
      params:delta("clock_tempo", d)
    end
    if n == 2 and key2_hold then -- change division
      local div_amt = vials[track].division
      vials[track].division = util.clamp(div_amt + d, 1, 8)
    end
  elseif delay_view > 0 then
    params:delta(delay_params[n], d)
  elseif reverb_view > 0 then
    params:delta(reverb_params[n], d)
  elseif param_view > 0 then
    if param_sel == 1 then
      params:delta(param_view .. chan_params[n], d)
    else
      params:delta(param_view .. chan_params[n + 3], d)
    end
  end
  screen_dirty = true
  grid_dirty = true
end

function vials_save() -- save seq data
  local file = io.open(_path.data .. "vials.data", "w+")
  io.output(file)
  io.write("v1" .. "\n")
  for pat = 1, 15 do
    for tr = 1, 4 do
      for step = 1, 4 do
        io.write(vi[pat][tr].steps[step] .. "\n")
      end
      io.write(vi[pat][tr].rotations .. "\n")
      io.write(vi[pat][tr].mute .. "\n")
      io.write(vi[pat][tr].division .. "\n")
      io.write(vi[pat][tr].prob .. "\n")
      io.write(vi[pat][tr].loop .. "\n")
    end
  end
  io.write(params:get("clock_tempo") .. "\n")
  io.close(file)
end

function vials_load() -- load seq data
  local file = io.open(_path.data .. "vials.data", "r")
  if file then
    print("datafile found")
    io.input(file)
    if io.read() == "v1" then
      for pat = 1, 15 do
        for tr = 1, 4 do
          for step = 1, 4 do
            vi[pat][tr].steps[step] = tonumber(io.read()) or 0
          end
          vi[pat][tr].rotations = tonumber(io.read()) or 0
          vi[pat][tr].mute = tonumber(io.read()) or 0
          vi[pat][tr].division = tonumber(io.read()) or 1
          vi[pat][tr].prob = tonumber(io.read()) or 100
          vi[pat][tr].loop = tonumber(io.read()) or 0
        end
      end
      params:set("clock_tempo", tonumber(io.read()) or 100)
    else
      print("invalid data file")
    end
    io.close(file)
  end
end

function menu_save()
  vi[current_vials] = vials_utils.deepcopy(vials)
end

function load_save(x, y)
  if y == 1 then -- load
    current_vials = x
    vials = vials_utils.deepcopy(vi[current_vials])
    print("loaded: " .. x)
    for i = 1, 4 do
      vials[i].seq = generate_sequence(i)
    end
    screen_dirty = true
    grid_dirty = true
  else -- save
    vi[x] = vials_utils.deepcopy(vials)
    print("saved: " .. x)
  end
end

function grid_rotator(x, y, level)
  g:led(x, y + 1, level)
  g:led(x + 2, y + 1, level)
  g:led(x + 1, y, level)
  g:led(x + 1, y + 2, level)
end

function handle_track_press(y, z)
  if paraming.state then
    param_view = z * y
  elseif z == 1 then
    if muting.state then
      vials[y].mute = 1 - vials[y].mute
    else
      track = y
      change_focus()
    end
  elseif reverbing.state and z == 1 then
    if params:get(y .. "_reverb_send") == -60.0 then
      params:set(y .. "_reverb_send", 0)
    else
      params:set(y .. "_reverb_send", -60.0)
    end
  else
    if z == 1 then
      engine.trig(y - 1)
    end
  end
  grid_dirty = true
  screen_dirty = true
end

function handle_action_press(y)
  muting.state = false
  reverbing.state = false
  paraming.state = false
  looping.state = false
  if y == 1 then
    looping.state = looping.state and false or true
  elseif y == 2 then
    muting.state = muting.state and false or true
  elseif y == 3 then
    paraming.state = paraming.state and false or true
  elseif y == 4 then
    reverbing.state = reverbing.state and false or true
  end
  grid_dirty = true
end

function grid_4x4(x, y, low, mid, active)
  for col = y, y + 3 do -- 1, 4
    for row = x, x + 3 do -- 5, 8
      is_selected = col == track and selected == row - 5
      g:led(row, col, row - 4 == vials[col].loop and active or is_selected and mid or low)
    end
  end
end

-- GRID FUNCTIONS
function grid_redraw()
  if g == nil then
    return
  end
  if loadsave_view == 1 then
    g:all(0)
    for x = 1, 15 do
      g:led(x, 1, g_low)
      g:led(x, 8, g_low)
    end
    g:refresh()
  else
    g:all(0)
    g:led(16, 5, g_low)
    for tr = 1, 4 do
      for i = 1, 8 do -- binary pattern leds
        if binary_input[i] ~= nil and i <= #binary_input then
          g:led(9 + tr, 0 + i, binary_input[i] == 1 and g_active or g_high)
        else
          g:led(9 + tr, 0 + i, 0)
        end
      end
    end
    g:led(looping.x, looping.y, looping.state and g_high or g_low)
    g:led(muting.x, muting.y, muting.state and g_high or g_low)
    g:led(paraming.x, paraming.y, paraming.state and g_high or g_low)
    g:led(reverbing.x, reverbing.y, reverbing.state and g_high or g_low)
    for t = 1, 4 do
      g:led(3, t, vials[t].mute == 1 and g_low or g_high) -- sample triggers
    end
    grid_4x4(5, 1, g_low, g_high, g_active)
    if playing then
      g:led(16, 8, meta_position % 4 == 0 and g_active or g_off) -- beat indicator
    else
      g:led(16, 8, g_mid)
    end
    g:led(16, 7, g_mid) -- reset
    -- g:led(11, 8, delay_view == 1 and g_active or g_low) -- delay
    -- g:led(10, 8, delay_in == 1 and g_active or g_low)
    -- g:led(12, 8, g_low)
    -- g:led(13, 8, g_low)
    -- for i = 10, 14 do -- reverb
    --   g:led(i, 7, g_low)
    -- end
    grid_rotator(14, 1, g_mid)
    g:refresh()
  end
end

function calculate_minus(y)
  if y == 1 then
    return 9
  elseif y == 2 then
    return 6
  else
    return 3
  end
end

function track_shift(shift)
  local rotated_tracks = {}
  local t_rotations = {}
  if shift == 1 then
    rotated_tracks = {vials[4].steps, vials[1].steps, vials[2].steps, vials[3].steps}
    t_rotations = {vials[4].rotations, vials[1].rotations, vials[2].rotations, vials[3].rotations}
  else
    rotated_tracks = {vials[2].steps, vials[3].steps, vials[4].steps, vials[1].steps}
    t_rotations = {vials[2].rotations, vials[3].rotations, vials[4].rotations, vials[1].rotations}
  end
  for i = 1, 4 do
    vials[i].steps = rotated_tracks[i]
    vials[i].rotations = t_rotations[i]
    vials[i].seq = generate_sequence(i)
  end
end

function rotate_track(dir)
  if #vials[track].seq > 0 then
    if dir == "left" then
      vials[track].rotations = vials[track].rotations - 1
      if vials[track].rotations == -1 then
        vials[track].rotations = #vials[track].seq - 1
      end
    else
      vials[track].rotations = vials[track].rotations + 1
      if vials[track].rotations >= #vials[track].seq then
        vials[track].rotations = 0
      end
    end
    vials[track].seq = generate_sequence(track)
  end
end

function run_update()
  if vials[track].loop < 1 then
    vials[track].seq = generate_sequence(track)
  elseif selected + 1 == vials[track].loop then
    loop_on(track)
  end
end

function new_pos_selector()
  calc_input = {}
  decimal_value = vials[track].steps[selected + 1]
  binary_input = vials_utils.split_str(vials_utils.dec_to_bin(decimal_value))
end

-- function handle_binary_input(x)
--   if vials_utils.check_nil(binary_input) then -- if array of nil
--     binary_input[x] = 1
--     for i = x + 1, #binary_input do
--       binary_input[i] = 0 -- fill rest of input with 0s
--     end
--   else
--     local index_1 = vials_utils.table_index(binary_input)
--     if binary_input[x] == 1 then
--       local first_index = vials_utils.first_index(binary_input)
--       if x == first_index then
--         if vials_utils.tally(binary_input) == 1 then
--           make_nil(binary_input, first_index)
--           decimal_value = 0
--         else
--           binary_input[x] = nil
--           for n = x + 1, vials_utils.first_index(binary_input) - 1 do
--             binary_input[n] = nil
--           end
--         end
--       elseif x > first_index then
--         binary_input[x] = 0
--       end
--     else
--       if x ~= index_1 then
--         binary_input[x] = 1
--         for j = x + 1, index_1 - 1 do
--           binary_input[j] = binary_input[j] == nil and 0
--         end
--       end
--     end
--   end
--   local binary = vials_utils.concatenate_table(binary_input)
--   local newNumber = tonumber(binary, 2)
--   vials[track].steps[selected + 1] = newNumber ~= nil and newNumber or 0
--   decimal_value = vials[track].steps[selected + 1]
--   run_update()
--   g:refresh()
-- end

g.key = function(x, y, z)
  if loadsave_view == 1 and x < 16 and z == 1 then
    load_save(x, y)
    return
  end

  if z == 1 then
    if x == 1 and y <= 5 then
      handle_action_press(y)
    end -- actions keys
    if x == 16 and y == 8 then -- start/stop
      if not playing then
        start()
      else
        stop()
      end
    end
    if x == 16 and y == 7 then -- reset sequences
      reset_positions()
    end
    if x >= 5 and x < 9 and y < 5 then
      track = y
      selected = x - 5
      new_pos_selector()
      if looping.state then
        if vials[y].loop == x - 4 then --loop
          vials[y].loop = 0
          loop_off(y)
        else
          vials[y].loop = x - 4
          loop_on(y)
        end
      end
    end
  --   if x == 10 and y == 8 then
  --     delay_in = 1 - delay_in
  --     audio.level_eng_cut(delay_in)
  --   end
  --   if x == 12 and y == 8 then
  --     params:set("delay_rate", (rand(200)) / 100)
  --     params:set("delay_feedback", (rand(100)) / 100)
  --   end
  --   if x == 13 and y == 8 then
  --     delay_view = 0
  --     params:set("delay", delay_view)
  --   end
  --   if x == 3 then
  --     if y == 5 then
  --       for mute_rev_in = 1, 4 do
  --         params:set(mute_rev_in .. "_reverb_send", -60.0)
  --       end
  --     end
  --   end
  --   if y == 7 then
  --     if x == 10 then -- reverb level
  --       if params:get("reverb_level") > -20.0 then
  --         params:set("reverb_level", -80.0)
  --       else
  --         params:set("reverb_level", -10.0)
  --       end
  --     elseif x == 11 then -- short spaces
  --       params:set("reverb_room_size", rand(25) / 100)
  --       params:set("reverb_damp", rand(75, 100) / 100)
  --     elseif x == 12 then -- mid spaces
  --       params:set("reverb_room_size", rand(25, 75) / 100)
  --       params:set("reverb_damp", rand(40, 80) / 100)
  --     elseif x == 13 then -- long spaces
  --       params:set("reverb_room_size", rand(75, 100) / 100)
  --       params:set("reverb_damp", rand(30, 80) / 100)
  --     end
  --   end
  end
  -- if x == 11 and y == 8 then -- fx
  --   delay_view = 0 + z
  --   params:set("delay", delay_view)
  --   screen_dirty = true
  -- end
  -- if x == 14 and y == 7 then
  --   reverb_view = 0 + z
  -- end
  if x == 16 and y == 5 then
    loadsave_view = 0 + z
    grid_dirty = true
  end
  -- if x <= 8 and y == 8 and z == 1 then -- make a bit nil
  --   for iter = x, #binary_input do
  --     binary_input[iter] = nil
  --   end
  --   if not vials_utils.check_nil(binary_input) then
  --     binary = vials_utils.concatenate_table(binary_input)
  --     vials[track].steps[selected + 1] = tonumber(binary, 2)
  --     decimal_value = vials[track].steps[selected + 1]
  --   else
  --     vials[track].steps[selected + 1] = 0
  --     decimal_value = 0
  --   end
  --   run_update()
  -- end
  -- if x <= 8 and y == 7 and z == 1 then -- binary input
  --   handle_binary_input(x)
  -- end
  if (x == 14 or x == 16) and (z == 1 and y == 2) then -- rotator
    rotate_track(x == 14 and "left" or "right")
  end
  if z == 1 and x == 15 and (y == 1 or y == 3) then -- track shift
    track_shift(y - 2)
    binary_input = calc_binary_input()
  end
  if x == 3 and y < 5 then -- track press
    handle_track_press(y, z)
  end
  g:refresh()
  screen_dirty = true
  grid_dirty = true
end

function init()
  Passthrough.init()
  params:add_option("send_midi", "send midi", {"yes", "no"}, 1)
  params:add_number("midi_chan", "midi chan", 1, 16, 1)
  params:add_separator()
  params:add {type = "trigger", id = "Save", name = "save pattern", action = menu_save}
  params:add {type = "trigger", id = "Clear", name = "clear vials", action = reset_vials}
  params:add_separator()
  for channel = 1, 4 do
    params:add_number(channel .. ":_midi_note", channel .. ": midi note", 1, 127, 32 + channel)
    ack.add_channel_params(channel)
    params:add_separator()
  end
  ack.add_effects_params()
  hs.init() -- halfsecond
  params:set("delay", 0)
  vials_load()
  vials = vials_utils.deepcopy(vi[current_vials])
  for init_t = 1, 4 do
    vials[init_t].seq = generate_sequence(init_t)
  end
  track = 1
  change_focus()

  local screen_redraw_metro = metro.init()
  screen_redraw_metro.event = function()
    if screen_dirty then
      redraw()
      screen_dirty = false
    end
  end

  local grid_redraw_metro = metro.init()
  grid_redraw_metro.event = function()
    if grid_dirty and g.device then
      grid_dirty = false
      grid_redraw()
    end
  end

  screen_redraw_metro:start(1 / SCREEN_FRAMERATE)
  grid_redraw_metro:start(1 / GRID_FRAMERATE)
end

function cleanup()
  playing = false
  note_off()
  vials_save()
end
