-- Voicemail: a short typed message left when nobody picks up. (Recording a voice needs the audio layer, which comes later.)
local Voicemail = {}
Phone.Voicemail = Voicemail

local KEEP = 50

function Voicemail.add(number, sender, body)
    body = Phone.text(body, 300, true)
    if not body then return nil, 'empty' end
    local id = MySQL.insert.await(
        'INSERT INTO `vr_ph_voicemail` (`number`, `sender`, `body`, `heard`, `created_at`) VALUES (?, ?, ?, 0, ?)',
        { number, sender, body, os.time() }
    )
    -- Old ones go once there are more than KEEP.
    MySQL.update.await(
        'DELETE FROM `vr_ph_voicemail` WHERE `number` = ? AND `id` NOT IN (SELECT `id` FROM (SELECT `id` FROM `vr_ph_voicemail` WHERE `number` = ? ORDER BY `id` DESC LIMIT 50) AS `keep`)',
        { number, number }
    )
    return id, body
end

function Voicemail.list(number)
    local rows = MySQL.query.await(
        'SELECT `id`, `sender`, `body`, `heard`, `created_at` FROM `vr_ph_voicemail` WHERE `number` = ? ORDER BY `id` DESC LIMIT 50',
        { number }
    ) or {}
    local out = {}
    for i, r in ipairs(rows) do
        out[i] = { id = r.id, from = r.sender, body = r.body, heard = r.heard == 1 or r.heard == true, at = r.created_at }
    end
    return out
end

function Voicemail.unheard(number)
    return tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_voicemail` WHERE `number` = ? AND `heard` = 0', { number })) or 0
end

function Voicemail.markHeard(number, id)
    id = tonumber(id)
    if not id then return false end
    return (MySQL.update.await('UPDATE `vr_ph_voicemail` SET `heard` = 1 WHERE `number` = ? AND `id` = ?', { number, id }) or 0) > 0
end

function Voicemail.remove(number, id)
    id = tonumber(id)
    if not id then return false end
    return (MySQL.update.await('DELETE FROM `vr_ph_voicemail` WHERE `number` = ? AND `id` = ?', { number, id }) or 0) > 0
end
