BHC.actions = {}

local propList = {}

function BHC.clearProps()
    for _, p in ipairs(propList) do
        if p.obj and DoesEntityExist(p.obj) then DeleteEntity(p.obj) end
    end
    propList = {}
end

local function wanted(bank, el)
    if not BHC.usable(bank, el) then return 0 end
    local st = BHC.elState(bank, el)
    local left = st and st.l or el.grabs or 0
    return math.max(0, math.min(math.floor(left), 6))
end

local FALLBACK = {
    cash = { 'prop_cash_pile_01', 'bkr_prop_money_sorted_01', 'prop_money_bag_01' },
    gold = { 'ch_prop_gold_bar_01a', 'h4_prop_h4_gold_bar_01a', 'prop_gold_bar', 'prop_cash_pile_01' },
}

local SPACING = { cash = 0.34, gold = 0.26 }

local function spawnPile(el, index)
    local names = { el.model }
    for _, n in ipairs(FALLBACK[el.type] or FALLBACK.cash) do names[#names + 1] = n end
    local hash = BHC.loadModel(names)
    if not hash then return nil end
    local rad = math.rad(el.w or 0.0)
    local right = vec3(math.cos(rad), math.sin(rad), 0.0)
    local offset = (index - 3.5) * (SPACING[el.type] or 0.3)
    local x, y = el.x + right.x * offset, el.y + right.y * offset
    local obj = CreateObject(hash, x, y, el.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    if not obj or obj == 0 then return nil end
    SetEntityHeading(obj, (el.w or 0.0) + 0.0)
    SetEntityCoordsNoOffset(obj, x, y, el.z, false, false, false)
    FreezeEntityPosition(obj, true)
    SetEntityCollision(obj, false, false)
    return obj
end

function BHC.refreshProps(force)
    local here = GetEntityCoords(BHC.ped())
    local keep = {}
    for _, bank in ipairs(BHC.banks) do
        for _, el in ipairs(bank.elements or {}) do
            if el.type == 'cash' or el.type == 'gold' then
                local key = ('%d:%d'):format(bank.id, el.id)
                local near = #(here - vec3(el.x, el.y, el.z)) < 60.0
                local want = near and wanted(bank, el) or 0
                local have = {}
                for _, p in ipairs(propList) do
                    if p.key == key then have[#have + 1] = p end
                end
                if force and #have > 0 and want == 0 then
                    for _, p in ipairs(have) do
                        if DoesEntityExist(p.obj) then DeleteEntity(p.obj) end
                        p.dead = true
                    end
                end
                while #have > want do
                    local p = table.remove(have)
                    if DoesEntityExist(p.obj) then DeleteEntity(p.obj) end
                    p.dead = true
                end
                while #have < want do
                    local obj = spawnPile(el, #have + 1)
                    if not obj then break end
                    have[#have + 1] = { key = key, obj = obj }
                    propList[#propList + 1] = have[#have]
                end
                for _, p in ipairs(have) do keep[p] = true end
            end
        end
    end
    local alive = {}
    for _, p in ipairs(propList) do
        if not p.dead and keep[p] then
            alive[#alive + 1] = p
        elseif p.obj and DoesEntityExist(p.obj) then
            DeleteEntity(p.obj)
        end
    end
    propList = alive
end

CreateThread(function()
    while true do
        Wait(1500)
        if BHC.ready and #BHC.banks > 0 then pcall(BHC.refreshProps) end
    end
end)

function BHC.progress(o)
    local ped = BHC.ped()
    local ms = math.floor((o.seconds or 3) * 1000)
    BHC.message({ action = 'progress', label = o.label or 'Working', ms = ms })
    if o.face then
        TaskTurnPedToFaceCoord(ped, o.face.x, o.face.y, o.face.z, 500)
        Wait(500)
    end
    if o.anim then
        local dict = lib.requestAnimDict(o.anim.dict)
        if dict then TaskPlayAnim(ped, o.anim.dict, o.anim.clip, 8.0, -8.0, -1, o.anim.flag or 1, 0, false, false, false) end
    end
    local started = GetGameTimer()
    local done = true
    while GetGameTimer() - started < ms do
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 21, true)
        DisableControlAction(0, 22, true)
        DisableControlAction(0, 23, true)
        if IsControlJustPressed(0, 73) then done = false break end
        if IsEntityDead(ped) then done = false break end
        Wait(0)
    end
    if o.anim then ClearPedTasks(ped) end
    BHC.message({ action = 'progressEnd' })
    return done
end

BHC.actions.grab = function(bank, el)
    local cfg = Config.Grab[el.type]
    local done = BHC.progress({
        label = el.type == 'cash' and 'Grabbing cash' or 'Grabbing gold',
        seconds = Config.Grab.seconds,
        face = vec3(el.x, el.y, el.z),
        anim = { dict = cfg.animDict, clip = cfg.animClip, flag = 1 },
    })
    if not done then return end
    local ok, data = BHC.call('grab', bank.id, el.id)
    if not ok then
        if data ~= 'slow_down' then BHC.fail(data) end
        return
    end
    if data.kind == 'cash' then
        BHC.notify(('Grabbed $%d'):format(data.amount), 'success')
    else
        BHC.notify(('Grabbed %d gold bar%s'):format(data.amount, data.amount == 1 and '' or 's'), 'success')
    end
    BHC.refreshProps()
end

BHC.actions.drill = function(bank, el)
    local ok, data = BHC.call('drill:begin', bank.id, el.id)
    if not ok then return BHC.fail(data) end
    local result = BHC.drillGame(el, data.seconds, data.difficulty, function()
        local _, res = BHC.call('drill:jam', bank.id, el.id)
        return type(res) == 'table' and res.broken == true
    end)
    if result == 'done' then
        local good, res = BHC.call('drill:finish', bank.id, el.id)
        if not good then
            BHC.fail(res)
            return
        end
        local parts = {}
        if res.cash then parts[#parts + 1] = ('$%d'):format(res.cash) end
        if res.item then parts[#parts + 1] = ('%dx %s'):format(res.item.count, res.item.name) end
        BHC.notify(#parts > 0 and ('The box held ' .. table.concat(parts, ' and ')) or 'The box was empty', 'success')
    elseif result == 'broken' then
        BHC.notify('The drill bit snapped', 'error')
    else
        BHC.call('drill:cancel', bank.id, el.id)
    end
end

BHC.actions.hack = function(bank, el)
    local ok, data = BHC.call('hack:open', bank.id, el.id)
    if not ok then return BHC.fail(data) end
    if data.external then return end
    BHC.openTerminal(data)
end

local function pickAnim(dict, clip, fallbackDict, fallbackClip)
    local ok, got = pcall(lib.requestAnimDict, dict)
    if ok and got then return { dict = dict, clip = clip } end
    if fallbackDict then
        local fok, fgot = pcall(lib.requestAnimDict, fallbackDict)
        if fok and fgot then return { dict = fallbackDict, clip = fallbackClip } end
    end
    return nil
end

BHC.actions.till = function(bank, el)
    local ok, data = BHC.call('till:begin', bank.id, el.id)
    if not ok then return BHC.fail(data) end
    local cfg = Config.Till
    local done = BHC.progress({
        label = 'Forcing the register',
        seconds = data.seconds,
        face = vec3(el.x, el.y, el.z),
        anim = pickAnim(cfg.animDict, cfg.animClip, cfg.fallbackDict, cfg.fallbackClip),
    })
    if not done then
        BHC.call('till:cancel', bank.id, el.id)
        return
    end
    local good, res = BHC.call('till:finish', bank.id, el.id)
    if not good then return BHC.fail(res) end
    local parts = {}
    if res.cash then parts[#parts + 1] = ('$%d'):format(res.cash) end
    if res.item then parts[#parts + 1] = ('%dx %s'):format(res.item.count, res.item.name) end
    BHC.notify(#parts > 0 and ('The register held ' .. table.concat(parts, ' and ')) or 'The register was empty', #parts > 0 and 'success' or 'inform')
end

local swapped = {}

local function caseKey(bank, el)
    return ('%d:%d'):format(bank.id, el.id)
end

local function applySwap(key, el, broken)
    local cfg = Config.Case
    local entry = swapped[key]
    if broken then
        if entry and entry.broken then return true end
        entry = entry or { pairs = {} }
        entry.pairs = {}
        local here = vec3(el.x, el.y, el.z)
        local best
        for _, pair in ipairs(cfg.swaps) do
            local a, b = joaat(pair[1]), joaat(pair[2])
            local obj = GetClosestObjectOfType(el.x + 0.0, el.y + 0.0, el.z + 0.0, cfg.findRadius, a, false, false, false)
            if obj and obj ~= 0 then
                local c = GetEntityCoords(obj)
                local d = #(c - here)
                if not best or d < best.d then best = { d = d, c = c, a = a, b = b } end
            end
        end
        if best then
            local radius = el.r or 0.4
            CreateModelSwap(best.c.x, best.c.y, best.c.z, radius, best.a, best.b, true)
            entry.pairs[1] = { best.c.x, best.c.y, best.c.z, radius, best.a, best.b }
        end
        if #entry.pairs == 0 then return false end
        entry.broken = true
        swapped[key] = entry
        return true
    end
    if entry and entry.broken then
        for _, p in ipairs(entry.pairs) do RemoveModelSwap(p[1], p[2], p[3], p[4], p[5], p[6], true) end
        swapped[key] = nil
    end
    return true
end

function BHC.syncCases()
    local here = GetEntityCoords(BHC.ped())
    for _, bank in ipairs(BHC.banks) do
        local st = BHC.status[bank.id]
        for _, el in ipairs(bank.elements or {}) do
            if el.type == 'case' then
                local key = caseKey(bank, el)
                local mine = BHC.elState(bank, el)
                local broken = st ~= nil and (st.state == 'cooldown' or (st.state == 'active' and mine ~= nil and mine.d == true))
                local entry = swapped[key]
                local is = entry ~= nil and entry.broken == true
                if broken ~= is then
                    if broken then
                        if #(here - vec3(el.x, el.y, el.z)) < 120.0 then pcall(applySwap, key, el, true) end
                    elseif not (entry and entry.pending) then
                        pcall(applySwap, key, el, false)
                    end
                end
            end
        end
    end
end

CreateThread(function()
    while true do
        Wait(1500)
        if BHC.ready and #BHC.banks > 0 then pcall(BHC.syncCases) end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for _, entry in pairs(swapped) do
        for _, p in ipairs(entry.pairs or {}) do pcall(RemoveModelSwap, p[1], p[2], p[3], p[4], p[5], p[6], true) end
    end
    swapped = {}
end)

local function smashEffect(bank, el)
    local key = caseKey(bank, el)
    applySwap(key, el, true)
    if swapped[key] then swapped[key].pending = true end
    local cfg = Config.Case
    local ok = pcall(lib.requestNamedPtfxAsset, cfg.ptfxAsset)
    if ok then
        UseParticleFxAsset(cfg.ptfxAsset)
        StartParticleFxNonLoopedAtCoord(cfg.ptfx, el.x + 0.0, el.y + 0.0, el.z + 0.0, 0.0, 0.0, 0.0, 1.0, false, false, false)
    end
end

BHC.actions.case = function(bank, el)
    local cfg = Config.Case
    local ped = BHC.ped()
    if cfg.needWeapon and GetSelectedPedWeapon(ped) == joaat('WEAPON_UNARMED') then
        return BHC.fail('need_weapon')
    end
    local ok, data = BHC.call('case:begin', bank.id, el.id)
    if not ok then return BHC.fail(data) end
    local clip = cfg.clips[data.anim] or cfg.clips.necklace
    local anim = pickAnim(cfg.dict, clip)
    TaskTurnPedToFaceCoord(ped, el.x, el.y, el.z, 500)
    Wait(500)
    local total = 2200
    if anim then
        TaskPlayAnim(ped, anim.dict, anim.clip, 8.0, -8.0, -1, 0, 0.0, false, false, false)
        total = math.max(1500, math.min(8000, math.floor(GetAnimDuration(anim.dict, anim.clip) * 1000)))
    end
    local started = GetGameTimer()
    local hit = math.floor(total * cfg.hitAt)
    local hitDone = false
    local aborted = false
    while GetGameTimer() - started < total do
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        if IsEntityDead(ped) then aborted = true break end
        if not hitDone and GetGameTimer() - started >= hit then
            hitDone = true
            smashEffect(bank, el)
        end
        Wait(0)
    end
    if aborted then
        local entry = swapped[caseKey(bank, el)]
        if entry then entry.pending = nil end
        applySwap(caseKey(bank, el), el, false)
        BHC.call('case:cancel', bank.id, el.id)
        return
    end
    if not hitDone then smashEffect(bank, el) end
    ClearPedTasks(ped)
    local good, res = BHC.call('case:finish', bank.id, el.id)
    local entry = swapped[caseKey(bank, el)]
    if entry then entry.pending = nil end
    if not good then
        applySwap(caseKey(bank, el), el, false)
        return BHC.fail(res)
    end
    local parts = {}
    if res.item then parts[#parts + 1] = ('%dx %s'):format(res.item.count, res.item.name) end
    if res.rare then parts[#parts + 1] = ('%dx %s'):format(res.rare.count, res.rare.name) end
    if res.cash then parts[#parts + 1] = ('$%d'):format(res.cash) end
    BHC.notify(#parts > 0 and ('You grabbed ' .. table.concat(parts, ', ')) or 'The case was empty', #parts > 0 and 'success' or 'inform')
end
