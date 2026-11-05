const codes = {
  Tab: 0x09, Pause: 0x13, CapsLock: 0x14, Space: 0x20, Enter: 0x0d, NumpadEnter: 0x0d, Escape: 0x1b, Backspace: 0x08,
  PageUp: 0x21, PageDown: 0x22, End: 0x23, Home: 0x24, ArrowLeft: 0x25, ArrowUp: 0x26, ArrowRight: 0x27, ArrowDown: 0x28,
  Insert: 0x2d, Delete: 0x2e, NumpadMultiply: 0x6a, NumpadAdd: 0x6b, NumpadSubtract: 0x6d, NumpadDecimal: 0x6e, NumpadDivide: 0x6f,
  NumLock: 0x90, ScrollLock: 0x91, ShiftLeft: 0xa0, ShiftRight: 0xa1, ControlLeft: 0xa2, ControlRight: 0xa3, AltLeft: 0xa4, AltRight: 0xa5,
  Semicolon: 0xba, Equal: 0xbb, Comma: 0xbc, Minus: 0xbd, Period: 0xbe, Slash: 0xbf, Backquote: 0xc0,
  BracketLeft: 0xdb, Backslash: 0xdc, BracketRight: 0xdd, Quote: 0xde, IntlBackslash: 0xe2,
};
for (let i = 0; i < 10; i++) {
  codes[`Digit${i}`] = 0x30 + i;
  codes[`Numpad${i}`] = 0x60 + i;
}
for (let i = 0; i < 26; i++) codes[`Key${String.fromCharCode(65 + i)}`] = 0x41 + i;
for (let i = 1; i <= 24; i++) codes[`F${i}`] = 0x6f + i;

export const vkFromCode = (code) => codes[code] ?? null;

const family = { 0xa0: 'shift', 0xa1: 'shift', 0xa2: 'ctrl', 0xa3: 'ctrl', 0xa4: 'alt', 0xa5: 'alt' };

export const modFamily = (vk) => family[vk] ?? null;

export const modFromEvent = (e) => (e.ctrlKey ? 'ctrl' : e.altKey ? 'alt' : e.shiftKey ? 'shift' : null);

export const sameBind = (a, b) => !!a && !!b && a.k === b.k && (a.m ?? null) === (b.m ?? null);
