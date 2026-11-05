Speakers = {}
Systems = {}
Zones = {}
IsAdmin = false
PanelSystem = nil

local loaded = false

function Notify(msg, kind) Bridge.notify(msg, kind or 'primary') end

function ReasonText(reason, ...) return Lang.get(reason or 'bad_request', ...) end

function PlayerData() return Bridge.playerData() or {} end

function MyBucket() return LocalPlayer.state.instance or 0 end

function SpeakerInfo(sp) return DJ.itemInfo(sp.item) end

local function canUse(sp)
    if sp.owner then return Config.Boombox.anyoneCanControl or sp.owner == PlayerData().citizenid end
    if IsAdmin then return true end
    if sp.job then
        local job = PlayerData().job
        return job ~= nil and job.name == sp.job and job.onduty == true
    end
    return sp.home == true
end

local function targetOptions(sp)
    if sp.booster then
        local options = {
            {
                name = 'vr-djbooth:pickup', icon = 'fa-solid fa-hand', label = 'Pick up Range Booster', distance = 2.0,
                canInteract = function() return canUse(sp) end,
                onSelect = function() PickupSpeaker(sp.id) end,
            },
        }
        if IsAdmin then
            options[2] = {
                name = 'vr-djbooth:adminRemove', icon = 'fa-solid fa-trash', label = 'Remove Range Booster (admin)', distance = 2.5,
                onSelect = function()
                    local ok, reason = lib.callback.await('vr-djbooth:adminRemove', false, sp.id)
                    if not ok then Notify(ReasonText(reason), 'error') end
                end,
            }
        end
        return options
    end
    local options = {
        {
            name = 'vr-djbooth:open', icon = 'fa-solid fa-music', label = 'Sound system', distance = 2.5,
            canInteract = function() return canUse(sp) end,
            onSelect = function() OpenSystem(sp.system) end,
        },
        {
            name = 'vr-djbooth:pickup', icon = 'fa-solid fa-hand', label = sp.owner and 'Pick up boombox' or 'Pick up speaker', distance = 2.0,
            canInteract = function() return canUse(sp) end,
            onSelect = function() PickupSpeaker(sp.id) end,
        },
    }
    if IsAdmin and not sp.owner then
        options[#options + 1] = {
            name = 'vr-djbooth:adminRemove', icon = 'fa-solid fa-trash', label = 'Remove speaker (admin)', distance = 2.5,
            onSelect = function()
                local ok, reason = lib.callback.await('vr-djbooth:adminRemove', false, sp.id)
                if not ok then Notify(ReasonText(reason), 'error') end
            end,
        }
    end
    return options
end

local function despawn(sp)
    if sp.entity then
        Bridge.target.removeLocalEntity(sp.entity)
        if DoesEntityExist(sp.entity) then DeleteEntity(sp.entity) end
    end
    sp.entity = nil
end

function LoadModel(model)
    if not IsModelInCdimage(model) then return false end
    local ok = pcall(lib.requestModel, model, 10000)
    return ok
end

local function spawn(sp)
    local info = SpeakerInfo(sp)
    if not info or sp.spawning then return end
    sp.spawning = true
    local model = joaat(info.model)
    if not IsModelInCdimage(model) then
        sp.spawning = false
        sp.badModel = true
        return print(('^3[vr-djbooth] model %s for %s does not exist in this game build^0'):format(info.model, sp.item))
    end
    if not LoadModel(model) then
        sp.spawning = false
        return
    end
    if Speakers[sp.id] ~= sp then sp.spawning = false return SetModelAsNoLongerNeeded(model) end
    local obj = CreateObjectNoOffset(model, sp.x, sp.y, sp.z, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityHeading(obj, sp.h or 0.0)
    FreezeEntityPosition(obj, true)
    SetEntityInvincible(obj, true)
    sp.entity = obj
    sp.interior = GetInteriorAtCoords(sp.x, sp.y, sp.z)
    sp.spawning = false
    Bridge.target.addLocalEntity(obj, targetOptions(sp))
end

CreateThread(function()
    while true do
        Wait(750)
        if loaded then
            local here = GetEntityCoords(cache.ped)
            local bucket = MyBucket()
            local toSpawn = {}
            for _, sp in pairs(Speakers) do
                local want = (sp.bucket or 0) == bucket and not sp.badModel
                    and #(here - vector3(sp.x, sp.y, sp.z)) < Config.StreamDistance
                if want and not sp.entity then
                    toSpawn[#toSpawn + 1] = sp
                elseif not want and sp.entity then
                    despawn(sp)
                end
            end

            for _, sp in ipairs(toSpawn) do
                if Speakers[sp.id] == sp then spawn(sp) end
            end
        end
    end
end)

local function setSpeaker(data)
    local old = Speakers[data.id]
    if old then

        local moved = old.x ~= data.x or old.y ~= data.y or old.z ~= data.z or old.h ~= data.h or old.item ~= data.item
        if moved then despawn(old) end
        local keep = { entity = true, interior = true, spawning = true, badModel = true }
        for k in pairs(old) do
            if not keep[k] and data[k] == nil then old[k] = nil end
        end
        for k, v in pairs(data) do old[k] = v end
    else
        Speakers[data.id] = data
    end
    SpeakersChanged()
end

local function sendSystemsToUi()
    local list = {}
    for _, sys in pairs(Systems) do list[#list + 1] = sys end
    SendNUIMessage({ action = 'systems', list = list })
end

local function init()
    local data
    for _ = 1, 5 do
        data = lib.callback.await('vr-djbooth:init', false)
        if data then break end
        Wait(3500)
    end
    if not data then return end
    for _, sp in pairs(Speakers) do despawn(sp) end
    Speakers, Systems = {}, {}
    for _, sp in ipairs(data.speakers or {}) do Speakers[sp.id] = sp end
    for _, sys in ipairs(data.systems or {}) do Systems[sys.id] = sys end
    Zones = data.zones or {}
    IsAdmin = data.isAdmin == true
    SpeakersChanged()
    loaded = true
    SendNUIMessage({ action = 'config', occlusion = Config.Occlusion, master = Config.MasterVolume })
    sendSystemsToUi()
end

AddEventHandler('onClientResourceStart', function(res)
    if res ~= GetCurrentResourceName() then return end
    if Bridge.loggedIn() then CreateThread(init) end
end)

Bridge.on('playerLoaded', function() CreateThread(init) end)

Bridge.on('playerUnloaded', function()
    loaded = false
    ClosePanel()
    for _, sp in pairs(Speakers) do despawn(sp) end
    Speakers, Systems = {}, {}
    SpeakersChanged()
    SendNUIMessage({ action = 'systems', list = {} })
end)

RegisterNetEvent('vr-djbooth:client:reload', function()
    if Bridge.loggedIn() then init() end
end)

RegisterNetEvent('vr-djbooth:client:speaker', function(data)
    if type(data) == 'table' and data.id then setSpeaker(data) end
end)

RegisterNetEvent('vr-djbooth:client:speakerRemoved', function(id)
    local sp = Speakers[id]
    if sp then despawn(sp) end
    Speakers[id] = nil
    SpeakersChanged()
end)

RegisterNetEvent('vr-djbooth:client:system', function(data)
    if type(data) ~= 'table' or not data.id then return end
    Systems[data.id] = data
    SendNUIMessage({ action = 'system', data = data })
end)

RegisterNetEvent('vr-djbooth:client:systemRemoved', function(id)
    Systems[id] = nil
    SendNUIMessage({ action = 'systemRemoved', id = id })
    if PanelSystem == id then ClosePanel(true) end
end)

RegisterNetEvent('vr-djbooth:client:zones', function(list) Zones = list or {} end)

AddEventHandler('onResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, sp in pairs(Speakers) do despawn(sp) end
    if PanelSystem then SetNuiFocus(false, false) end
end)

function ShowPanel(data)
    PanelSystem = data.id
    SendNUIMessage({ action = 'panel', data = data, open = true })
    SetNuiFocus(true, true)
end

function ClosePanel(silent)
    if not PanelSystem then return end
    local id = PanelSystem
    PanelSystem = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'closePanel' })
    if not silent then TriggerServerEvent('vr-djbooth:server:close', id) end
end

function OpenSystem(systemId)
    local ok, data = lib.callback.await('vr-djbooth:open', false, systemId)
    if not ok then return Notify(ReasonText(data), 'error') end
    ShowPanel(data)
end

function PickupSpeaker(id)
    local ok, reason = lib.callback.await('vr-djbooth:pickup', false, id)
    if not ok then return Notify(ReasonText(reason), 'error') end
    if PanelSystem and not Systems[PanelSystem] then ClosePanel(true) end
end

RegisterNetEvent('vr-djbooth:client:panel', function(data)
    if PanelSystem and data and data.id == PanelSystem then
        SendNUIMessage({ action = 'panel', data = data })
    end
end)

RegisterNetEvent('vr-djbooth:client:panelClosed', function(id)
    if PanelSystem == id then ClosePanel(true) end
end)

RegisterNetEvent('vr-djbooth:client:toast', function(kind, msg)
    if PanelSystem then
        SendNUIMessage({ action = 'toast', kind = kind, text = msg })
    else
        Notify(msg, kind)
    end
end)

RegisterNUICallback('close', function(_, cb)
    ClosePanel()
    cb({})
end)

RegisterNUICallback('action', function(data, cb)
    if type(data) ~= 'table' or not PanelSystem then return cb({ ok = false, error = ReasonText('gone') }) end
    local ok, reason, extra = lib.callback.await('vr-djbooth:action', false, PanelSystem, data.action, data.data)
    if ok then return cb({ ok = true }) end
    cb({ ok = false, error = ReasonText(reason, extra) })
end)

local lastSent = {}
RegisterNUICallback('info', function(data, cb)
    cb({})
    local batch, now = {}, GetGameTimer()
    for _, item in ipairs(type(data) == 'table' and data.list or {}) do
        local sys = Systems[item.system]
        local playing = sys and sys.now
        if playing and playing.trackId == item.trackId then
            local needTitle = type(item.title) == 'string' and item.title ~= '' and playing.title ~= item.title
            local needDuration = (playing.duration or 0) == 0 and tonumber(item.duration) and item.duration ~= 0
            local key = tostring(item.system) .. ':' .. tostring(item.trackId)
            if (needTitle or needDuration) and now - (lastSent[key] or -10000) >= 5000 and #batch < 8 then
                lastSent[key] = now
                batch[#batch + 1] = { system = item.system, trackId = item.trackId, title = needTitle and item.title or nil, duration = needDuration and item.duration or nil }
            end
        end
    end
    if #batch > 0 then TriggerServerEvent('vr-djbooth:server:trackInfo', batch) end
end)

RegisterNUICallback('ended', function(data, cb)
    cb({})
    if type(data) == 'table' then TriggerServerEvent('vr-djbooth:server:trackEnded', data.system, data.trackId) end
end)

RegisterNUICallback('error', function(data, cb)
    cb({})
    if type(data) == 'table' then TriggerServerEvent('vr-djbooth:server:trackError', data.system, data.trackId, tostring(data.code)) end
end)

local pendingConfirm

function Confirm(opts)
    if pendingConfirm then return false end
    if PanelSystem then ClosePanel() end
    pendingConfirm = promise.new()
    local p = pendingConfirm
    SendNUIMessage({ action = 'confirm', title = opts.title, text = opts.text, yes = opts.yes, no = opts.no, danger = opts.danger })
    SetNuiFocus(true, true)
    local answer = Citizen.Await(p)
    SetNuiFocus(false, false)
    return answer == true
end

RegisterNUICallback('confirm', function(data, cb)
    cb({})
    local p = pendingConfirm
    pendingConfirm = nil
    if p then p:resolve(type(data) == 'table' and data.yes == true) end
end)

RegisterNUICallback('distances', function(data, cb)
    local here = GetEntityCoords(cache.ped)
    local out = {}
    for _, p in ipairs(type(data) == 'table' and data.points or {}) do
        local x, y, z = DJ.num(p.x), DJ.num(p.y), DJ.num(p.z)
        out[#out + 1] = (x and y and z) and math.floor(#(here - vector3(x, y, z)) + 0.5) or -1
    end
    cb({ list = out })
end)
