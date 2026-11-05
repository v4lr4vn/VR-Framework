MdtRadio = {}

local R = (Config.Dispatcher or {}).radio or {}
local signature = nil
local menuShown = false

local function voice()
    return Bridge.voice.resource() ~= nil
end

local function unitDept()
    local who = Mdt.radioUser and Mdt.radioUser()
    if who == 'police' or who == 'ems' then return who end
    return nil
end

local function channelsFor(dept)
    local out = {}
    for _, c in ipairs(R.channels or {}) do
        if c.dept == dept or c.dept == 'all' then out[#out + 1] = c end
    end
    return out
end

local function allowed(dept, id)
    for _, c in ipairs(channelsFor(dept)) do
        if c.id == id then return c end
    end
end

local function current()
    return tonumber(LocalPlayer.state.radioChannel) or 0
end

function MdtRadio.join(id, quiet)
    local dept = unitDept()
    local c = dept and id and allowed(dept, id)
    if not c or not voice() then
        if not quiet then Bridge.notify("You can't use that channel.", 'error') end
        return false
    end
    Bridge.voice.setRadio(id)
    if not quiet then Bridge.notify(('Radio: CH %d · %s'):format(c.id, c.label), 'inform') end
    return true
end

function MdtRadio.leave(quiet)
    if not voice() then return end
    Bridge.voice.setRadio(0)
    if not quiet then Bridge.notify('You left the radio.', 'inform') end
end

RegisterNetEvent('vr-mdt:client:radioMove', function(id, label, by)
    if GetInvokingResource() or not voice() then return end
    id = tonumber(id)
    if not id then return end
    if id == 0 then
        Bridge.voice.setRadio(0)
        Bridge.notify(('%s took you off the radio.'):format(by or 'Dispatch'), 'inform')
        return
    end
    if not unitDept() then return end
    Bridge.voice.setRadio(id)
    Bridge.notify(('%s moved you to CH %d%s.'):format(by or 'Dispatch', id, label and (' · ' .. label) or ''), 'inform')
end)

local function membersChanged()
    if unitDept() then Mdt.send({ type = 'push', name = 'radio:members', payload = {} }) end
end

for _, prefix in ipairs({ 'vr-voice', 'pma-voice' }) do
    RegisterNetEvent(prefix .. ':addPlayerToRadio', membersChanged)
    RegisterNetEvent(prefix .. ':removePlayerFromRadio', membersChanged)
    RegisterNetEvent(prefix .. ':syncRadioData', membersChanged)
end

local function ui()
    return R.radial ~= false and GetResourceState('vr-ui') == 'started'
end

local function removeMenu()
    if not menuShown then return end
    menuShown = false
    if GetResourceState('vr-ui') == 'started' then pcall(function() exports['vr-ui']:removeRadialItem('vr_mdt_job') end) end
end

local function buildMenu(dept)
    local now = current()
    local items = {}
    for _, c in ipairs(channelsFor(dept)) do
        local id = c.id
        items[#items + 1] = {
            label = ('%sCH %d %s'):format(now == id and '● ' or '', id, c.label),
            icon = now == id and 'circle-dot' or 'tower-broadcast',
            onSelect = function() MdtRadio.join(id) end,
        }
    end
    if now > 0 then
        items[#items + 1] = { label = 'Leave radio', icon = 'power-off', onSelect = function() MdtRadio.leave() end }
    end
    local title = dept == 'ems' and 'EMS' or 'Police'
    local ok = pcall(function()
        exports['vr-ui']:registerRadial({ id = 'vr_mdt_radio', label = now > 0 and ('Radio · CH %d'):format(now) or 'Radio', items = items })
        exports['vr-ui']:registerRadial({ id = 'vr_mdt_job', label = title, items = {
            { label = now > 0 and ('Radio · CH %d'):format(now) or 'Radio', icon = 'walkie-talkie', menu = 'vr_mdt_radio' },
            { label = 'Open MDT', icon = 'tablet-screen-button', onSelect = function() Mdt.openTablet() end },
        } })
        exports['vr-ui']:addRadialItem({ id = 'vr_mdt_job', label = title, icon = dept == 'ems' and 'truck-medical' or 'shield-halved', menu = 'vr_mdt_job' })
    end)
    menuShown = ok
end

function MdtRadio.refreshMenu(force)
    local dept = ui() and unitDept() or nil
    local sig = dept and (dept .. ':' .. current()) or 'none'
    if sig == signature and not force then return end
    signature = sig
    if dept then buildMenu(dept) else removeMenu() end
end

AddStateBagChangeHandler('radioChannel', ('player:%s'):format(GetPlayerServerId(PlayerId())), function()
    SetTimeout(100, MdtRadio.refreshMenu)
end)

Bridge.on('jobChanged', function() SetTimeout(250, MdtRadio.refreshMenu) end)
Bridge.on('dutyChanged', function() SetTimeout(250, MdtRadio.refreshMenu) end)
Bridge.on('playerLoaded', function() SetTimeout(1000, MdtRadio.refreshMenu) end)
Bridge.on('playerUnloaded', function()
    signature = nil
    removeMenu()
end)

AddEventHandler('onClientResourceStart', function(res)
    if res == 'vr-ui' then
        menuShown = false
        SetTimeout(1000, function() MdtRadio.refreshMenu(true) end)
    end
end)

CreateThread(function()
    Wait(1500)
    while true do
        MdtRadio.refreshMenu()
        Wait(2000)
    end
end)
