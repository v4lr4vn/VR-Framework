local dragging = {}
local draggedBy = {}

function releaseDrag(target)
    local officer = draggedBy[target]
    if not officer then return false end
    draggedBy[target] = nil
    if dragging[officer] == target then dragging[officer] = nil end
    TriggerClientEvent('vr-policejob:client:drag', target, officer, false)
    TriggerClientEvent('vr-policejob:client:dragStopped', officer)
    return true
end

function releaseDragsBy(officer)
    local target = dragging[officer]
    if target then return releaseDrag(target) end
    return false
end

function isDragging(officer)
    return dragging[officer]
end

RegisterNetEvent('vr-policejob:server:drag', function(target, start)
    local src = source
    if not Config.Interactions.enable or not Config.Interactions.escort then return end
    if not hasJob(src, Config.Interactions.jobs) then return end

    target = Security.int(target, 1)
    if start ~= true then
        if target and draggedBy[target] == src then releaseDrag(target) end
        return
    end

    local ok = Security.cooldown('drag', src, 1)
    local valid = ok and Security.target(src, target, Config.Security.interactDistance) or nil
    if not valid or not isCuffed(valid) or (draggedBy[valid] and draggedBy[valid] ~= src) then
        if ok and not valid then Security.flag(src, 'drag on an invalid or far target') end
        TriggerClientEvent('vr-policejob:client:dragStopped', src)
        return
    end

    if dragging[src] and dragging[src] ~= valid then releaseDragsBy(src) end
    dragging[src] = valid
    draggedBy[valid] = src
    TriggerClientEvent('vr-policejob:client:drag', valid, src, true)
end)
