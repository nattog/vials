utils.split = function(s, delimiter)
  result = {}
  for match in (s .. delimiter):gmatch("(.-)" .. delimiter) do
    table.insert(result, match)
  end
  return result
end

utils.split_str = function(str)
  local tab = {}
  for i = 1, string.len(str) do
    tab[i] = tonumber(string.sub(str, i, i))
  end
  return tab
end

utils.dec_to_bin = function(num)
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

utils.concatenate_table = function(t)
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

utils.table_index = function(t)
  local index = {}
  for k, v in pairs(t) do
    index[v] = k
  end
  return index[1]
end

utils.first_index = function(t)
  local iter
  for iter = 1, #t do
    if t[iter] == 1 then
      return iter
    end
  end
end

utils.tally = function(t)
  local freq = 0
  local iter
  for iter = 1, #t do
    if t[iter] == 1 then
      freq = freq + 1
    end
  end
  return freq
end

utils.check_nil = function(t)
  local iter
  for iter = 1, #t do
    if t[iter] ~= nil then
      return false
    end
  end
  return true
end
