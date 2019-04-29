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

local g = grid.connect()

local clk = BeatClock.new()
local clk_midi = midi.connect()
clk_midi.event = function(data)
  clk:process_midi(data)
end

local automatic = 0


function init()
  color = 3
  valueColor = color + 5
  number = 0
  screenX = 0
  screenY = 0
  selected = 0
  decimal_value = 0
  track = 1
  bpm = 120
  playing = false
  reset = false
  positions = {0, 0, 0, 0}
  probs = {100, 100, 100, 100}
  mutes = {0, 0, 0, 0}
  wordFont = 15
  numberFont = 23
  KEY2_hold = false
  KEY3_hold = false
  calc_hold = false
  hold_count = 0
  calc_input = {}
  meta_location = 0
  external = false
  binaryInput = {0, 0, 0, 0, 0, 0, 0}
  loop = {0, 0, 0, 0}
  
  for i=1, 4 do
    sequences[i] = generate_sequence(track)
    track = track + 1
    end
  track = 1

  
  clk.on_step = count
  clk.on_select_internal = function() clk:start() external = false end
  clk.on_select_external = reset_pattern
  clk:add_clock_params()

  params:add_separator()
  for channel=1,4 do
    ack.add_channel_params(channel)
  end
  ack.add_effects_params()
  
  grid_redraw()
end

function reset_pattern()
  clk:reset()
  external = true
  positions = {0, 0, 0, 0}
end


function count()
  local t
  meta_location = meta_location % 16 + 1
  grid_redraw()

  for t = 1, 4 do
    
    -- wrap sequence
    if positions[t] >= #sequences[t] then
      positions[t] = 0
    end
    
    -- change position
    positions[t] = (positions[t] + 1)

    -- trigger note
    if sequences[t][positions[t]] == 1 then
      if math.random(100) <= probs[t] and mutes[t] == 0 then
        engine.trig(t-1)
      end
    end
  end
  print(positions[1], positions[2], positions[3], positions[4])
  redraw()
end

function dec_to_bin(num)
    local total = 0
    local modifier = 0
    local value = ""
    while math.pow(2, modifier) <= num do
         modifier = modifier + 1
    end
    for i = modifier, 1, -1 do
       if math.pow(2, i-1) + total <= num then
           total = total + math.pow(2, i-1)
           value = value.."1"
        else
            value = value.."0"
        end
    end
    return value
end

sequences = {}
steps = {{0,0,0,0},{0,0,0,0},{0,0,0,0},{0,0,0,0}}




function redraw()
  screen.clear()
  screen.level(color)
  screen.font_face(wordFont)
  screen.font_size(9)
  screen.move(0,10)
  screen.text("trigger bits")
  screen.move(80, 10)
  screen.text("bpm ")
  screen.level(valueColor)
  if external then
    screen.font_face(wordFont)
    screen.text("ext")
  else
    screen.font_face(numberFont)
    screen.text(params:get("bpm"))
  end
  screen.move(0, 20)
  screen.font_size(6)
  screen.font_face(15)
  screen.level(color)
  position_vis()
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
        if j == selected+1 then
          screen.font_size(6)
          screen.text("*")
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
  screen.text("track ")
  screen.level(valueColor)
  screen.font_face(numberFont)
  screen.text(track)
  if mutes[track] == 1 then
    screen.font_face(wordFont)
    screen.text("m")
  end
  screen.move(80, 42)
  screen.level(color)
  screen.font_face(wordFont)
  screen.text("prob ")
  screen.level(valueColor)
  screen.font_face(numberFont)
  screen.text(probs[track])
  screen.move(80, 52)
  screen.level(color)
  screen.font_face(wordFont)
  screen.text("binary")
  screen.move(80, 62)
  screen.level(valueColor)
  screen.font_face(numberFont)
  screen.text(dec_to_bin(decimal_value))
  screen.update()
end

function position_vis()
  local phase
  if loop[track] > 0 then
    phrase = dec_to_bin(steps[track][loop[track]])
  else
    phrase = binaryString(track)
  end
  if positions[track] > 0 then
    screen.text(string.sub(phrase, 1, positions[track] -1))
  end
  screen.level(valueColor)
  screen.text(string.sub(phrase, positions[track], positions[track]))
  screen.level(color)
  screen.text(string.sub(phrase, positions[track] +1, #phrase))
end



function start()
  playing = true
  clk:start()
end

function stop()
  clk:stop()
  playing = false
  meta_location = 0
  print('stop')
end

function reset_positions()
  meta_location = 0
  positions = {0, 0, 0, 0}
end

function change_selected(inp)
  selected = (selected + inp) % 4
  decimal_value = steps[track][selected+1]
end



function key(n,z)
  --key 1 === START/STOP
  if n == 1 and z == 1 and KEY3_hold == false then
    automatic = automatic + 1
    if automatic % 2 == 1 then
      start()
    elseif automatic % 2 == 0 then
      stop()
    end
  end
  
  -- key 1 ALT === RESET to 0    
  if n == 1 and z == 1 and KEY3_hold == true then
    reset_positions()
  end
  
  --key 2 CHANGE SLOT
  if n == 2 and z == 1 and KEY3_hold == false then
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
      local rotation = rotate(steps[track])
      steps[track] = rotation
      sequences[track] = generate_sequence(track)
  end
    
  -- RESET
  if n == 3 and z == 1 and KEY2_hold == false then
    reset_positions()
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

function enc(n,d)
  -- change track
  if n ==2 then
    track = track + d
    if track == 0 then
      track = 4
      end
    if track == 5 then
      track = 1
      end
    end
  
  -- change decimal
  if n == 3 then
    if KEY3_hold == false then
      decimal_value = steps[track][selected+1]
      decimal_value = ((decimal_value + d) % 128) 
      steps[track][selected+1] = decimal_value
      sequences[track] = generate_sequence(track)
    elseif KEY3_hold == true then
      probs[track] = (probs[track] + d) % 101
    end
  end
    
  -- change bpm
  if n == 1 then
    params:delta("bpm", d)
  end
  redraw()
  grid_redraw()
end

function loop_on(chan)
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
  local x = ""
  for i = 1, #steps[track] do
    local y = dec_to_bin(steps[track][i])
    x = x .. y
    end
  return x
  end

function split_str(str)
   local tab = {}
   for i=1,string.len(str) do
      tab[i] = tonumber(string.sub(str, i, i))
   end
   return tab
end

function generate_sequence(track)
  local seq_string = binaryString(track)
  local seq_tab = split_str(seq_string)
  return seq_tab
  end
  


function rotate(m)
  table.insert(m,1,m[#m])
   table.remove(m,#m)
  return m
  end

function concatenate_table(t)
  local x = ""
  for i = 1, #t do
    local y = t[i]
    x = x .. y
    end
  return x
  end
  

function grid_redraw()
  if g == nil then
    return
  end  
  
  -- binary pattern leds
  for t=1, #binaryInput do 
    g:led(8-t, 6, 3)
  end
    
  -- sample triggers
  for t=1, 4 do
    g:led(t,8,3)
  end
  
  -- clock indicator
  if meta_location % 4 == 0 then
    g:led(16, 8, 6)
  else
    g:led(16, 8, 0)
  end
  if playing == false then
    g:led(16, 8, 2)
  end
  
  -- reset
  g:led(16, 7, 2)
  
  -- track mutes
  for chan = 1, 4 do
    if mutes[chan] == 0 then
      g:led(1, chan, 2)
    else
      g:led(1, chan, 7)
    end
  end
  
  -- 4x4 grid
  for c = 1, 4 do
    for r = 3,6 do
      g:led(r, c, 3)
    end
  end
  
  for i = 1, 4 do
    if loop[i] > 0 then
      g:led(loop[i]+2, i, 6)
    end
  end
  
  -- navigation
  g:led(15, 1, 3)
  g:led(15, 3, 3)
  g:led(14, 2, 3)
  g:led(16, 2, 3)
  
  --  calculator
  for u = 1, 3 do
    for v = 1, 3 do
      g:led(u+9, v, 3)
    end
    g:led(11, 4, 3)
  end
  
  -- calc_hold
  g:led(15, 2, 3)
  g:refresh()
end


  
g.key = function(x,y,z)
  print(x,y,z)
  
  
  -- trigger samples
  if x < 5 and y == 8 then
    if z==1 then engine.trig(x-1) 
      g:led(x,y,15)
      g:refresh()
    else 
      g:led(x,y,3)
      g:refresh()
    end
  end
  
  -- mute track
  if x == 1 and y < 5 and z == 1 then
    if mutes[y] == 0 then
      mutes[y] = 1
    else
      mutes[y] = 0
    end
  redraw()
  grid_redraw()
  end
  
  -- start/stop
  if x == 16 and y == 8 and z == 1 then
    automatic = automatic + 1
    if playing == false then
      start()
    else
      stop()
    end
  grid_redraw()
  end
  
  -- reset sequences
  if x == 16 and y == 7 and z == 1 then
    reset_positions()
  end
  
  -- loop
  if x >= 3 and x < 7 and y < 5 then
    if z == 1 then
      if loop[y] == x - 2 then
        loop[y] = 0
        loop_off(y)
      else
        loop[y] = x - 2
        loop_on(y)
      end
    end
    grid_redraw()
    print('loop ' .. y .. ' = ' .. loop[y])
  end
    
  -- binary input
  if x <= 7 and y == 6 and z == 1 then
    if binaryInput[x] then
      -- grid lights
      if binaryInput[x] == 1 then
        g:led(x, y, 3)
        binaryInput[x] = 0
      else
        g:led(x, y, 9)
        binaryInput[x] = 1
      end
    else 
      binaryInput[x] = 1
      g:led(x, y, 15)
    end
    
    -- send input
    binary = concatenate_table(binaryInput)
    steps[track][selected+1] = tonumber(binary, 2)
    decimal_value = steps[track][selected+1]
    g:refresh()
  end

  -- nav
  if x == 15 and y == 1 and z == 1 then
    track = track - z
    if track == 0 then
      track = 4
    end
  end
  if x == 15 and y == 3 and z == 1 then
    track = track + z
    if track == 5 then
      track = 1
    end
  end
  if x == 14 and y == 2 and z == 1 then
    selected = (selected - z) % 4
    decimal_value = steps[track][selected+1]
    binaryInput = split_str(dec_to_bin(decimal_value))
    print(binaryInput[1])
    end
  if x == 16 and y == 2 and z == 1 then
    selected = (selected + z) % 4
    decimal_value = steps[track][selected+1]
    binaryInput = split_str(dec_to_bin(decimal_value))
    print(binaryInput[1])
    end
  redraw()
  
  if calc_hold == true then
    g:led(15,2,15)
  else
    g:led(15,2,3)
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
    g:led(x,y,15)
    if x == 10 and y == 4 then
      g:led(x,y,0)
    else if x == 12 and y == 4 then
      g:led(x,y,0)
    end
    g:refresh()
    end
    if calc_hold == false then
        calc_input = {}
        if y == 4 then
          calc_input[1] = 0
        else 
          calc_input[1] = (x - y*3)
        end
    else if calc_hold == true then
        if y == 4 then
          calc_input[#calc_input+1] = 0
        else 
          calc_input[#calc_input+1] = x - y*3
        end
    end
  end
  

  if calc_input[2] ~= nil then
      final_input = calc_input[1] .. calc_input[2]
      g:led(15,1,3)
      g:refresh()
      calc_hold = false
      hold_count = 0
    else final_input = calc_input[1]
  end
  if tonumber(final_input) > 127 then
    final_input = calc_input[2]
  end
  steps[track][selected+1] = tonumber(final_input)
  decimal_value = steps[track][selected+1]
  sequences[track] = generate_sequence(track)
  redraw()
  
  else if z == 0 and x >= 10 and x < 13 and y < 5 then
    g:led(x,y,3)
    if x == 10 and y == 4 then
      g:led(x,y,0)
    else if x == 12 and y == 4 then
      g:led(x,y,0)
    end
    g:refresh()
  end

  -- print(x,y,z)
  end
end
g:refresh()
end