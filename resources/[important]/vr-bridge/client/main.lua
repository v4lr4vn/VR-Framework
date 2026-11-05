local U = Bridge.util
local C = Bridge.framework ~= 'none' and Bridge.include(('client/framework/%s.lua'):format(Bridge.framework)) or {}
Bridge.fw = C

local cached

local function refresh()
    if not C.playerData then return nil end
    local ok, pd = pcall(C.playerData)
    cached = ok and pd or nil
    return cached
end

if C.listen then
    C.listen(function(name, a, ...)
        if name == 'playerData' then cached = a
        elseif name == 'playerUnloaded' then cached = nil
        elseif name == 'jobChanged' or name == 'gangChanged' or name == 'dutyChanged' or name == 'moneyChanged' then refresh() end
        Bridge.emit(name, a, ...)
    end)
end

function Bridge.playerData(fresh)
    if fresh or not cached then return refresh() end
    return cached
end

function Bridge.loggedIn()
    if C.loggedIn then
        local ok, res = pcall(C.loggedIn)
        if ok then return res == true end
    end
    return Bridge.playerData() ~= nil
end

function Bridge.cid()
    local pd = Bridge.playerData()
    return pd and pd.cid or nil
end

function Bridge.job()
    local pd = Bridge.playerData()
    return pd and pd.job or nil
end

function Bridge.gang()
    local pd = Bridge.playerData()
    return pd and pd.gang or nil
end

function Bridge.money(account)
    local pd = Bridge.playerData(true)
    if not pd then return 0 end
    if account == 'money' then account = 'cash' end
    return tonumber(pd.money and pd.money[account or 'cash']) or 0
end

function Bridge.getMeta(key)
    local pd = Bridge.playerData(true)
    local md = pd and pd.metadata or {}
    if key == nil then return md end
    return md[key]
end

function Bridge.needs()
    if C.needs then
        local ok, res = pcall(C.needs)
        if ok and type(res) == 'table' then return res end
    end
    local md = Bridge.getMeta() or {}
    return { hunger = tonumber(md.hunger), thirst = tonumber(md.thirst), stress = tonumber(md.stress) }
end

local function matchGroup(filter, name, grade)
    if not name then return false end
    local kind = type(filter)
    if kind == 'string' then return filter == name end
    if kind ~= 'table' then return false end
    if filter[1] ~= nil then
        for i = 1, #filter do
            if filter[i] == name then return true end
        end
        return false
    end
    local need = filter[name]
    if type(need) == 'table' then
        for _, g in ipairs(need) do if tonumber(g) == tonumber(grade) then return true end end
        return false
    end
    return need ~= nil and (tonumber(grade) or 0) >= (tonumber(need) or 0)
end
Bridge.matchGroup = matchGroup

function Bridge.hasGroup(filter, onduty)
    local pd = Bridge.playerData()
    if not pd then return false end
    if pd.job and matchGroup(filter, pd.job.name, pd.job.grade) and (not onduty or pd.job.onduty) then return pd.job.name, pd.job.grade end
    if pd.gang and matchGroup(filter, pd.gang.name, pd.gang.grade) then return pd.gang.name, pd.gang.grade end
    return false
end

function Bridge.groups()
    local pd = Bridge.playerData()
    local out = {}
    if pd and pd.job then out[pd.job.name] = pd.job.grade end
    if pd and pd.gang then out[pd.gang.name] = pd.gang.grade end
    return out
end

Bridge.cache = setmetatable({}, {
    __index = function(_, key)
        if key == 'ped' then return PlayerPedId() end
        if key == 'playerId' then return PlayerId() end
        if key == 'serverId' then return GetPlayerServerId(PlayerId()) end
        if key == 'vehicle' then
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
            return veh ~= 0 and veh or nil
        end
        if key == 'seat' then
            local veh = GetVehiclePedIsIn(PlayerPedId(), false)
            if veh == 0 then return nil end
            for seat = -1, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                if GetPedInVehicleSeat(veh, seat) == PlayerPedId() then return seat end
            end
            return nil
        end
        if key == 'coords' then return GetEntityCoords(PlayerPedId()) end
    end,
})

function Bridge.notify(msg, kind, ms, title)
    if type(msg) == 'table' then
        title, kind, ms, msg = msg.title, msg.type or kind, msg.duration or ms, msg.description or msg.message
    end
    local mode = GetConvar('vr_bridge:notify', BridgeConfig.notify or 'auto')
    if (mode == 'auto' or mode == 'vr-ui') and U.started('vr-ui') then
        if title then return exports['vr-ui']:Notify({ title = title, description = msg, type = kind, duration = ms }) end
        return exports['vr-ui']:Notify(msg, kind, ms)
    end
    if (mode == 'auto' or mode == 'ox_lib') and U.started('ox_lib') then
        return TriggerEvent('ox_lib:notify', { title = title, description = msg, type = kind == 'primary' and 'inform' or kind, duration = ms })
    end
    if C.notify then return C.notify(msg, kind, ms) end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(tostring(msg))
    EndTextCommandThefeedPostTicker(false, true)
end

local textUIOpen = false
local textUIText

local function nativeTextUI()
    CreateThread(function()
        while textUIOpen == 'native' do
            BeginTextCommandDisplayHelp('STRING')
            AddTextComponentSubstringPlayerName(textUIText or '')
            EndTextCommandDisplayHelp(0, false, false, -1)
            Wait(0)
        end
    end)
end

Bridge.textUI = {}

function Bridge.textUI.show(text, opts)
    local mode = GetConvar('vr_bridge:textUI', BridgeConfig.textUI or 'auto')
    textUIText = text
    if (mode == 'auto' or mode == 'vr-ui') and U.started('vr-ui') then
        textUIOpen = 'ui'
        return exports['vr-ui']:showTextUI(text, opts)
    end
    if (mode == 'auto' or mode == 'ox_lib') and U.started('ox_lib') then
        textUIOpen = 'ox'
        return exports.ox_lib:showTextUI(text, opts)
    end
    if mode ~= 'native' and C.textUI and C.textUI.show then
        textUIOpen = 'fw'
        return C.textUI.show(text)
    end
    local wasOpen = textUIOpen == 'native'
    textUIOpen = 'native'
    if not wasOpen then nativeTextUI() end
end

function Bridge.textUI.hide()
    if textUIOpen == 'ui' then exports['vr-ui']:hideTextUI()
    elseif textUIOpen == 'ox' then exports.ox_lib:hideTextUI()
    elseif textUIOpen == 'fw' and C.textUI and C.textUI.hide then C.textUI.hide() end
    textUIOpen = false
end

function Bridge.textUI.isOpen() return textUIOpen ~= false end

local function waitFor(check, timeout)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not check() do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

function Bridge.requestModel(model, timeout)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then error(('[vr-bridge] invalid model %s'):format(tostring(model)), 2) end
    if HasModelLoaded(hash) then return hash end
    RequestModel(hash)
    if not waitFor(function() return HasModelLoaded(hash) end, timeout) then error(('[vr-bridge] model %s timed out'):format(tostring(model)), 2) end
    return hash
end

function Bridge.requestAnimDict(dict, timeout)
    if not DoesAnimDictExist(dict) then error(('[vr-bridge] invalid anim dict %s'):format(tostring(dict)), 2) end
    if HasAnimDictLoaded(dict) then return dict end
    RequestAnimDict(dict)
    if not waitFor(function() return HasAnimDictLoaded(dict) end, timeout) then error(('[vr-bridge] anim dict %s timed out'):format(dict), 2) end
    return dict
end

Bridge.include('client/inventory.lua')
Bridge.include('client/vehicle.lua')
Bridge.include('client/voice.lua')
Bridge.include('client/target.lua')

function Bridge.exportAs(name, fn, aliases)
    exports(name, fn)
    for _, res in ipairs(aliases or {}) do
        AddEventHandler(('__cfx_export_%s_%s'):format(res, name), function(setCB) setCB(fn) end)
    end
end

return true
