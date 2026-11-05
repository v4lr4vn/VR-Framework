local function weatherReady(src)
    if ResourceUp('weathersync') then return true end
    VRCore.Functions.Notify(src, locale("missing_resource", tostring(Config.Resources.weathersync)), 'error', 7500)
    return false
end

local Blackout = false
RegisterNetEvent('vr-adminmenu:server:ToggleBlackout', function()
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:ToggleBlackout') then return end
    if not weatherReady(src) then return end

    local hasState, current = CallExport('weathersync', 'getBlackoutState')
    if hasState and type(current) == 'boolean' then Blackout = current end

    local ok = CallExport('weathersync', 'setBlackout', not Blackout)
    if not ok then
        return VRCore.Functions.Notify(src, locale("missing_resource", tostring(Config.Resources.weathersync)), 'error', 7500)
    end

    Blackout = not Blackout
    VRCore.Functions.Notify(src, locale("blackout", Blackout and "enabled" or "disabled"), 'primary')
end)

RegisterNetEvent('vr-adminmenu:server:ChangeWeather', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:ChangeWeather', selectedData) then return end

    local weather = Field(selectedData, "Weather")
    if type(weather) ~= 'string' or not IsAllowedValue('vr-adminmenu:server:ChangeWeather', "Weather", weather) then
        return VRCore.Functions.Notify(src, locale("empty_input"), 'error')
    end
    if not weatherReady(src) then return end

    local ok, changed = CallExport('weathersync', 'setWeather', weather:upper())
    if ok and changed ~= false then
        VRCore.Functions.Notify(src, locale("weatherType", weather), 'success')
    else
        VRCore.Functions.Notify(src, locale("empty_input"), 'error')
    end
end)

RegisterNetEvent('vr-adminmenu:server:ChangeTime', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:ChangeTime', selectedData) then return end

    local value = Field(selectedData, "Time Events")
    local hour = tonumber(value)
    if not hour or hour < 0 or hour > 24 or hour ~= math.floor(hour)
        or IsAllowedValue('vr-adminmenu:server:ChangeTime', "Time Events", value) == false then
        return VRCore.Functions.Notify(src, locale("empty_input"), 'error')
    end
    if not weatherReady(src) then return end

    CallExport('weathersync', 'setTime', math.floor(hour) % 24, 0)
end)

RegisterNetEvent('vr-adminmenu:server:PlaySound', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:PlaySound', selectedData) then return end

    local target = GetTargetId(Field(selectedData, "Player"))
    local sound = Field(selectedData, "Sound")

    if not target then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error', 7500)
    end
    if type(sound) ~= 'string' or not IsAllowedValue('vr-adminmenu:server:PlaySound', "Sound", sound) then
        return VRCore.Functions.Notify(src, locale("empty_input"), 'error')
    end
    if not CanActOn(src, target) then return end
    if not ResourceUp('sound') then
        return VRCore.Functions.Notify(src, locale("missing_resource", tostring(Config.Resources.sound)), 'error', 7500)
    end

    TriggerClientEvent('InteractSound_CL:PlayOnOne', target, sound, 0.30)
end)
