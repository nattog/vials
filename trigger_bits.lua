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

local clk = BeatClock.new()
local clk_midi = midi.connect()
clk_midi.event = clk.process_midi
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

  for i=1, 4 do
    sequences[i] = generate_sequence(track)
    track = track + 1
    end
  track = 1

  
  clk.on_step = count
  clk.on_select_internal = function() clk:start() end
  clk.on_select_external = function() print("external") end
  clk:add_clock_params()
  params:add_separator()
  for channel=1,4 do
    ack.add_channel_params(channel)
  end
  ack.add_effects_params()
  
end


function count()
  local t
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
end

local binaryLookup = {0, 1, 10, 11, 100, 
  101, 110, 111, 1000, 
  1001, 1010, 1011, 1100, 
  1101, 1110, 1111, 10000, 
  10001, 10010, 10011, 10100,
  10101, 10110, 10111, 11000,
  11001, 11010, 11011, 11100,
  11101, 11110, 11111, 100000}

sequences = {}
local steps = { {0,0,0,0},{0,0,0,0},{0,0,0,0},{0,0,0,0}}

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
  screen.text(binaryString(track))
  screen.move(0, 30)
  screenY = 30
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
  screen.move(80, 30)
  screen.font_face(wordFont)
  screen.text("binary")
  screen.move(80, 40)
  screen.font_face(numberFont)
  screen.text(binaryLookup[1 + decimal_value])
  screen.move(80, 50)
  screen.font_face(wordFont)
  screen.text("bpm")
  screen.move(80, 60)
  screen.font_face(numberFont)
  screen.text(params:get("bpm"))
  screen.update()
end

function key(n,z)
  if n == 1 and z == 1 then
    automatic = automatic + 1
    if automatic % 2 == 1 then
      clk:start()
    elseif automatic % 2 == 0 then
      clk:stop()
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
    decimal_value = ((decimal_value + d) % 33) 
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
    local y = binaryLookup[steps[track][i]+1]
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
  
