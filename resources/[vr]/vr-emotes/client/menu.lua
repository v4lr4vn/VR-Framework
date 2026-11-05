local menu = { open = false, ready = false, built = false }
local prefs = { favs = {}, slots = {}, walk = nil, mood = nil }
local items, walks, moods = {}, {}, {}
local loaded = false
local pendingSave = nil
local SLOT_PREFIX = 'quick'

local function send(action, data)
    if menu.ready then SendNUIMessage({ action = action, data = data }) end
end

SendEmoteUi = send

local function flagsFor(entry, tbl, key)
    local o = entry.AnimationOptions or {}
    local f = {}
    local dict = entry[1]
    if dict == 'Scenario' or dict == 'MaleScenario' or dict == 'ScenarioObject' then f[#f + 1] = 'S' end
    if dict == 'MaleScenario' then f[#f + 1] = 'G' end
    if o.EmoteLoop then f[#f + 1] = 'L' end
    if o.EmoteMoving then f[#f + 1] = 'M' end
    if o.Prop then f[#f + 1] = 'P' end
    if o.PtfxAsset then f[#f + 1] = 'X' end
    if o.EmoteDuration and o.EmoteDuration > 0 then f[#f + 1] = 'T' end
    if o.NotInVehicle then f[#f + 1] = 'N' end
    if o.onlyInVehicle then f[#f + 1] = 'V' end
    if Catalog.isAdult(entry, key) then f[#f + 1] = 'A' end
    if tbl == 'Shared' then f[#f + 1] = 'W' end
    return table.concat(f)
end

local function build()
    if menu.built then return end
    menu.built = true
    items = {}
    for _, tab in ipairs(Catalog.tabs) do
        for _, tbl in ipairs(tab.tables) do
            for key, entry in pairs(RP[tbl] or {}) do
                if Catalog.allowed(entry, tbl, key) then
                    local item = { id = tbl .. ':' .. key, k = key, c = tab.id, l = StripLabel(entry[3]) or key, f = flagsFor(entry, tbl, key) }
                    if tbl == 'Shared' then
                        local other = Catalog.partner(tbl, key)
                        if other and other ~= key then item.t = StripLabel(RP.Shared[other][3]) or other end
                    end
                    if tab.id == 'custom' then item.p = tbl == 'White2do' and 'Pack 2' or tbl == 'White3ro' and 'Pack 3' or 'Pack 5' end
                    local variations = entry.AnimationOptions and entry.AnimationOptions.PropTextureVariations
                    if type(variations) == 'table' and #variations > 0 then
                        local names = {}
                        for i, v in ipairs(variations) do names[i] = StripLabel(type(v) == 'table' and v.Name or tostring(v)) or ('Option ' .. i) end
                        item.v = names
                    end
                    items[#items + 1] = item
                end
            end
        end
    end
    table.sort(items, function(a, b) return a.l:lower() < b.l:lower() end)
    walks = {}
    for key, entry in pairs(RP.Walks) do walks[#walks + 1] = { k = key, l = StripLabel(entry[2]) or key, s = entry[1] } end
    table.sort(walks, function(a, b) return a.l:lower() < b.l:lower() end)
    moods = {}
    for key, entry in pairs(RP.Expressions) do moods[#moods + 1] = { k = key, l = StripLabel(entry[2]) or key, s = entry[1] } end
    table.sort(moods, function(a, b) return a.l:lower() < b.l:lower() end)
end

local function isAnimalModel()
    local model = GetEntityModel(PlayerPedId())
    for _, list in ipairs({ BigDogs, SmallDogs }) do
        for _, m in ipairs(list) do
            if model == joaat(m) then return true end
        end
    end
    return false
end

local function slotId(i)
    return 'vr-emotes:' .. SLOT_PREFIX .. i
end

local function keyLabel(id)
    if GetResourceState('vr-keybinds') ~= 'started' then return '' end
    return exports['vr-keybinds']:getKeyLabel(id) or ''
end

local function slotKeys()
    local out = {}
    for i = 1, Config.QuickSlots do out[i] = keyLabel(slotId(i)) end
    return out
end

local function slotList()
    local out = {}
    for i = 1, Config.QuickSlots do out[i] = prefs.slots[i] or false end
    return out
end

local function favList()
    local out = {}
    for id in pairs(prefs.favs) do out[#out + 1] = id end
    return out
end

local function walkKeyFor(clipset)
    for _, w in ipairs(walks) do
        if w.s == clipset then return w.k end
    end
end

local function moodKeyFor(expression)
    for _, m in ipairs(moods) do
        if m.s == expression then return m.k end
    end
end

local function state()
    return {
        slots = slotList(),
        keys = slotKeys(),
        favs = favList(),
        walk = CurrentWalk and walkKeyFor(CurrentWalk) or false,
        mood = CurrentMood and moodKeyFor(CurrentMood) or false,
        playing = IsInAnimation and CurrentAnimationTable and CurrentAnimationName and (CurrentAnimationTable .. ':' .. CurrentAnimationName) or false,
        cancelKey = keyLabel('vr-emotes:cancel'),
        menuKey = keyLabel('vr-emotes:menu'),
    }
end

function SavePref(key, value)
    if key == 'walk' then prefs.walk = value or nil
    elseif key == 'mood' then prefs.mood = value or nil end
    pendingSave = pendingSave or {}
    pendingSave[key] = value == nil and false or value
end

CreateThread(function()
    while true do
        Wait(1500)
        if pendingSave and loaded then
            local patch = pendingSave
            pendingSave = nil
            if patch.favs then patch.favs = favList() end
            if patch.slots then patch.slots = slotList() end
            TriggerServerEvent('vr-emotes:prefs:save', patch)
        end
    end
end)

local function playSlot(i)
    local id = prefs.slots[i]
    if not id then return end
    if LocalPlayer.state.isLoggedIn ~= true or menu.open then return end
    local playing = IsInAnimation and CurrentAnimationTable and (CurrentAnimationTable .. ':' .. tostring(CurrentAnimationName))
    if playing == id then return EmoteCancel() end
    PlayEmoteById(id)
end

function OpenEmoteMenu(tab)
    if menu.open or LocalPlayer.state.isLoggedIn ~= true then return end
    if IsEntityDead(PlayerPedId()) then return EmoteChatMessage(Lang.dead) end
    build()
    menu.open = true
    local preview = Preview.start()
    local _, why = Preview.available()
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    send('open', {
        tab = tab,
        preview = preview,
        previewWhy = not preview and why or nil,
        animals = Config.AnimalEmotesEnabled and isAnimalModel(),
        state = state(),
    })
end

local function closeMenu()
    if not menu.open then return end
    menu.open = false
    Preview.stop()
    SetNuiFocus(false, false)
    send('close', {})
end

RegisterNUICallback('ready', function(_, cb)
    menu.ready = true
    build()
    cb({
        items = items,
        walks = walks,
        moods = moods,
        tabs = Catalog.tabs,
        slots = Config.QuickSlots,
        shared = Config.SharedEmotesEnabled,
        walksOn = Config.WalkingStylesEnabled,
        moodsOn = Config.ExpressionsEnabled,
        delay = Config.PreviewDelay,
    })
end)

RegisterNUICallback('close', function(_, cb)
    closeMenu()
    cb({ ok = true })
end)

RegisterNUICallback('preview', function(data, cb)
    cb({ ok = true })
    if not menu.open or type(data) ~= 'table' then return end
    if data.kind == 'walk' then Preview.walk(data.key)
    elseif data.kind == 'mood' then Preview.mood(data.key)
    elseif data.kind == 'emote' then Preview.emote(data.id)
    else Preview.idle() end
end)

RegisterNUICallback('play', function(data, cb)
    cb({ ok = true })
    if type(data) ~= 'table' or type(data.id) ~= 'string' then return end
    local entry, tbl, key = Catalog.get(data.id)
    if not entry then return end
    closeMenu()
    local variation = tonumber(data.variation)
    if tbl == 'Shared' then return RequestSharedEmote(key) end
    PlayEmoteById(data.id, variation)
end)

RegisterNUICallback('cancel', function(_, cb)
    EmoteCancel()
    cb({ ok = true, state = state() })
end)

RegisterNUICallback('walk', function(data, cb)
    if type(data) == 'table' and data.key and RP.Walks[data.key] then SetWalkByKey(data.key)
    else ResetWalk() end
    cb({ ok = true, state = state() })
end)

RegisterNUICallback('mood', function(data, cb)
    if type(data) == 'table' and data.key and RP.Expressions[data.key] then SetMoodByKey(data.key)
    else ResetMood() end
    Preview.syncMood()
    cb({ ok = true, state = state() })
end)

RegisterNUICallback('fav', function(data, cb)
    if type(data) == 'table' and Catalog.get(data.id) then
        prefs.favs[data.id] = data.on and true or nil
        SavePref('favs', true)
    end
    cb({ ok = true, state = state() })
end)

RegisterNUICallback('slot', function(data, cb)
    local i = type(data) == 'table' and tonumber(data.slot)
    if i and i >= 1 and i <= Config.QuickSlots and i == math.floor(i) then
        if data.id and Catalog.get(data.id) then
            for j = 1, Config.QuickSlots do
                if prefs.slots[j] == data.id then prefs.slots[j] = nil end
            end
            prefs.slots[i] = data.id
        else
            prefs.slots[i] = nil
        end
        SavePref('slots', true)
    end
    cb({ ok = true, state = state() })
end)

RegisterNUICallback('keyinfo', function(_, cb)
    if GetResourceState('vr-keybinds') ~= 'started' then return cb({ ok = false }) end
    cb({ ok = true, data = exports['vr-keybinds']:keyData() })
end)

RegisterNUICallback('keycheck', function(data, cb)
    local i = type(data) == 'table' and tonumber(data.slot)
    if not i or GetResourceState('vr-keybinds') ~= 'started' then return cb({ ok = false }) end
    cb(exports['vr-keybinds']:checkBind(slotId(i), data.bind))
end)

RegisterNUICallback('key', function(data, cb)
    local i = type(data) == 'table' and tonumber(data.slot)
    if not i or i < 1 or i > Config.QuickSlots or GetResourceState('vr-keybinds') ~= 'started' then return cb({ ok = false }) end
    local ok, reason, other, otherLabel = exports['vr-keybinds']:setBind(slotId(i), data.bind or nil, data.mode)
    cb({ ok = ok, reason = reason, other = other, otherLabel = otherLabel, state = state() })
end)

RegisterNUICallback('shared', function(data, cb)
    cb({ ok = true })
    if type(data) ~= 'table' then return end
    local _, tbl, key = Catalog.get(data.id)
    if not key then return end
    closeMenu()
    RequestSharedEmote(key)
end)

local function loadPrefs()
    lib.callback('vr-emotes:prefs:load', false, function(res)
        prefs = { favs = {}, slots = {}, walk = nil, mood = nil }
        if type(res) == 'table' then
            for _, id in ipairs(type(res.favs) == 'table' and res.favs or {}) do
                if type(id) == 'string' then prefs.favs[id] = true end
            end
            if type(res.slots) == 'table' then
                for i = 1, Config.QuickSlots do
                    local id = res.slots[i] or res.slots[tostring(i)]
                    if type(id) == 'string' then prefs.slots[i] = id end
                end
            end
            prefs.walk = type(res.walk) == 'string' and res.walk or nil
            prefs.mood = type(res.mood) == 'string' and res.mood or nil
        end
        loaded = true
        if LocalPlayer.state.isLoggedIn == true then
            if prefs.walk and Config.WalkingStylesEnabled then WalkMenuStart(prefs.walk, false) end
            if prefs.mood and Config.ExpressionsEnabled then SetPlayerPedExpression(prefs.mood, false) end
        end
    end)
end

RegisterNetEvent('VRCore:Client:OnPlayerLoaded', function()
    SetTimeout(2500, loadPrefs)
end)

RegisterNetEvent('VRCore:Client:OnPlayerUnload', function()
    closeMenu()
    CurrentWalk = nil
    CurrentMood = nil
end)

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    if LocalPlayer.state.isLoggedIn == true then loadPrefs() end
end)

Keybinds.add({ name = 'menu', label = 'Open the emote menu', description = 'Same as /emotes', suggested = Config.Suggested.menu, order = 1, onPressed = function() OpenEmoteMenu() end })
Keybinds.add({ name = 'cancel', label = 'Stop your emote', suggested = Config.Suggested.cancel, order = 2, onPressed = function() if IsInAnimation then EmoteCancel() end end })
if Config.HandsupEnabled then
    Keybinds.add({ name = 'handsup', label = 'Hands up', description = 'Press again to put them down', suggested = Config.Suggested.handsup, order = 20, onPressed = function() Handsup() end })
end
for i = 1, Config.QuickSlots do
    Keybinds.add({
        name = SLOT_PREFIX .. i,
        label = ('Quick emote %d'):format(i),
        description = 'Pick the emote in the emote menu, under Quick slots',
        suggested = Config.Suggested.quick[i],
        order = 100 + i,
        onPressed = function() playSlot(i) end,
    })
end

RegisterCommand('emotes', function() OpenEmoteMenu() end, false)
RegisterCommand('emotemenu', function() OpenEmoteMenu() end, false)
TriggerEvent('chat:addSuggestion', '/emotes', 'Open the emote menu')

exports('OpenMenu', function(tab) OpenEmoteMenu(tab) end)
exports('CloseMenu', closeMenu)
exports('IsMenuOpen', function() return menu.open end)
