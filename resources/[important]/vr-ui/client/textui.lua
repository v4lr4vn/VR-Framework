local open, current, owner = false, nil, nil

local function show(text, options)
    current = tostring(text or '')
    owner = UI.owner()
    open = true
    local opts = type(options) == 'table' and options or {}
    UI.send('textui:show', {
        text = current,
        options = {
            position = UI.text(opts.position, 24),
            icon = type(opts.icon) == 'table' and ('%s fa-%s'):format(opts.icon[1] or 'fas', opts.icon[2] or '') or UI.text(opts.icon, 64),
            iconColor = UI.text(opts.iconColor, 32),
            iconAnimation = UI.text(opts.iconAnimation, 16),
            alignIcon = UI.text(opts.alignIcon, 8),
            style = type(opts.style) == 'table' and opts.style or nil,
        },
    })
end

local function hide()
    if not open then return end
    open, current, owner = false, nil, nil
    UI.send('textui:hide')
end

local function isOpen()
    return open, current
end

UI.onOwnerStop(function(resource)
    if owner == resource then hide() end
end)

exports('showTextUI', show)
exports('hideTextUI', hide)
exports('isTextUIOpen', isOpen)
