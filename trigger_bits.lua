-- trigger bits
-- binary rhythmbox
-- v1.0 @nattog
--
-- hold key 1 to start/stop       
-- key3 resets
-- enc1 changes track
-- key2 changes index
-- enc2 changes digit 
-- enc3 changes tempo
-- key2 + key3 rotates track

engine.name = 'Ack'

local ack = require 'ack/lib/ack'

local BeatClock = require 'beatclock'
local g = grid.connect()

local BeatClock = require 'beatclock'
local clk = BeatClock.new()
local clk_midi = midi.connect()
clk_midi.event = function(data)
  clk:process_midi(data)
end

local automatic = 0

function init()
  color = 3
  number = 0
  screenX = 0
  screenY = 0
  selected = 0
  decimal_value = 0
  track = 1
  bpm = 120
  reset = false
  positions = {0, 0, 0, 0}
  wordFont = 15
  numberFont = 3
  KEY2_hold = false
  calc_hold = false
  hold_count = 0
  calc_input = {}
  meta_location = 0
  external = false


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
      engine.trig(t-1)
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
steps = { {0,0,0,0},{0,0,0,0},{0,0,0,0},{0,0,0,0}}

local presets = {}

function redraw()
  screen.clear()
  screen.level(color)
  screen.font_face(wordFont)
  screen.font_size(9)
  screen.move(0,10)
  screen.text("trigger bits")
  screen.move(80, 10)
  screen.text("track ")
  screen.font_face(numberFont)
  screen.text(track)
  screen.move(0, 20)
  screen.font_size(6)
  screen.font_face(15)
  if positions[track] > 0 then
    screen.text(string.sub(binaryString(track), 1, positions[track] -1))
  end
  screen.level(color+2)
  screen.text(string.sub(binaryString(track), positions[track], positions[track]))
  screen.level(color)
  screen.text(string.sub(binaryString(track), positions[track] +1, #binaryString(track)))
  screen.font_face(numberFont)
  screen.font_size(9)
  screenY = 32
  screen.move(0, screenY)
  for i = 1, #steps do
    for j = 1, #steps[i] do
      if i == track then
        screen.level(color + 6)
        end
      screen.text(steps[i][j])
      if i == track then
        if j == selected+1 then
          screen.font_size(7)
          screen.text(" ! ")
          screen.font_size(9)
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
  screen.font_face(wordFont)
  screen.text("binary")
  screen.move(80, 40)
  screen.font_face(numberFont)
  screen.text(dec_to_bin(decimal_value))
  screen.move(80, 50)
  screen.font_face(wordFont)
  screen.text("bpm")
  screen.move(80, 60)
  screen.font_face(numberFont)
  if external then
    screen.font_face(wordFont)
    screen.text("ext")
  else
    screen.text(params:get("bpm"))
  end
  screen.update()
end

function key(n,z)
  if n == 1 and z == 1 then
    automatic = automatic + 1
    if automatic % 2 == 1 then
      clk:start()
    elseif automatic % 2 == 0 then
      clk:stop()
      meta_location = 0
      print('stop')
    end
  end
  
  if n == 2 and z == 1 then
    selected = (selected + z) % 4
    KEY2_hold = true
  elseif n == 2 and z == 0 then
    KEY2_hold = false
  end
    
  if n == 3 and z == 1 and KEY2_hold == true then
      local rotation = rotate(steps[track])
      steps[track] = rotation
      sequences[track] = generate_sequence(track)
  elseif n == 3 and z == 1 and KEY2_hold == false then
    meta_location = 0
    positions = {0, 0, 0, 0}
  end
  
  redraw()
end

function enc(n,d)
  -- change track
  if n ==1 then
    track = track + d
    if track == 0 then
      track = 1
      end
    if track == 5 then
      track = 4
      end
    end
  
  -- change number
  if n == 2 then
    decimal_value = steps[track][selected+1]
    decimal_value = ((decimal_value + d) % 100) 
    steps[track][selected+1] = decimal_value
    sequences[track] = generate_sequence(track)
    end
    
  -- change bpm
  if n == 3 then

    params:delta("bpm", d)
    end
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





function grid_redraw()
  if g == nil then
    -- bail if we are too early
    return
  end  
  
  -- grid leds
    
  -- sample triggers
  for t=1, 4 do
    g:led(t,8,3)
  end
  
  -- meta
  for t=1,16 do
    if t == meta_location then
      g:led(t,6,15)
    else
      g:led(t,6,1)
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
    end
  if x == 16 and y == 2 and z == 1 then
    selected = (selected + z) % 4
    end
  redraw()
  
  
  -- calculator misc
  if x == 15 and y == 2 then
    if z == 1 then
      hold_count = hold_count + 1
    end
    if hold_count % 2 ~= 0 then
      calc_hold = true
      g:led(x,y,15)
    else
      calc_hold = false
      g:led(x,y,3)
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
  if tonumber(final_input) > 99 then
    final_input = calc_input[2]
  end
  steps[track][selected+1] = tonumber(final_input)
  decimal_value = steps[track][selected+1]
  -- print(type(steps[track][selected+1]), steps[track][selected+1])
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
end