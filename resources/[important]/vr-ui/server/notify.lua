local function notify(target, data, kind, duration)
    if type(data) ~= 'table' then
        data = { message = data, type = kind, duration = duration }
    end
    TriggerClientEvent('vr-ui:notify', target, data)
end

exports('Notify', notify)
exports('notify', notify)
