xyd = {2, 3, 5, 9}

function binaryString(track)
    local x = ''
    for i = 1, #xyd do
        if xyd[i] ~= nil and xyd[i] ~= 0 then
            local y = dec_to_bin(xyd[i])
            x = x .. y
        end
    end
    return x
end

function rotate_string(m, dir)
    if dir > 0 then
        norm = string.sub(m, 1, math.abs(dir))
        shift = string.sub(m, dir + 1, #m)
        return shift .. norm
    end
    if dir < 0 then
        norm = string.sub(m, dir + 1, #m)
        shift = string.sub(m, 1, math.abs(dir))
        return norm .. shift
    end
end

function split_str(str)
    local tab = {}
    for i = 1, string.len(str) do
        tab[i] = tonumber(string.sub(str, i, i))
    end
    return tab
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
