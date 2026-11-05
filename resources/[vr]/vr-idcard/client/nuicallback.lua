local config = require('config')

RegisterNUICallback('close', function(_, cb)
    cb(1)
    CloseCard()
end)

RegisterNUICallback('jsReady', function(_, cb)
    local langConvar = GetConvar('ox:locale', 'en')
    local ok, locale = pcall(lib.loadJson, ('locales/%s'):format(langConvar))
    if not ok or not locale then locale = lib.loadJson('locales/en') end
    cb({ configData = config, localeData = locale })
end)

RegisterNUICallback('requestPresignedUrl', function(_, cb)
    local url = lib.callback.await('vr-idcard:server:getPresignedUrl')
    cb({ url = url })
end)
