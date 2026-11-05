exports('setClipboard', function(value)
    UI.send('clipboard', tostring(value or ''))
end)
