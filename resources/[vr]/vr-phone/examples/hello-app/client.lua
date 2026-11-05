-- The page runs in the phone, and asks the game through NUI callbacks of THIS resource.
RegisterNUICallback('hello:time', function(_, cb)
    cb(lib.callback.await('hello-app:time', false) or {})
end)
