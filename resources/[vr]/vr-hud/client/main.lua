local PlayerData = Bridge.playerData() or {}
local loggedIn = Bridge.loggedIn()
local serverId = GetPlayerServerId(PlayerId())

local KVP = 'vrhud:v2'
local STAT_KEYS = { 'health', 'armor', 'hunger', 'thirst', 'stamina', 'oxygen', 'stress' }
local MODES = { always = true, auto = true, off = true }

local settings = json.decode(json.encode(Config.Defaults))
local layout = {}
local mapRect
local panelOpen = false
local uiReady = false
local gearsUnlocked = Config.GearsUnlocked

local st = { hunger = 100, thirst = 100, stress = 0, seatbelt = false, harness = 0 }
local last = {}
local fuelBlacklist = {}
for _, m in ipairs(Config.FuelBlacklist) do fuelBlacklist[joaat(m)] = true end

local function clamp(v, fallback, lo, hi)
    v = tonumber(v)
    if not v or v ~= v then return fallback end
    return math.max(lo or 0, math.min(hi or 100, v))
end

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

local function cleanSettings(s)
    if type(s) ~= 'table' then return nil end
    local out = json.decode(json.encode(Config.Defaults))
    if type(s.stats) == 'table' then
        for _, k in ipairs(STAT_KEYS) do
            local v = s.stats[k]
            if type(v) == 'table' then
                if MODES[v.mode] then out.stats[k].mode = v.mode end
                out.stats[k].at = math.floor(clamp(v.at, out.stats[k].at, 1, 100))
            end
        end
    end
    for _, k in ipairs({ 'mapOnFoot', 'compassOnFoot', 'postal', 'gears' }) do
        if type(s[k]) == 'boolean' then out[k] = s[k] end
    end
    if s.unit == 'mph' or s.unit == 'kph' then out.unit = s.unit end
    return out
end

local function cleanLayout(l)
    local out = {}
    if type(l) ~= 'table' then return out end
    local ids = { 'map', 'status', 'vehicle', 'voice', 'street' }
    for _, k in ipairs(STAT_KEYS) do ids[#ids + 1] = 'stat_' .. k end
    for _, id in ipairs(ids) do
        local p = l[id]
        if type(p) == 'table' and tonumber(p.x) and tonumber(p.y) then
            out[id] = { x = clamp(p.x, 0, 0, 1), y = clamp(p.y, 0, 0, 1) }
        end
    end
    return out
end

local function cleanRect(r)
    if type(r) ~= 'table' then return nil end
    local x, y, w, h = tonumber(r.x), tonumber(r.y), tonumber(r.w), tonumber(r.h)
    if not (x and y and w and h) or w <= 0 or h <= 0 then return nil end
    return { x = clamp(x, 0, 0, 1), y = clamp(y, 0, 0, 1), w = clamp(w, 0.1, 0.01, 1), h = clamp(h, 0.1, 0.01, 1) }
end

local function saveKvp()
    SetResourceKvp(KVP, json.encode({ settings = settings, layout = layout, map = mapRect }))
end

local function loadKvp()
    local raw = GetResourceKvpString(KVP)
    if not raw then return end
    local ok, data = pcall(json.decode, raw)
    if not ok or type(data) ~= 'table' then return end
    settings = cleanSettings(data.settings) or settings
    layout = cleanLayout(data.layout)
    mapRect = cleanRect(data.map)
end

local function readNeeds(n)
    if type(n) ~= 'table' then return end
    st.hunger = clamp(n.hunger, st.hunger)
    st.thirst = clamp(n.thirst, st.thirst)
    st.stress = clamp(n.stress, st.stress)
    Stress.value = st.stress
end

local function readMeta(data)
    local meta = data and data.metadata
    if not meta then return end
    readNeeds(Bridge.needs())
end

local function readFuel(veh)
    return clamp(Bridge.vehicle.getFuel(veh), 0)
end

local function harnessCount()
    return Bridge.inventory.count(Config.HarnessItem)
end

local function onLoaded()
    Wait(2000)
    PlayerData = Bridge.playerData(true) or {}
    loggedIn = Bridge.loggedIn()
    readMeta(PlayerData)
    if mapRect then Minimap.apply() end
end

Bridge.on('playerLoaded', function()
    loggedIn = true
    CreateThread(onLoaded)
end)
AddEventHandler('onResourceStart', function(name)
    if name == GetCurrentResourceName() then CreateThread(onLoaded) end
end)
Bridge.on('playerUnloaded', function()
    PlayerData = {}
    loggedIn = false
end)
Bridge.on('playerData', function(val)
    PlayerData = val or {}
    readMeta(PlayerData)
end)
Bridge.on('needs', readNeeds)

RegisterNetEvent('hud:client:UpdateNeeds', function(hunger, thirst)
    st.hunger = clamp(hunger, st.hunger)
    st.thirst = clamp(thirst, st.thirst)
end)

RegisterNetEvent('hud:client:UpdateStress', function(v)
    st.stress = clamp(v, st.stress)
    Stress.value = st.stress
end)

for _, key in ipairs({ 'hunger', 'thirst', 'stress' }) do
    AddStateBagChangeHandler(key, ('player:%s'):format(serverId), function(_, _, value)
        st[key] = clamp(value, st[key])
        if key == 'stress' then Stress.value = st.stress end
    end)
end

RegisterNetEvent('seatbelt:client:ToggleSeatbelt', function()
    st.seatbelt = not st.seatbelt
    Stress.seatbelt = st.seatbelt
end)

RegisterNetEvent('hud:client:UpdateHarness', function(hp) st.harness = tonumber(hp) or 0 end)

RegisterNetEvent('hud:client:ShowAccounts', function(kind, amount)
    local text = (kind == 'bank' and Config.Notify.bank or Config.Notify.cash):format(math.floor(tonumber(amount) or 0))
    Bridge.notify(text, 'primary')
end)

local function setGears(v)
    gearsUnlocked = v == true
end
RegisterNetEvent('vr-hud:client:SetGears', setGears)
exports('SetGearsUnlocked', setGears)
exports('SetSeatbelt', function(v) st.seatbelt = v == true; Stress.seatbelt = st.seatbelt end)

local function openPanel(open)
    panelOpen = open
    SetNuiFocus(open, open)
    send('panel', { open = open })
end

RegisterNUICallback('hud:ready', function(_, cb)
    uiReady = true
    send('init', {
        settings = settings,
        layout = layout,
        voiceModes = Config.VoiceModes,
    })
    cb(1)
end)

RegisterNUICallback('hud:save', function(body, cb)
    settings = cleanSettings(body and body.settings) or settings
    layout = cleanLayout(body and body.layout)
    saveKvp()
    cb(1)
end)

RegisterNUICallback('hud:map', function(body, cb)
    local r = cleanRect(body)
    if r then
        mapRect = r
        saveKvp()
        Minimap.apply(r)
    end
    cb(1)
end)

RegisterNUICallback('hud:close', function(_, cb)
    openPanel(false)
    cb(1)
end)

RegisterCommand('vrhud_menu', function() openPanel(not panelOpen) end, false)
Keybinds.add({
    name = 'menu',
    label = 'Open HUD settings',
    description = ('Same as /%s'):format(Config.Command),
    suggested = Config.OpenMenu,
    order = 10,
    onPressed = function() openPanel(not panelOpen) end,
})
RegisterCommand(Config.Command, function() openPanel(not panelOpen) end, false)

CreateThread(function()
    while true do
        HideHudComponentThisFrame(6)
        HideHudComponentThisFrame(7)
        HideHudComponentThisFrame(9)
        Wait(0)
    end
end)

local function voice(pid)
    local prox = LocalPlayer.state.proximity
    local radioOn = LocalPlayer.state.radioActive == true
    return {
        voiceIndex = prox and prox.index or 2,
        voiceMode = prox and prox.mode or 'Normal',
        radio = tonumber(LocalPlayer.state.radioChannel) or 0,
        talking = NetworkIsPlayerTalking(pid) or radioOn,
        radioTalking = radioOn,
    }
end

local streetName, nextStreet = '', 0

CreateThread(function()
    local wasLoggedIn = false
    while true do
        local inVeh = false
        if uiReady then
            local ped = PlayerPedId()
            local pid = PlayerId()
            local veh = GetVehiclePedIsIn(ped, false)
            inVeh = veh ~= 0
            local meta = PlayerData.metadata or {}
            local dead = IsEntityDead(ped) or meta.inlaststand or meta.isdead or false

            local maxHp = math.max(1, GetEntityMaxHealth(ped) - 100)
            local d = {
                visible = loggedIn and not IsPauseMenuActive(),
                id = serverId,
                dead = dead and true or false,
                health = dead and 0 or math.floor(clamp((GetEntityHealth(ped) - 100) / maxHp * 100, 0)),
                armor = math.floor(clamp(GetPedArmour(ped), 0)),
                hunger = math.floor(st.hunger),
                thirst = math.floor(st.thirst),
                stress = math.floor(st.stress),
                stamina = math.floor(clamp(100 - GetPlayerSprintStaminaRemaining(pid), 100)),
                oxygen = IsPedSwimmingUnderWater(ped) and math.floor(clamp(GetPlayerUnderwaterTimeRemaining(pid) * 10, 0)) or 100,
                inVehicle = inVeh,
                postal = Postal.nearest and Postal.nearest.code or '',
                postalDist = Postal.nearest and math.floor(Postal.nearest.dist) or 0,
                gearsUnlocked = gearsUnlocked,
            }

            if Config.UseRealTime then
                local _, _, _, h, m = GetLocalTime()
                d.time = ('%02d:%02d'):format(h, m)
            else
                d.time = ('%02d:%02d'):format(GetClockHours(), GetClockMinutes())
            end

            local now = GetGameTimer()
            if now >= nextStreet then
                nextStreet = now + 500
                local c = GetEntityCoords(ped)
                local s1 = GetStreetNameAtCoord(c.x, c.y, c.z)
                streetName = GetStreetNameFromHashKey(s1) or ''
            end
            d.street = streetName

            for k, v in pairs(voice(pid)) do d[k] = v end

            if inVeh then
                local class = GetVehicleClass(veh)
                local _, lo, hi = GetVehicleLightsState(veh)
                local ind = GetVehicleIndicatorLights(veh)
                local fwd = GetEntitySpeedVector(veh, true)
                local gear = GetVehicleCurrentGear(veh)
                local kph = GetEntitySpeed(veh) * 3.6
                d.speed = math.floor(kph + 0.5)
                d.fuel = math.floor(readFuel(veh))
                d.lowFuelAlert = not fuelBlacklist[GetEntityModel(veh)]
                d.engineOn = GetIsVehicleEngineRunning(veh)
                d.engineHealth = math.floor(clamp(GetVehicleEngineHealth(veh) / 10, 0))
                d.lights = hi and 2 or (lo and 1 or 0)
                d.left = (ind & 1) ~= 0
                d.right = (ind & 2) ~= 0
                d.gear = (gear == 0 and fwd.y < -0.5) and 'R' or ((gear == 0 or kph < 1) and 'N' or tostring(gear))
                d.noBelt = class == 8 or class == 13 or class == 14
                d.seatbelt = st.seatbelt
                d.harness = st.harness > 0
            else
                if st.seatbelt then st.seatbelt = false; Stress.seatbelt = false end
            end

            local patch, any = {}, false
            for k, v in pairs(d) do
                if last[k] ~= v then last[k] = v; patch[k] = v; any = true end
            end
            if any then send('patch', patch) end

            local wantRadar = d.visible and (inVeh or settings.mapOnFoot or panelOpen)
            if last._radar ~= wantRadar then
                last._radar = wantRadar
                Minimap.show(wantRadar)
            end
        end

        if loggedIn and not wasLoggedIn and mapRect then Minimap.apply() end
        wasLoggedIn = loggedIn
        Wait(inVeh and 100 or 250)
    end
end)

CreateThread(function()
    local sent = -999.0
    while true do
        Wait(33)
        if uiReady and (last.inVehicle or settings.compassOnFoot or panelOpen) then
            local ped = PlayerPedId()
            local cam = Config.CompassFollowsCamera and GetGameplayCamRot(0).z or GetEntityHeading(ped) * -1.0
            local h = (360.0 - ((cam + 360.0) % 360.0)) % 360.0
            local diff = math.abs(((h - sent + 540.0) % 360.0) - 180.0)
            if diff >= 0.4 then
                sent = h
                send('patch', { heading = math.floor(h * 10 + 0.5) / 10 })
            end
        end
    end
end)

CreateThread(function()
    local zone = GetSafeZoneSize()
    while true do
        Wait(2000)
        local now = GetSafeZoneSize()
        if now ~= zone then
            zone = now
            Minimap.apply()
        end
    end
end)

CreateThread(function()
    while true do
        Wait(5000)
        if loggedIn and GetVehiclePedIsIn(PlayerPedId(), false) ~= 0 then
            st.harness = harnessCount() > 0 and 1 or 0
        end
    end
end)

loadKvp()
