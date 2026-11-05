local items = {}
local radials = {}
local isOpen = false
local disabled = false
local currentId
local rootId
local history = {}
local shown = {}
local CONTROLS = { 1, 2, 24, 25, 142, 199, 200, 257, 263 }

local function iconOf(icon)
    if type(icon) == 'table' then return ('%s fa-%s'):format(icon[1] or 'fas', icon[2] or 'circle') end
    return UI.text(icon, 96)
end

local function listOf(id)
    if id then return radials[id] and radials[id].items or {} end
    return items
end

local function render(id)
    currentId = id
    shown = listOf(id)
    local out = {}
    for i, it in ipairs(shown) do
        out[i] = { label = UI.text(it.label, 48) or '', icon = iconOf(it.icon), hasMenu = it.menu ~= nil }
    end
    UI.send('radial:open', { items = out, sub = id ~= nil and id ~= rootId, title = id and radials[id] and UI.text(radials[id].label, 32) or nil })
end

local function hide()
    if not isOpen then return end
    isOpen = false
    currentId, rootId = nil, nil
    history = {}
    UI.release('radial')
    UI.send('radial:close')
end

local function open(id)
    if disabled then return end
    if id and not radials[id] then return end
    if isOpen then
        if rootId == id then return hide() end
        rootId = id
        history = {}
        return render(id)
    end
    local list = listOf(id)
    if IsNuiFocused() or IsPauseMenuActive() then return end
    isOpen = true
    rootId = id
    history = {}
    UI.focus('radial', true, true, CONTROLS, true)
    SetCursorLocation(UIConfig.radial.x or 0.24, UIConfig.radial.y or 0.24)
    render(id)
end

local function add(item, owner)
    if type(item) ~= 'table' or item.id == nil then return end
    item.__owner = owner
    for i = 1, #items do
        if items[i].id == item.id then
            items[i] = item
            return
        end
    end
    items[#items + 1] = item
end

local function addRadialItem(data)
    local owner = UI.owner()
    if type(data) ~= 'table' then return end
    if data.id ~= nil then add(data, owner) else for _, it in ipairs(data) do add(it, owner) end end
    if isOpen and currentId == nil then render(nil) end
end

local function removeRadialItem(id)
    for i = #items, 1, -1 do
        if items[i].id == id then table.remove(items, i) end
    end
    if isOpen and currentId == nil then
        render(nil)
    end
end

local function clearRadialItems()
    items = {}
    if isOpen and currentId == nil then hide() end
end

local function registerRadial(data)
    if type(data) ~= 'table' or data.id == nil then return end
    data.__owner = UI.owner()
    radials[data.id] = data
    if isOpen then hide() end
end

RegisterNUICallback('radial:select', function(data, cb)
    cb(1)
    if not isOpen or type(data) ~= 'table' then return end
    local index = tonumber(data.index) or 0
    local it = shown[index]
    if not it then return end
    if it.menu then
        if radials[it.menu] then
            history[#history + 1] = currentId or false
            render(it.menu)
        end
        return
    end
    local from = currentId
    if not it.keepOpen then hide() end
    if type(it.onSelect) == 'string' then
        TriggerEvent(it.onSelect, from, index)
    elseif it.onSelect then
        UI.call(it.onSelect, from, index)
    end
end)

RegisterNUICallback('radial:back', function(_, cb)
    cb(1)
    if not isOpen then return end
    if #history == 0 then return hide() end
    local prev = table.remove(history)
    render(prev or nil)
end)

RegisterNUICallback('radial:close', function(_, cb)
    cb(1)
    hide()
end)

UI.onOwnerStop(function(resource)
    local changed = false
    for i = #items, 1, -1 do
        if items[i].__owner == resource then
            table.remove(items, i)
            changed = true
        end
    end
    for id, r in pairs(radials) do
        if r.__owner == resource then
            radials[id] = nil
            changed = true
        end
    end
    if changed and isOpen then hide() end
end)

RegisterCommand('vrui_radial', function() open(nil) end, false)
Keybinds.add({
    name = 'radial',
    label = 'Open radial menu',
    description = 'Quick actions for you, your vehicle and your job',
    suggested = UIConfig.radial.key or 'z',
    order = 20,
    onPressed = function() open(nil) end,
})

exports('addRadialItem', addRadialItem)
exports('removeRadialItem', removeRadialItem)
exports('clearRadialItems', clearRadialItems)
exports('registerRadial', registerRadial)
exports('showRadial', open)
exports('showRadialMenu', open)
exports('hideRadial', hide)
exports('disableRadial', function(state)
    disabled = state == true
    if disabled then hide() end
end)
exports('getCurrentRadialId', function() return currentId end)
exports('isRadialOpen', function() return isOpen end)
