local function reply(src, text, kind)
    if src > 0 then Core.notify(src, text, kind) else print(('[vr-garages] %s'):format(text)) end
end

local function here(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local veh = GetVehiclePedIsIn(ped, false)
    local ent = veh ~= 0 and veh or ped
    local p = GetEntityCoords(ent)
    return vec4(p.x, p.y, p.z, GetEntityHeading(ent)), veh ~= 0 and veh or nil
end

local function editable(id)
    local def = Garages.raw(id)
    if not def then return nil end
    local copy = {}
    for k, v in pairs(def) do copy[k] = v end
    local spawns = {}
    for i, s in ipairs(def.spawns) do spawns[i] = s end
    copy.spawns = spawns
    return copy
end

local sub = {}

function sub.create(src, args)
    local id = args[1] and args[1]:lower():gsub('[^%w_]', '')
    if not id or id == '' then return reply(src, 'Usage: /garage create [id] [public|job|gang|impound] [group]', 'error') end
    if Garages.raw(id) then return reply(src, ('Garage %s already exists'):format(id), 'error') end
    local pos = here(src)
    if not pos then return end
    local kind = args[2] or 'public'
    if (kind == 'job' or kind == 'gang') and not args[3] then return reply(src, 'Job and gang garages need a group name', 'error') end
    local def = {
        id = id, label = id, type = kind, category = kind == 'impound' and 'all' or 'car', group = args[3],
        center = vec3(pos.x, pos.y, pos.z), radius = Config.ZoneRadius, spawns = {}, blip = true, requireDuty = false,
    }
    Garages.store(id, def)
    reply(src, ('Garage %s created here. Add spawn spots with /garage spawn %s'):format(id, id), 'success')
end

function sub.spawn(src, args)
    local def = editable(args[1] or '')
    if not def then return reply(src, 'Unknown garage', 'error') end
    local pos = here(src)
    def.spawns[#def.spawns + 1] = pos
    Garages.store(def.id, def)
    reply(src, ('Spawn spot %d added to %s'):format(#def.spawns, def.id), 'success')
end

function sub.clearspawns(src, args)
    local def = editable(args[1] or '')
    if not def then return reply(src, 'Unknown garage', 'error') end
    def.spawns = {}
    Garages.store(def.id, def)
    reply(src, ('Spawn spots cleared for %s'):format(def.id), 'success')
end

function sub.center(src, args)
    local def = editable(args[1] or '')
    if not def then return reply(src, 'Unknown garage', 'error') end
    local pos = here(src)
    def.center = vec3(pos.x, pos.y, pos.z)
    Garages.store(def.id, def)
    reply(src, ('Moved %s here'):format(def.id), 'success')
end

function sub.radius(src, args)
    local def = editable(args[1] or '')
    local r = tonumber(args[2])
    if not def or not r then return reply(src, 'Usage: /garage radius [id] [metres]', 'error') end
    def.radius = math.max(3, math.min(80, r)) + 0.0
    Garages.store(def.id, def)
    reply(src, ('%s radius is now %.0fm'):format(def.id, def.radius), 'success')
end

function sub.label(src, args)
    local def = editable(args[1] or '')
    if not def or not args[2] then return reply(src, 'Usage: /garage label [id] [name]', 'error') end
    def.label = table.concat(args, ' ', 2):gsub('[%c<>]', ''):sub(1, 40)
    Garages.store(def.id, def)
    reply(src, ('Renamed %s to %s'):format(def.id, def.label), 'success')
end

function sub.category(src, args)
    local def = editable(args[1] or '')
    local c = args[2]
    if not def or not ({ car = true, air = true, boat = true, all = true })[c] then return reply(src, 'Usage: /garage category [id] [car|air|boat|all]', 'error') end
    def.category = c
    Garages.store(def.id, def)
    reply(src, ('%s now holds %s'):format(def.id, c), 'success')
end

function sub.duty(src, args)
    local def = editable(args[1] or '')
    if not def then return reply(src, 'Unknown garage', 'error') end
    def.requireDuty = not def.requireDuty
    Garages.store(def.id, def)
    reply(src, ('%s %s'):format(def.id, def.requireDuty and 'needs players on duty' or 'works off duty too'), 'success')
end

function sub.blip(src, args)
    local def = editable(args[1] or '')
    if not def then return reply(src, 'Unknown garage', 'error') end
    def.blip = not def.blip
    Garages.store(def.id, def)
    reply(src, ('%s blip %s'):format(def.id, def.blip and 'on' or 'off'), 'success')
end

function sub.delete(src, args)
    local id = args[1] or ''
    if not Garages.raw(id) then return reply(src, 'Unknown garage', 'error') end
    Garages.store(id, nil)
    reply(src, ('Garage %s deleted'):format(id), 'success')
end

function sub.list(src)
    local ids = {}
    for id, def in pairs(Garages.list) do ids[#ids + 1] = ('%s (%s, %d spots)'):format(id, def.type, #def.spawns) end
    table.sort(ids)
    reply(src, table.concat(ids, ', '), 'inform')
end

function sub.debug(src)
    TriggerClientEvent('vr-garages:client:debug', src)
end

local function allowed(src)
    return src > 0 and (IsPlayerAceAllowed(tostring(src), 'command.garage') == true or Bridge.isAdmin(src) == true)
end

local function groups()
    local function pack(list)
        local out = {}
        for name, info in pairs(list or {}) do
            local grades = {}
            for _, g in ipairs(Bridge.grades(name)) do grades[#grades + 1] = { level = g.level, name = g.name } end
            out[#out + 1] = { name = name, label = type(info) == 'table' and info.label or name, grades = grades }
        end
        table.sort(out, function(a, b) return tostring(a.label):lower() < tostring(b.label):lower() end)
        return out
    end
    return { job = pack(Bridge.jobs()), gang = pack(Bridge.gangs()) }
end

local function snapshot()
    local out = {}
    for id, def in pairs(Garages.list) do
        local g = Garages.serialise(def)
        g.source = Garages.source(id)
        out[#out + 1] = g
    end
    for _, def in ipairs(Garages.removedConfig()) do
        local g = Garages.serialise(def)
        g.source = 'removed'
        out[#out + 1] = g
    end
    table.sort(out, function(a, b) return a.label:lower() < b.label:lower() end)
    return out
end

local function after(info, what, id)
    pcall(Vehicles.tidy)
    print(('[vr-garages] %s (%s) %s garage %s'):format(info.name or '?', info.cid or '?', what, id))
end

Api.reg('builder.open', function(info)
    if not allowed(info.src) then return Api.fail('no_access') end
    return Api.ok({ garages = snapshot(), groups = groups(), radius = Config.ZoneRadius })
end)

Api.reg('builder.save', function(info, d)
    if not allowed(info.src) then return Api.fail('no_access') end
    local id = type(d.id) == 'string' and d.id:lower() or nil
    if not id then return Api.fail('bad_id') end
    local exists = Garages.raw(id) ~= nil or Config.Garages[id] ~= nil
    if d.isNew and exists then return Api.fail('id_taken') end
    if not d.isNew and not exists then return Api.fail('no_garage') end
    local def, err = Garages.fromInput(id, d.garage)
    if not def then return Api.fail(err) end
    Garages.store(id, def)
    after(info, d.isNew and 'created' or 'saved', id)
    return Api.ok({ garages = snapshot(), id = id })
end)

Api.reg('builder.delete', function(info, d)
    if not allowed(info.src) then return Api.fail('no_access') end
    local id = type(d.id) == 'string' and d.id or ''
    if not Garages.raw(id) then return Api.fail('no_garage') end
    Garages.store(id, nil)
    after(info, 'removed', id)
    return Api.ok({ garages = snapshot() })
end)

Api.reg('builder.reset', function(info, d)
    if not allowed(info.src) then return Api.fail('no_access') end
    local id = type(d.id) == 'string' and d.id or ''
    if not Garages.reset(id) then return Api.fail('no_garage') end
    after(info, 'reset', id)
    return Api.ok({ garages = snapshot() })
end)

RegisterCommand('garage', function(src, args)
    if not args[1] then
        if src <= 0 then return reply(src, 'Open the garage builder in game with /garage', 'inform') end
        return TriggerClientEvent('vr-garages:client:builder', src)
    end
    local fn = sub[(args[1] or ''):lower()]
    if not fn then
        return reply(src, 'Type /garage on its own to open the garage builder', 'inform')
    end
    table.remove(args, 1)
    fn(src, args)
end, true)
