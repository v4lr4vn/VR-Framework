local D = Config.Dispatcher or {}
local zones = {}

local function voice()
    return GetResourceState('vr-voice') == 'started'
end

local function channel(id)
    for _, c in ipairs((D.radio or {}).channels or {}) do
        if c.id == id then return c end
    end
end

local function isDispatchJob()
    local job = Mdt.playerData().job or {}
    return job.type == 'dispatch', job.onduty == true
end

local function radioUser()
    local job = Mdt.playerData().job or {}
    if job.onduty ~= true then return nil end
    if job.type == 'dispatch' then return 'dispatch' end
    if job.type == 'leo' then return 'police' end
    if job.type == 'ems' then return 'ems' end
    return nil
end
Mdt.radioUser = radioUser

Mdt.callback('radio', function(data)
    local who = radioUser()
    if not who or not voice() then return { ok = false } end
    if data.op == 'transmit' then
        if who ~= 'dispatch' then return { ok = false } end
        local id = tonumber(data.id)
        if not id or not channel(id) then return { ok = false } end
        Bridge.voice.setRadio(id)
        return { ok = true, transmit = id }
    elseif data.op == 'join' then
        if who == 'dispatch' then return { ok = false } end
        local ok = MdtRadio.join(tonumber(data.id), true)
        return { ok = ok, transmit = ok and tonumber(data.id) or nil }
    elseif data.op == 'leave' then
        if who == 'dispatch' then return { ok = false } end
        MdtRadio.leave(true)
        return { ok = true, transmit = 0 }
    elseif data.op == 'ptt' then
        if data.down == true then ExecuteCommand('+radiotalk') else ExecuteCommand('-radiotalk') end
        return { ok = true }
    end
    return { ok = false }
end)

AddEventHandler('vr-voice:listenTalking', function(ch, src, talking)
    if radioUser() ~= 'dispatch' then return end
    Mdt.send({ type = 'push', name = 'radio:talk', payload = { channel = ch, src = src, talking = talking == true } })
end)

local function radioTalking(src, talking)
    if not radioUser() then return end
    local ch = LocalPlayer.state.radioChannel or 0
    if ch == 0 then return end
    Mdt.send({ type = 'push', name = 'radio:talk', payload = { channel = ch, src = src, talking = talking == true } })
end

local function radioActive(talking)
    if not radioUser() then return end
    Mdt.send({ type = 'push', name = 'radio:self', payload = { talking = talking == true } })
end

AddEventHandler('vr-voice:radioTalking', radioTalking)
AddEventHandler('vr-voice:radioActive', radioActive)
RegisterNetEvent('pma-voice:setTalkingOnRadio', radioTalking)
AddEventHandler('pma-voice:radioActive', radioActive)

AddStateBagChangeHandler('radioChannel', ('player:%s'):format(GetPlayerServerId(PlayerId())), function(_, _, value)
    if not radioUser() then return end
    Mdt.send({ type = 'push', name = 'radio:tx', payload = { channel = tonumber(value) or 0 } })
end)

RegisterNetEvent('vr-mdt:client:radioReset', function()
    if GetInvokingResource() then return end
    Mdt.send({ type = 'push', name = 'radio:reset', payload = {} })
    if voice() and (LocalPlayer.state.radioChannel or 0) ~= 0 and isDispatchJob() then
        local _, onduty = isDispatchJob()
        if not onduty then Bridge.voice.setRadio(0) end
    end
end)

local function openConsole()
    local dispatchJob, onduty = isDispatchJob()
    if not dispatchJob then return Bridge.notify("You don't work in dispatch.", 'error') end
    if not onduty then return Bridge.notify(D.autoDuty and 'Clocking you in, try again in a second.' or 'Clock in first.', 'error') end
    Mdt.openTablet('dispatch', nil, true)
end

local function addComputers()
    for _, id in ipairs(zones) do pcall(function() Bridge.target.removeZone(id) end) end
    zones = {}
    for i, pc in ipairs(D.computers or {}) do
        local options = {
            {
                name = ('vr_mdt_console_%d'):format(i),
                icon = 'fa-solid fa-desktop',
                label = 'Open the dispatch console',
                distance = D.computerRange or 2.5,
                canInteract = function()
                    local dispatchJob, onduty = isDispatchJob()
                    return dispatchJob and onduty
                end,
                onSelect = openConsole,
            },
        }
        if not D.autoDuty then
            options[2] = {
                name = ('vr_mdt_duty_%d'):format(i),
                icon = 'fa-solid fa-clock',
                label = 'Clock in or out of dispatch',
                distance = D.computerRange or 2.5,
                canInteract = function() return (isDispatchJob()) end,
                onSelect = function() TriggerServerEvent('vr-mdt:server:dispatchDuty') end,
            }
        end
        local ok, id = pcall(function()
            return Bridge.target.addSphereZone({
                coords = vector3(pc.coords.x + 0.0, pc.coords.y + 0.0, pc.coords.z + 0.0),
                radius = pc.radius or 1.2,
                options = options,
            })
        end)
        if ok and id then zones[#zones + 1] = id end
    end
end

CreateThread(function()
    Wait(1000)
    addComputers()
    TriggerServerEvent('vr-mdt:server:dispatchSpots')
end)

local function toSpots(list)
    local out = {}
    for _, z in ipairs(type(list) == 'table' and list or {}) do
        if type(z) == 'table' and type(z.points) == 'table' then
            local pts = {}
            for _, p in ipairs(z.points) do
                if type(p) == 'table' and tonumber(p.x) and tonumber(p.y) then pts[#pts + 1] = vector2(p.x + 0.0, p.y + 0.0) end
            end
            if #pts >= 3 and tonumber(z.minZ) and tonumber(z.maxZ) then
                out[#out + 1] = { label = z.label, points = pts, minZ = z.minZ + 0.0, maxZ = z.maxZ + 0.0 }
            end
        else
            local c = type(z) == 'table' and z.coords
            if type(c) == 'table' and tonumber(c.x) and tonumber(c.y) and tonumber(c.z) then
                out[#out + 1] = { label = z.label, coords = vector3(c.x + 0.0, c.y + 0.0, c.z + 0.0), radius = tonumber(z.radius) or 2.0 }
            end
        end
    end
    return out
end

RegisterNetEvent('vr-mdt:client:dispatchSpots', function(data)
    if GetInvokingResource() or type(data) ~= 'table' then return end
    D.zones = toSpots(data.zones)
    D.computers = toSpots(data.computers)
    if data.autoDuty ~= nil then D.autoDuty = data.autoDuty == true end
    addComputers()
end)

local function drawWall(a, b, minZ, maxZ, r, g, bl, al)
    DrawPoly(a.x, a.y, minZ, b.x, b.y, minZ, b.x, b.y, maxZ, r, g, bl, al)
    DrawPoly(a.x, a.y, minZ, b.x, b.y, maxZ, a.x, a.y, maxZ, r, g, bl, al)
    DrawPoly(b.x, b.y, maxZ, b.x, b.y, minZ, a.x, a.y, minZ, r, g, bl, al)
    DrawPoly(a.x, a.y, maxZ, b.x, b.y, maxZ, a.x, a.y, minZ, r, g, bl, al)
    DrawLine(a.x, a.y, minZ, b.x, b.y, minZ, r, g, bl, 255)
    DrawLine(a.x, a.y, maxZ, b.x, b.y, maxZ, r, g, bl, 255)
    DrawLine(a.x, a.y, minZ, a.x, a.y, maxZ, r, g, bl, 255)
end

local function drawZone(z, r, g, b)
    if z.points then
        for i, p in ipairs(z.points) do
            drawWall(p, z.points[i % #z.points + 1], z.minZ, z.maxZ, r, g, b, 45)
        end
    elseif z.coords then
        DrawMarker(1, z.coords.x, z.coords.y, z.coords.z - 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, z.radius * 2.0, z.radius * 2.0, 1.5, r, g, b, 60, false, false, 2, false, nil, nil, false)
    end
end

local showUntil = 0

RegisterNetEvent('vr-mdt:client:showDispatchSpots', function(data)
    if GetInvokingResource() or type(data) ~= 'table' then return end
    local zonesList, desks = toSpots(data.zones), toSpots(data.computers)
    local running = showUntil > GetGameTimer()
    showUntil = GetGameTimer() + 30000
    if running then return end
    CreateThread(function()
        while GetGameTimer() < showUntil do
            for _, z in ipairs(zonesList) do drawZone(z, 61, 214, 140) end
            for _, z in ipairs(desks) do
                DrawMarker(28, z.coords.x, z.coords.y, z.coords.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, z.radius, z.radius, z.radius, 255, 176, 32, 110, false, false, 2, false, nil, nil, false)
            end
            Wait(0)
        end
    end)
end)

local tool = nil
local TOOL_ADD, TOOL_UNDO, TOOL_SAVE = 38, 194, 191

local function toolHelp()
    Bridge.textUI.show(('Dispatch zone: %d corners  [E] add corner  [Backspace] undo  [Enter] save  /dispatchzone to cancel'):format(#tool.points))
end

local function stopTool(msg, kind)
    tool = nil
    Bridge.textUI.hide()
    if msg then Bridge.notify(msg, kind or 'inform') end
end

RegisterNetEvent('vr-mdt:client:zoneTool', function(height)
    if GetInvokingResource() then return end
    if tool then return stopTool('Zone drawing cancelled.') end
    tool = { points = {}, height = tonumber(height) or 6.0 }
    toolHelp()
    Bridge.notify('Walk to each corner of the dispatch room and press E. Press Enter when done.', 'inform')
    CreateThread(function()
        while tool do
            DisableControlAction(0, TOOL_ADD, true)
            DisableControlAction(0, TOOL_UNDO, true)
            DisableControlAction(0, TOOL_SAVE, true)
            DisableControlAction(0, 177, true)
            local pos = GetEntityCoords(Bridge.cache.ped)
            local feet = pos.z - 1.0
            local pts = tool.points
            local lowest, highest = feet, feet
            for _, p in ipairs(pts) do
                lowest, highest = math.min(lowest, p.z), math.max(highest, p.z)
            end
            local minZ, maxZ = lowest - 0.5, highest + tool.height
            for i, p in ipairs(pts) do
                DrawMarker(28, p.x, p.y, p.z + 0.1, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.15, 0.15, 0.15, 255, 176, 32, 220, false, false, 2, false, nil, nil, false)
                if i > 1 then drawWall(pts[i - 1], p, minZ, maxZ, 61, 214, 140, 45) end
            end
            if #pts >= 1 then
                local last = pts[#pts]
                local here = { x = pos.x, y = pos.y }
                drawWall(last, here, minZ, maxZ, 255, 176, 32, 35)
                if #pts >= 2 then drawWall(here, pts[1], minZ, maxZ, 255, 176, 32, 20) end
            end
            if IsDisabledControlJustPressed(0, TOOL_ADD) then
                if #pts >= 40 then
                    Bridge.notify('That is the most corners a zone can have.', 'error')
                else
                    pts[#pts + 1] = { x = pos.x, y = pos.y, z = feet }
                    toolHelp()
                end
            elseif IsDisabledControlJustPressed(0, TOOL_UNDO) and #pts > 0 then
                pts[#pts] = nil
                toolHelp()
            elseif IsDisabledControlJustPressed(0, TOOL_SAVE) then
                if #pts < 3 then
                    Bridge.notify('Add at least 3 corners first.', 'error')
                else
                    local send = {}
                    for i, p in ipairs(pts) do send[i] = { x = p.x, y = p.y, z = p.z } end
                    TriggerServerEvent('vr-mdt:server:saveDispatchZone', { points = send, height = tool.height })
                    stopTool()
                end
            end
            Wait(0)
        end
    end)
end)

local function mdtCheck()
    local pd = Mdt.playerData()
    local job = pd.job or {}
    local coords = GetEntityCoords(Bridge.cache.ped)
    local lines = {
        ('job %s, type %s, on duty %s'):format(tostring(job.name), tostring(job.type), tostring(job.onduty)),
        ('position %.1f %.1f %.1f'):format(coords.x, coords.y, coords.z),
        ('this client: %d zone(s), %d desk(s), inside a zone %s, spot %s'):format(#(D.zones or {}), #(D.computers or {}), tostring(DispatchZones.inZone(coords)), tostring(Mdt.dispatchSpot())),
    }
    local ok, s = pcall(Mdt.checkServer)
    if ok and type(s) == 'table' then
        lines[#lines + 1] = ('server: job %s, type %s, dept %s, on duty %s'):format(tostring(s.job), tostring(s.type), tostring(s.dept), tostring(s.onduty))
        lines[#lines + 1] = ('server: %d zone(s), %d desk(s), inside a zone %s, spot %s, auto duty %s'):format(s.zones or 0, s.desks or 0, tostring(s.inZone), tostring(s.spot), tostring(s.autoDuty))
        lines[#lines + 1] = ('server: MDT access %s%s'):format(s.ok and 'yes' or 'no', s.why and (' (' .. tostring(s.why) .. ')') or '')
    else
        lines[#lines + 1] = 'server: no answer'
    end
    for _, line in ipairs(lines) do print('[vr-mdt] ' .. line) end
    Bridge.notify('MDT check printed in F8.', 'inform')
end

function Mdt.checkServer()
    return Bridge.callback.await('vr-mdt:check', 5000)
end

RegisterCommand('mdtcheck', function() CreateThread(mdtCheck) end, false)

AddEventHandler('onClientResourceStart', function(res)
    if res == Bridge.targetResource then SetTimeout(500, addComputers) end
end)

AddEventHandler('onClientResourceStop', function(res)
    if res ~= GetCurrentResourceName() then return end
    for _, id in ipairs(zones) do pcall(function() Bridge.target.removeZone(id) end) end
    if tool then Bridge.textUI.hide() end
end)

RegisterCommand('mdtpos', function()
    local ped = Bridge.cache.ped
    local c = GetEntityCoords(ped)
    local line = ("{ label = 'New spot', coords = vec3(%.2f, %.2f, %.2f), radius = 1.2 },"):format(c.x, c.y, c.z)
    print('[vr-mdt] ' .. line)
    if GetResourceState('vr-ui') == 'started' then pcall(function() exports['vr-ui']:setClipboard(line) end) end
    Bridge.notify('Position copied and printed in F8.', 'inform')
end, false)
