local cfg = Config.Jobs.trucker
local H = {}

local run = 0
local deliverZone

local function vehicles()
    local s = Cj.session
    if not s then return nil, nil end
    local cab = s.vehicles[1] and Cj.entity(s.vehicles[1].netId, 5)
    local tr = s.vehicles[2] and Cj.entity(s.vehicles[2].netId, 5)
    return cab, tr
end

local function hitchLoop(token)
    CreateThread(function()
        while run == token and Cj.session and Cj.session.job == 'trucker' do
            local cab, tr = vehicles()
            if cab and tr and DoesEntityExist(cab) and DoesEntityExist(tr) then
                local attached = IsVehicleAttachedToTrailer(cab)
                if not attached and #(GetEntityCoords(cab) - GetEntityCoords(tr)) < 9.0 and GetPedInVehicleSeat(cab, -1) == Cj.ped() then
                    AttachVehicleToTrailer(cab, tr, 6.0)
                end
            end
            Wait(750)
        end
    end)
end

local function deliver()
    local ok, err = Cj.act('deliver')
    if not ok then return Cj.fail(err) end
    Cj.notify('Cargo delivered', 'success')
end

local function hud(view)
    local d = view.data
    if d.phase == 'deliver' then
        Cj.hudSet(d.contract, {
            { label = 'Cargo', value = d.cargo },
            { label = 'Distance', value = ('%.1f km'):format(d.km) },
            { label = 'Payout', value = ('$%d'):format(d.payout) },
            { label = 'Next', value = 'Deliver the trailer to the marked bay' },
        })
    else
        Cj.hudSet(d.contract, {
            { label = 'Cargo', value = 'Delivered' },
            { label = 'Next', value = 'Bring the cab back to the depot', state = 'go' },
        })
    end
end

function H.start(view)
    run = run + 1
    hitchLoop(run)
    H.sync(view)
end

function H.sync(view)
    local d = view.data
    hud(view)
    if d.phase == 'deliver' then
        Cj.blip('dest', d.to, { sprite = 477, colour = 5, route = true, label = 'Delivery bay' })
        if not deliverZone then
            deliverZone = Cj.zone('vr-civjobs:deliver', d.to, cfg.deliverRange, {
                { name = 'vr-civjobs:deliver', label = 'Deliver cargo', icon = 'fa-solid fa-truck-ramp-box', distance = cfg.deliverRange, onSelect = deliver },
            })
        end
    else
        Cj.unblip('dest')
        if deliverZone then
            Cj.unzone(deliverZone)
            deliverZone = nil
        end
        Cj.blip('depot', d.depot, { sprite = 477, colour = 2, route = true, label = 'Return the cab' })
        Cj.finishZone('finish', d.depot, 'Finish shift', cfg.vehicle.returnRadius)
    end
end

function H.stop()
    run = run + 1
    deliverZone = nil
end

Cj.register('trucker', H)
