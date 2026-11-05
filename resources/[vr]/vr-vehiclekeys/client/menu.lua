local KIND = {
    owner = 'Your vehicle',
    shared = 'A copy given to you',
    lent = 'Lent to you for a while',
    temp = 'Temporary key',
}

local counter = 0

local function show(title, options, onSelect)
    counter = counter + 1
    local id = 'vr-vehiclekeys:menu' .. counter
    lib.registerMenu({ id = id, title = title, position = 'top-right', options = options }, function(_, _, args)
        if type(args) == 'table' then onSelect(args) end
    end)
    lib.showMenu(id)
end

local open

local function result(res, text)
    if res.ok then return Keys.notify(text, 'success') end
    Keys.notify(Keys.errorText(res.error), 'error')
end

local function pickPlayer(v, lend)
    local res = Keys.api('nearby')
    local players = res.ok and res.data.players or {}
    if #players == 0 then return Keys.notify('Nobody is close enough', 'error') end
    local options = {}
    for i, p in ipairs(players) do
        options[i] = { label = p.name, description = ('ID %d'):format(p.src), icon = 'fa-solid fa-user', args = { src = p.src, name = p.name } }
    end
    show(lend and 'Lend the key to' or 'Give a copy to', options, function(a)
        local r = Keys.api('share', { plate = v.plate, target = a.src, lend = lend })
        result(r, lend and ('Lent the key to %s'):format(a.name) or ('Gave %s a copy of the key'):format(a.name))
    end)
end

local function holders(v)
    local res = Keys.api('holders', { plate = v.plate })
    if not res.ok then return Keys.notify(Keys.errorText(res.error), 'error') end
    local list = res.data.holders
    if #list == 0 then return Keys.notify('Nobody else has a key to this vehicle', 'inform') end
    local options = {}
    for i, h in ipairs(list) do
        options[i] = { label = h.name, description = h.lent and 'Lent. Select to take it back' or 'Select to take the key back', icon = 'fa-solid fa-user-xmark', args = { cid = h.cid, name = h.name } }
    end
    show('Who has keys', options, function(a)
        result(Keys.api('revoke', { plate = v.plate, cid = a.cid }), ('Took the key back from %s'):format(a.name))
    end)
end

local function vehicleMenu(v)
    local options = {}
    if v.kind == 'owner' then
        options[#options + 1] = { label = 'Give a copy', description = 'A permanent key for someone close to you', icon = 'fa-solid fa-key', args = { act = 'give' } }
        options[#options + 1] = { label = ('Lend for %d minutes'):format(Config.Keys.lendMinutes), description = 'The key stops working by itself', icon = 'fa-solid fa-clock', args = { act = 'lend' } }
        options[#options + 1] = { label = 'Who has keys', description = 'See and take back keys you handed out', icon = 'fa-solid fa-users', args = { act = 'holders' } }
    else
        options[#options + 1] = { label = 'Hand the key back', icon = 'fa-solid fa-rotate-left', args = { act = 'return' } }
    end
    options[#options + 1] = { label = 'Back', icon = 'fa-solid fa-arrow-left', args = { act = 'back' } }
    show(('%s  ·  %s'):format(v.label, v.plate), options, function(a)
        if a.act == 'give' then pickPlayer(v, false)
        elseif a.act == 'lend' then pickPlayer(v, true)
        elseif a.act == 'holders' then holders(v)
        elseif a.act == 'return' then
            result(Keys.api('revoke', { plate = v.plate }), 'Key handed back')
        elseif a.act == 'back' then open() end
    end)
end

open = function()
    local res = Keys.api('list')
    if not res.ok then return Keys.notify(Keys.errorText(res.error), 'error') end
    local list = res.data.vehicles
    if #list == 0 then return Keys.notify('You do not have any keys', 'inform') end
    local options = {}
    for i, v in ipairs(list) do
        options[i] = { label = ('%s  ·  %s'):format(v.label, v.plate), description = KIND[v.kind] or 'Key', icon = 'fa-solid fa-car', args = { vehicle = v } }
    end
    show('Your keys', options, function(a)
        if a.vehicle then vehicleMenu(a.vehicle) end
    end)
end

Keys.openMenu = open
Keys.pickPlayer = pickPlayer
Keys.showHolders = holders
Keys.showMenu = show

RegisterCommand('keys', function() open() end, false)

lib.addKeybind({
    name = 'menu',
    description = 'Open your keys',
    defaultKey = '',
    onPressed = function() open() end,
})
