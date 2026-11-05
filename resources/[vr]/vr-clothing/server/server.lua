local outfitCache = {}
local uniformCache = {}

local function getMoneyForShop(type)
    local validShopTypes = {
        ["clothing"] = Config.ClothingCost,
        ["barber"] = Config.BarberCost,
        ["tattoo"] = Config.TattooCost,
        ["surgeon"] = Config.SurgeonCost,
    }

    local shopType = validShopTypes[type]

    local money = shopType and shopType or 0

    return money
end

local function getOutfitsForPlayer(citizenid)
    outfitCache[citizenid] = {}
    local result = Database.PlayerOutfits.GetAllByCitizenID(citizenid)

    for i = 1, #result, 1 do
        outfitCache[citizenid][#outfitCache[citizenid] + 1] = {
            id = result[i].id,
            name = result[i].outfitname,
            model = result[i].model,
            components = json.decode(result[i].components),
            props = json.decode(result[i].props),
        }
    end
end

local function GenerateUniqueCode()
    local code, exists
    repeat
        code = GenerateNanoID(Config.OutfitCodeLength)
        exists = Database.PlayerOutfitCodes.GetByCode(code)
    until not exists
    return code
end

lib.callback.register("vr-clothing:server:generateOutfitCode", function(_, outfitID)
    local existingOutfitCode = Database.PlayerOutfitCodes.GetByOutfitID(outfitID)
    if not existingOutfitCode then
        local code = GenerateUniqueCode()
        local id = Database.PlayerOutfitCodes.Add(outfitID, code)
        if not id then
            print("Something went wrong while generating outfit code")
            return
        end
        return code
    end
    return existingOutfitCode.code
end)

lib.callback.register("vr-clothing:server:importOutfitCode", function(source, outfitName, outfitCode)
    local citizenID = Framework.GetPlayerID(source)
    local existingOutfitCode = Database.PlayerOutfitCodes.GetByCode(outfitCode)

    if not existingOutfitCode then
        return nil
    end

    local playerOutfit = Database.PlayerOutfits.GetByID(existingOutfitCode.outfitid)
    if not playerOutfit then
        return
    end

    if playerOutfit.citizenid == citizenID then
        return
    end

    if Database.PlayerOutfits.GetByOutfit(outfitName, citizenID) then
        return
    end

    local id = Database.PlayerOutfits.Add(citizenID, outfitName, playerOutfit.model, playerOutfit.components,
        playerOutfit.props)

    if not id then
        print("Something went wrong while importing the outfit")
        return
    end

    outfitCache[citizenID][#outfitCache[citizenID] + 1] = {
        id = id,
        name = outfitName,
        model = playerOutfit.model,
        components = json.decode(playerOutfit.components),
        props = json.decode(playerOutfit.props),
    }

    return true
end)

lib.callback.register("vr-clothing:server:getAppearance", function(source, model)
    local citizenID = Framework.GetPlayerID(source)
    return Framework.GetAppearance(citizenID, model)
end)

lib.callback.register("vr-clothing:server:hasMoney", function(source, shopType)
    local money = getMoneyForShop(shopType)

    if not Framework.HasMoney(source, "cash", money) then
        return false, money
    end

    return true, money
end)

lib.callback.register("vr-clothing:server:payForTattoo", function(source, tattoo)
    local src = source
    local cost = math.max(0, math.floor(tonumber(Config.TattooCost) or 0))

    if not Framework.RemoveMoney(src, "cash", cost) then
        lib.notify(src, {
            title = _L("purchase.tattoo.failure.title"),
            description = _L("purchase.tattoo.failure.description"),
            type = "error",
            position = Config.NotifyOptions.position,
        })
        return false
    end

    lib.notify(src, {
        title = _L("purchase.tattoo.success.title"),
        description = string.format(_L("purchase.tattoo.success.description"), tattoo.label, cost),
        type = "success",
        position = Config.NotifyOptions.position,
    })
    return true
end)

lib.callback.register("vr-clothing:server:getOutfits", function(source)
    local citizenID = Framework.GetPlayerID(source)
    if outfitCache[citizenID] == nil then
        getOutfitsForPlayer(citizenID)
    end
    return outfitCache[citizenID]
end)

lib.callback.register("vr-clothing:server:getManagementOutfits", function(source, mType, gender)
    local job = Framework.GetJob(source)
    if mType == "Gang" then
        job = Framework.GetGang(source)
    end

    local grade = tonumber(job.grade.level)
    local managementOutfits = {}
    local result = Database.ManagementOutfits.GetAllByJob(mType, job.name, gender)

    for i = 1, #result, 1 do
        if grade >= result[i].minrank then
            managementOutfits[#managementOutfits + 1] = {
                id = result[i].id,
                name = result[i].name,
                model = result[i].model,
                gender = result[i].gender,
                components = json.decode(result[i].components),
                props = json.decode(result[i].props),
            }
        end
    end
    return managementOutfits
end)

lib.callback.register("vr-clothing:server:getUniform", function(source)
    return uniformCache[Framework.GetPlayerID(source)]
end)

RegisterServerEvent("vr-clothing:server:saveAppearance", function(appearance)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    if appearance ~= nil then
        Framework.SaveAppearance(appearance, citizenID)
    end
end)

RegisterServerEvent("vr-clothing:server:chargeCustomer", function(shopType)
    local src = source
    local money = getMoneyForShop(shopType)
    if Framework.RemoveMoney(src, "cash", money) then
        lib.notify(src, {
            title = _L("purchase.store.success.title"),
            description = string.format(_L("purchase.store.success.description"), money, shopType),
            type = "success",
            position = Config.NotifyOptions.position,
        })
    else
        lib.notify(src, {
            title = _L("purchase.store.failure.title"),
            description = _L("purchase.store.failure.description"),
            type = "error",
            position = Config.NotifyOptions.position,
        })
    end
end)

RegisterNetEvent("vr-clothing:server:saveOutfit", function(name, model, components, props)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    if outfitCache[citizenID] == nil then
        getOutfitsForPlayer(citizenID)
    end
    if model and components and props then
        local id = Database.PlayerOutfits.Add(citizenID, name, model, json.encode(components), json.encode(props))
        if not id then
            return
        end
        outfitCache[citizenID][#outfitCache[citizenID] + 1] = {
            id = id,
            name = name,
            model = model,
            components = components,
            props = props,
        }
        lib.notify(src, {
            title = _L("outfits.save.success.title"),
            description = string.format(_L("outfits.save.success.description"), name),
            type = "success",
            position = Config.NotifyOptions.position,
        })
    end
end)

RegisterNetEvent("vr-clothing:server:updateOutfit", function(id, model, components, props)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    local owned = Database.PlayerOutfits.GetByID(id)
    if not owned or owned.citizenid ~= citizenID then return end
    if outfitCache[citizenID] == nil then
        getOutfitsForPlayer(citizenID)
    end
    if model and components and props then
        if not Database.PlayerOutfits.Update(id, model, json.encode(components), json.encode(props)) then
            return
        end
        local outfitName = ""
        for i = 1, #outfitCache[citizenID], 1 do
            local outfit = outfitCache[citizenID][i]
            if outfit.id == id then
                outfit.model = model
                outfit.components = components
                outfit.props = props
                outfitName = outfit.name
                break
            end
        end
        lib.notify(src, {
            title = _L("outfits.update.success.title"),
            description = string.format(_L("outfits.update.success.description"), outfitName),
            type = "success",
            position = Config.NotifyOptions.position,
        })
    end
end)

local function canManage(src, outfitType, jobName)
    local group = outfitType == "Gang" and Framework.GetGang(src) or Framework.GetJob(src)
    return group ~= nil and group.name == jobName and (group.isboss == true or (group.grade and group.grade.isboss == true))
end

RegisterNetEvent("vr-clothing:server:saveManagementOutfit", function(outfitData)
    local src = source
    if type(outfitData) ~= "table" or not canManage(src, outfitData.Type, outfitData.JobName) then return end
    local id = Database.ManagementOutfits.Add(outfitData)
    if not id then
        return
    end

    lib.notify(src, {
        title = _L("outfits.save.success.title"),
        description = string.format(_L("outfits.save.success.description"), outfitData.Name),
        type = "success",
        position = Config.NotifyOptions.position,
    })
end)

RegisterNetEvent("vr-clothing:server:deleteManagementOutfit", function(id)
    local src = source
    local outfit = MySQL.single.await("SELECT type, job_name FROM vr_clothing_job_outfits WHERE id = ?", { id })
    if not outfit or not canManage(src, outfit.type, outfit.job_name) then return end
    Database.ManagementOutfits.DeleteByID(id)
end)

RegisterNetEvent("vr-clothing:server:syncUniform", function(uniform)
    local src = source
    uniformCache[Framework.GetPlayerID(src)] = uniform
end)

RegisterNetEvent("vr-clothing:server:deleteOutfit", function(id)
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    local owned = Database.PlayerOutfits.GetByID(id)
    if not owned or owned.citizenid ~= citizenID then return end
    Database.PlayerOutfitCodes.DeleteByOutfitID(id)
    Database.PlayerOutfits.DeleteByID(id)

    for k, v in ipairs(outfitCache[citizenID] or {}) do
        if v.id == id then
            table.remove(outfitCache[citizenID], k)
            break
        end
    end
end)

RegisterNetEvent("vr-clothing:server:resetOutfitCache", function()
    local src = source
    local citizenID = Framework.GetPlayerID(src)
    if citizenID then
        outfitCache[citizenID] = nil
    end
end)

RegisterNetEvent("vr-clothing:server:ChangeRoutingBucket", function()
    local src = source
    SetPlayerRoutingBucket(src, src)
end)

RegisterNetEvent("vr-clothing:server:ResetRoutingBucket", function()
    local src = source
    SetPlayerRoutingBucket(src, 0)
end)

if Config.EnablePedMenu then
    lib.addCommand("pedmenu", {
        help = _L("commands.pedmenu.title"),
        params = {
            {
                name = "playerID",
                type = "number",
                help = "Target player's server id",
                optional = true,
            },
        },
        restricted = Config.PedMenuGroup,
    }, function(source, args)
        local target = source
        if args.playerID then
            local citizenID = Framework.GetPlayerID(args.playerID)
            if citizenID then
                target = args.playerID
            else
                lib.notify(source, {
                    title = _L("commands.pedmenu.failure.title"),
                    description = _L("commands.pedmenu.failure.description"),
                    type = "error",
                    position = Config.NotifyOptions.position,
                })
                return
            end
        end
        TriggerClientEvent("vr-clothing:client:openClothingShopMenu", target, true)
    end)
end

if Config.EnableJobOutfitsCommand then
    lib.addCommand("joboutfits", { help = _L("commands.joboutfits.title") }, function(source)
        TriggerClientEvent("vr-clothing:client:outfitsCommand", source, true)
    end)

    lib.addCommand("gangoutfits", { help = _L("commands.gangoutfits.title") }, function(source)
        TriggerClientEvent("vr-clothing:client:outfitsCommand", source)
    end)
end

lib.addCommand("reloadskin", { help = _L("commands.reloadskin.title") }, function(source)
    TriggerClientEvent("vr-clothing:client:reloadSkin", source)
end)

lib.addCommand("clearstuckprops", { help = _L("commands.clearstuckprops.title") }, function(source)
    TriggerClientEvent("vr-clothing:client:ClearStuckProps", source)
end)

