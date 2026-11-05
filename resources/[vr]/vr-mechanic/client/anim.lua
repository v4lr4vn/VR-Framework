Anim = {}

local WORK = {
    engine = { spot = 'front', dict = 'mini@repair', clip = 'fixing_a_ped', flag = 1, hood = true },
    lights = { spot = 'front', dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@', clip = 'machinic_loop_mechandplayer', flag = 1 },
    paint = {
        spot = 'side', dict = 'switch@franklin@lamar_tagging_wall', clip = 'lamar_tagging_wall_loop_lamar', flag = 1,
        prop = { model = 'prop_cs_spray_can', bone = 28422, pos = vec3(0.0, 0.0, 0.07), rot = vec3(0.0, 0.0, 0.0) },
    },
    wheel = { spot = 'wheel', scenario = 'CODE_HUMAN_MEDIC_KNEEL' },
    under = { spot = 'side', scenario = 'WORLD_HUMAN_VEHICLE_MECHANIC' },
    body = { spot = 'side', scenario = 'WORLD_HUMAN_WELDING' },
    glass = { spot = 'door', scenario = 'WORLD_HUMAN_MAID_CLEAN' },
    rear = { spot = 'rear', scenario = 'CODE_HUMAN_MEDIC_KNEEL' },
}

local function spotFor(veh, spot)
    local mn, mx = GetModelDimensions(GetEntityModel(veh))
    local ox, oy, lx, ly
    if spot == 'front' then
        ox, oy, lx, ly = 0.0, mx.y + 0.45, 0.0, mx.y
    elseif spot == 'rear' then
        ox, oy, lx, ly = 0.0, mn.y - 0.55, 0.0, mn.y
    elseif spot == 'door' then
        ox, oy, lx, ly = mn.x - 0.55, 0.45, mn.x, 0.45
    elseif spot == 'wheel' then
        local wy = mx.y * 0.6
        local bone = GetEntityBoneIndexByName(veh, 'wheel_lf')
        if bone and bone ~= -1 then
            local w = GetWorldPositionOfEntityBone(veh, bone)
            local lo = GetOffsetFromEntityGivenWorldCoords(veh, w.x, w.y, w.z)
            wy = lo.y
        end
        ox, oy, lx, ly = mn.x - 0.6, wy, mn.x, wy
    else
        ox, oy, lx, ly = mn.x - 0.7, 0.0, mn.x, 0.0
    end
    local pos = GetOffsetFromEntityInWorldCoords(veh, ox, oy, 0.0)
    local look = GetOffsetFromEntityInWorldCoords(veh, lx, ly, 0.0)
    return pos, look
end

function Anim.goTo(veh, spot)
    local ped = cache.ped
    local pos, look = spotFor(veh, spot)
    local heading = GetHeadingFromVector_2d(look.x - pos.x, look.y - pos.y)
    local here = GetEntityCoords(ped)
    local dx, dy = here.x - pos.x, here.y - pos.y
    if dx * dx + dy * dy > 0.16 then
        TaskGoStraightToCoord(ped, pos.x, pos.y, pos.z, 1.0, 6000, heading, 0.15)
        local deadline = GetGameTimer() + 6000
        while GetGameTimer() < deadline do
            here = GetEntityCoords(ped)
            dx, dy = here.x - pos.x, here.y - pos.y
            if dx * dx + dy * dy <= 0.1225 then break end
            Wait(100)
        end
    end
    ClearPedTasks(ped)
    SetEntityHeading(ped, heading)
    Wait(150)
end

function Anim.perform(veh, work, ms, label)
    local w = WORK[work] or WORK.engine
    if not DoesEntityExist(veh) then return false end
    Anim.goTo(veh, w.spot)
    if w.hood then SetVehicleDoorOpen(veh, 4, false, false) end
    local done = lib.progressBar({
        duration = ms,
        label = label,
        useWhileDead = false,
        canCancel = true,
        disable = { move = true, car = true, combat = true },
        anim = w.scenario and { scenario = w.scenario } or { dict = w.dict, clip = w.clip, flag = w.flag },
        prop = w.prop,
    })
    ClearPedTasks(cache.ped)
    if w.hood and DoesEntityExist(veh) then SetVehicleDoorShut(veh, 4, false) end
    return done == true
end
