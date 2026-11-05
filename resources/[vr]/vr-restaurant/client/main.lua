Rn = { spots = {}, zones = {}, blips = {}, busy = false }

local ERRORS = {
    not_ready = 'Not ready yet, try again',
    no_player = 'Choose a character first',
    bad_request = 'Something went wrong, try again',
    bad_value = 'That value is not allowed',
    slow_down = 'Slow down a little',
    too_far = 'You are too far away',
    failed = 'Something went wrong, try again',
    not_found = 'That no longer exists',
    not_staff = 'You do not work here',
    not_owner = 'Only the owner can do that',
    no_permission = 'Your rank is not allowed to do that',
    too_senior = 'You can only manage people and ranks below yours',
    perm_not_yours = 'You can only give permissions you have yourself',
    name_taken = 'There is already a rank with that name',
    too_many_ranks = 'There are already as many ranks as this restaurant allows',
    too_many_staff = 'This restaurant has all the staff it can have',
    rank_in_use = 'Move the people in that rank somewhere else first',
    has_job = 'They already work at a restaurant',
    declined = 'They did not accept',
    no_answer = 'The offer never appeared on their screen. Ask them to check their F8 console',
    busy = 'They are already looking at an offer',
    owner_cannot_quit = 'The owner cannot quit. Ask an admin to change the owner',
    no_money = 'You do not have enough cash',
    not_enough_in_account = 'There is not enough in the business account',
    not_admin = 'You cannot use this',
    limit = 'There are as many restaurants or crafting areas as the server allows',
    closed = 'This restaurant is closed, so nobody can clock in',
    not_for_sale = 'That business is not for sale',
    banned = 'You are not allowed to buy a business right now',
    closed_for_good = 'This business was shut down. It will be put up for sale again later',
    already_clean = 'This area is already clean',
    not_inspector = 'You need to be on duty as a Food Standards officer',
    no_owner = 'This business has no owner',
    not_closed = 'It is not closed',
    not_on_duty = 'Clock in at the staff office first',
    wrong_item = 'That does not go in here',
    storage_full = 'There is no more room in here',
    no_room = 'You have no room to carry that',
    spoiled = 'That has gone off',
    not_priced = 'That is not on the menu yet',
    customer_no_money = 'They could not afford it',
    too_many_dishes = 'You already have as many designed dishes as allowed',
    too_many_ingredients = 'That is too many different ingredients',
    no_nutrition = 'Food needs something filling in it and a drink needs something to drink. Check the ingredients and where it is made',
    bad_image = 'That picture link is not allowed. Use a direct https link ending in .png, .jpg, .jpeg, .webp or .gif from an allowed image site',
    nothing_to_add = 'You already have all the starter dishes',
    missing_ingredients = 'You are missing ingredients',
}

function Rn.text(code) return ERRORS[code] or ERRORS.failed end

function Rn.notify(text, kind)
    lib.notify({ title = 'Restaurant', description = text, type = kind or 'inform' })
end

function Rn.fail(code, extra)
    local text = Rn.text(code)
    if code == 'wage_too_high' and type(extra) == 'table' then
        text = ('The most that can be paid is $%d'):format(extra.max or 0)
    elseif code == 'missing_ingredients' and type(extra) == 'table' and extra.label then
        text = ('You have no fresh %s in the fridge'):format(extra.label)
    elseif code == 'not_yet' and type(extra) == 'table' then
        text = ('The licence still has %s left. You can renew it in the last %d days'):format(Rn.span(extra.left or 0), Config.Licence.renewWindowDays)
    elseif code == 'level_too_high' and type(extra) == 'table' then
        text = ('A rank has to be below yours, so the highest level you can use is %d'):format(extra.max or 0)
    end
    Rn.notify(text, 'error')
end

function Rn.call(name, ...)
    local res = lib.callback.await('vr-restaurant:' .. name, false, ...)
    if type(res) ~= 'table' then return false, 'failed' end
    if res.ok then return true, res.data end
    return false, res.error, res.data
end

-- 93784 -> '1 day 2 hours'
function Rn.span(seconds)
    seconds = math.max(0, math.floor(tonumber(seconds) or 0))
    local d, h, m = seconds // 86400, (seconds % 86400) // 3600, (seconds % 3600) // 60
    if d > 0 then return ('%d day%s%s'):format(d, d == 1 and '' or 's', h > 0 and (' %d hour%s'):format(h, h == 1 and '' or 's') or '') end
    if h > 0 then return ('%d hour%s%s'):format(h, h == 1 and '' or 's', m > 0 and (' %d min'):format(m) or '') end
    return ('%d min'):format(math.max(1, m))
end

function Rn.stars(n)
    n = math.max(0, math.min(5, tonumber(n) or 0))
    return ('★'):rep(n) .. ('☆'):rep(5 - n)
end

function Rn.money(n)
    local s = tostring(math.floor(n or 0))
    local out = s:reverse():gsub('(%d%d%d)', '%1,'):reverse():gsub('^,', '')
    return '$' .. out
end

local function clearZones()
    for _, id in ipairs(Rn.zones) do pcall(function() Bridge.target.removeZone(id) end) end
    Rn.zones = {}
end

local function clearBlips()
    for _, b in ipairs(Rn.blips) do
        if DoesBlipExist(b) then RemoveBlip(b) end
    end
    Rn.blips = {}
end

local function build()
    clearZones()
    clearBlips()
    for _, spot in ipairs(Rn.spots) do
        local id = Bridge.target.addSphereZone({
            name = ('vr-restaurant:%d'):format(spot.id),
            coords = vec3(spot.x, spot.y, spot.z),
            radius = 1.6,
            options = {
                {
                    name = ('vr-restaurant:%d:office'):format(spot.id),
                    label = 'Staff office',
                    icon = 'fa-solid fa-clipboard-user',
                    distance = Config.Business.reach,
                    canInteract = function() return not Rn.busy end,
                    onSelect = function()
                        CreateThread(function() Rn.openOffice(spot.id) end)
                    end,
                },
            },
        })
        Rn.zones[#Rn.zones + 1] = id

        local blip = AddBlipForCoord(spot.x, spot.y, spot.z)
        SetBlipSprite(blip, Config.Blip.sprite)
        SetBlipScale(blip, Config.Blip.scale)
        SetBlipColour(blip, spot.closed and 1 or Config.Blip.colour)
        SetBlipAsShortRange(blip, true)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(spot.label)
        EndTextCommandSetBlipName(blip)
        Rn.blips[#Rn.blips + 1] = blip
    end
end

local function apply(list)
    Rn.spots = type(list) == 'table' and list or {}
    build()
end

RegisterNetEvent('vr-restaurant:client:spots', function(list)
    apply(list)
end)

CreateThread(function()
    Wait(1500)
    apply(lib.callback.await('vr-restaurant:spots', false))
end)

-- A job offer from a manager. The answer goes back to the server.
lib.callback.register('vr-restaurant:invite', function(offer)
    if type(offer) ~= 'table' then return false end
    local answered = false
    CreateThread(function()
        Wait((tonumber(offer.seconds) or 30) * 1000)
        if not answered then pcall(lib.closeAlertDialog, 'cancel') end
    end)
    local choice = lib.alertDialog({
        header = 'Job offer',
        content = ('%s offers you a job at **%s** as **%s**.\n\nWage: %s each payday while you are clocked in.'):format(
            tostring(offer.by or 'Someone'), tostring(offer.business or 'a restaurant'), tostring(offer.rank or 'staff'), Rn.money(offer.wage or 0)),
        centered = true,
        cancel = true,
    })
    answered = true
    return choice == 'confirm'
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    clearZones()
    clearBlips()
end)
