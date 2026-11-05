-- The contact list. It belongs to the phone, so it moves with the phone like the settings do.
local Contacts = {}
Phone.Contacts = Contacts

local function max() return (Config.Phone.Contacts and Config.Phone.Contacts.max) or 500 end

local function shape(row)
    return {
        id = row.id,
        name = row.name,
        number = row.number,
        favourite = row.favourite == 1 or row.favourite == true,
        blocked = row.blocked == 1 or row.blocked == true,
    }
end

function Contacts.list(phoneId)
    local rows = MySQL.query.await(
        'SELECT `id`, `name`, `number`, `favourite`, `blocked` FROM `vr_ph_contacts` WHERE `phone_id` = ? ORDER BY `name` LIMIT 500',
        { phoneId }
    ) or {}
    local out = {}
    for i, row in ipairs(rows) do out[i] = shape(row) end
    return out
end

-- The contact with this number, or nil.
function Contacts.byNumber(phoneId, number)
    local row = MySQL.single.await(
        'SELECT `id`, `name`, `number`, `favourite`, `blocked` FROM `vr_ph_contacts` WHERE `phone_id` = ? AND `number` = ?',
        { phoneId, number }
    )
    return row and shape(row) or nil
end

function Contacts.isBlocked(phoneId, number)
    local c = Contacts.byNumber(phoneId, number)
    return c ~= nil and c.blocked == true
end

-- The name to show for a number: the contact's name, or nil.
function Contacts.nameFor(phoneId, number)
    local c = Contacts.byNumber(phoneId, number)
    return c and c.name or nil
end

-- Adds a contact, or changes one when data.id is given. Returns the contact, or nil and a reason.
function Contacts.save(phoneId, data)
    if type(data) ~= 'table' then return nil, 'invalid' end
    local name = Phone.text(data.name, 40)
    local number = Phone.number(data.number)
    if not name then return nil, 'invalid_name' end
    if not number then return nil, 'invalid_number' end
    local favourite = data.favourite == true and 1 or 0
    local blocked = data.blocked == true and 1 or 0

    local clash = Contacts.byNumber(phoneId, number)
    local id = tonumber(data.id)

    if id then
        local mine = MySQL.single.await('SELECT `id` FROM `vr_ph_contacts` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id })
        if not mine then return nil, 'not_found' end
        if clash and clash.id ~= id then return nil, 'duplicate' end
        MySQL.update.await(
            'UPDATE `vr_ph_contacts` SET `name` = ?, `number` = ?, `favourite` = ?, `blocked` = ? WHERE `phone_id` = ? AND `id` = ?',
            { name, number, favourite, blocked, phoneId, id }
        )
    else
        if clash then return nil, 'duplicate' end
        local count = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM `vr_ph_contacts` WHERE `phone_id` = ?', { phoneId })) or 0
        if count >= max() then return nil, 'full' end
        id = MySQL.insert.await(
            'INSERT INTO `vr_ph_contacts` (`phone_id`, `name`, `number`, `favourite`, `blocked`) VALUES (?, ?, ?, ?, ?)',
            { phoneId, name, number, favourite, blocked }
        )
        if not id then return nil, 'failed' end
    end
    return { id = id, name = name, number = number, favourite = favourite == 1, blocked = blocked == 1 }
end

function Contacts.remove(phoneId, id)
    id = tonumber(id)
    if not id then return false end
    return (MySQL.update.await('DELETE FROM `vr_ph_contacts` WHERE `phone_id` = ? AND `id` = ?', { phoneId, id }) or 0) > 0
end
