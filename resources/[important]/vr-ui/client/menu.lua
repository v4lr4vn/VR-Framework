local menus = {}
local openId
local CONTROLS = { 27, 172, 173, 174, 175, 176, 177, 178, 18, 191, 194, 199, 200, 201, 202 }

local function iconOf(icon)
    if type(icon) == 'table' then return ('%s fa-%s'):format(icon[1] or 'fas', icon[2] or 'circle') end
    return UI.text(icon, 96)
end

local function values(list)
    if type(list) ~= 'table' then return nil end
    local out = {}
    for i = 1, #list do
        local v = list[i]
        if type(v) == 'table' then
            out[i] = { label = UI.text(v.label, 96) or '', description = UI.text(v.description, 400) }
        else
            out[i] = tostring(v)
        end
    end
    return out
end

local function options(menu)
    local out = {}
    for i, o in ipairs(menu.options or {}) do
        local checked
        if o.checked ~= nil then checked = o.checked == true end
        out[i] = {
            label = UI.text(o.label, 120) or '',
            description = UI.text(o.description, 400),
            icon = iconOf(o.icon),
            iconColor = UI.text(o.iconColor, 32),
            iconAnimation = UI.text(o.iconAnimation, 16),
            values = values(o.values),
            checked = checked,
            defaultIndex = tonumber(o.defaultIndex),
        }
    end
    return out
end

local function register(data, cb)
    if type(data) ~= 'table' or data.id == nil then return end
    data.__owner = UI.owner()
    data.__cb = cb
    menus[data.id] = data
end

local function selectedArgs(menu, index)
    local o = menu.options and menu.options[index]
    return o and o.args
end

local function show(id, startIndex)
    local menu = menus[id]
    if not menu then error(('No menu with id %s was found'):format(tostring(id)), 2) end
    openId = id
    local start = math.max(1, math.min(#(menu.options or {}), tonumber(startIndex) or 1))
    UI.send('menu:show', {
        id = id,
        title = UI.text(menu.title, 120) or '',
        position = UI.text(menu.position, 16),
        canClose = menu.canClose ~= false,
        startIndex = start,
        options = options(menu),
    })
    UI.focus('menu', false, not menu.disableInput, CONTROLS, true)
    if menu.onSelected and menu.options and menu.options[start] then
        local o = menu.options[start]
        UI.call(menu.onSelected, start, o.values and (o.defaultIndex or 1) or o.checked, o.args)
    end
end

local function hide(onExit, key)
    if not openId then return end
    local menu = menus[openId]
    openId = nil
    UI.release('menu')
    UI.send('menu:hide')
    if onExit and menu and menu.onClose then UI.call(menu.onClose, key) end
end

local function setOptions(id, opts, index)
    local menu = menus[id]
    if not menu then return end
    if index then
        menu.options = menu.options or {}
        menu.options[index] = opts
    else
        menu.options = opts
    end
    if openId == id then UI.send('menu:update', { id = id, options = options(menu) }) end
end

local function getOpen()
    return openId
end

local function current(data)
    local menu = openId and menus[openId]
    if not menu or type(data) ~= 'table' or data.id ~= menu.id then return nil end
    return menu
end

RegisterNUICallback('menu:move', function(data, cb)
    cb(1)
    local menu = current(data)
    if not menu or not menu.onSelected then return end
    local i = tonumber(data.index) or 1
    local o = menu.options and menu.options[i]
    if not o then return end
    UI.call(menu.onSelected, i, o.values and (tonumber(data.scroll) or o.defaultIndex or 1) or o.checked, o.args)
end)

RegisterNUICallback('menu:scroll', function(data, cb)
    cb(1)
    local menu = current(data)
    if not menu then return end
    local i = tonumber(data.index) or 1
    local o = menu.options and menu.options[i]
    if not o then return end
    o.defaultIndex = tonumber(data.scroll) or 1
    if menu.onSideScroll then UI.call(menu.onSideScroll, i, o.defaultIndex, o.args) end
end)

RegisterNUICallback('menu:check', function(data, cb)
    cb(1)
    local menu = current(data)
    if not menu then return end
    local i = tonumber(data.index) or 1
    local o = menu.options and menu.options[i]
    if not o then return end
    o.checked = data.checked == true
    if menu.onCheck then UI.call(menu.onCheck, i, o.checked, o.args) end
end)

RegisterNUICallback('menu:select', function(data, cb)
    cb(1)
    local menu = current(data)
    if not menu then return end
    local i = tonumber(data.index) or 1
    local o = menu.options and menu.options[i]
    if not o then return end
    local scroll = o.values and (tonumber(data.scroll) or o.defaultIndex or 1) or nil
    if o.values then o.defaultIndex = scroll end
    if o.close ~= false then hide(false) end
    if menu.__cb then UI.call(menu.__cb, i, scroll, o.args, o.checked) end
end)

RegisterNUICallback('menu:close', function(data, cb)
    cb(1)
    local menu = current(data)
    if not menu or menu.canClose == false then return end
    hide(true, type(data.key) == 'string' and data.key or 'Escape')
end)

UI.onOwnerStop(function(resource)
    for id, menu in pairs(menus) do
        if menu.__owner == resource then
            if openId == id then hide(false) end
            menus[id] = nil
        end
    end
end)

exports('registerMenu', register)
exports('showMenu', show)
exports('hideMenu', hide)
exports('setMenuOptions', setOptions)
exports('getOpenMenu', getOpen)
