-- Notes. Plain text, a title, pinned notes first.
local Notes = {}
Phone.Notes = Notes

local function cfg() return Config.Phone.Notes or {} end

local function toNote(row, withBody)
    local n = { id = row.id, title = row.title, pinned = row.pinned == 1 or row.pinned == true, at = row.updated_at }
    if withBody then
        n.body = row.body or ''
    else
        local b = (row.body or ''):gsub('%s+', ' ')
        n.preview = b:sub(1, 90)
    end
    return n
end

function Notes.list(phoneId)
    local rows = MySQL.query.await(
        'SELECT `id`, `title`, LEFT(`body`, 120) AS `body`, `pinned`, `updated_at` FROM `vr_ph_notes` WHERE `phone_id` = ? '
            .. 'ORDER BY `pinned` DESC, `updated_at` DESC, `id` DESC LIMIT ' .. (cfg().max or 100),
        { phoneId }
    ) or {}
    local out = {}
    for i, row in ipairs(rows) do out[i] = toNote(row, false) end
    return out
end

function Notes.get(phoneId, id)
    id = tonumber(id)
    if not id then return nil end
    local row = MySQL.single.await('SELECT `id`, `title`, `body`, `pinned`, `updated_at` FROM `vr_ph_notes` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id })
    return row and toNote(row, true) or nil
end

-- note = { id?, title, body, pinned? }. Returns the note, or nil and a reason ('empty', 'full', 'not_found', 'failed').
function Notes.save(phoneId, note)
    local c = cfg()
    local body = Phone.text(note.body, c.bodyLength or 4000, true)
    local title = Phone.text(note.title, c.titleLength or 80)
    if not title and body then
        -- No title: the first line of the text.
        title = Phone.text((body:match('^[^\n]+') or ''), c.titleLength or 80)
    end
    if not title and not body then return nil, 'empty' end
    title = title or 'Note'
    local now = os.time()

    if note.id ~= nil then
        local id = tonumber(note.id)
        if not id then return nil, 'not_found' end
        local changed = MySQL.update.await(
            'UPDATE `vr_ph_notes` SET `title` = ?, `body` = ?, `updated_at` = ? WHERE `phone_id` = ? AND `id` = ?',
            { title, body, now, phoneId, id }
        )
        if (changed or 0) < 1 then
            -- Saving identical text changes nothing, which is fine as long as the note exists.
            if not MySQL.scalar.await('SELECT `id` FROM `vr_ph_notes` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id }) then return nil, 'not_found' end
        end
        return Notes.get(phoneId, id)
    end

    local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_notes` WHERE `phone_id` = ?', { phoneId })) or 0
    if count >= (c.max or 100) then return nil, 'full' end
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_notes` (`phone_id`, `title`, `body`, `pinned`, `created_at`, `updated_at`) VALUES (?, ?, ?, 0, ?, ?)',
        { phoneId, title, body, now, now }
    )
    if not id then return nil, 'failed' end
    return Notes.get(phoneId, id)
end

function Notes.pin(phoneId, id, on)
    id = tonumber(id)
    if not id then return false end
    -- Pinning does not count as editing, so the order of the other notes stays.
    MySQL.update.await('UPDATE `vr_ph_notes` SET `pinned` = ? WHERE `phone_id` = ? AND `id` = ?', { on and 1 or 0, phoneId, id })
    return MySQL.scalar.await('SELECT `id` FROM `vr_ph_notes` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id }) ~= nil
end

function Notes.remove(phoneId, id)
    id = tonumber(id)
    if not id then return false end
    return (MySQL.update.await('DELETE FROM `vr_ph_notes` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id }) or 0) > 0
end
