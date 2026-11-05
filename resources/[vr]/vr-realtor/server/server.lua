local function realtorJob(src, minGrade)
    local player = exports['vr-core']:GetPlayer(src)
    if not player then return end
    local job = player.PlayerData.job
    if not RealtorJobs[job.name] then return end
    if (tonumber(job.grade and job.grade.level) or 0) < (minGrade or 0) then
        TriggerClientEvent('vr-ui:notify', src, { description = 'Your grade is too low for that.', type = 'error' })
        return
    end
    return job
end

local function str(v, max)
    if type(v) ~= 'string' then return nil end
    v = v:gsub('[%c<>]', '')
    return v:sub(1, max or 255)
end

local function num(v, min, max)
    v = tonumber(v)
    if not v or v ~= v or v == math.huge or v == -math.huge then return nil end
    if min and v < min then return nil end
    if max and v > max then return nil end
    return v
end

local function coord(c)
    if type(c) ~= 'table' and type(c) ~= 'vector3' and type(c) ~= 'vector4' then return nil end
    local x, y, z = num(c.x), num(c.y), num(c.z)
    if not x or not y or not z then return nil end
    return { x = x, y = y, z = z, h = num(c.h) or 0.0, length = num(c.length, 0, 50), width = num(c.width, 0, 50) }
end

local function imgList(list)
    if type(list) ~= 'table' then return {} end
    local out = {}
    for i = 1, math.min(#list, 20) do
        local img = list[i]
        if type(img) == 'table' then
            local url = str(img.url, 512)
            if url and url:match('^https?://') then
                out[#out + 1] = { url = url, label = str(img.label, 64) or '' }
            end
        end
    end
    return out
end

local changes = {
    UpdateDescription = { perm = 'manageProperty', clean = function(d) local s = str(d.description, 2000); return s and { description = s } end },
    UpdatePrice       = { perm = 'manageProperty', clean = function(d) local p = num(d.price, 0, 1000000000); return p and { price = math.floor(p) } end },
    UpdateImgs        = { perm = 'manageProperty', clean = function(d) return { imgs = imgList(d.imgs) } end },
    UpdateShell       = { perm = 'manageProperty', clean = function(d)
        local shells = exports['vr-housing']:GetShells()
        return type(d.shell) == 'string' and shells[d.shell] and d.shell ~= 'mlo' and { shell = d.shell } or nil
    end },
    UpdateDoor        = { perm = 'manageProperty', clean = function(d)
        local door = coord(d.door)
        return door and { door = door, street = str(d.street, 100), region = str(d.region, 100) } or nil
    end },
    UpdateGarage      = { perm = 'manageProperty', clean = function(d)
        if d.garage == nil then return { garage = nil } end
        local garage = coord(d.garage)
        return garage and { garage = garage } or nil
    end },
    UpdateForSale     = { perm = 'changePropertyForSale', clean = function(d) return { forsale = d.forsale and true or false } end },
    UpdateOwner       = { perm = 'sellProperty', clean = function(d)
        local target = num(d.targetSrc, 1)
        return target and GetPlayerName(target) and { targetSrc = math.floor(target) } or nil
    end },
    DeleteProperty    = { perm = 'deleteProperty', clean = function() return {} end },
}

RegisterNetEvent("vr-realtor:server:updateProperty", function(changeType, property_id, data)
    local src = source
    local change = changes[changeType]
    if not change then return end
    if type(data) ~= 'table' then data = {} end
    if not realtorJob(src, Config.RealtorPerms[change.perm]) then return end

    local clean = change.clean(data)
    if not clean then
        TriggerClientEvent('vr-ui:notify', src, { description = 'Invalid property data.', type = 'error' })
        return
    end

    clean.realtorSrc = src
    TriggerEvent("vr-housing:server:updateProperty", changeType, property_id, clean)
end)

RegisterNetEvent("vr-realtor:server:registerProperty", function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if not realtorJob(src, Config.RealtorPerms.listNewProperty) then return end

    local shells = exports['vr-housing']:GetShells()
    local isMlo = data.propertyType == 'mlo'
    local shell = isMlo and 'mlo' or data.shell
    if type(shell) ~= 'string' or not shells[shell] then
        TriggerClientEvent('vr-ui:notify', src, { description = 'Pick an interior first.', type = 'error' })
        return
    end

    local door
    if isMlo then
        door = type(data.door_data) == 'table' and data.door_data or {}
    else
        door = coord(data.door_data)
        if not door then
            TriggerClientEvent('vr-ui:notify', src, { description = 'Place the door first.', type = 'error' })
            return
        end
        door.length = door.length or 1.5
        door.width = door.width or 2.2
        door.locked = false
    end

    local garage = data.garage_data and coord(data.garage_data) or nil

    local zone
    if type(data.zone_data) == 'table' and type(data.zone_data.points) == 'table' then
        local points = {}
        for i = 1, math.min(#data.zone_data.points, 64) do
            local p = coord(data.zone_data.points[i])
            if p then points[#points + 1] = { x = p.x, y = p.y, z = p.z } end
        end
        zone = { points = points, thickness = num(data.zone_data.thickness, 0, 100) or 4.0 }
    end

    exports['vr-housing']:registerProperty({
        street = str(data.street, 100) or 'Unknown',
        region = str(data.region, 100) or 'Unknown',
        description = str(data.description, 2000) or '',
        for_sale = data.for_sale ~= false and data.for_sale ~= 0,
        price = math.floor(num(data.price, 0, 1000000000) or 0),
        shell = shell,
        door_data = door,
        garage_data = garage,
        zone_data = zone,
    }, true, src)
end)

RegisterNetEvent("vr-realtor:server:addTenantToApartment", function(data)
    local src = source
    if type(data) ~= 'table' then return end
    if not realtorJob(src, Config.RealtorPerms.setApartments) then return end

    TriggerEvent("vr-housing:server:addTenantToApartment", {
        apartment = str(data.apartment, 50),
        targetSrc = num(data.targetSrc, 1),
        realtorSrc = src,
    })
end)

lib.callback.register("vr-realtor:server:getNames", function(source, data)
    if not realtorJob(source) or type(data) ~= 'table' then return false end

    local names = {}
    for i = 1, math.min(#data, 100) do
        local citizenid = data[i]
        local name = "Unknown"
        if type(citizenid) == 'string' then
            local online = exports['vr-core']:GetPlayerByCitizenId(citizenid)
            local charinfo
            if online then
                charinfo = online.PlayerData.charinfo
            else
                local raw = MySQL.scalar.await('SELECT charinfo FROM vr_players WHERE citizenid = ? LIMIT 1', { citizenid })
                local ok, decoded = pcall(json.decode, raw or '')
                charinfo = ok and decoded or nil
            end
            if type(charinfo) == 'table' and charinfo.firstname then
                name = charinfo.firstname .. " " .. (charinfo.lastname or '')
            end
        end
        names[#names + 1] = name
    end

    return names
end)

if Config.UseItem then
    exports('useTablet', function(event, item, inventory)
        if event == 'usingItem' then
            TriggerClientEvent("vr-realtor:client:toggleUI", inventory.id)
        end
    end)
end
