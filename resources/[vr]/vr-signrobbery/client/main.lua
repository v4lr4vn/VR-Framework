local gone = {}
local busy = false
local holding = nil     -- index of the sign being carried
local prop = nil

for i, sign in ipairs(Config.Signs) do
    sign.hash = joaat(sign.model)
    sign.index = i
end

local WHY = {
    gone = 'Someone already took this sign',
    cooldown = 'Lay low for a bit before taking another sign',
    limit = "You've taken enough signs for now",
    full = "You can't carry this sign",
}

local function say(text, kind) lib.notify({ description = text, type = kind or 'inform' }) end

-- Signs that were stolen stay gone for everyone, including people who join later.
local function hideSign(entry)
    local c = entry.coords
    local e = GetClosestObjectOfType(c.x, c.y, c.z, 1.0, entry.model, false, false, false)
    if e ~= 0 and DoesEntityExist(e) then
        SetEntityAsMissionEntity(e, true, true)
        DeleteObject(e)
    end
end

local function refresh() gone = lib.callback.await('vr-signrobbery:list', false) or {} end
AddEventHandler('onClientResourceStart', function(res) if res == GetCurrentResourceName() then refresh() end end)

RegisterNetEvent('vr-signrobbery:client:gone', function(entry)
    if GetInvokingResource() or type(entry) ~= 'table' or not entry.coords then return end
    entry.coords = vector3(entry.coords.x, entry.coords.y, entry.coords.z)
    gone[#gone + 1] = entry
    hideSign(entry)
end)

CreateThread(function()
    while true do
        local pos = GetEntityCoords(PlayerPedId())
        for i = 1, #gone do
            local c = gone[i].coords
            if c and #(pos - vector3(c.x, c.y, c.z)) < 200.0 then hideSign(gone[i]) end
        end
        Wait(1500)
    end
end)

-- Stealing -----------------------------------------------------------------------------------
local function steal(sign, entity)
    if busy or holding or not DoesEntityExist(entity) then return end
    busy = true
    local ok, info = lib.callback.await('vr-signrobbery:begin', false, sign.index, GetEntityCoords(entity))
    if not ok then
        if WHY[info] then say(WHY[info], 'error') end
        busy = false
        return
    end

    if Config.Steal.skillCheck and not lib.skillCheck(Config.Steal.skillCheck) then
        lib.callback.await('vr-signrobbery:abort', false)
        say('You fumbled the bolts', 'error')
        busy = false
        return
    end

    local finished = lib.progressBar({
        duration = info,
        label = ('Stealing %s...'):format(sign.label),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'amb@prop_human_bum_bin@base', clip = 'base', flag = 49 },
    })
    if not finished then
        lib.callback.await('vr-signrobbery:abort', false)
        busy = false
        return
    end

    local got, why = lib.callback.await('vr-signrobbery:complete', false)
    if got then
        if DoesEntityExist(entity) then
            SetEntityAsMissionEntity(entity, true, true)
            DeleteEntity(entity)
        end
    elseif WHY[why] then
        say(WHY[why], 'error')
    end
    busy = false
end

CreateThread(function()
    for _, sign in ipairs(Config.Signs) do
        Bridge.target.addModel(sign.model, {
            {
                name = 'vr-signrobbery:steal:' .. sign.item,
                icon = 'fas fa-user-secret',
                label = 'Steal Sign',
                distance = Config.Steal.distance,
                canInteract = function() return not busy and not holding end,
                onSelect = function(data) steal(sign, data.entity) end,
            },
        })
    end
end)

-- Carrying -----------------------------------------------------------------------------------
local DICT, CLIP = 'amb@world_human_janitor@male@base', 'base'

local function drop()
    if prop and DoesEntityExist(prop) then DeleteEntity(prop) end
    prop, holding = nil, nil
    StopAnimTask(PlayerPedId(), DICT, CLIP, 1.0)
end

local function carry(sign)
    local ped = PlayerPedId()
    if not lib.requestAnimDict(DICT, 5000) or not lib.requestModel(sign.hash, 5000) then return end
    local at = GetEntityCoords(ped)
    prop = CreateObject(sign.hash, at.x, at.y, at.z + 0.2, true, true, true)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, 57005), 0.10, -1.0, 0.0, -90.0, -250.0, 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(sign.hash)
    TaskPlayAnim(ped, DICT, CLIP, 8.0, 1.0, -1, 49, 0, false, false, false)
    holding = sign.index

    CreateThread(function()
        local n = 0
        while holding == sign.index do
            Wait(1000)
            n = n + 1
            if holding ~= sign.index then break end
            if IsEntityDead(PlayerPedId()) or not IsEntityPlayingAnim(PlayerPedId(), DICT, CLIP, 3) then
                drop()
            elseif n % 4 == 0 and (lib.callback.await('vr-signrobbery:count', false, sign.item) or 0) < 1 then
                drop()
            end
        end
    end)
end

RegisterNetEvent('vr-signrobbery:client:hold', function(index)
    if GetInvokingResource() then return end
    local sign = Config.Signs[tonumber(index) or 0]
    if not sign then return end
    if holding then
        local same = holding == sign.index
        drop()
        if same then return end
    end
    carry(sign)
end)

AddEventHandler('onResourceStop', function(res)
    if res == GetCurrentResourceName() and prop and DoesEntityExist(prop) then DeleteEntity(prop) end
end)

-- Scrapping ----------------------------------------------------------------------------------
local function scrap(sign)
    if busy then return end
    busy = true
    if holding == sign.index then drop() end
    local finished = lib.progressBar({
        duration = 1500,
        label = ('Scrapping %s...'):format(sign.label),
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = { dict = 'mp_common', clip = 'givetake2_a', flag = 48 },
    })
    if finished and lib.callback.await('vr-signrobbery:scrap', false, sign.item) then
        say(('Scrapped the %s'):format(sign.label), 'success')
    end
    busy = false
end

local function menu()
    local options = {}
    for _, sign in ipairs(Config.Signs) do
        local n = lib.callback.await('vr-signrobbery:count', false, sign.item) or 0
        options[#options + 1] = {
            title = sign.label,
            description = n > 0 and ('Trade for materials (%d)'):format(n) or "You don't have one",
            icon = 'fas fa-recycle',
            disabled = n < 1,
            onSelect = function() scrap(sign) end,
        }
    end
    lib.registerContext({ id = 'vr-signrobbery:scrap', title = 'Sign Scrapping', options = options })
    lib.showContext('vr-signrobbery:scrap')
end

CreateThread(function()
    Bridge.target.addSphereZone({
        name = 'vr-signrobbery:scrap',
        coords = Config.Scrap.coords,
        radius = Config.Scrap.radius,
        options = {
            { name = 'vr-signrobbery:scrap', icon = 'fas fa-recycle', label = 'Scrap Sign', distance = Config.Scrap.radius, onSelect = menu },
        },
    })
end)
