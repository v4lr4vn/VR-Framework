local input
local alert
local seq = 0

local function sanitizeRows(rows)
    if type(rows) ~= 'table' then return {} end
    local out = {}
    for i = 1, #rows do
        local r = rows[i]
        if type(r) == 'string' then
            out[i] = { type = 'input', label = r }
        elseif type(r) == 'table' then
            local copy = {}
            for k, v in pairs(r) do
                local t = type(v)
                if t == 'string' or t == 'number' or t == 'boolean' or t == 'table' then copy[k] = v end
            end
            if type(copy.icon) == 'table' then copy.icon = ('%s fa-%s'):format(copy.icon[1] or 'fas', copy.icon[2] or 'circle') end
            out[i] = copy
        else
            out[i] = { type = 'input', label = '' }
        end
    end
    return out
end

local function inputDialog(heading, rows, options)
    if input then return nil end
    seq = seq + 1
    local p = promise.new()
    input = { id = seq, promise = p, owner = UI.owner() }
    local opts = type(options) == 'table' and options or {}
    UI.send('input:open', {
        id = seq,
        heading = UI.text(heading, 160) or '',
        rows = sanitizeRows(rows),
        options = { allowCancel = opts.allowCancel ~= false, size = UI.text(opts.size, 4) },
    })
    UI.focus('input', true, false)
    return Citizen.Await(p)
end

local function finishInput(result)
    if not input then return end
    local p = input.promise
    input = nil
    UI.release('input')
    UI.send('input:close')
    p:resolve(result)
end

local function closeInputDialog()
    finishInput(nil)
end

RegisterNUICallback('input:submit', function(data, cb)
    cb(1)
    if not input or type(data) ~= 'table' or data.id ~= input.id then return end
    local values = type(data.values) == 'table' and data.values or {}
    finishInput(values)
end)

RegisterNUICallback('input:cancel', function(data, cb)
    cb(1)
    if not input or type(data) ~= 'table' or data.id ~= input.id then return end
    finishInput(nil)
end)

local function finishAlert(result)
    if not alert then return end
    local p = alert.promise
    alert = nil
    UI.release('alert')
    UI.send('alert:close')
    p:resolve(result)
end

local function alertDialog(data, timeout)
    if alert or type(data) ~= 'table' then return nil end
    seq = seq + 1
    local p = promise.new()
    local id = seq
    alert = { id = id, promise = p, owner = UI.owner() }
    UI.send('alert:open', {
        id = id,
        header = UI.text(data.header, 160) or '',
        content = UI.text(data.content, 4000) or '',
        centered = data.centered ~= false,
        size = UI.text(data.size, 4),
        overflow = data.overflow == true,
        cancel = data.cancel == true,
        labels = type(data.labels) == 'table' and { confirm = UI.text(data.labels.confirm, 40), cancel = UI.text(data.labels.cancel, 40) } or nil,
    })
    UI.focus('alert', true, false)
    if tonumber(timeout) then
        SetTimeout(math.floor(tonumber(timeout)), function()
            if alert and alert.id == id then finishAlert(nil) end
        end)
    end
    return Citizen.Await(p)
end

local function closeAlertDialog(reason)
    finishAlert(reason)
end

RegisterNUICallback('alert:result', function(data, cb)
    cb(1)
    if not alert or type(data) ~= 'table' or data.id ~= alert.id then return end
    finishAlert(data.result == 'confirm' and 'confirm' or 'cancel')
end)

UI.onOwnerStop(function(resource)
    if input and input.owner == resource then finishInput(nil) end
    if alert and alert.owner == resource then finishAlert(nil) end
end)

exports('inputDialog', inputDialog)
exports('closeInputDialog', closeInputDialog)
exports('alertDialog', alertDialog)
exports('closeAlertDialog', closeAlertDialog)
