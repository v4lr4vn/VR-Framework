KeybindConfig = {}

KeybindConfig.command = 'keybinds'

KeybindConfig.essential = {
    ['vr-inventory:inv'] = true,
    ['vr-target:vr_target'] = true,
    ['vr-phone:vr_phone_toggle'] = true,
    ['vr-voice:radiotalk'] = true,
}

KeybindConfig.categories = {
    { id = 'inventory', label = 'Inventory', icon = 'box-open', resources = { 'vr-inventory' } },
    { id = 'interaction', label = 'Interaction', icon = 'eye', resources = { 'vr-target', 'vr-ui' } },
    { id = 'phone', label = 'Phone', icon = 'mobile-screen', resources = { 'vr-phone' } },
    { id = 'voice', label = 'Voice & radio', icon = 'tower-broadcast', resources = { 'vr-voice' } },
    { id = 'emotes', label = 'Emotes', icon = 'face-smile', resources = { 'vr-emotes' } },
    { id = 'interface', label = 'Interface', icon = 'display', resources = { 'vr-hud', 'vr-keybinds' } },
    { id = 'vehicle', label = 'Vehicle', icon = 'car', resources = { 'vr-djbooth' } },
    { id = 'jobs', label = 'Jobs', icon = 'briefcase', resources = { 'vr-mdt', 'vr-policejob', 'vr-multijob' } },
    { id = 'admin', label = 'Admin', icon = 'shield-halved', resources = { 'vr-adminmenu' }, admin = true },
    { id = 'other', label = 'Other', icon = 'ellipsis' },
}

KeybindConfig.blocked = {
    [0x57] = 'Movement key', [0x41] = 'Movement key', [0x53] = 'Movement key', [0x44] = 'Movement key',
    [0x20] = 'Jump', [0x1B] = 'Pause menu', [0x0D] = 'Used to confirm and send', [0x08] = 'Used to go back and clear',
    [0x54] = 'Opens chat', [0x77] = 'Opens the F8 console',
}

KeybindConfig.gta = {
    [0x45] = 'Interact / horn', [0x46] = 'Enter or leave a vehicle', [0x52] = 'Reload', [0x51] = 'Take cover',
    [0x47] = 'Throw a grenade', [0x09] = 'Weapon wheel', [0x43] = 'Look behind', [0x56] = 'Change camera',
    [0x58] = 'Duck in a vehicle', [0x48] = 'Headlights', [0x5A] = 'Expand the map', [0x50] = 'Pause map',
    [0x4E] = 'Push to talk', [0x14] = 'Special ability', [0xA0] = 'Sprint', [0xA2] = 'Crouch / stealth',
    [0x31] = 'Weapon select', [0x32] = 'Weapon select', [0x33] = 'Weapon select', [0x34] = 'Weapon select',
    [0x35] = 'Weapon select', [0x36] = 'Weapon select', [0x37] = 'Weapon select', [0x38] = 'Weapon select', [0x39] = 'Weapon select',
}

KeybindConfig.saveDelay = 1000

-- ValRavn framework: a renamed copy of this resource does not run.
do
    local expected = 'vr-keybinds'
    local current = GetCurrentResourceName()
    if current ~= expected then
        local message = ('^1%s is a ValRavn resource %s under another name. Renamed copies do not run.^0'):format(current, expected)
        print(message)
        if IsDuplicityVersion() then CreateThread(function() StopResource(current) end) end
        error(message, 0)
    end
end
