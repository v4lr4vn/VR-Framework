lib.callback.register('vr-cards:api', function(src, action, data)
    return Api.handle(src, action, data)
end)

Db.onReady(function()
    Shop.load()
    while true do
        Wait(60000)
        local ok, err = pcall(Shop.readyTick)
        if not ok then print(('^1[vr-cards] grading: %s^0'):format(tostring(err))) end
    end
end)

local function reply(src, text, kind)
    if src > 0 then Core.notify(src, text, kind) else print(('[vr-cards] %s'):format(text)) end
end

RegisterCommand('givepack', function(src, args)
    local target = tonumber(args[1])
    local pack = args[2] or Config.DefaultPack
    local count = tonumber(args[3]) or 1
    if not target or not GetPlayerName(target) then return reply(src, 'Usage: /givepack [id] [pack] [count]', 'inform') end
    local ok, err = Packs.give(target, pack, count)
    if not ok then return reply(src, err == 'bad_pack' and 'Unknown pack' or 'They cannot carry that', 'error') end
    reply(src, ('Gave %dx %s'):format(math.max(1, math.floor(count)), Config.Packs[pack].label), 'success')
    Core.notify(target, ('You received %s'):format(Config.Packs[pack].label), 'success')
end, true)

RegisterCommand('givecard', function(src, args)
    local target = tonumber(args[1])
    local card = args[2] and Catalog.get(args[2]:lower())
    local foil = args[3] and args[3]:lower() or 'none'
    if not target or not GetPlayerName(target) or not card then return reply(src, 'Usage: /givecard [id] [card id] [none|shiny|holo]', 'inform') end
    local info = Core.info(target)
    if not info then return end
    if not Core.canCarry(target, Config.Items.card, 1) then return reply(src, 'They cannot carry that', 'error') end
    local c = Copies.create(card.id, foil, info.cid)
    if not c or not Copies.give(target, c, info.cid) then return reply(src, 'Could not give the card', 'error') end
    Copies.markDex(info.cid, card.id)
    reply(src, ('Gave %s (%s)'):format(card.name, Config.Foils.labels[c.foil]), 'success')
end, true)

RegisterCommand('cardshop', function(src)
    if src <= 0 then return end
    local ped = GetPlayerPed(src)
    local p = GetEntityCoords(ped)
    Shop.move(vec4(p.x, p.y, p.z, GetEntityHeading(ped)))
    reply(src, 'Card shop moved here', 'success')
end, true)

if Bridge.inventoryName ~= 'ox' then
    local function slotOf(item)
        return { slot = item.slot, metadata = item.metadata or item.info or {} }
    end
    Bridge.useItem(Config.Items.pack, function(src, item) TriggerClientEvent('vr-cards:client:use', src, 'pack', slotOf(item)) end)
    Bridge.useItem(Config.Items.card, function(src, item) TriggerClientEvent('vr-cards:client:use', src, 'card', slotOf(item)) end)
    Bridge.useItem(Config.Items.binder, function(src, item) TriggerClientEvent('vr-cards:client:use', src, 'binder', slotOf(item)) end)
end
