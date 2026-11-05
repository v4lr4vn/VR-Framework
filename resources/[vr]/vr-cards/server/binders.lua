Binders = {}

local B = Config.Binder

function Binders.capacity()
    return B.pages * B.perPage
end

function Binders.create(info, title)
    local id = MySQL.insert.await('INSERT INTO vr_cards_binders (title, created_by, created) VALUES (?, ?, ?)', { title or 'Card Binder', info.cid, os.time() })
    return tonumber(id)
end

function Binders.meta(id, title)
    return { binderId = id, label = 'Card Binder', description = ('%s. Holds %d cards.'):format(title or 'Card Binder', Binders.capacity()) }
end

function Binders.holds(src, id)
    id = tonumber(id)
    if not id then return false end
    return Core.slots(src, Config.Items.binder, { binderId = id })[1] ~= nil
end

function Binders.row(id)
    return MySQL.single.await('SELECT id, title FROM vr_cards_binders WHERE id = ?', { tonumber(id) })
end

function Binders.slots(id)
    local rows = MySQL.query.await('SELECT slot, uid FROM vr_cards_binder_slots WHERE binder = ?', { tonumber(id) }) or {}
    local uids, bySlot = {}, {}
    for _, r in ipairs(rows) do
        uids[#uids + 1] = r.uid
        bySlot[tonumber(r.slot)] = r.uid
    end
    return bySlot, Copies.many(uids)
end

function Binders.progress(views)
    local seen, out = {}, {}
    for _, v in pairs(views) do
        seen[v.setId] = seen[v.setId] or {}
        seen[v.setId][v.id] = true
    end
    for _, s in ipairs(Catalog.setList()) do
        local n = 0
        for _ in pairs(seen[s.id] or {}) do n = n + 1 end
        out[#out + 1] = { id = s.id, code = s.code, label = s.label, owned = n, total = s.total }
    end
    return out
end

function Binders.view(info, id)
    local row = Binders.row(id)
    if not row then return nil end
    local bySlot, copies = Binders.slots(id)
    local slots, all = {}, {}
    for slot, uid in pairs(bySlot) do
        local c = copies[uid]
        local v = c and Copies.view(c)
        if v then
            slots[tostring(slot)] = v
            all[#all + 1] = v
        end
    end
    local hand = Copies.inHand(info.src)
    return {
        id = tonumber(row.id), title = row.title, pages = B.pages, perPage = B.perPage, slots = slots, hand = hand,
        progress = Binders.progress(all), count = #all, capacity = Binders.capacity(), meta = Catalog.meta(),
    }
end

local function validSlot(slot)
    slot = tonumber(slot)
    if not slot or slot % 1 ~= 0 or slot < 1 or slot > Binders.capacity() then return nil end
    return slot
end

function Binders.put(info, id, uid, slot)
    if not Binders.holds(info.src, id) then return false, 'no_binder' end
    slot = validSlot(slot)
    if not slot then return false, 'bad_slot' end
    if MySQL.scalar.await('SELECT uid FROM vr_cards_binder_slots WHERE binder = ? AND slot = ?', { id, slot }) then return false, 'slot_taken' end
    local c, err = Copies.take(info.src, uid)
    if not c then return false, err end
    local n = MySQL.update.await('INSERT IGNORE INTO vr_cards_binder_slots (binder, slot, uid) VALUES (?, ?, ?)', { id, slot, uid })
    if (tonumber(n) or 0) == 0 then
        Copies.give(info.src, c, info.cid)
        return false, 'slot_taken'
    end
    Copies.set(uid, { state = 'binder', holder = ('binder:%d'):format(id) })
    c.state = 'binder'
    return true, { slot = slot, card = Copies.view(c) }
end

function Binders.take(info, id, slot)
    if not Binders.holds(info.src, id) then return false, 'no_binder' end
    slot = validSlot(slot)
    if not slot then return false, 'bad_slot' end
    local uid = MySQL.scalar.await('SELECT uid FROM vr_cards_binder_slots WHERE binder = ? AND slot = ?', { id, slot })
    if not uid then return false, 'empty_slot' end
    local c = Copies.get(uid)
    if not c then return false, 'empty_slot' end
    if not Core.canCarry(info.src, Config.Items.card, 1) then return false, 'no_room' end
    MySQL.update.await('DELETE FROM vr_cards_binder_slots WHERE binder = ? AND slot = ?', { id, slot })
    if not Copies.give(info.src, c, info.cid) then
        MySQL.insert.await('INSERT INTO vr_cards_binder_slots (binder, slot, uid) VALUES (?, ?, ?)', { id, slot, uid })
        return false, 'no_room'
    end
    return true, { slot = slot, card = Copies.view(c) }
end

function Binders.move(info, id, from, to)
    if not Binders.holds(info.src, id) then return false, 'no_binder' end
    from, to = validSlot(from), validSlot(to)
    if not from or not to or from == to then return false, 'bad_slot' end
    local a = MySQL.scalar.await('SELECT uid FROM vr_cards_binder_slots WHERE binder = ? AND slot = ?', { id, from })
    if not a then return false, 'empty_slot' end
    local b = MySQL.scalar.await('SELECT uid FROM vr_cards_binder_slots WHERE binder = ? AND slot = ?', { id, to })
    MySQL.update.await('DELETE FROM vr_cards_binder_slots WHERE binder = ? AND slot IN (?, ?)', { id, from, to })
    MySQL.insert.await('INSERT INTO vr_cards_binder_slots (binder, slot, uid) VALUES (?, ?, ?)', { id, to, a })
    if b then MySQL.insert.await('INSERT INTO vr_cards_binder_slots (binder, slot, uid) VALUES (?, ?, ?)', { id, from, b }) end
    return true, { from = from, to = to }
end

function Binders.rename(info, id, title)
    if not Binders.holds(info.src, id) then return false, 'no_binder' end
    title = type(title) == 'string' and title:gsub('[%c<>]', ''):gsub('^%s+', ''):gsub('%s+$', '') or ''
    if title == '' then return false, 'bad_title' end
    title = title:sub(1, B.titleLength)
    MySQL.update.await('UPDATE vr_cards_binders SET title = ? WHERE id = ?', { title, id })
    return true, { title = title }
end
