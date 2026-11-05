local notes = {}
local nextId = 0
local writing = {}
local last = {}
local RES = GetCurrentResourceName()

local function now() return GetGameTimer() // 1000 end

local function throttle(src, key, ms)
    local t = GetGameTimer()
    local id = ('%s:%s'):format(src, key)
    if last[id] and t - last[id] < ms then return true end
    last[id] = t
    return false
end

local function player(src)
    src = tonumber(src)
    if not src or src <= 0 then return nil end
    local p = Bridge.player(src)
    if not p or not p.cid then return nil end
    return p
end

local function near(src, note)
    local me = Bridge.coords(src)
    if not me then return false end
    local dx, dy, dz = note.x - me.x, note.y - me.y, note.z - me.z
    local limit = Config.ReadDistance or 3.0
    return dx * dx + dy * dy + dz * dz <= limit * limit
end

local function view(n) return { id = n.id, x = n.x, y = n.y, z = n.z } end

local function clean(text)
    if type(text) ~= 'string' then return nil end
    text = text:gsub('[<>]', ''):gsub('%c', function(c) return (c == '\n') and '\n' or ' ' end)
    text = text:gsub('^%s+', ''):gsub('%s+$', '')
    if #text < 1 or #text > (Config.MaxLength or 400) then return nil end
    return text
end

-- The first plain http(s) link that ends in an image extension, if there is one.
local function imageOf(text)
    for url in text:gmatch('https?://[%w%-%._~:/%?#%[%]@!%$&%*%+,;=%%]+') do
        local path = url:gsub('[%?#].*$', ''):lower()
        if path:match('%.png$') or path:match('%.jpe?g$') or path:match('%.gif$') or path:match('%.webp$') then
            if #url < 300 and not url:find('[%(%)]') then return url end
        end
    end
    return nil
end

local function open(src)
    local p = player(src)
    if not p then return end
    if Config.RequireItem then
        local ok, n = pcall(Bridge.inventory.count, src, Config.Item)
        if not ok or (tonumber(n) or 0) < 1 then
            return Bridge.notify(src, 'You need a notepad for that', 'error', nil, 'Notepad')
        end
    end
    writing[src] = GetGameTimer()
    TriggerClientEvent(RES .. ':client:write', src)
end

Bridge.useItem(Config.Item, function(src) open(src) end)

if Config.Command then
    RegisterCommand(Config.Command, function(src)
        if src > 0 then open(src) end
    end, false)
end

lib.callback.register(RES .. ':list', function()
    local out = {}
    for _, n in pairs(notes) do out[#out + 1] = view(n) end
    return out
end)

lib.callback.register(RES .. ':create', function(src, text, anonymous)
    if throttle(src, 'create', 3000) then return { ok = false, error = 'slow_down' } end
    local p = player(src)
    if not p then return { ok = false, error = 'no_player' } end
    local started = writing[src]
    writing[src] = nil
    if not started or GetGameTimer() - started > 5 * 60 * 1000 then return { ok = false, error = 'not_writing' } end
    if Config.RequireItem then
        local ok, n = pcall(Bridge.inventory.count, src, Config.Item)
        if not ok or (tonumber(n) or 0) < 1 then return { ok = false, error = 'no_item' } end
    end
    text = clean(text)
    if not text then return { ok = false, error = 'bad_text' } end
    local mine, total = 0, 0
    for _, n in pairs(notes) do
        total = total + 1
        if n.cid == p.cid then mine = mine + 1 end
    end
    if mine >= (Config.MaxPerPlayer or 5) then return { ok = false, error = 'too_many_mine' } end
    if total >= (Config.MaxNotes or 150) then return { ok = false, error = 'too_many' } end
    local at = Bridge.coords(src)
    if not at then return { ok = false, error = 'no_player' } end
    nextId = nextId + 1
    local n = {
        id = nextId, x = at.x + 0.0, y = at.y + 0.0, z = at.z + 0.0, text = text, image = imageOf(text),
        anonymous = anonymous == true, author = p.name or 'Someone', cid = p.cid, created = now(),
    }
    notes[n.id] = n
    TriggerClientEvent(RES .. ':client:add', -1, view(n))
    return { ok = true, data = { id = n.id } }
end)

lib.callback.register(RES .. ':read', function(src, id)
    if throttle(src, 'read', 500) then return { ok = false, error = 'slow_down' } end
    local n = notes[tonumber(id) or -1]
    if not n then return { ok = false, error = 'gone' } end
    if not near(src, n) then return { ok = false, error = 'too_far' } end
    return { ok = true, data = { text = n.text, image = n.image, author = (not n.anonymous) and n.author or nil } }
end)

lib.callback.register(RES .. ':destroy', function(src, id)
    if throttle(src, 'destroy', 500) then return { ok = false, error = 'slow_down' } end
    local n = notes[tonumber(id) or -1]
    if not n then return { ok = false, error = 'gone' } end
    if not near(src, n) then return { ok = false, error = 'too_far' } end
    notes[n.id] = nil
    TriggerClientEvent(RES .. ':client:remove', -1, n.id)
    return { ok = true }
end)

AddEventHandler('playerDropped', function() writing[source] = nil end)

CreateThread(function()
    while true do
        Wait(60000)
        local minutes = tonumber(Config.ExpireMinutes) or 0
        if minutes > 0 then
            local limit = now() - minutes * 60
            for id, n in pairs(notes) do
                if n.created < limit then
                    notes[id] = nil
                    TriggerClientEvent(RES .. ':client:remove', -1, id)
                end
            end
        end
    end
end)
