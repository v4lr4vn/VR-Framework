KeyData = {}

local labels = {
    [0x08] = 'Backspace', [0x09] = 'Tab', [0x0D] = 'Enter', [0x13] = 'Pause', [0x14] = 'Caps Lock', [0x1B] = 'Esc',
    [0x20] = 'Space', [0x21] = 'Page Up', [0x22] = 'Page Down', [0x23] = 'End', [0x24] = 'Home',
    [0x25] = 'Left', [0x26] = 'Up', [0x27] = 'Right', [0x28] = 'Down', [0x2D] = 'Insert', [0x2E] = 'Delete',
    [0x6A] = 'Num *', [0x6B] = 'Num +', [0x6D] = 'Num -', [0x6E] = 'Num .', [0x6F] = 'Num /',
    [0x90] = 'Num Lock', [0x91] = 'Scroll Lock',
    [0xA0] = 'Left Shift', [0xA1] = 'Right Shift', [0xA2] = 'Left Ctrl', [0xA3] = 'Right Ctrl', [0xA4] = 'Left Alt', [0xA5] = 'Right Alt',
    [0xBA] = ';', [0xBB] = '=', [0xBC] = ',', [0xBD] = '-', [0xBE] = '.', [0xBF] = '/', [0xC0] = '`',
    [0xDB] = '[', [0xDC] = '\\', [0xDD] = ']', [0xDE] = "'", [0xE2] = '\\ (ISO)',
}
for i = 0, 9 do labels[0x30 + i] = tostring(i) end
for i = 0, 25 do labels[0x41 + i] = string.char(65 + i) end
for i = 0, 9 do labels[0x60 + i] = 'Num ' .. i end
for i = 1, 24 do labels[0x6F + i] = 'F' .. i end
KeyData.labels = labels

local names = {
    BACK = 0x08, BACKSPACE = 0x08, TAB = 0x09, RETURN = 0x0D, ENTER = 0x0D, PAUSE = 0x13, CAPITAL = 0x14, CAPSLOCK = 0x14,
    ESCAPE = 0x1B, ESC = 0x1B, SPACE = 0x20, PAGEUP = 0x21, PRIOR = 0x21, PAGEDOWN = 0x22, NEXT = 0x22, ['END'] = 0x23,
    HOME = 0x24, LEFT = 0x25, UP = 0x26, RIGHT = 0x27, DOWN = 0x28, INSERT = 0x2D, DELETE = 0x2E,
    MULTIPLY = 0x6A, ADD = 0x6B, SUBTRACT = 0x6D, DECIMAL = 0x6E, DIVIDE = 0x6F, NUMLOCK = 0x90, SCROLL = 0x91,
    LSHIFT = 0xA0, RSHIFT = 0xA1, LCONTROL = 0xA2, RCONTROL = 0xA3, LMENU = 0xA4, RMENU = 0xA5,
    SEMICOLON = 0xBA, EQUALS = 0xBB, PLUS = 0xBB, COMMA = 0xBC, MINUS = 0xBD, PERIOD = 0xBE, SLASH = 0xBF,
    GRAVE = 0xC0, LBRACKET = 0xDB, BACKSLASH = 0xDC, RBRACKET = 0xDD, APOSTROPHE = 0xDE,
}
for i = 0, 9 do names[tostring(i)] = 0x30 + i; names['NUMPAD' .. i] = 0x60 + i end
for i = 0, 25 do names[string.char(65 + i)] = 0x41 + i end
for i = 1, 24 do names['F' .. i] = 0x6F + i end
KeyData.names = names

KeyData.mods = { shift = { 0xA0, 0xA1, 0x10 }, ctrl = { 0xA2, 0xA3, 0x11 }, alt = { 0xA4, 0xA5, 0x12 } }
KeyData.modLabels = { shift = 'Shift', ctrl = 'Ctrl', alt = 'Alt' }
KeyData.modFamily = { [0xA0] = 'shift', [0xA1] = 'shift', [0xA2] = 'ctrl', [0xA3] = 'ctrl', [0xA4] = 'alt', [0xA5] = 'alt' }
KeyData.generic = { [0xA0] = 0x10, [0xA1] = 0x10, [0xA2] = 0x11, [0xA3] = 0x11, [0xA4] = 0x12, [0xA5] = 0x12 }

KeyData.textless = {}
for _, vk in ipairs({ 0x09, 0x13, 0x14, 0x21, 0x22, 0x23, 0x24, 0x2D, 0x2E, 0x90, 0x91, 0xA0, 0xA1, 0xA2, 0xA3, 0xA4, 0xA5 }) do
    KeyData.textless[vk] = true
end
for i = 1, 24 do KeyData.textless[0x6F + i] = true end

function KeyData.parse(value)
    if type(value) == 'number' then return labels[value] and math.floor(value) or nil end
    if type(value) ~= 'string' or value == '' then return nil end
    return names[value:upper():gsub('^IOM_', ''):gsub('%s', '')]
end

function KeyData.label(bind)
    if type(bind) ~= 'table' or not bind.k then return '' end
    local key = labels[bind.k] or ('Key ' .. bind.k)
    if bind.m and KeyData.modLabels[bind.m] then return KeyData.modLabels[bind.m] .. ' + ' .. key end
    return key
end
