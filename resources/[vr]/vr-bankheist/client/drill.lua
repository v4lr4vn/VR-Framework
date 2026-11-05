local function holdDrill()
    local cfg = Config.Drill
    local hash = BHC.loadModel({ cfg.model })
    local obj
    if hash then
        local ped = BHC.ped()
        local c = GetEntityCoords(ped)
        obj = CreateObject(hash, c.x, c.y, c.z + 0.2, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        if obj and obj ~= 0 then
            AttachEntityToEntity(obj, ped, GetPedBoneIndex(ped, 28422), 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, true, true, false, true, 1, true)
        else
            obj = nil
        end
    end
    local dict = lib.requestAnimDict(cfg.animDict)
    if dict then TaskPlayAnim(BHC.ped(), cfg.animDict, cfg.animClip, 8.0, -8.0, -1, 1, 0, false, false, false) end
    return obj
end

function BHC.drillGame(el, seconds, difficulty, onJam)
    local ped = BHC.ped()
    TaskTurnPedToFaceCoord(ped, el.x, el.y, el.z, 500)
    Wait(500)
    local obj = holdDrill()
    local depth, heat, jammed = 0.0, 20.0, 0.0
    local rate = 100.0 / math.max(seconds, 4)
    local heatUp = 14.0 + 8.0 * (difficulty or 2)
    local result = 'cancel'
    local last = GetGameTimer()
    local sent = 0
    BHC.message({ action = 'drill', depth = 0, heat = heat, jam = false })
    while true do
        Wait(0)
        local now = GetGameTimer()
        local dt = math.min((now - last) / 1000.0, 0.1)
        last = now
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 23, true)
        DisableControlAction(0, 38, true)
        if IsControlJustPressed(0, 73) then result = 'cancel' break end
        if IsEntityDead(ped) then result = 'cancel' break end
        if #(GetEntityCoords(ped) - vec3(el.x, el.y, el.z)) > (el.r or 1.5) + 3.0 then result = 'cancel' break end
        if jammed > 0.0 then
            jammed = jammed - dt
            if jammed <= 0.0 then
                jammed = 0.0
                heat = 55.0
            end
        else
            local pressing = IsDisabledControlPressed(0, 38)
            if pressing then
                local speed = 1.0
                if heat < 35.0 then speed = 0.55 elseif heat > 70.0 then speed = 1.25 end
                depth = depth + rate * speed * dt
                heat = heat + heatUp * (heat > 70.0 and 1.35 or 1.0) * dt
            else
                heat = math.max(0.0, heat - 22.0 * dt)
            end
            if heat >= 100.0 then
                heat = 100.0
                jammed = 2.5
                if onJam and onJam() then result = 'broken' break end
            end
            if depth >= 100.0 then
                depth = 100.0
                result = 'done'
                break
            end
        end
        if now - sent > 45 then
            sent = now
            BHC.message({ action = 'drill', depth = depth, heat = heat, jam = jammed > 0.0 })
        end
    end
    BHC.message({ action = 'drillEnd' })
    ClearPedTasks(ped)
    if obj and DoesEntityExist(obj) then DeleteEntity(obj) end
    return result
end
