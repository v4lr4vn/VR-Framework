local open = false

function BHC.openTerminal(data)
    if open then return end
    open = true
    local p = promise.new()
    BHC.termPromise = p
    SetNuiFocus(true, true)
    BHC.message({ action = 'terminal', data = data })
    CreateThread(function()
        while open do
            if IsEntityDead(BHC.ped()) then
                BHC.closeTerminal()
                break
            end
            Wait(500)
        end
    end)
    Citizen.Await(p)
end

function BHC.closeTerminal()
    if not open then return end
    open = false
    SetNuiFocus(false, false)
    BHC.message({ action = 'terminalClose' })
    pcall(function() lib.callback.await('vr-bankheist:hack:close', false) end)
    local p = BHC.termPromise
    BHC.termPromise = nil
    if p then p:resolve(true) end
end

RegisterNUICallback('hackCmd', function(d, cb)
    if not open or type(d) ~= 'table' then return cb({ ok = false, error = 'bad_request' }) end
    local res = lib.callback.await('vr-bankheist:hack:cmd', false, tostring(d.cmd or ''):sub(1, 200))
    cb(type(res) == 'table' and res or { ok = false, error = 'failed' })
end)

RegisterNUICallback('hackClose', function(_, cb)
    cb(true)
    BHC.closeTerminal()
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if open then
        SetNuiFocus(false, false)
        SetNuiFocusKeepInput(false)
    end
end)
