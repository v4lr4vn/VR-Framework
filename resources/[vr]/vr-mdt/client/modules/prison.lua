local jail = { active = false, seconds = 0, months = 0, left = 0, reason = nil, endsAt = 0 }
local guardRunning = false

local function hud()
    Mdt.send({
        type = 'prison',
        active = jail.active,
        seconds = jail.active and math.max(0, math.floor((jail.endsAt - GetGameTimer()) / 1000)) or 0,
        months = jail.months,
        left = jail.left,
        perMonth = Config.Prison.secondsPerMonth,
        reason = jail.reason,
    })
end

local function spawned()
    return Bridge.loggedIn() and IsScreenFadedIn() and not IsPlayerSwitchInProgress()
end

local function waitSpawned()
    local deadline = GetGameTimer() + 120000
    while not spawned() and GetGameTimer() < deadline do Wait(250) end
end

local function teleport(v)
    local ped = Bridge.cache.ped
    DoScreenFadeOut(400)
    local deadline = GetGameTimer() + 2000
    while not IsScreenFadedOut() and GetGameTimer() < deadline do Wait(0) end
    if IsPedInAnyVehicle(ped, false) then TaskLeaveVehicle(ped, GetVehiclePedIsIn(ped, false), 16) Wait(200) end
    RequestCollisionAtCoord(v.x, v.y, v.z)
    SetEntityCoords(ped, v.x, v.y, v.z, false, false, false, false)
    SetEntityHeading(ped, v.w or 0.0)
    deadline = GetGameTimer() + 3000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(0) end
    DoScreenFadeIn(600)
end

local function outside()
    local c = GetEntityCoords(Bridge.cache.ped)
    return #(c - Config.Prison.centre) > Config.Prison.radius
end

local function guard()
    if guardRunning then return end
    guardRunning = true
    CreateThread(function()
        while jail.active do
            if spawned() and outside() and not IsPedDeadOrDying(Bridge.cache.ped, true) then
                teleport(Config.Prison.inside)
                Bridge.notify("You can't leave the prison.", 'error')
            end
            Wait(1000)
        end
        guardRunning = false
    end)
    if Config.Prison.disableWeapons then
        CreateThread(function()
            while jail.active do
                DisableControlAction(0, 37, true)
                HudWeaponWheelIgnoreSelection()
                Wait(0)
            end
        end)
    end
end

local function apply(state)
    if type(state) ~= 'table' then return end
    if state.active then
        jail.active = true
        jail.seconds = tonumber(state.seconds) or 0
        jail.endsAt = GetGameTimer() + jail.seconds * 1000
        jail.months = tonumber(state.months) or 0
        jail.left = tonumber(state.left) or 0
        jail.reason = type(state.reason) == 'string' and state.reason or nil
        hud()
        if state.teleport then
            CreateThread(function()
                waitSpawned()
                if jail.active then teleport(Config.Prison.inside) end
            end)
        end
        guard()
        return
    end
    jail.active = false
    hud()
    if state.release then
        CreateThread(function()
            waitSpawned()
            teleport(Config.Prison.release)
            Bridge.notify('You are free to go.', 'success')
        end)
    end
end

RegisterNetEvent('vr-mdt:client:prison', apply)

local function ask()
    local state = Bridge.callback.await('vr-mdt:prison:mine')
    if state then apply(state) end
end

Bridge.on('playerLoaded', function()
    SetTimeout(2000, ask)
end)

Bridge.on('playerUnloaded', function()
    jail.active = false
    hud()
end)

CreateThread(function()
    Wait(1500)
    if Bridge.loggedIn() then ask() end
end)
