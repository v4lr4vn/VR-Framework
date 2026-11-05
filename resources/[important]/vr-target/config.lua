TargetConfig = {
    key = GetConvar('vr-target:key', GetConvar('ox_target:defaultHotkey', 'LMENU')),
    toggle = GetConvarInt('vr-target:toggle', GetConvarInt('ox_target:toggleHotkey', 0)) == 1,
    leftClick = GetConvarInt('vr-target:leftClick', GetConvarInt('ox_target:leftClick', 1)) == 1,
    defaults = GetConvarInt('vr-target:defaults', GetConvarInt('ox_target:defaults', 1)) == 1,
    sprites = GetConvarInt('vr-target:drawSprite', GetConvarInt('ox_target:drawSprite', 24)),
    debug = GetConvarInt('vr-target:debug', GetConvarInt('ox_target:debug', 0)) == 1,
    defaultDistance = 7.0,
    spriteColour = { 140, 154, 176, 190 },
    spriteHover = { 245, 165, 36, 255 },
}
