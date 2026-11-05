local function getVehicles(cid)
    if not TableExists(Config.VehicleTable) then return {} end

    local result = MySQL.query.await(
        ('SELECT vehicle, plate, fuel, engine, body FROM `%s` WHERE citizenid = ?'):format(Config.VehicleTable), { cid })
    local vehicles = {}

    for k, v in pairs(result or {}) do
        local vehicleData = exports['vr-core']:GetShared('Vehicles', v.vehicle)

        if vehicleData then
            vehicles[#vehicles + 1] = {
                id = k,
                cid = cid,
                label = vehicleData.name,
                brand = vehicleData.brand,
                model = vehicleData.model,
                plate = v.plate,
                fuel = v.fuel,
                engine = v.engine,
                body = v.body
            }
        end
    end

    return vehicles
end

local function getPlayers()
    local players = {}
    local list = VRCore.Functions.GetPlayers()

    for i = 1, #list do
        local k = list[i]
        local player = VRCore.Functions.GetPlayer(k)
        local playerData = player and player.PlayerData

        if playerData then
            players[#players + 1] = {
                id = k,
                name = playerData.charinfo.firstname .. ' ' .. playerData.charinfo.lastname,
                cid = playerData.citizenid,
                license = VRCore.Functions.GetIdentifier(k, 'license'),
                discord = VRCore.Functions.GetIdentifier(k, 'discord'),
                steam = VRCore.Functions.GetIdentifier(k, 'steam'),
                job = playerData.job.label,
                grade = playerData.job.grade.level,
                dob = playerData.charinfo.birthdate,
                cash = playerData.money.cash,
                bank = playerData.money.bank,
                phone = playerData.charinfo.phone,
                vehicles = getVehicles(playerData.citizenid)
            }
        end
    end

    table.sort(players, function(a, b) return a.id < b.id end)

    return players
end

lib.callback.register('vr-adminmenu:callback:GetPlayers', function(source)
    if not HasPerms(source, Config.MenuPerms) then return {} end
    return getPlayers()
end)

local function resolveGrade(grades, input)
    if type(grades) ~= 'table' or input == nil then return nil, nil end

    local key = tonumber(input)
    if key and grades[tostring(math.floor(key))] then
        return grades[tostring(math.floor(key))], math.floor(key)
    end

    for k, v in pairs(grades) do
        if type(v) == 'table' and v.name and tostring(v.name):lower() == tostring(input):lower() then
            return v, tonumber(k)
        end
    end

    return nil, nil
end

RegisterNetEvent('vr-adminmenu:server:SetJob', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:SetJob', selectedData) then return end

    local playerId, Player = GetTargetPlayer(Field(selectedData, "Player"))
    local Job, Grade = Field(selectedData, "Job"), Field(selectedData, "Grade")
    if not playerId then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error')
    end
    if not CanActOn(src, playerId) then return end

    local jobInfo = type(Job) == 'string' and exports['vr-core']:GetShared('Jobs', Job:lower()) or nil
    if not jobInfo then
        return VRCore.Functions.Notify(src, locale("invalid_job"), 'error')
    end

    local grade, gradeValue = resolveGrade(jobInfo.grades, Grade)
    if not grade then
        return VRCore.Functions.Notify(src, locale("invalid_grade"), 'error')
    end

    if not Player.Functions.SetJob(Job:lower(), gradeValue) then
        return VRCore.Functions.Notify(src, locale("invalid_job"), 'error')
    end

    if Config.RenewedPhone then
        CallExport('phone', 'hireUser', Job:lower(), Player.PlayerData.citizenid, gradeValue)
    end

    VRCore.Functions.Notify(src, locale("jobset", FullName(Player), Job, gradeValue), 'success', 5000)
end)

RegisterNetEvent('vr-adminmenu:server:SetGang', function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:SetGang', selectedData) then return end

    local playerId, Player = GetTargetPlayer(Field(selectedData, "Player"))
    local Gang, Grade = Field(selectedData, "Gang"), Field(selectedData, "Grade")
    if not playerId then
        return VRCore.Functions.Notify(src, locale("not_online"), 'error')
    end
    if not CanActOn(src, playerId) then return end

    local gangInfo = type(Gang) == 'string' and exports['vr-core']:GetShared('Gangs', Gang:lower()) or nil
    if not gangInfo then
        return VRCore.Functions.Notify(src, locale("invalid_gang"), 'error')
    end

    local grade, gradeValue = resolveGrade(gangInfo.grades, Grade)
    if not grade then
        return VRCore.Functions.Notify(src, locale("invalid_grade"), 'error')
    end

    if not Player.Functions.SetGang(Gang:lower(), gradeValue) then
        return VRCore.Functions.Notify(src, locale("invalid_gang"), 'error')
    end

    VRCore.Functions.Notify(src, locale("gangset", FullName(Player), Gang, gradeValue), 'success', 5000)
end)

RegisterNetEvent("vr-adminmenu:server:SetPerms", function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:SetPerms', selectedData) then return end

    local rank = Field(selectedData, "Permissions")
    local targetId, tPlayer = GetTargetPlayer(Field(selectedData, "Player"))

    if not targetId then
        return VRCore.Functions.Notify(src, locale("not_online"), "error", 5000)
    end

    local wanted = type(rank) == 'string' and RankOf(rank) or nil
    if not wanted or IsAllowedValue('vr-adminmenu:server:SetPerms', 'Permissions', rank) == false then
        return VRCore.Functions.Notify(src, locale("invalid_perms"), "error", 5000)
    end

    local own = GetRank(src)
    if own < 3 and wanted >= own then
        return VRCore.Functions.Notify(src, locale("perms_too_high"), "error", 5000)
    end
    if not CanActOn(src, targetId) then return end

    VRCore.Functions.AddPermission(targetId, rank)
    VRCore.Functions.Notify(src, locale("player_perms", FullName(tPlayer), rank), 'success', 5000)
    VRCore.Functions.Notify(targetId, locale("player_perms", FullName(tPlayer), rank), 'success', 5000)
end)

RegisterNetEvent("vr-adminmenu:server:RemoveStress", function(_, selectedData)
    local src = source
    if not Authorize(src, 'vr-adminmenu:server:RemoveStress', selectedData) then return end

    local picked = Field(selectedData, 'Player (Optional)')
    local targetId, tPlayer = GetTargetPlayer(picked ~= nil and picked ~= '' and picked or src)

    if not targetId then
        return VRCore.Functions.Notify(src, locale("not_online"), "error", 5000)
    end

    tPlayer.Functions.SetMetaData('stress', 0)
    TriggerClientEvent('hud:client:UpdateStress', targetId, 0)

    VRCore.Functions.Notify(targetId, locale("removed_stress_player"), 'success', 5000)
    if targetId ~= src then
        VRCore.Functions.Notify(src, locale("removed_stress_player"), 'success', 5000)
    end
end)
