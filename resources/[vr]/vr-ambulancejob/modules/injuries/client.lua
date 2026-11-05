local TriggerServerEvent   = TriggerServerEvent
local GetPedLastDamageBone = GetPedLastDamageBone

local injuryItems          = lib.load("config").injuryItems

local function checkInjuryCause(cause)
    local item = injuryItems[cause] or "bandage"

    utils.debug(item, cause)

    local canUse, reason = utils.canUseItem(item)
    if not canUse then
        utils.showNotification(locale(reason))
        return false
    end

    return true
end

function checkInjuries(data)
    local injuries = {}

    utils.debug(data.injuries)

    if not data.injuries or not next(data.injuries) then
        injuries[#injuries + 1] = {
            title = locale('no_injuries'),
        }
    else
        for _, v in pairs(data.injuries) do
            injuries[#injuries + 1] = {
                title = v.label,
                description = v.desc,

                arrow = true,
                onSelect = function()
                    lib.registerContext({
                        id = 'vr-ambulancejob:patient_injury',
                        title = v.label,
                        menu = "vr-ambulancejob:patient_injuries",
                        options = {
                            {
                                title = locale("injury_value"),
                                progress = v.value,
                                metadata = { v.value .. "%" },
                            },
                            {
                                title = locale("injury_cause"),
                                description = locale(v.cause),
                            },
                            {
                                title = locale("injury_treat"),
                                onSelect = function()
                                    if checkInjuryCause(v.cause) then
                                        if lib.progressBar({
                                                duration = 2000 * (v.value / 10),
                                                label = locale("treating_injury"),
                                                useWhileDead = false,
                                                canCancel = true,
                                                disable = {
                                                    car = true,
                                                    move = true
                                                },
                                                anim = {
                                                    scenario = "CODE_HUMAN_MEDIC_TEND_TO_DEAD"
                                                }

                                            })
                                        then
                                            TriggerServerEvent("vr-ambulancejob:treatInjury", data.target, v.bone)

                                            utils.showNotification(locale("injury_treated"))
                                            utils.debug("Injury treated " .. tostring(v.bone))
                                        else
                                            utils.showNotification(locale("operation_canceled"))
                                        end
                                    end
                                end

                            }
                        }
                    })

                    lib.showContext("vr-ambulancejob:patient_injury")
                end
            }
        end
    end

    lib.registerContext({
        id = 'vr-ambulancejob:patient_injuries',
        title = locale("injury_menu_title"),
        menu = "vr-ambulancejob:check_patient",
        options = injuries
    })

    lib.showContext('vr-ambulancejob:patient_injuries')
end

local injurySyncQueued = false

function syncInjuries()
    LocalPlayer.state:set("injuries", player.injuries, false)
    if injurySyncQueued then return end
    injurySyncQueued = true
    SetTimeout(300, function()
        injurySyncQueued = false
        TriggerServerEvent("vr-ambulancejob:server:setInjuries", player.injuries or {})
    end)
end

function treatInjury(bone)
    if not player.injuries[bone] then return end

    player.injuries[bone] = nil
    syncInjuries()

    local playerHealth = GetEntityHealth(cache.ped)
    local playerMaxHealth = GetEntityMaxHealth(cache.ped)
    local newHealth = math.min(playerHealth + 10, playerMaxHealth)

    utils.debug("current", playerHealth)
    utils.debug("max", playerMaxHealth)
    utils.debug("new", newHealth, type(newHealth))

    SetEntityHealth(cache.ped, newHealth)
end

local bodyParts = lib.load("data.body_parts")
local weapons = lib.load("data.weapons")
function updateInjuries(victim, weapon)
    local found, lastDamagedBone = GetPedLastDamageBone(victim)

    local damagedBone = found and bodyParts[tostring(lastDamagedBone)]

    if damagedBone then
        utils.debug("Damaged bone ", lastDamagedBone, damagedBone.label)

        if not player.injuries[damagedBone.id] then
            player.injuries[damagedBone.id] = { bone = damagedBone.id, label = damagedBone.label, desc = damagedBone.levels["default"], value = player.isDead and 100 or 10, cause = weapons[weapon] and weapons[weapon][2] or "not found" }
        else
            local newVal = math.min(player.injuries[damagedBone.id].value + 10, 100)
            player.injuries[damagedBone.id].value = newVal
            player.injuries[damagedBone.id].desc = damagedBone.levels[tostring(newVal)] or damagedBone.levels["default"]
        end

        syncInjuries()
    end
end
