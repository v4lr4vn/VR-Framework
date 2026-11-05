return function(source, event, message, ...)
    if GetConvar('vr:logger', GetConvar('ox:logger', '')) == '' then return end
    local n = select('#', ...)
    local tags = { ... }
    for i = 1, n do tags[i] = tostring(tags[i]) end
    print(('^5[log]^7 %s %s %s %s'):format(tostring(source), tostring(event), tostring(message), table.concat(tags, ', ', 1, n)))
end
