DJ = DJ or {}

function DJ.num(v)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    return v
end

function DJ.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function DJ.trim(s)
    local first = s:find('%S')
    if not first then return '' end
    local last = #s
    while last > first do
        local b = s:byte(last)
        if b == 32 or (b >= 9 and b <= 13) then last = last - 1 else break end
    end
    return s:sub(first, last)
end

local function cutChars(s, max)
    local len = utf8.len(s)
    if not len then
        s = s:gsub('[\128-\255]', '')
        len = #s
    end
    if len > max then s = s:sub(1, utf8.offset(s, max + 1) - 1) end
    return s
end

function DJ.cleanText(s, max)
    if type(s) ~= 'string' then return nil end
    max = max or 64
    if #s > max * 8 + 64 then s = s:sub(1, max * 8 + 64) end
    s = DJ.trim(s:gsub('[%c<>]', ''):gsub('%s+', ' '))
    if s == '' then return nil end
    return cutChars(s, max)
end

function DJ.youtubeId(url)
    if type(url) ~= 'string' then return nil end
    if url:match('^[%w_-]+$') and #url == 11 then return url end
    local host = url:match('^https?://([^/?#]+)')
    if not host then return nil end
    host = host:lower():gsub('^www%.', ''):gsub('^m%.', ''):gsub('^music%.', '')
    if host == 'youtu.be' then
        return url:match('^https?://[^/]+/([%w_-]+)')
    end
    if host ~= 'youtube.com' and host ~= 'youtube-nocookie.com' then return nil end
    return url:match('[?&]v=([%w_-]+)')
        or url:match('/embed/([%w_-]+)')
        or url:match('/shorts/([%w_-]+)')
        or url:match('/live/([%w_-]+)')
end

local function privateHost(host)
    if host:match('^[%d%.]+$') or host:find(':', 1, true) or host:match('^%[') then return true end
    if host == 'localhost' or host:match('%.localhost$') or host:match('%.local$') or host:match('%.lan$')
        or host:match('%.internal$') or host:match('%.home$') or not host:find('.', 1, true) then
        return true
    end
    return false
end

local function allowedHost(host)
    local list = Config.AudioHosts
    if type(list) ~= 'table' or #list == 0 then return true end
    for _, allowed in ipairs(list) do
        allowed = allowed:lower()
        if host == allowed or host:sub(-(#allowed + 1)) == '.' .. allowed then return true end
    end
    return false
end

function DJ.parseLink(url)
    if type(url) ~= 'string' or #url > 600 then return nil, 'bad_link' end
    url = DJ.trim(url)
    local id = DJ.youtubeId(url)
    if id and #id >= 6 and #id <= 20 then
        return 'https://www.youtube.com/watch?v=' .. id, 'youtube', 'YouTube video'
    end
    if #url > 512 or not url:match('^https?://[^%s]+$') or url:find('["\'<>\\`]') then
        return nil, 'bad_link'
    end
    local host = url:match('^https?://([^/?#]+)')
    if host then host = host:gsub('^[^@]*@', ''):gsub(':%d+$', ''):lower() end
    if not host or host == '' then return nil, 'bad_link' end
    if privateHost(host) then return nil, 'bad_host' end
    if not allowedHost(host) then return nil, 'host_not_allowed' end
    local file = url:match('/([^/?#]+)[^/]*$') or host
    file = file:gsub('%%20', ' ')
    return url, 'audio', DJ.cleanText(file, 80) or host
end

function DJ.inZone(zone, x, y, z)
    if not zone or not zone.points or #zone.points < 3 then return false end
    if z and ((zone.minZ and z < zone.minZ) or (zone.maxZ and z > zone.maxZ)) then return false end
    local inside, pts = false, zone.points
    local j = #pts
    for i = 1, #pts do
        local xi, yi, xj, yj = pts[i].x, pts[i].y, pts[j].x, pts[j].y
        if ((yi > y) ~= (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

function DJ.dist(a, b)
    local dx, dy, dz = a.x - b.x, a.y - b.y, (a.z or 0) - (b.z or 0)
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function DJ.itemInfo(item)
    if type(item) ~= 'string' then return nil end
    local s = Config.Speakers[item]
    if s then return s, 'speaker' end
    if item == Config.Boombox.item then return Config.Boombox, 'boombox' end
    if item == Config.Booster.item then return Config.Booster, 'booster' end
    return nil
end
