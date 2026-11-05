local TYPES = {
    primary = 'primary', default = 'primary',
    inform = 'info', info = 'info',
    success = 'success',
    error = 'error',
    warning = 'warning', warn = 'warning',
    police = 'police', leo = 'police',
    ambulance = 'ems', ems = 'ems',
    doj = 'doj',
}

local function notify(data, kind, duration)
    if type(data) ~= 'table' then
        data = { message = data, type = kind, duration = duration }
    end
    local message = data.message or data.description or data.text
    local title = data.title or data.caption
    if type(message) == 'table' then
        title = title or message.caption
        message = message.text
    end
    local icon = data.icon
    if type(icon) == 'table' then icon = ('%s fa-%s'):format(icon[1] or 'fas', icon[2] or 'circle') end
    local payload = {
        id = UI.text(data.id, 64),
        title = UI.text(title, 96),
        message = UI.text(message, 600),
        type = TYPES[tostring(data.type or data.status or kind or 'primary'):lower()] or 'primary',
        code = UI.text(data.code, 16),
        icon = UI.text(icon, 64),
        iconColor = UI.text(data.iconColor, 32),
        iconAnimation = UI.text(data.iconAnimation, 16),
        duration = math.max(1000, math.min(tonumber(data.duration or duration or data.length) or UIConfig.notify.duration, 60000)),
    }
    if not payload.message and not payload.title then return end
    UI.send('notify', payload)
end

exports('Notify', notify)
exports('notify', notify)
RegisterNetEvent('vr-ui:notify', notify)
