local config         = lib.load("config")
local hospitals      = lib.load("data.hospitals")
local emsJobs        = config.emsJobs
local maxDistance    = config.maxDistance
local vrInventory   = exports['vr-inventory']

local DEFIB_ITEM     = config.defibrillatorItem or "defibrillator"
local CONSUME        = math.max(0, math.floor(tonumber(config.consumeItemPerUse) or 10))

local REVIVE_TIME    = 14900 + (900 * 15) + 1000
local REVIVE_READY   = 25000
local MAX_DISTRESS   = 50
local SYNC_THROTTLE  = 1000

local EXPECT_TTL     = {
    ems = REVIVE_TIME + 60000,
    respawn = 60000,
    paramedic = 60000,
    npc = 120000,
    admin = 15000,
}

local function now() return GetGameTimer() end

local function validPlayer(id)
    id = tonumber(id)
    if not id or id < 1 or id ~= math.floor(id) then return nil end
    if not GetPlayerName(id) or not Framework.getPlayer(id) then return nil end
    return math.floor(id)
end

local function pedCoords(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    return GetEntityCoords(ped)
end

local function distanceBetween(a, b)
    if GetPlayerRoutingBucket(a) ~= GetPlayerRoutingBucket(b) then return math.huge end
    local ca, cb = pedCoords(a), pedCoords(b)
    if not ca or not cb then return math.huge end
    return #(ca - cb)
end

local function notify(src, key, notifyType, ...)
    TriggerClientEvent("vr-ambulancejob:showNotification", src, locale(key, ...), notifyType)
end

local function cleanText(value, maxChars)
    if type(value) ~= "string" then return nil end

    value = value:gsub("%c", " "):gsub("[%[%]<>]", "")
    if not utf8.len(value) then value = value:gsub("[\128-\255]", "") end
    value = value:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s%s+", " ")

    if utf8.len(value) > maxChars then
        value = value:sub(1, utf8.offset(value, maxChars + 1) - 1)
    end

    return value
end

local function sanitizeKiller(weapon)
    if type(weapon) ~= "number" or weapon ~= weapon or weapon % 1 ~= 0 then return false end
    if weapon < -2147483648 or weapon > 4294967295 then return false end
    if weapon > 2147483647 then weapon = weapon - 4294967296 end
    return math.tointeger(weapon) or false
end

local function copyList(list)
    local out = {}
    for i = 1, #list do out[i] = list[i] end
    return out
end

local function emsGroups(minGrade)
    local groups = {}
    for _, name in ipairs(Framework.emsJobNames()) do
        groups[name] = tonumber(minGrade) or 0
    end
    return groups
end

local function countMedics()
    local count = 0
    local players = Framework.getPlayers()

    for i = 1, #players do
        if Framework.hasJob(players[i], emsJobs) then count += 1 end
    end

    return count
end

local function sameHash(a, b)
    a, b = math.tointeger(a), math.tointeger(b)
    return a ~= nil and b ~= nil and (a & 0xFFFFFFFF) == (b & 0xFFFFFFFF)
end

local deaths = {}

local function getState(src)
    local state = deaths[src]
    if not state then
        state = { isDead = false, killedBy = false }
        deaths[src] = state
    end
    return state
end

local function isDead(src)
    src = tonumber(src)
    if not src then return false end

    local state = deaths[src]
    if state and state.isDead then return true end

    if not state then
        local status = Framework.getDeathStatus(src)
        return status ~= nil and status.isDead == true
    end

    local xPlayer = Framework.getPlayer(src)
    return xPlayer ~= nil and xPlayer.PlayerData.metadata.inlaststand == true
end

local function setStateBag(src, value)
    local ply = Player(src)
    if ply and ply.state then ply.state:set("dead", value, true) end
end

local function syncStatus(src, dead)
    Framework.updateStatus({ target = src, status = dead })
    setStateBag(src, dead)
end

local function initPlayer(src, xPlayer)
    local metadata = xPlayer and xPlayer.PlayerData.metadata or {}
    local dead = metadata.isdead == true or metadata.inlaststand == true

    deaths[src] = { isDead = dead, killedBy = false, diedAt = dead and now() or nil }
    syncStatus(src, dead)
end

local function dispatchStarted()
    return GetResourceState("vr-mdt") == "started"
end

local function sendAlert(template, message, src, information)
    if not dispatchStarted() or type(template) ~= "table" then return nil end

    local data = {
        message = message,
        information = information,
        codeName = template.codeName,
        code = template.code,
        icon = template.icon,
        priority = template.priority,
        jobs = copyList(template.jobs or {}),
    }

    local ok, id = pcall(function()
        return exports["vr-mdt"]:SendAlert(data, src)
    end)

    return ok and id or nil
end

local lastDownAlert = {}

local function sendDownAlert(src)
    local template, messageKey

    if Framework.isOnDutyType(src, "leo") then
        template, messageKey = config.dispatch.officerDown, "officer_down_alert"
    elseif Framework.isOnDutyType(src, "ems") then
        template, messageKey = config.dispatch.emsDown, "ems_down_alert"
    else
        return
    end

    if not dispatchStarted() then return end

    local key = Framework.getCitizenId(src) or src
    local t = now()
    if lastDownAlert[key] and t - lastDownAlert[key] < (config.dispatch.downCooldown or 60) * 1000 then return end
    lastDownAlert[key] = t

    sendAlert(template, locale(messageKey), src)
end

local function markDead(src, killedBy)
    local state = getState(src)

    if state.isDead then
        if killedBy then state.killedBy = killedBy end
        return false
    end

    state.isDead = true
    state.killedBy = killedBy or false
    state.diedAt = now()
    state.expect = nil

    syncStatus(src, true)
    sendDownAlert(src)

    return true
end

local function applyRecovery(src)
    local state = getState(src)

    state.isDead = false
    state.killedBy = false
    state.diedAt = nil
    state.expect = nil

    syncStatus(src, false)
    Framework.resetNeeds(src)
end

local function expectRevive(src, reason, opts)
    local state = getState(src)

    state.expect = {
        reason = reason,
        expires = now() + (EXPECT_TTL[reason] or 30000),
        readyAt = opts and opts.readyAt or nil,
        medic = opts and opts.medic or nil,
    }
end

local function takeExpectation(src)
    local state = deaths[src]
    local expect = state and state.expect
    if not expect then return nil end

    local t = now()
    if t > expect.expires then
        state.expect = nil
        return nil
    end
    if expect.readyAt and t < expect.readyAt then return nil end

    state.expect = nil
    return expect
end

local function resyncDead(src)
    local state = getState(src)
    local t = now()
    if state.lastSync and t - state.lastSync < SYNC_THROTTLE then return end
    state.lastSync = t

    TriggerClientEvent("vr-ambulancejob:syncDeath", src, true)
end

local rewardLog = {}

local function rewardEntry(patient)
    local cid = Framework.getCitizenId(patient)
    if not cid then return nil end

    local entry = rewardLog[cid]
    if not entry then
        entry = { injuryCount = 0 }
        rewardLog[cid] = entry
    end
    return entry
end

local function rewardCooldown()
    return (tonumber(config.rewardCooldown) or 10) * 60000
end

local function payReviveReward(medic, patient)
    medic = validPlayer(medic)
    if not medic or medic == patient then return end
    if not Framework.hasJob(medic, emsJobs) then return end
    if distanceBetween(medic, patient) > maxDistance.revive + 6.0 then return end

    local amount = math.floor(tonumber(config.reviveReward) or 0)
    if amount <= 0 then return end

    local entry = rewardEntry(patient)
    if not entry then return end

    local t = now()
    if entry.reviveAt and t - entry.reviveAt < rewardCooldown() then
        return notify(medic, "reward_cooldown", "inform")
    end
    entry.reviveAt = t

    Framework.addAccountMoney(medic, "cash", amount, "ems-revive-reward")
end

local function payInjuryReward(medic, patient)
    local amount = math.floor(tonumber(config.baseInjuryReward) or 0)
    if amount <= 0 then return end

    local entry = rewardEntry(patient)
    if not entry then return end

    local t = now()
    if not entry.injuryWindow or t - entry.injuryWindow >= rewardCooldown() then
        entry.injuryWindow = t
        entry.injuryCount = 0
    end

    if entry.injuryCount >= (tonumber(config.maxInjuryRewards) or 5) then
        return notify(medic, "reward_cooldown", "inform")
    end
    entry.injuryCount += 1

    Framework.addAccountMoney(medic, "cash", amount, "ems-treatment-reward")
end

local function wearItem(src, itemName)
    local slots = vrInventory:GetSlotsWithItem(src, itemName)
    if type(slots) ~= "table" or #slots == 0 then return false, "not_enough_" .. itemName end

    for i = 1, #slots do
        local slot = slots[i]
        local durability = type(slot.metadata) == "table" and tonumber(slot.metadata.durability) or 100

        if durability >= CONSUME then
            if CONSUME > 0 then
                vrInventory:SetDurability(src, slot.slot, math.max(0, durability - CONSUME))
            end
            return true
        end
    end

    return false, "no_durability"
end

local function injuryItem(cause)
    return config.injuryItems and config.injuryItems[cause] or "bandage"
end

local function isActiveMedic(src)
    return Framework.hasJob(src, emsJobs) and not isDead(src)
end

RegisterNetEvent("vr-ambulancejob:updateDeathStatus", function(death)
    local source = source
    if not Framework.getPlayer(source) or type(death) ~= "table" then return end

    if death.isDead == true then
        markDead(source, sanitizeKiller(death.weapon))
        return
    end

    if death.isDead ~= false then return end

    local state = getState(source)
    local expect = takeExpectation(source)

    if not state.isDead then
        if expect then applyRecovery(source) end
        return
    end

    if not expect then
        return resyncDead(source)
    end

    applyRecovery(source)

    if expect.reason == "ems" then
        payReviveReward(expect.medic, source)
    end
end)

local reviving = {}
local medicBusy = {}

RegisterNetEvent("vr-ambulancejob:revivePatient", function(target)
    local source = source
    if not isActiveMedic(source) then return end

    target = validPlayer(target)
    if not target or target == source then return end
    if distanceBetween(source, target) > maxDistance.revive then return end
    if not isDead(target) then return notify(source, "patient_not_unconscious", "error") end

    local t = now()
    if (medicBusy[source] or 0) > t then return end

    local current = reviving[target]
    if current and current.untilT > t then return notify(source, "patient_being_revived", "error") end

    local ok, reason = wearItem(source, DEFIB_ITEM)
    if not ok then return notify(source, reason, "error") end

    reviving[target] = { medic = source, untilT = t + REVIVE_TIME + 10000 }
    medicBusy[source] = t + REVIVE_TIME
    expectRevive(target, "ems", { medic = source, readyAt = t + REVIVE_READY })

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    local rad = math.rad(heading)
    local forward = vector3(-math.sin(rad), math.cos(rad), 0.0)

    TriggerClientEvent("vr-ambulancejob:playHealAnim", source, { anim = "medic", heading = heading, coords = coords, location = forward })
    TriggerClientEvent("vr-ambulancejob:playHealAnim", target, { anim = "dead", heading = heading, coords = coords, location = forward })
end)

RegisterNetEvent("vr-ambulancejob:treatInjury", function(target, bone)
    local source = source
    if not isActiveMedic(source) then return end

    target = validPlayer(target)
    if not target or target == source then return end
    if type(bone) ~= "string" or #bone == 0 or #bone > 32 then return end
    if distanceBetween(source, target) > maxDistance.treat then return end

    local injuries = Player(target).state.injuries
    local injury = type(injuries) == "table" and injuries[bone] or nil
    if type(injury) ~= "table" then return end

    local ok, reason = wearItem(source, injuryItem(injury.cause))
    if not ok then return notify(source, reason, "error") end

    TriggerClientEvent("vr-ambulancejob:healPlayer", target, { injury = true, bone = bone })
    payInjuryReward(source, target)
end)

local distressCalls = {}
local lastDistress = {}
local distressId = 0

lib.callback.register("vr-ambulancejob:createDistressCall", function(source, data)
    if not Framework.getPlayer(source) or type(data) ~= "table" then return false end

    local msg = cleanText(data.msg, 200)
    if not msg or msg == "" then return false end

    local key = Framework.getCitizenId(source) or source
    local t = now()
    local last = lastDistress[key]
    if last and t - last < (tonumber(config.waitTimeForNewCall) or 5) * 60000 then
        return false, "distress_call_in_cooldown"
    end

    local coords = pedCoords(source)
    if not coords then return false end

    lastDistress[key] = t

    local playerName = cleanText(Framework.getPlayerName(source), 64) or ""
    distressId += 1

    distressCalls[#distressCalls + 1] = {
        id = distressId,
        msg = msg,
        gps = coords,
        location = cleanText(data.location, 64) or "",
        name = playerName,
    }
    while #distressCalls > MAX_DISTRESS do table.remove(distressCalls, 1) end

    local players = Framework.getPlayers()
    for i = 1, #players do
        local id = players[i]
        if Framework.hasJob(id, emsJobs) then
            TriggerClientEvent("vr-ambulancejob:createDistressCall", id, playerName)
        end
    end

    sendAlert(config.dispatch.distress, cleanText(msg, 64), source, cleanText(msg, 200))

    return true
end)

RegisterNetEvent("vr-ambulancejob:callCompleted", function(id)
    local source = source
    if not Framework.hasJob(source, emsJobs) then return end

    id = tonumber(id)
    if not id then return end

    for i = #distressCalls, 1, -1 do
        if distressCalls[i].id == id then
            table.remove(distressCalls, i)
            break
        end
    end
end)

lib.callback.register("vr-ambulancejob:getDistressCalls", function(source)
    if not Framework.hasJob(source, emsJobs) then return {} end
    return distressCalls
end)

lib.callback.register("vr-ambulancejob:respawn", function(source)
    local state = deaths[source]
    if not state or not state.isDead then return false end

    local waited = now() - (state.diedAt or now())
    if waited < (tonumber(config.respawnTime) or 0) * 60000 then return false end

    if config.removeItemsOnRespawn then
        Framework.wipeInventory(source, config.keepItemsOnRespawn)
    end

    expectRevive(source, "respawn")
    return true
end)

local function chargePlayer(source, amount, reason)
    local xPlayer = Framework.getPlayer(source)
    if not xPlayer then return false end

    for _, account in ipairs(config.paramedicAccounts or { "cash" }) do
        local balance = tonumber(xPlayer.PlayerData.money[account]) or 0
        if balance >= amount and Framework.removeAccountMoney(source, account, amount, reason) then
            return true
        end
    end

    return false
end

lib.callback.register("vr-ambulancejob:paramedicTreatment", function(source, hospitalId)
    if not Framework.getPlayer(source) then return false end

    local hospital = type(hospitalId) == "string" and hospitals[hospitalId] or nil
    if not hospital or not hospital.paramedic then return false end

    local coords = pedCoords(source)
    if not coords or #(coords - hospital.paramedic.pos.xyz) > maxDistance.paramedic then return false end

    if not config.allowAlways and countMedics() > 0 then return false, "medics_online" end

    local price = math.floor(tonumber(config.paramedicTreatmentPrice) or 0)
    if price > 0 then
        if not chargePlayer(source, price, "ems-paramedic-treatment") then return false, "not_enough_money" end
        Framework.addSocietyMoney(config.society or "ambulance", price, "paramedic-treatment")
    end

    if config.shouldRevive and isDead(source) then
        expectRevive(source, "paramedic")
    end

    return true
end)

lib.callback.register("vr-ambulancejob:requestNpcRevive", function(source)
    local state = deaths[source]
    if not state or not state.isDead then return false end

    if countMedics() > 0 then return false, "medics_online" end

    local need = (tonumber(config.timeToWaitForCommand) or 0) * 60000
    local waited = now() - (state.diedAt or now())
    if waited < need then return false, "wait_time", math.ceil((need - waited) / 1000) end

    if state.expect and state.expect.expires > now() then return false end

    expectRevive(source, "npc", { readyAt = now() + 15000 })
    return true
end)

lib.callback.register("vr-ambulancejob:getMedicsOnline", function(source)
    return countMedics()
end)

local function canInspect(source, target)
    if target == source then return true end
    if not Framework.hasJob(source, emsJobs) then return false end
    return distanceBetween(source, target) <= maxDistance.check
end

lib.callback.register("vr-ambulancejob:getDeathStatus", function(source, target)
    target = target == nil and source or validPlayer(target)
    if not target or not canInspect(source, target) then return nil end

    return { isDead = isDead(target) }
end)

lib.callback.register("vr-ambulancejob:getData", function(source, target)
    target = target == nil and source or validPlayer(target)
    if not target or not canInspect(source, target) then return nil end

    local state = deaths[target]
    local dead = isDead(target)

    return {
        injuries = Player(target).state.injuries or false,
        status = { isDead = dead },
        killedBy = dead and state and state.killedBy or false,
    }
end)

RegisterNetEvent("vr-ambulancejob:putOnStretcher", function(data)
    local source = source
    if type(data) ~= "table" or not isActiveMedic(source) then return end

    local target = validPlayer(data.target)
    if not target or target == source then return end
    if distanceBetween(source, target) > maxDistance.stretcher then return end

    local toggle = data.toggle == true
    if toggle and not isDead(target) then return end

    TriggerClientEvent("vr-ambulancejob:putOnStretcher", target, toggle)
end)

RegisterNetEvent("vr-ambulancejob:togglePatientFromVehicle", function(data)
    local source = source
    if type(data) ~= "table" or not isActiveMedic(source) then return end

    local target = validPlayer(data.target)
    if not target or target == source then return end
    if not isDead(target) then return end
    if distanceBetween(source, target) > maxDistance.vehicle then return end

    local netId = nil
    if data.vehicle ~= nil then
        netId = math.tointeger(tonumber(data.vehicle))
        if not netId then return end

        local vehicle = NetworkGetEntityFromNetworkId(netId)
        if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end

        local coords = pedCoords(source)
        if not coords or #(GetEntityCoords(vehicle) - coords) > maxDistance.vehicle then return end
    end

    TriggerClientEvent("vr-ambulancejob:togglePatientFromVehicle", target, netId)
end)

local medicBagItem = config.medicBagItem
local medicBagModel = joaat(config.medicBagProp)
local BAG_CREDIT_TTL = 15000

local bagCredits = {}
local bags = {}

local function ownedBag(source, netId)
    netId = math.tointeger(tonumber(netId))
    local bag = netId and bags[netId]
    if not bag or bag.owner ~= Framework.getCitizenId(source) then return nil end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then
        bags[netId] = nil
        return nil
    end

    local coords = pedCoords(source)
    if not coords or #(GetEntityCoords(entity) - coords) > maxDistance.medicalBag then return nil end

    return entity, netId
end

lib.callback.register("vr-ambulancejob:placeMedicalBag", function(source)
    if not isActiveMedic(source) then return false end
    if (bagCredits[source] or 0) > now() then return false end

    if not Framework.removeItem(source, medicBagItem, 1) then return false end

    bagCredits[source] = now() + BAG_CREDIT_TTL
    return true
end)

RegisterNetEvent("vr-ambulancejob:registerMedicalBag", function(netId)
    local source = source
    local credit = bagCredits[source]
    if not credit or credit < now() then return end

    netId = math.tointeger(tonumber(netId))
    if not netId then return end

    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return end
    if not sameHash(GetEntityModel(entity), medicBagModel) then return end

    local coords = pedCoords(source)
    if not coords or #(GetEntityCoords(entity) - coords) > maxDistance.medicalBag then return end

    bagCredits[source] = nil
    bags[netId] = { owner = Framework.getCitizenId(source), src = source }
end)

lib.callback.register("vr-ambulancejob:pickupMedicalBag", function(source, netId)
    local entity, id = ownedBag(source, netId)
    if not entity then return false end

    if not vrInventory:CanCarryItem(source, medicBagItem, 1) then return false, "cannot_carry" end

    bags[id] = nil
    DeleteEntity(entity)
    Framework.addItem(source, medicBagItem, 1)

    return true
end)

lib.callback.register("vr-ambulancejob:openMedicalBag", function(source, netId)
    local entity = ownedBag(source, netId)
    if not entity then return false end

    local citizenid = Framework.getCitizenId(source)
    local stashId = "medicalBag_" .. citizenid

    vrInventory:RegisterStash(stashId, locale("medical_bag_stash"), 10, 50 * 1000, nil, emsGroups(0), GetEntityCoords(entity))

    return stashId
end)

vrInventory:registerHook("swapItems", function(payload)
    if type(payload.toInventory) == "string" and payload.toInventory:find("^medicalBag_") then
        local fromSlot = payload.fromSlot
        if type(fromSlot) == "table" and fromSlot.name == medicBagItem then return false end
    end
end, { inventoryFilter = { "^medicalBag_" } })

local function registerInventories()
    for _, hospital in pairs(hospitals) do
        for id, stash in pairs(hospital.stash or {}) do
            local owner = (not stash.shared) and true or nil
            vrInventory:RegisterStash(id, stash.label, stash.slots, stash.weight * 1000, owner, emsGroups(stash.min_grade), stash.pos)
        end

        for id, pharmacy in pairs(hospital.pharmacy or {}) do
            vrInventory:RegisterShop(id, {
                name = pharmacy.label,
                inventory = pharmacy.items,
                groups = pharmacy.job and emsGroups(pharmacy.grade) or nil,
                locations = { pharmacy.pos },
                targets = { { loc = pharmacy.pos, coords = pharmacy.pos } },
            })
        end
    end
end

CreateThread(registerInventories)

AddEventHandler("onServerResourceStart", function(resourceName)
    if resourceName == "vr-inventory" then registerInventories() end
end)

function RevivePlayer(target)
    target = validPlayer(target)
    if not target then return false end

    applyRecovery(target)
    TriggerClientEvent("vr-ambulancejob:healPlayer", target, { revive = true })

    return true
end

function HealPlayer(target)
    target = validPlayer(target)
    if not target then return false end

    Framework.resetNeeds(target)
    TriggerClientEvent("vr-ambulancejob:healPlayer", target, { heal = true })

    return true
end

IsPlayerDead = isDead

local adminMenu = config.adminMenu or {}

local function adminMenuRevive(source)
    if not adminMenu.resource or GetResourceState(adminMenu.resource) ~= "started" then return false end
    return Framework.hasPermission(source, adminMenu.permission or "admin")
end

RegisterNetEvent("vr-adminmenu:server:Revive", function(_, selectedData)
    local source = source
    if not adminMenuRevive(source) then return end

    local field = type(selectedData) == "table" and selectedData.Player or nil
    local target = validPlayer(type(field) == "table" and field.value or nil)
    if target then expectRevive(target, "admin") end
end)

RegisterNetEvent("vr-adminmenu:server:ReviveAll", function()
    local source = source
    if not adminMenuRevive(source) then return end

    local players = Framework.getPlayers()
    for i = 1, #players do expectRevive(players[i], "admin") end
end)

RegisterNetEvent("vr-adminmenu:server:ReviveRadius", function()
    local source = source
    if not adminMenuRevive(source) then return end

    local players = Framework.getPlayers()
    for i = 1, #players do
        local id = players[i]
        local a, b = pedCoords(source), pedCoords(id)
        if a and b and #(a - b) < (adminMenu.radius or 15.0) then expectRevive(id, "admin") end
    end
end)

local partsById = {}
for _, part in pairs(lib.load("data.body_parts") or {}) do
    if type(part) == "table" and type(part.id) == "string" then partsById[part.id] = part end
end

local injuryCauses = { ["not found"] = true }
for _, entry in pairs(lib.load("data.weapons") or {}) do
    if type(entry) == "table" and type(entry[2]) == "string" then injuryCauses[entry[2]] = true end
end

local injuryAt = {}

RegisterNetEvent("vr-ambulancejob:server:setInjuries", function(list)
    local src = source
    if type(list) ~= "table" or not Framework.getPlayer(src) then return end

    local t = now()
    if injuryAt[src] and t - injuryAt[src] < 200 then return end
    injuryAt[src] = t

    local clean, count = {}, 0
    for bone, entry in pairs(list) do
        local part = type(bone) == "string" and partsById[bone] or nil
        if part and type(entry) == "table" then
            local value = math.floor(tonumber(entry.value) or 0)
            if value ~= value then value = 0 end
            value = math.max(0, math.min(100, value))
            if value > 0 then
                count += 1
                if count > 32 then return end
                local levels = type(part.levels) == "table" and part.levels or {}
                clean[bone] = {
                    bone = bone,
                    label = part.label,
                    desc = levels[tostring(value)] or levels["default"],
                    value = value,
                    cause = injuryCauses[entry.cause] and entry.cause or "not found",
                }
            end
        end
    end

    Player(src).state:set("injuries", clean, true)
end)

local function clearPlayer(src)
    injuryAt[src] = nil
    deaths[src] = nil
    medicBusy[src] = nil
    bagCredits[src] = nil
    reviving[src] = nil

    for patient, entry in pairs(reviving) do
        if entry.medic == src then reviving[patient] = nil end
    end
end

Framework.onPlayerLoaded(function(source, xPlayer)
    clearPlayer(source)
    initPlayer(source, xPlayer)
end)

Framework.onPlayerUnload(clearPlayer)

AddEventHandler("playerDropped", function()
    clearPlayer(source)
end)

CreateThread(function()
    local players = Framework.getPlayers()
    for i = 1, #players do
        local src = players[i]
        if not deaths[src] then initPlayer(src, Framework.getPlayer(src)) end
    end
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end

    for netId in pairs(bags) do
        local entity = NetworkGetEntityFromNetworkId(netId)
        if entity and entity ~= 0 and DoesEntityExist(entity) then DeleteEntity(entity) end
    end
end)

exports("IsDead", function(src)
    return isDead(src)
end)

exports("RevivePlayer", function(src)
    return RevivePlayer(src)
end)
