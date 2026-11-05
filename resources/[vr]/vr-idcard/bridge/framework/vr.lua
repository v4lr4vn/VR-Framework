if GetResourceState('vr-core') == 'missing' then return end

local VRCore = exports['vr-core']:GetCoreObject({ 'Functions' })

function getPlayerFramework(src)
    return exports['vr-core']:GetPlayer(src)
end

function getGradeName(src)
    local player = getPlayerFramework(src)
    if not player then return end
    return player.PlayerData.job.grade.name
end

function getPlayerLicenseData(src)
    local player = getPlayerFramework(src)
    if not player then return end
    local pd = player.PlayerData
    local ci = pd.charinfo or {}
    local height = ci.height and GetResourceState('vr-pedscale') == 'started' and exports['vr-pedscale']:FormatHeight(ci.height) or nil
    return {
        citizenid = pd.citizenid,
        firstname = ci.firstname,
        lastname = ci.lastname,
        birthdate = ci.birthdate,
        sex = ci.gender == 1 and 'F' or 'M',
        nationality = ci.nationality,
        height = height,
    }
end

function registerItemCreate(itemName)
    VRCore.Functions.CreateUseableItem(itemName, function(source, item)
        SendIDCardData(source, item)
    end)
end
