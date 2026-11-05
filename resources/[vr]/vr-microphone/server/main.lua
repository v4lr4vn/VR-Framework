Bridge.useItem(Config.MegaphoneItem, function(src)
    TriggerClientEvent('vr-microphone:client:toggle', src)
end)

-- The client asks whether the megaphone is still in the bag while it is held.
lib.callback.register('vr-microphone:hasMegaphone', function(src)
    local ok, n = pcall(Bridge.inventory.count, src, Config.MegaphoneItem)
    return ok and (tonumber(n) or 0) > 0
end)
