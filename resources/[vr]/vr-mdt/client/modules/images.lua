local stored = {}
local fetched = {}
local tokenCount = 0

RegisterNetEvent('vr-mdt:client:imageStored', function(token, id, err)
    if stored[token] then stored[token]:resolve({ id = id, err = err }) end
end)

RegisterNetEvent('vr-mdt:client:image', function(token, data)
    if fetched[token] then fetched[token]:resolve(data) end
end)

local function screenshot(quality)
    if GetResourceState('screenshot-basic') ~= 'started' then return nil end
    local p = promise.new()
    exports['screenshot-basic']:requestScreenshot({ encoding = 'jpg', quality = quality }, function(data)
        p:resolve(data)
    end)
    return Citizen.Await(p)
end

function Mdt.takePhoto(maxBytes, quality)
    local q = quality or Config.Images.quality
    for _ = 1, 4 do
        local data = screenshot(q)
        if not data then return nil, 'no_camera' end
        if #data * 0.75 <= maxBytes then return data end
        q = q - 0.15
        if q < 0.2 then break end
    end
    return nil, 'too_large'
end

function Mdt.upload(kind, dataUrl, token)
    local p = promise.new()
    stored[token] = p
    TriggerLatentServerEvent('vr-mdt:server:imageUpload', 500000, token, dataUrl)
    SetTimeout(30000, function()
        if stored[token] then stored[token]:resolve({ err = 'server_error' }) end
    end)
    local res = Citizen.Await(p)
    stored[token] = nil
    return res.id, res.err
end

function Mdt.captureAndUpload(kind, before, after)
    local prep = Mdt.request('images.prepare', { kind = kind })
    if not prep or not prep.ok then return nil, prep and prep.error or 'server_error' end
    if before then
        local go = before()
        if not go then
            if after then after() end
            return nil, 'cancelled'
        end
    end
    local data, err = Mdt.takePhoto(prep.data.maxBytes, prep.data.quality)
    if after then after() end
    if not data then return nil, err end
    local id, uerr = Mdt.upload(kind, data, prep.data.token)
    if not id then return nil, uerr end
    return id, nil, data
end

function Mdt.captureWithCameraScript(kind)
    local resource = Config.Images.cameraResource
    if not resource or GetResourceState(resource) ~= 'started' then return nil, 'unsupported' end

    local startedAt = GetGameTimer()
    local prep = Mdt.request('images.prepare', { kind = kind })
    if not prep or not prep.ok then return nil, prep and prep.error or 'server_error' end

    Mdt.hideTablet()
    Mdt.pauseTabletProp()
    local ok, res = pcall(function()
        return exports[resource]:TakePhoto({ quality = prep.data.quality, maxBytes = prep.data.maxBytes })
    end)
    Mdt.resumeTabletProp()
    Mdt.showTablet()

    if not ok then return nil, 'unsupported' end
    if type(res) ~= 'table' then return nil, 'no_camera' end
    if not res.ok then
        local map = { busy = 'slow_down', unavailable = 'no_camera' }
        return nil, map[res.error] or res.error
    end

    local token = prep.data.token
    if GetGameTimer() - startedAt > 40000 then
        local again = Mdt.request('images.prepare', { kind = kind })
        if not again or not again.ok then return nil, again and again.error or 'server_error' end
        token = again.data.token
    end

    local id, err = Mdt.upload(kind, res.data, token)
    if not id then return nil, err end
    return id, nil, res.data
end

function Mdt.hideTablet()
    if not Mdt.open then return end
    SetNuiFocus(false, false)
    Mdt.send({ type = 'hide' })
end

function Mdt.showTablet()
    if not Mdt.open then return end
    Mdt.send({ type = 'show' })
    SetNuiFocus(true, true)
end

function Mdt.photoMode(prompt)
    Bridge.textUI.show(prompt or '[Enter] Take photo  [Backspace] Cancel')
    local result = false
    while true do
        Wait(0)
        DisableControlAction(0, 24, true)
        DisableControlAction(0, 25, true)
        DisableControlAction(0, 200, true)
        if IsControlJustPressed(0, 38) or IsControlJustPressed(0, 176) then result = true break end
        if IsControlJustPressed(0, 177) or IsDisabledControlJustPressed(0, 200) then break end
        if IsPedDeadOrDying(Bridge.cache.ped, true) then break end
    end
    Bridge.textUI.hide()
    Wait(50)
    return result
end

Mdt.callback('capture', function(data)
    local kind = type(data.kind) == 'string' and data.kind or ''
    if kind == 'mugshot' and Mdt.captureMugshot then
        return Mdt.captureMugshot(data)
    end
    local id, err, url = Mdt.captureWithCameraScript(kind)
    if err == 'unsupported' then
        id, err, url = Mdt.captureAndUpload(kind, function()
            Mdt.hideTablet()
            return Mdt.photoMode()
        end, function()
            Mdt.showTablet()
        end)
    end
    if not id then return { ok = false, error = err } end
    return { ok = true, data = { id = id, url = url } }
end)

Mdt.callback('image', function(data)
    if type(data.id) ~= 'string' or not data.id:match('^%x+$') then return { ok = false, error = 'bad_request' } end
    tokenCount = tokenCount + 1
    local token = ('i%d'):format(tokenCount)
    local p = promise.new()
    fetched[token] = p
    TriggerServerEvent('vr-mdt:server:imageFetch', token, data.id)
    SetTimeout(20000, function()
        if fetched[token] then fetched[token]:resolve(nil) end
    end)
    local url = Citizen.Await(p)
    fetched[token] = nil
    if not url then return { ok = false, error = 'not_found' } end
    return { ok = true, data = url }
end)
