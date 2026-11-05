TCG = { open = false, mode = nil }

local ERR = {
    no_pack = 'That pack is gone',
    no_room = 'Make room in your pockets first',
    no_card = 'You do not have that card',
    no_binder = 'You need the binder on you',
    too_far = 'Head to the card shop',
    no_money = 'Not enough money',
    slow_down = 'Slow down a little',
    failed = 'Something went wrong, try again',
}

function TCG.errorText(code)
    return ERR[code] or ERR.failed
end

function TCG.api(action, data)
    local ok, res = pcall(lib.callback.await, 'vr-cards:api', false, action, data)
    if not ok or type(res) ~= 'table' then return { ok = false, error = 'failed' } end
    return res
end

function TCG.notify(text, kind)
    lib.notify({ title = 'Cards', description = text, type = kind or 'inform' })
end

function TCG.show(mode, data)
    TCG.open = true
    TCG.mode = mode
    SendNUIMessage({ action = 'open', mode = mode, data = data, sound = Config.Sound.volume })
    SetNuiFocus(true, true)
end

function TCG.hide()
    if not TCG.open then return end
    TCG.open = false
    TCG.mode = nil
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function TCG.openPack(slot)
    if TCG.open then return end
    local res = TCG.api('pack.open', { slot = slot })
    if not res.ok then return TCG.notify(TCG.errorText(res.error), 'error') end
    TCG.show('pack', res.data)
end

function TCG.openBinder(id)
    local res = TCG.api('binder.open', { id = id })
    if not res.ok then return TCG.notify(TCG.errorText(res.error), 'error') end
    TCG.show('binder', res.data)
end

function TCG.openShop()
    local res = TCG.api('shop.open', {})
    if not res.ok then return TCG.notify(TCG.errorText(res.error), 'error') end
    TCG.show('shop', res.data)
end

local function firstPackSlot()
    local list = Bridge.inventory.search(Config.Items.pack)
    if list[1] then return list[1].slot end
    return nil
end

RegisterNUICallback('api', function(d, cb)
    if type(d) ~= 'table' or type(d.action) ~= 'string' then return cb({ ok = false, error = 'bad_request' }) end
    cb(TCG.api(d.action, type(d.data) == 'table' and d.data or {}))
end)

RegisterNUICallback('close', function(_, cb)
    cb(true)
    TCG.hide()
end)

RegisterNUICallback('nextPack', function(_, cb)
    local slot = firstPackSlot()
    if not slot then return cb({ ok = false, error = 'no_pack' }) end
    cb(TCG.api('pack.open', { slot = slot }))
end)

RegisterNUICallback('packCount', function(_, cb)
    cb(Bridge.inventory.count(Config.Items.pack))
end)

local function usePack(slot)
    if type(slot) == 'table' and slot.slot then TCG.openPack(slot.slot) end
end

local function viewCard(slot)
    local uid = type(slot) == 'table' and type(slot.metadata) == 'table' and slot.metadata.uid
    if not uid or TCG.open then return end
    local res = TCG.api('card.view', { uid = uid })
    if not res.ok then return TCG.notify(TCG.errorText(res.error), 'error') end
    TCG.show('card', res.data)
end

local function useBinder(slot)
    local id = type(slot) == 'table' and type(slot.metadata) == 'table' and tonumber(slot.metadata.binderId)
    if not id then return TCG.notify('This binder is empty and unregistered', 'error') end
    if TCG.open then return end
    TCG.openBinder(id)
end

exports('openPack', function(_, slot) usePack(slot) end)
exports('viewCard', function(_, slot) viewCard(slot) end)
exports('openBinder', function(_, slot) useBinder(slot) end)

RegisterNetEvent('vr-cards:client:use', function(kind, slot)
    if kind == 'pack' then usePack(slot)
    elseif kind == 'card' then viewCard(slot)
    elseif kind == 'binder' then useBinder(slot) end
end)

AddEventHandler('onResourceStop', function(name)
    if name == GetCurrentResourceName() and TCG.open then SetNuiFocus(false, false) end
end)
