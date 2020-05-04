local utils = {}

local power = math.pow
local mceil = math.ceil

function utils.deepcopy(orig)
  local orig_type = type(orig)
  local copy
  if orig_type == "table" then
    copy = {}
    for orig_key, orig_value in next, orig, nil do
      copy[utils.deepcopy(orig_key)] = utils.deepcopy(orig_value)
    end
    setmetatable(copy, utils.deepcopy(getmetatable(orig)))
  else -- number, string, boolean, etc
    copy = orig
  end
  return copy
end

function utils.split(s, delimiter)
  result = {}
  for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
    table.insert(result, match)
  end
  return result
end

function utils.count(base, pattern)
  return select(2, string.gsub(base, pattern, ""))
end

function utils.get_binary_density(decimal)
  if decimal == 0 then
    return 0
  end
  binarystring = tostring(utils.dec_to_bin(decimal)) or ""
  one_count = utils.count(binarystring, 1)
  return math.floor((one_count / #binarystring) * 16)
end

function utils.round(what, precision)
  return math.floor(what * power(10, precision) + 0.5) / power(10, precision)
end

function utils.rotate(m, dir)
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

function utils.dec_to_bin(num)
  local total = 0
  local modifier = 0
  local value = ""
  while power(2, modifier) <= num do
    modifier = modifier + 1
  end
  for i = modifier, 1, -1 do
    if power(2, i - 1) + total <= num then
      total = total + power(2, i - 1)
      value = value .. "1"
    else
      value = value .. "0"
    end
  end
  return value
end

function utils.split_str(str)
  local tab = {}
  for i = 1, string.len(str) do
    tab[i] = tonumber(string.sub(str, i, i))
  end
  return tab
end

function utils.concatenate_table(t)
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

function utils.table_index(t)
  local index = {}
  for k, v in pairs(t) do
    index[v] = k
  end
  return index[1]
end

function utils.first_index(t)
  for iter = 1, #t do
    if t[iter] == 1 then
      return iter
    end
  end
end

function utils.tally(t)
  local freq = 0
  for iter = 1, #t do
    if t[iter] == 1 then
      freq = freq + 1
    end
  end
  return freq
end

function utils.check_nil(t)
  for iter = 1, #t do
    if t[iter] ~= nil then
      return false
    end
  end
  return true
end

return utils