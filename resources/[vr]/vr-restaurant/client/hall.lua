-- City Hall: buy a restaurant, buy and renew its licence, hand it back.
-- Opened from the clerk's menu in vr-cityhall (exports['vr-restaurant']:OpenBusinesses()).

local ROOT = 'vr-restaurant:hall'

local REASON = {
    licence = 'No valid licence',
    hygiene = 'Failed a hygiene inspection',
    officer = 'Closed by a Food Standards officer',
    revoked = 'Shut down for good',
}

local function act(action, id)
    local ok, data, extra = Rn.call('hallAct', action, id)
    if not ok then
        Rn.fail(data, extra)
        return false
    end
    return true, data
end

local function confirm(header, content)
    return lib.alertDialog({ header = header, content = content, centered = true, cancel = true }) == 'confirm'
end

local function licenceLines(m)
    local l = m.licence
    if l.status == 'none' then
        return 'No licence', ('You need one to run legally. Cost %s, lasts %d days'):format(Rn.money(m.fee), m.days)
    elseif l.valid then
        return ('Licence %s'):format(l.number), ('Valid for another %s'):format(Rn.span(l.left))
    end
    return ('Licence %s expired'):format(l.number), ('Expired %s ago. Renew it to open again'):format(Rn.span(-l.left))
end

local function mine(d, m)
    local id = ROOT .. ':mine'
    local title, desc = licenceLines(m)
    local options = {
        { title = m.label, description = ('%s %s · hygiene %d%% (%s)'):format(Rn.stars(m.stars), m.rating, math.floor(tonumber(m.hygiene) or 0), 'cleanliness'), icon = 'fa-solid fa-store', readOnly = true },
        { title = title, description = desc, icon = 'fa-solid fa-certificate', readOnly = true },
    }
    if m.closed then
        options[#options + 1] = {
            title = 'Closed', icon = 'fa-solid fa-ban', readOnly = true,
            description = ('%s%s'):format(REASON[m.reason] or 'Closed', m.closedLeft > 0 and (' · %s left'):format(Rn.span(m.closedLeft)) or ''),
        }
    end
    if m.strikes > 0 then
        options[#options + 1] = {
            title = ('Strikes: %d of %d'):format(m.strikes, m.maxStrikes), icon = 'fa-solid fa-triangle-exclamation', readOnly = true,
            description = m.strikes >= m.maxStrikes - 1 and 'One more and you are shut down for good' or 'They fade over time if you stay clean and legal',
        }
    end
    if m.licence.status == 'none' or not m.licence.valid or m.licence.renewable then
        options[#options + 1] = {
            title = m.licence.status == 'none' and 'Buy a licence' or 'Renew the licence',
            description = ('%s for %d days%s'):format(Rn.money(m.fee), m.days, m.licence.valid and ', added on to what is left' or ''),
            icon = 'fa-solid fa-file-signature',
            onSelect = function()
                if confirm('Licence', ('Pay %s for %d days?'):format(Rn.money(m.fee), m.days)) then
                    local ok, res = act('licence', m.id)
                    if ok then Rn.notify(('Licence %s valid for %d days'):format(res.number, res.days), 'success') end
                end
                Rn.openHall('mine')
            end,
        }
    end
    options[#options + 1] = {
        title = 'Hand the business back', icon = 'fa-solid fa-hand-holding-dollar',
        description = m.refund > 0 and ('You get %s back'):format(Rn.money(m.refund)) or 'No refund. Staff lose their jobs and the account is paid out to you',
        onSelect = function()
            if confirm('Hand back ' .. m.label, 'Everyone working there loses their job, the business account is paid out to you, and the place goes back on sale.') then
                local ok, res = act('surrender', m.id)
                if ok then
                    Rn.notify(('Handed back. %s paid out'):format(Rn.money((res.refund or 0) + (res.account or 0))), 'success')
                    return
                end
            end
            Rn.openHall('mine')
        end,
    }
    lib.registerContext({ id = id, title = m.label, menu = ROOT, options = options })
end

local function forSale(d)
    local options = {}
    if #d.forSale == 0 then
        options[1] = { title = 'Nothing is for sale right now', icon = 'fa-solid fa-store-slash', readOnly = true }
    end
    for _, b in ipairs(d.forSale) do
        options[#options + 1] = {
            title = b.label,
            description = ('%s · %s %s · licence lasts %d days'):format(Rn.money(b.price), Rn.stars(b.stars), b.rating, b.licenceDays),
            icon = 'fa-solid fa-store',
            onSelect = function()
                if d.hasJob then return Rn.notify('You already work at a restaurant', 'error') end
                local ok = confirm('Buy ' .. b.label,
                    ('Price: %s\n\nYou will own the business, but you still need a licence (%s for %d days) before you can legally run it. Operating without one risks being shut down.'):format(Rn.money(b.price), Rn.money(Config.Licence.fee), b.licenceDays))
                if ok then
                    local bought, res = act('buy', b.id)
                    if bought then
                        Rn.notify(('You bought %s. Buy a licence next'):format(res.label), 'success')
                    end
                end
                Rn.openHall()
            end,
        }
    end
    lib.registerContext({ id = ROOT .. ':sale', title = 'Businesses for sale', menu = ROOT, options = options })
end

function Rn.openHall(sub)
    local ok, d, extra = Rn.call('hall')
    if not ok then return Rn.fail(d, extra) end
    local options = {}
    if d.mine then
        mine(d, d.mine)
        local title, desc = licenceLines(d.mine)
        options[#options + 1] = { title = d.mine.label, description = title .. ' · ' .. desc, icon = 'fa-solid fa-store', menu = ROOT .. ':mine', arrow = true }
    end
    forSale(d)
    options[#options + 1] = { title = 'Businesses for sale', description = ('%d available'):format(#d.forSale), icon = 'fa-solid fa-tags', menu = ROOT .. ':sale', arrow = true }
    if d.bannedLeft then
        options[#options + 1] = { title = 'You cannot buy a business yet', description = ('%s left'):format(Rn.span(d.bannedLeft)), icon = 'fa-solid fa-ban', readOnly = true }
    end
    lib.registerContext({ id = ROOT, title = 'Restaurants and food licences', options = options })
    lib.showContext(sub and (ROOT .. ':' .. sub) or ROOT)
end

exports('OpenBusinesses', function()
    CreateThread(function() Rn.openHall() end)
end)
