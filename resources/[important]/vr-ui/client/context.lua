local menus = {}
local openId

local function iconOf(icon)
    if type(icon) == 'table' then return ('%s fa-%s'):format(icon[1] or 'fas', icon[2] or 'circle') end
    return UI.text(icon, 96)
end

local function metadata(meta)
    if type(meta) ~= 'table' then return nil end
    local out = {}
    if meta[1] ~= nil then
        for i = 1, #meta do
            local m = meta[i]
            if type(m) == 'table' then
                out[#out + 1] = { label = UI.text(m.label, 64), value = m.value ~= nil and tostring(m.value) or nil, progress = tonumber(m.progress), colorScheme = UI.text(m.colorScheme, 24) }
            elseif m ~= nil then
                out[#out + 1] = { label = tostring(m) }
            end
        end
    else
        local keys = {}
        for k in pairs(meta) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local v = meta[k]
            if type(v) == 'table' then
                out[#out + 1] = { label = tostring(k), value = v.value ~= nil and tostring(v.value) or nil, progress = tonumber(v.progress), colorScheme = UI.text(v.colorScheme, 24) }
            else
                out[#out + 1] = { label = tostring(k), value = v ~= nil and tostring(v) or nil }
            end
        end
    end
    return #out > 0 and out or nil
end

local function resolve(ctx)
    local list = {}
    local options = ctx.options or {}
    if options[1] ~= nil or next(options) == nil then
        for i = 1, #options do
            if type(options[i]) == 'table' then list[#list + 1] = options[i] end
        end
    else
        local keys = {}
        for k in pairs(options) do keys[#keys + 1] = k end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do
            local o = options[k]
            if type(o) == 'table' then
                o.title = o.title or tostring(k)
                list[#list + 1] = o
            end
        end
    end
    return list
end

local function payload(ctx)
    local list = resolve(ctx)
    ctx.__list = list
    local out = {}
    for i, o in ipairs(list) do
        out[i] = {
            index = i,
            title = UI.text(o.title, 160) or '',
            description = UI.text(o.description, 600),
            icon = iconOf(o.icon),
            iconColor = UI.text(o.iconColor, 32),
            iconAnimation = UI.text(o.iconAnimation, 16),
            arrow = o.arrow == true,
            menu = o.menu ~= nil,
            disabled = o.disabled == true,
            readOnly = o.readOnly == true,
            progress = tonumber(o.progress),
            colorScheme = UI.text(o.colorScheme, 24),
            metadata = metadata(o.metadata),
            image = UI.text(o.image, 512),
        }
    end
    return {
        id = ctx.id,
        title = UI.text(ctx.title, 160) or '',
        canClose = ctx.canClose ~= false,
        hasBack = ctx.menu ~= nil,
        position = UI.text(ctx.position, 12),
        options = out,
    }
end

local function store(ctx, owner)
    if type(ctx) ~= 'table' or ctx.id == nil then return end
    ctx.__owner = owner
    menus[ctx.id] = ctx
    if openId == ctx.id then UI.send('context:show', payload(ctx)) end
end

local function register(context)
    local owner = UI.owner()
    if type(context) ~= 'table' then return end
    if context.id ~= nil then
        store(context, owner)
    else
        for _, ctx in pairs(context) do store(ctx, owner) end
    end
end

local function show(id)
    local ctx = menus[id]
    if not ctx then error(('No context menu of such id found (%s)'):format(tostring(id)), 2) end
    openId = id
    UI.send('context:show', payload(ctx))
    UI.focus('context', true, false)
end

local function hide(onExit)
    if not openId then return end
    local ctx = menus[openId]
    openId = nil
    UI.release('context')
    UI.send('context:hide')
    if onExit and ctx and ctx.onExit then UI.call(ctx.onExit) end
end

local function getOpen()
    return openId
end

RegisterNUICallback('context:select', function(data, cb)
    cb(1)
    local ctx = openId and menus[openId]
    if not ctx or type(data) ~= 'table' or data.id ~= ctx.id then return end
    local opt = ctx.__list and ctx.__list[tonumber(data.index) or 0]
    if not opt or opt.disabled or opt.readOnly then return end
    if opt.menu then
        if not menus[opt.menu] then return end
        if opt.onSelect then UI.call(opt.onSelect, opt.args) end
        show(opt.menu)
        return
    end
    hide(false)
    if opt.onSelect then UI.call(opt.onSelect, opt.args) end
    if opt.event then TriggerEvent(opt.event, opt.args) end
    if opt.serverEvent then TriggerServerEvent(opt.serverEvent, opt.args) end
end)

RegisterNUICallback('context:back', function(data, cb)
    cb(1)
    local ctx = openId and menus[openId]
    if not ctx or not ctx.menu then return end
    if ctx.onBack then UI.call(ctx.onBack) end
    if menus[ctx.menu] then show(ctx.menu) else hide(true) end
end)

RegisterNUICallback('context:close', function(_, cb)
    cb(1)
    local ctx = openId and menus[openId]
    if ctx and ctx.canClose == false then return end
    hide(true)
end)

UI.onOwnerStop(function(resource)
    for id, ctx in pairs(menus) do
        if ctx.__owner == resource then
            if openId == id then hide(false) end
            menus[id] = nil
        end
    end
end)

exports('registerContext', register)
exports('showContext', show)
exports('hideContext', hide)
exports('getOpenContextMenu', getOpen)
