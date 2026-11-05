Mdt.callback('openStash', function(data)
    local id = type(data.id) == 'string' and data.id or ''
    if not id:match('^mdt_case_%d+$') or #id > 24 then return { ok = false, error = 'bad_request' } end
    Mdt.closeTablet()
    SetTimeout(200, function()
        Mdt.request('evidence.open', { id = id })
    end)
    return { ok = true }
end)

Mdt.callback('evidenceHere', function()
    local c = GetEntityCoords(PlayerPedId())
    return { ok = true, data = { street = Mdt.streetAt(c.x, c.y, c.z) } }
end)
