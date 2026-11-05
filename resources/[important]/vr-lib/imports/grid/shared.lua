local CELL = 512.0
local cells = {}

local function cellOf(x, y)
    return math.floor(x / CELL), math.floor(y / CELL)
end

local function key(cx, cy)
    return cx .. ':' .. cy
end

local function bounds(entry)
    local r = entry.radius or math.max(entry.width or 0, entry.length or 0) / 2
    local c = entry.coords
    local x1, y1 = cellOf(c.x - r, c.y - r)
    local x2, y2 = cellOf(c.x + r, c.y + r)
    return x1, y1, x2, y2
end

local grid = {}

function grid.getCellPosition(coords)
    return cellOf(coords.x, coords.y)
end

function grid.getCell(coords)
    local cx, cy = cellOf(coords.x, coords.y)
    local k = key(cx, cy)
    cells[k] = cells[k] or {}
    return cells[k]
end

function grid.addEntry(entry)
    local x1, y1, x2, y2 = bounds(entry)
    entry.__cells = {}
    for x = x1, x2 do
        for y = y1, y2 do
            local k = key(x, y)
            cells[k] = cells[k] or {}
            cells[k][entry] = true
            entry.__cells[#entry.__cells + 1] = k
        end
    end
end

function grid.removeEntry(entry)
    if not entry.__cells then return false end
    for _, k in ipairs(entry.__cells) do
        if cells[k] then cells[k][entry] = nil end
    end
    entry.__cells = nil
    return true
end

function grid.getNearbyEntries(coords, filter)
    local cx, cy = cellOf(coords.x, coords.y)
    local seen, out = {}, {}
    for x = cx - 1, cx + 1 do
        for y = cy - 1, cy + 1 do
            local cell = cells[key(x, y)]
            if cell then
                for entry in pairs(cell) do
                    if not seen[entry] and (not filter or filter(entry)) then
                        seen[entry] = true
                        out[#out + 1] = entry
                    end
                end
            end
        end
    end
    return out
end

return grid
