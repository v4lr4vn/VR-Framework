local placing = false

local DISABLE = { 14, 15, 16, 17, 24, 25, 37, 38, 44, 45, 140, 141, 142, 177, 199, 200, 257, 263, 264 }

local function rotationToDirection(rot)
    local z, x = math.rad(rot.z), math.rad(rot.x)
    local c = math.abs(math.cos(x))
    return vector3(-math.sin(z) * c, math.cos(z) * c, math.sin(x))
end

local function aim(maxDist, ghost)
    local from = GetFinalRenderedCamCoord()
    local dir = rotationToDirection(GetFinalRenderedCamRot(2))
    local dest = from + dir * maxDist
    for _ = 1, 4 do
        local ray = StartExpensiveSynchronousShapeTestLosProbe(from.x, from.y, from.z, dest.x, dest.y, dest.z, 1 | 16, ghost or cache.ped, 7)
        local _, hit, coords, normal, entity = GetShapeTestResult(ray)
        if hit ~= 1 then return nil end
        if not ghost or entity ~= ghost then return coords, normal end
        from = coords + dir * 0.02
    end
    return nil
end

local function surfaceOf(normal)
    if normal.z > 0.7 then return 'floor' end
    if normal.z < -0.7 then return 'ceiling' end
    return 'wall'
end

local function precheck(kind, pos)
    if #(GetEntityCoords(cache.ped) - pos) > Config.Limits.placeDistance - 0.25 then return 'too_far' end
    if kind == 'boombox' then return nil end
    local pd = PlayerData()
    local inside = pd.metadata and pd.metadata.inside
    if inside and inside.property_id then return nil, 'home:' .. tostring(inside.property_id) end
    if MyBucket() ~= 0 then return 'not_here' end
    local job = pd.job or {}
    local other = false
    for _, z in ipairs(Zones) do
        if DJ.inZone(z, pos.x, pos.y, pos.z) then
            if z.job == job.name then
                if not job.onduty then return 'off_duty' end
                return nil, 'biz:' .. z.key
            end
            other = true
        end
    end
    return other and 'not_your_business' or 'not_here'
end

local function linkRangeAt(place)
    for _, sp in pairs(Speakers) do
        if sp.booster and sp.place == place then return Config.Booster.linkRange end
    end
    return Config.Limits.linkRange
end

local function nearestSpeaker(place, pos)
    local bucket = MyBucket()
    local best, bestD
    for _, sp in pairs(Speakers) do
        if sp.place == place and sp.system and not sp.booster and (sp.bucket or 0) == bucket then
            local d = #(pos - vector3(sp.x, sp.y, sp.z))
            if not bestD or d < bestD then best, bestD = sp, d end
        end
    end
    return best, bestD, linkRangeAt(place)
end

local function hud(label, valid, reason, info, infoKind)
    SendNUIMessage({
        action = 'placement', show = true, label = label, valid = valid,
        reason = reason and Lang.get(reason) or nil, info = info, infoKind = infoKind,
    })
end

local function place(item, slot, info, kind, replace)
    local model = joaat(info.model)
    if not LoadModel(model) then
        return Notify(("This speaker's model (%s) isn't in the game."):format(info.model), 'error')
    end
    local minDim, maxDim = GetModelDimensions(model)
    local start = GetEntityCoords(cache.ped)
    local ghost = CreateObjectNoOffset(model, start.x, start.y, start.z - 50.0, false, false, false)
    SetModelAsNoLongerNeeded(model)
    SetEntityAlpha(ghost, 170, false)
    SetEntityCollision(ghost, false, false)
    FreezeEntityPosition(ghost, true)
    SetEntityDrawOutline(ghost, true)

    local spin = (GetEntityHeading(cache.ped) + 180.0) % 360.0
    local lastValid, lastReason, lastInfo = nil, nil, nil
    local busy = false
    placing = true
    local label = info.label
    hud(label, false, nil)

    while placing do
        Wait(0)
        for i = 1, #DISABLE do DisableControlAction(0, DISABLE[i], true) end

        if IsPedInAnyVehicle(cache.ped, true) or IsEntityDead(cache.ped) then break end

        local step = IsControlPressed(0, 21) and 5.0 or 15.0
        if IsDisabledControlJustPressed(0, 15) then spin = (spin + step) % 360.0 end
        if IsDisabledControlJustPressed(0, 14) then spin = (spin - step) % 360.0 end

        local hit, normal = aim(10.0, ghost)
        local valid, reason, pos, heading = false, nil, nil, nil
        local linkText, linkKind = nil, nil
        if hit then
            local surface = surfaceOf(normal)
            if surface ~= info.mount then
                reason = 'wrong_surface'
            end
            if surface == 'wall' then
                local flat = vector3(normal.x, normal.y, 0.0)
                local len = #flat
                flat = len > 0 and flat / len or vector3(0.0, 1.0, 0.0)
                local yaw = (info.yaw or 0.0) % 360.0
                heading = (GetHeadingFromVector_2d(flat.x, flat.y) + yaw) % 360.0
                local back = (math.abs(yaw - 180.0) < 45.0 and maxDim.y or -minDim.y) + 0.01
                pos = vector3(hit.x, hit.y, hit.z - (minDim.z + maxDim.z) / 2.0) + flat * back
            elseif surface == 'ceiling' then
                heading = (spin + (info.yaw or 0.0)) % 360.0
                pos = vector3(hit.x, hit.y, hit.z - maxDim.z - 0.01)
            else
                heading = (spin + (info.yaw or 0.0)) % 360.0
                pos = vector3(hit.x, hit.y, hit.z - minDim.z + 0.005)
            end
            SetEntityCoordsNoOffset(ghost, pos.x, pos.y, pos.z, false, false, false)
            SetEntityHeading(ghost, heading)
            local place
            if not reason then reason, place = precheck(kind, pos) end
            valid = reason == nil
            if valid and place and kind == 'speaker' then
                local near, d, range = nearestSpeaker(place, pos)
                if not near then
                    linkText, linkKind = Lang.link_new, 'new'
                else
                    local ok = d <= range
                    local sys = Systems[near.system]
                    if ok then
                        linkText, linkKind = Lang.get('link_ok', sys and sys.name or 'the group', d, math.floor(range)), 'ok'
                    else
                        linkText, linkKind = Lang.get('link_far', d, math.floor(range)), 'far'
                    end
                    local r, g, b = 80, 220, 140
                    if not ok then r, g, b = 245, 170, 60 end
                    DrawLine(pos.x, pos.y, pos.z, near.x, near.y, near.z + 0.3, r, g, b, 255)
                end
            elseif valid and place and kind == 'booster' then
                linkText, linkKind = Lang.get('booster_info', math.floor(Config.Booster.linkRange)), 'ok'
            end
        else
            reason = 'too_far'
            SetEntityCoordsNoOffset(ghost, start.x, start.y, start.z - 50.0, false, false, false)
        end

        if valid then SetEntityDrawOutlineColor(80, 220, 140, 255) else SetEntityDrawOutlineColor(235, 80, 80, 255) end
        if valid ~= lastValid or reason ~= lastReason or linkText ~= lastInfo then
            hud(label, valid, reason, linkText, linkKind)
            lastValid, lastReason, lastInfo = valid, reason, linkText
        end

        if IsDisabledControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 25) then break end

        if IsDisabledControlJustPressed(0, 38) and not busy then
            if not valid then
                Notify(Lang.get(reason or 'bad_request'), 'error')
            else
                busy = true
                local ok, err, extra = lib.callback.await('vr-djbooth:place', false, item, slot, pos, heading, replace == true)
                busy = false
                if ok then
                    local done = kind == 'boombox' and 'Boombox placed.'
                        or kind == 'booster' and 'Range Booster placed.'
                        or ('Speaker placed in %s.'):format(extra or 'a new group')
                    Notify(done, 'success')
                    break
                end
                Notify(ReasonText(err), 'error')
            end
        end
    end

    placing = false
    if DoesEntityExist(ghost) then DeleteEntity(ghost) end
    SendNUIMessage({ action = 'placement', show = false })
end

local function streetAt(c)
    local street, crossing = GetStreetNameAtCoord(c.x + 0.0, c.y + 0.0, c.z + 0.0)
    local name = GetStreetNameFromHashKey(street)
    if name == nil or name == '' then name = GetStreetNameFromHashKey(crossing) end
    if name == nil or name == '' then return 'somewhere in the city' end
    return name
end

RegisterNetEvent('vr-djbooth:client:startPlacement', function(item, slot, old)
    if placing then return end
    local info, kind = DJ.itemInfo(item)
    if not info then return end
    if IsPedInAnyVehicle(cache.ped, true) then return Notify('Get out of the vehicle first.', 'error') end
    if PanelSystem then ClosePanel() end
    local replace = false
    if kind == 'boombox' and type(old) == 'table' and DJ.num(old.x) then
        replace = Confirm({
            title = Lang.boombox_replace_title,
            text = Lang.get('boombox_replace_text', streetAt(old)),
            yes = Lang.boombox_replace_yes,
            no = Lang.boombox_replace_no,
            danger = true,
        })
        if not replace then return end
    end
    place(item, slot, info, kind, replace)
end)
