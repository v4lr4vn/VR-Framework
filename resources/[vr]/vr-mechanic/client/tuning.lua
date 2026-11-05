Tuning = { veh = nil, netId = nil, original = nil, previewed = {}, cart = {}, pending = nil, pendingCart = nil }

local IDX = { modEngine = 11, modBrakes = 12, modTransmission = 13, modSuspension = 15, modArmor = 16 }
local WHEEL_TYPES = {
    { 0, 'Sport' }, { 1, 'Muscle' }, { 2, 'Lowrider' }, { 3, 'SUV' }, { 4, 'Off-road' }, { 5, 'Tuner' }, { 7, 'High end' },
    { 8, "Benny's Original" }, { 9, "Benny's Bespoke" }, { 10, 'Open wheel' }, { 11, 'Street' }, { 12, 'Track' },
}
local PAINT = { color1 = true, color2 = true, paintType1 = true, paintType2 = true, pearlescentColor = true, wheelColor = true }

local function text(label, fallback)
    if not label or label == '' then return fallback end
    local t = GetLabelText(label)
    if not t or t == 'NULL' then return fallback end
    return t
end

local function modLabel(veh, modType, i)
    return text(GetModTextLabel(veh, modType, i), ('Option %d'):format(i + 1))
end

local function control(veh)
    local t = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(veh) and GetGameTimer() < t do
        NetworkRequestControlOfEntity(veh)
        Wait(25)
    end
    return NetworkHasControlOfEntity(veh)
end

local function rgbOf(veh, slot)
    if slot == 1 then
        if GetIsVehiclePrimaryColourCustom(veh) then return { GetVehicleCustomPrimaryColour(veh) } end
        return { GetVehicleColor(veh) }
    end
    if GetIsVehicleSecondaryColourCustom(veh) then return { GetVehicleCustomSecondaryColour(veh) } end
    return nil
end

local function copy(t)
    if type(t) ~= 'table' then return t end
    local o = {}
    for k, v in pairs(t) do o[k] = copy(v) end
    return o
end

function Tuning.options(veh)
    SetVehicleModKit(veh, 0)
    local perf = {}
    for _, p in ipairs(Config.Tuning.performance) do
        if p.toggle then perf[p.key] = 1 else perf[p.key] = GetNumVehicleMods(veh, IDX[p.key]) end
    end
    local body = {}
    for _, b in ipairs(Config.Tuning.bodyMods) do
        local n = GetNumVehicleMods(veh, b.id)
        if n and n > 0 then
            local opts = {}
            for i = 0, n - 1 do opts[#opts + 1] = b.key == 'modHorns' and ('Horn %d'):format(i + 1) or modLabel(veh, b.id, i) end
            body[b.key] = opts
        end
    end
    local livery
    local count = GetVehicleLiveryCount(veh)
    if count and count > 0 then
        livery = { key = 'livery', options = {} }
        for i = 0, count - 1 do livery.options[#livery.options + 1] = text(GetLiveryName(veh, i), ('Livery %d'):format(i + 1)) end
    else
        local n = GetNumVehicleMods(veh, 48)
        if n and n > 0 then
            livery = { key = 'modLivery', options = {} }
            for i = 0, n - 1 do livery.options[#livery.options + 1] = modLabel(veh, 48, i) end
        end
    end
    local class = GetVehicleClass(veh)
    local bike = class == 8
    return {
        perf = perf,
        body = body,
        livery = livery,
        bike = bike,
        wheelTypes = bike and { { 6, 'Bike' } } or WHEEL_TYPES,
        neon = not bike and class ~= 13 and class ~= 14 and class ~= 15 and class ~= 16,
    }
end

function Tuning.wheelList(wtype)
    local veh = Tuning.veh
    if not veh or not DoesEntityExist(veh) then return {} end
    wtype = tonumber(wtype) or 0
    local curType, curMod = GetVehicleWheelType(veh), GetVehicleMod(veh, 23)
    local curVar = GetVehicleModVariation(veh, 23)
    local backMod = GetVehicleMod(veh, 24)
    SetVehicleWheelType(veh, wtype)
    local out = {}
    for i = 0, GetNumVehicleMods(veh, 23) - 1 do out[#out + 1] = modLabel(veh, 23, i) end
    SetVehicleWheelType(veh, curType)
    SetVehicleMod(veh, 23, curMod, curVar)
    if GetVehicleClass(veh) == 8 then SetVehicleMod(veh, 24, backMod, curVar) end
    return out
end

local function currentFrom(p, veh)
    local cur = {}
    for _, perf in ipairs(Config.Tuning.performance) do cur[perf.key] = perf.toggle and p.modTurbo == true or (p[perf.key] or -1) end
    for _, b in ipairs(Config.Tuning.bodyMods) do cur[b.key] = p[b.key] or -1 end
    cur.color1 = rgbOf(veh, 1)
    cur.color2 = rgbOf(veh, 2)
    cur.paintType1 = p.paintType1 or 0
    cur.paintType2 = p.paintType2 or 0
    cur.pearlescentColor = p.pearlescentColor or 0
    cur.wheelColor = p.wheelColor or 0
    cur.wheels = p.wheels or 0
    cur.modFrontWheels = p.modFrontWheels or -1
    cur.modCustomTiresF = p.modCustomTiresF == true
    cur.windowTint = p.windowTint or -1
    cur.plateIndex = p.plateIndex or 0
    cur.neonEnabled = p.neonEnabled or { false, false, false, false }
    cur.neonColor = p.neonColor or { 255, 255, 255 }
    cur.modXenon = p.modXenon == true
    cur.xenonColor = (p.xenonColor == nil or p.xenonColor < 0 or p.xenonColor > 12) and 255 or p.xenonColor
    cur.livery = p.livery or -1
    cur.modLivery = p.modLivery or -1
    return cur
end

function Tuning.normalize(changes)
    if type(changes) ~= 'table' then return {} end
    local c = copy(changes)
    local cur = Tuning.current or {}
    if c.paintType1 ~= nil and c.color1 == nil then c.color1 = copy(cur.color1) end
    if c.paintType2 ~= nil and c.color2 == nil then
        if cur.color2 then c.color2 = copy(cur.color2) else c.paintType2 = nil end
    end
    if c.modFrontWheels ~= nil and c.wheels == nil then c.wheels = cur.wheels end
    if c.wheels ~= nil and c.modFrontWheels == nil then c.modFrontWheels = -1 end
    if Tuning.bike and c.modFrontWheels ~= nil then c.modBackWheels = c.modFrontWheels end
    return c
end

function Tuning.keepFor(changes)
    if type(changes) ~= 'table' then return nil end
    local cur = Tuning.current or {}
    local keep = {}
    if changes.color1 ~= nil then
        if changes.paintType1 == nil then keep.paintType1 = cur.paintType1 end
        if changes.pearlescentColor == nil then keep.pearlescentColor = cur.pearlescentColor end
    end
    if changes.color2 ~= nil and changes.paintType2 == nil then keep.paintType2 = cur.paintType2 end
    return keep
end

local function applyPaint(veh, cart)
    local cur, orig = Tuning.current, Tuning.original
    local pearl = cart.pearlescentColor or cur.pearlescentColor or 0
    local wheel = cart.wheelColor or cur.wheelColor or 0
    local idx1 = cart.color1 == nil and type(orig.color1) == 'number' and orig.color1 or nil
    local idx2 = cart.color2 == nil and type(orig.color2) == 'number' and orig.color2 or nil
    if idx1 or idx2 then
        local p, s = GetVehicleColours(veh)
        if idx1 then ClearVehicleCustomPrimaryColour(veh) end
        if idx2 then ClearVehicleCustomSecondaryColour(veh) end
        SetVehicleColours(veh, idx1 or p, idx2 or s)
    end
    if not idx1 then
        local c = cart.color1 or cur.color1
        SetVehicleModColor_1(veh, cart.paintType1 or cur.paintType1 or 0, 0, pearl)
        if type(c) == 'table' then SetVehicleCustomPrimaryColour(veh, c[1], c[2], c[3]) end
    end
    if not idx2 then
        local c = cart.color2 or cur.color2
        SetVehicleModColor_2(veh, cart.paintType2 or cur.paintType2 or 0, 0)
        if type(c) == 'table' then SetVehicleCustomSecondaryColour(veh, c[1], c[2], c[3]) end
    end
    SetVehicleExtraColours(veh, pearl, wheel)
end

function Tuning.preview(cart)
    local veh = Tuning.veh
    if not veh or not DoesEntityExist(veh) or not Tuning.current then return end
    cart = Tuning.normalize(cart)
    local touched = {}
    for k in pairs(Tuning.previewed) do touched[k] = true end
    for k in pairs(cart) do touched[k] = true end
    local props, paint = {}, false
    for k in pairs(touched) do
        if PAINT[k] then
            paint = true
        else
            local v = cart[k]
            if v == nil then v = Tuning.original[k] end
            if v == nil then v = Tuning.current[k] end
            if v ~= nil then props[k] = copy(v) end
        end
    end
    if props.modFrontWheels ~= nil and props.wheels == nil then props.wheels = Tuning.current.wheels end
    if props.wheels ~= nil and props.modFrontWheels == nil then props.modFrontWheels = Tuning.current.modFrontWheels end
    if next(props) then lib.setVehicleProperties(veh, props) end
    if paint then applyPaint(veh, cart) end
    Tuning.previewed = {}
    for k in pairs(cart) do Tuning.previewed[k] = true end
    Tuning.cart = cart
end

function Tuning.revert()
    if next(Tuning.previewed) then Tuning.preview({}) end
    Tuning.previewed = {}
    Tuning.cart = {}
end

function Tuning.reset()
    Tuning.veh, Tuning.netId, Tuning.original, Tuning.current = nil, nil, nil, nil
    Tuning.previewed, Tuning.cart = {}, {}
    Tuning.design = false
end

function Tuning.billed(token, changes)
    Tuning.pending = token
    Tuning.pendingCart = copy(changes or Tuning.cart)
end

function Tuning.closed()
    Cam.stop()
    if Tuning.design then return Design.close() end
    if Tuning.pending then return end
    Tuning.revert()
    Tuning.reset()
end

function Tuning.finished(orderId)
    Tuning.revert()
    if Mech.open and Mech.mode == 'tune' then Mech.hide() end
    Tuning.reset()
    if orderId then
        if not Mech.open then
            Mech.openOrder(orderId)
        else
            Mech.notify(('Order #%d is paid. Open it from the work orders board to fit the parts'):format(orderId), 'success')
        end
    end
end

RegisterNetEvent('vr-mechanic:client:billResult', function(token, accepted, orderId)
    if Tuning.pending ~= token then return end
    local cart = Tuning.pendingCart
    Tuning.pending, Tuning.pendingCart = nil, nil
    if not Tuning.current then return end
    Tuning.previewed = {}
    for k in pairs(cart or {}) do Tuning.previewed[k] = true end
    if accepted then return Tuning.finished(orderId) end
    Tuning.revert()
    if Mech.open and Mech.mode == 'tune' then
        SendNUIMessage({ action = 'billResult', accepted = false, current = Tuning.current })
    elseif not Mech.open then
        Tuning.reset()
    end
end)

local function payload(d, veh)
    d.options = Tuning.options(veh)
    d.current = Tuning.current
    d.palette = Config.Palette
    d.swatches = Config.Swatches
    d.neonColors = Config.NeonColors
    d.xenonColors = Config.XenonColors
    d.maxBill = Config.MaxBill
    return d
end

function Tuning.open(veh)
    if not veh or not DoesEntityExist(veh) then return end
    if Tuning.pending and Tuning.veh ~= veh then return Mech.notify('Wait for the customer to answer the last bill', 'error') end
    local netId = NetworkGetNetworkIdFromEntity(veh)
    local res = Mech.api('tune.open', { netId = netId })
    if not res.ok then return Mech.notify(Mech.errorText(res.error), 'error') end
    local owns = control(veh)
    if Tuning.veh ~= veh or not Tuning.original then
        Tuning.veh, Tuning.netId = veh, netId
        Tuning.original = lib.getVehicleProperties(veh) or {}
        Tuning.current = currentFrom(Tuning.original, veh)
        Tuning.previewed, Tuning.cart = {}, {}
    end
    Tuning.design = false
    Tuning.bike = GetVehicleClass(veh) == 8
    Mech.netId = netId
    local d = payload(res.data, veh)
    d.label = d.label or Mech.vehicleLabel(veh)
    d.cart = Tuning.pending and Tuning.pendingCart or nil
    d.preview = owns
    Mech.show('tune', d)
    Cam.start(veh)
end

function Tuning.beginDesign(clone, real, props, data)
    Tuning.veh, Tuning.netId = clone, NetworkGetNetworkIdFromEntity(real)
    Tuning.original = props
    Tuning.current = currentFrom(props, clone)
    Tuning.previewed, Tuning.cart = {}, {}
    Tuning.design = true
    Tuning.bike = GetVehicleClass(clone) == 8
    local d = payload(data, clone)
    d.label = d.label or Mech.vehicleLabel(real)
    d.preview = true
    return d
end

RegisterNUICallback('tunePreview', function(d, cb)
    cb(true)
    if Tuning.pending then return end
    Tuning.preview(type(d) == 'table' and d.cart or {})
end)

RegisterNUICallback('tuneWheels', function(d, cb)
    cb(Tuning.wheelList(type(d) == 'table' and d.type or 0))
end)
