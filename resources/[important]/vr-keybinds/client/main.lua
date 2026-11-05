local C = KeybindConfig
local K = KeyData

local actions = {}
local binds = {}
local byKey = {}
local down = {}
local prev = {}
local loaded = false
local isAdmin = false
local ui = { open = false, mode = nil, ready = false }
local loggedIn = Bridge.loggedIn()
local saveAt = 0
local own = {}

local categoryOf = {}
for _, cat in ipairs(C.categories) do
    for _, res in ipairs(cat.resources or {}) do categoryOf[res] = cat.id end
end

local function cleanBind(b)
    if type(b) ~= 'table' then return nil end
    local k = tonumber(b.k)
    if not k or not K.labels[k] or C.blocked[k] then return nil end
    local m = b.m
    if m ~= nil and not K.modLabels[m] then return nil end
    if m and K.modFamily[k] == m then m = nil end
    return { k = math.floor(k), m = m }
end

local function rebuild()
    byKey = {}
    for id, b in pairs(binds) do
        if actions[id] then
            local list = byKey[b.k]
            if not list then
                list = {}
                byKey[b.k] = list
            end
            list[#list + 1] = { id = id, m = b.m }
        end
    end
end

local function fire(id, state)
    if state then down[id] = true else down[id] = nil end
    local handler = own[id]
    if handler then
        local fn = state and handler.onPressed or handler.onReleased
        if fn then fn() end
        return
    end
    TriggerEvent('vr-keybinds:fire', id, state)
end

local function releaseAll()
    for id in pairs(down) do fire(id, false) end
end

local function modHeld(m)
    for _, vk in ipairs(K.mods[m]) do
        if IsRawKeyDown(vk) then return true end
    end
    return false
end

local function keyDown(vk)
    if IsRawKeyDown(vk) then return true end
    local g = K.generic[vk]
    return g ~= nil and IsRawKeyDown(g)
end

local function blockedNow()
    if ui.open then return true end
    if IsPauseMenuActive() then return true end
    if UpdateOnscreenKeyboard() == 0 then return true end
    if loggedIn ~= true then return true end
    return false
end

local function uiBlocks(entry)
    if not IsNuiFocused() or IsNuiFocusKeepingInput() then return false end
    local action = actions[entry.id]
    return not (action and action.allowInUi and K.textless[binds[entry.id].k])
end

local function onPress(vk, list)
    if blockedNow() then return end
    local picked = {}
    for _, e in ipairs(list) do
        if e.m and modHeld(e.m) then picked[#picked + 1] = e end
    end
    if #picked == 0 then
        for _, e in ipairs(list) do
            if not e.m then picked[#picked + 1] = e end
        end
    end
    for _, e in ipairs(picked) do
        if not down[e.id] and not uiBlocks(e) then fire(e.id, true) end
    end
end

local function onRelease(list)
    for _, e in ipairs(list) do
        if down[e.id] then fire(e.id, false) end
    end
end

CreateThread(function()
    while true do
        if next(byKey) == nil then
            Wait(250)
        else
            for vk, list in pairs(byKey) do
                local now = keyDown(vk)
                local was = prev[vk]
                if now and not was then onPress(vk, list) elseif was and not now then onRelease(list) end
                prev[vk] = now
            end
            Wait(0)
        end
    end
end)

local function categoryFor(action)
    if action.category then
        for _, cat in ipairs(C.categories) do
            if cat.id == action.category then return cat.id end
        end
    end
    return categoryOf[action.owner] or 'other'
end

local function publicAction(a)
    return {
        id = a.id,
        label = a.label,
        description = a.description,
        category = a.categoryId,
        essential = a.essential,
        suggested = a.suggested,
        allowInUi = a.allowInUi,
        order = a.order,
    }
end

local function actionList()
    local out = {}
    for _, a in pairs(actions) do
        local cat
        for _, c in ipairs(C.categories) do
            if c.id == a.categoryId then cat = c break end
        end
        if not (cat and cat.admin and not isAdmin) then out[#out + 1] = publicAction(a) end
    end
    table.sort(out, function(x, y) return x.order < y.order end)
    return out
end

local function categoryList()
    local out = {}
    for _, c in ipairs(C.categories) do
        if not (c.admin and not isAdmin) then out[#out + 1] = { id = c.id, label = c.label, icon = c.icon } end
    end
    return out
end

local function bindsForUi()
    local out = {}
    for id, b in pairs(binds) do out[id] = { k = b.k, m = b.m } end
    return out
end

local function sendUi(action, data)
    if ui.ready then SendNUIMessage({ action = action, data = data }) end
end

local pendingRefresh = false
local function refreshUi()
    if not ui.open or pendingRefresh then return end
    pendingRefresh = true
    SetTimeout(100, function()
        pendingRefresh = false
        if ui.open then sendUi('actions', { actions = actionList(), binds = bindsForUi() }) end
    end)
end

local seq = 0
local function register(def, owner)
    if type(def) ~= 'table' or type(def.id) ~= 'string' or #def.id > 96 then return false end
    if not def.id:match('^[%w%-_]+:[%w%-_%.]+$') then return false end
    local existing = actions[def.id]
    if existing and existing.owner ~= owner and GetResourceState(existing.owner) == 'started' then return false end
    seq = seq + 1
    local suggested = K.parse(def.suggested)
    local a = {
        id = def.id,
        owner = owner,
        label = type(def.label) == 'string' and def.label:sub(1, 80) or def.id,
        description = type(def.description) == 'string' and def.description:sub(1, 160) or nil,
        category = type(def.category) == 'string' and def.category or nil,
        essential = def.essential == true or C.essential[def.id] == true,
        allowInUi = def.allowInUi == true,
        suggested = suggested and not C.blocked[suggested] and { k = suggested, m = K.modLabels[def.suggestedMod] and def.suggestedMod or nil } or nil,
        order = existing and existing.order or (tonumber(def.order) or 500) * 10000 + seq,
    }
    a.categoryId = categoryFor(a)
    actions[def.id] = a
    rebuild()
    refreshUi()
    return true
end

local function unregisterOwner(owner)
    local changed = false
    for id, a in pairs(actions) do
        if a.owner == owner then
            if down[id] then down[id] = nil end
            actions[id] = nil
            changed = true
        end
    end
    if changed then
        rebuild()
        refreshUi()
    end
end

AddEventHandler('onClientResourceStop', function(res)
    if res == GetCurrentResourceName() then
        SetNuiFocus(false, false)
        return
    end
    unregisterOwner(res)
end)

local function queueSave()
    saveAt = GetGameTimer() + C.saveDelay
end

CreateThread(function()
    while true do
        Wait(250)
        if saveAt > 0 and GetGameTimer() >= saveAt then
            saveAt = 0
            lib.callback('vr-keybinds:save', false, function() end, bindsForUi())
        end
    end
end)

local function missingEssentials()
    local out = {}
    for id, a in pairs(actions) do
        if a.essential and not binds[id] then out[#out + 1] = id end
    end
    return out
end

local function conflictFor(id, b)
    for other, ob in pairs(binds) do
        if other ~= id and ob.k == b.k and ob.m == b.m then return other end
    end
end

local function setBind(id, b, mode)
    if not actions[id] then return false, 'unknown' end
    if b == nil then
        binds[id] = nil
        if down[id] then fire(id, false) end
        rebuild()
        queueSave()
        return true
    end
    b = cleanBind(b)
    if not b then return false, 'blocked' end
    local other = conflictFor(id, b)
    if other then
        if mode == 'swap' then
            binds[other] = binds[id]
        elseif mode == 'replace' then
            binds[other] = nil
        else
            return false, 'conflict', other
        end
        if down[other] then fire(other, false) end
    end
    if down[id] then fire(id, false) end
    binds[id] = b
    rebuild()
    queueSave()
    return true
end

local function strKeys(t)
    local out = {}
    for k, v in pairs(t) do out[tostring(k)] = v end
    return out
end

local function openUi(mode)
    if ui.open then
        if mode == 'setup' and ui.mode ~= 'setup' then
            ui.mode = 'setup'
            sendUi('mode', { mode = 'setup' })
        end
        return
    end
    releaseAll()
    ui.open = true
    ui.mode = mode or 'menu'
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    sendUi('open', {
        mode = ui.mode,
        actions = actionList(),
        binds = bindsForUi(),
        categories = categoryList(),
        labels = strKeys(K.labels),
        modLabels = K.modLabels,
        blocked = strKeys(C.blocked),
        gta = strKeys(C.gta),
        command = C.command,
    })
end

local function closeUi()
    if not ui.open then return true end
    if ui.mode == 'setup' and #missingEssentials() > 0 then return false end
    ui.open = false
    ui.mode = nil
    SetNuiFocus(false, false)
    sendUi('close', {})
    return true
end

RegisterNUICallback('ready', function(_, cb)
    ui.ready = true
    cb({ ok = true })
end)

RegisterNUICallback('set', function(data, cb)
    if type(data) ~= 'table' or type(data.id) ~= 'string' then return cb({ ok = false }) end
    local ok, reason, other = setBind(data.id, data.bind, data.mode)
    cb({ ok = ok, reason = reason, other = other, binds = bindsForUi() })
end)

RegisterNUICallback('reset', function(_, cb)
    releaseAll()
    binds = {}
    rebuild()
    queueSave()
    cb({ ok = true, binds = bindsForUi() })
end)

RegisterNUICallback('close', function(_, cb)
    local ok = closeUi()
    cb({ ok = ok, missing = ok and {} or missingEssentials() })
    if ok and ui.wasSetup then
        ui.wasSetup = false
        lib.notify({ type = 'success', description = ('Keys saved. Change them anytime with /%s'):format(C.command) })
    end
end)

local function load(cb)
    lib.callback('vr-keybinds:load', false, function(res)
        binds = {}
        if type(res) == 'table' then
            isAdmin = res.admin == true
            if type(res.binds) == 'table' then
                for id, b in pairs(res.binds) do
                    local clean = type(id) == 'string' and cleanBind(b)
                    if clean then binds[id] = clean end
                end
            end
        end
        loaded = true
        rebuild()
        if cb then cb() end
    end)
end

local function settled()
    return not IsNuiFocused() and IsScreenFadedIn() and not IsPlayerSwitchInProgress() and loggedIn == true
end

local checking = false
local function checkSetup()
    if checking then return end
    checking = true
    CreateThread(function()
        local stable = 0
        local tries = 0
        while not loaded and tries < 200 do
            Wait(100)
            tries = tries + 1
        end
        while stable < 20 do
            Wait(100)
            if settled() then stable = stable + 1 else stable = 0 end
            if loggedIn ~= true then
                checking = false
                return
            end
        end
        checking = false
        if #missingEssentials() > 0 then
            ui.wasSetup = true
            openUi('setup')
        end
    end)
end

Bridge.on('playerLoaded', function()
    loggedIn = true
    checkSetup()
end)

Bridge.on('playerUnloaded', function()
    loggedIn = false
    releaseAll()
    if ui.open then
        ui.open = false
        ui.mode = nil
        SetNuiFocus(false, false)
        sendUi('close', {})
    end
end)

RegisterNetEvent('vr-keybinds:reset', function()
    if GetInvokingResource() then return end
    releaseAll()
    load(function() checkSetup() end)
end)

RegisterCommand(C.command, function()
    if loggedIn ~= true then return end
    openUi('menu')
end, false)

own['vr-keybinds:menu'] = { onPressed = function() openUi('menu') end }

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    load(function()
        register({ id = 'vr-keybinds:menu', label = 'Open key bindings', description = ('Same as /%s'):format(C.command), order = 900 }, GetCurrentResourceName())
        if loggedIn == true then checkSetup() end
    end)
    TriggerEvent('chat:addSuggestion', '/' .. C.command, 'Change your key bindings')
end)

exports('register', function(def)
    local owner = GetInvokingResource() or GetCurrentResourceName()
    return register(def, owner)
end)

exports('unregister', function(id)
    local a = actions[id]
    if not a or a.owner ~= (GetInvokingResource() or GetCurrentResourceName()) then return false end
    actions[id] = nil
    if down[id] then down[id] = nil end
    rebuild()
    refreshUi()
    return true
end)

exports('getBind', function(id)
    local b = binds[id]
    return b and { k = b.k, m = b.m } or nil
end)

exports('getKeyLabel', function(id)
    return K.label(binds[id])
end)

exports('isDown', function(id)
    return down[id] == true
end)

exports('setBind', function(id, bind, mode)
    local ok, reason, other = setBind(id, bind, mode)
    refreshUi()
    return ok, reason, other, other and actions[other] and actions[other].label or nil
end)

exports('labelFor', function(bind)
    return K.label(cleanBind(bind))
end)

exports('checkBind', function(id, bind)
    local b = cleanBind(bind)
    if not b then
        local k = type(bind) == 'table' and tonumber(bind.k)
        return { ok = false, reason = 'blocked', why = k and C.blocked[k] or 'Not allowed' }
    end
    local other = conflictFor(id, b)
    return {
        ok = other == nil,
        reason = other and 'conflict' or nil,
        other = other,
        otherLabel = other and actions[other] and actions[other].label or nil,
        gta = C.gta[b.k],
        label = K.label(b),
    }
end)

exports('keyData', function()
    return { labels = strKeys(K.labels), modLabels = K.modLabels, blocked = strKeys(C.blocked), gta = strKeys(C.gta) }
end)

exports('open', function() openUi('menu') end)
exports('isOpen', function() return ui.open end)
