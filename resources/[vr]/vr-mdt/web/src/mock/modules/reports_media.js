const images = new Map();

const W = 640;
const H = 420;

function noise(seed, opacity) {
  return `<filter id="n${seed}"><feTurbulence type="fractalNoise" baseFrequency=".85" numOctaves="2" seed="${seed}"/><feColorMatrix values="0 0 0 0 .5 0 0 0 0 .5 0 0 0 0 .5 0 0 0 ${opacity} 0"/></filter>`;
}

function marker(x, y, n) {
  return `<g transform="translate(${x} ${y})"><path d="M-16 18 0-20 16 18Z" fill="#f2c230" stroke="#6b5310" stroke-width="2"/><rect x="-10" y="-2" width="20" height="16" fill="#111"/><text x="0" y="11" fill="#f2c230" font-family="monospace" font-size="13" font-weight="700" text-anchor="middle">${n}</text></g>`;
}

function ruler(x, y, w) {
  let ticks = '';
  for (let i = 0; i <= w; i += 10) ticks += `<line x1="${x + i}" y1="${y}" x2="${x + i}" y2="${y + (i % 50 === 0 ? 12 : 7)}" stroke="#222" stroke-width="1.5"/>`;
  return `<rect x="${x - 4}" y="${y - 2}" width="${w + 8}" height="22" fill="#e9e3cf"/>${ticks}<text x="${x + w - 2}" y="${y + 18}" font-family="monospace" font-size="9" fill="#222" text-anchor="end">LSPD EVIDENCE · CM</text>`;
}

function casing(x, y, r) {
  return `<g transform="translate(${x} ${y}) rotate(${r})"><rect x="-11" y="-4" width="22" height="8" rx="2" fill="#c9a24a"/><rect x="-11" y="-4" width="5" height="8" fill="#9c7a2e"/><ellipse cx="10" cy="0" rx="1.6" ry="3.6" fill="#5e4a1c"/></g>`;
}

const scenes = {
  casings: () => `<defs><radialGradient id="g" cx=".45" cy=".35" r=".85"><stop offset="0" stop-color="#5a5f66"/><stop offset="1" stop-color="#16191d"/></radialGradient>${noise(3, 0.55)}</defs>
<rect width="${W}" height="${H}" fill="url(#g)"/><rect width="${W}" height="${H}" filter="url(#n3)"/>
<path d="M0 300 L640 250 L640 268 L0 320Z" fill="#d8d2b8" opacity=".55"/>
${casing(180, 200, 20)}${casing(330, 160, -35)}${casing(420, 300, 70)}
${marker(150, 240, 1)}${marker(300, 200, 2)}${marker(455, 335, 3)}
${ruler(440, 380, 160)}`,
  sedan: () => `<defs><linearGradient id="s" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#0a1220"/><stop offset=".62" stop-color="#1b2433"/><stop offset=".63" stop-color="#202227"/><stop offset="1" stop-color="#0e0f12"/></linearGradient><radialGradient id="lamp" cx=".78" cy=".18" r=".45"><stop offset="0" stop-color="#ffcf7a" stop-opacity=".55"/><stop offset="1" stop-color="#ffcf7a" stop-opacity="0"/></radialGradient>${noise(7, 0.35)}</defs>
<rect width="${W}" height="${H}" fill="url(#s)"/><rect width="${W}" height="${H}" fill="url(#lamp)"/>
<rect x="490" y="60" width="6" height="200" fill="#2a2d33"/><rect x="470" y="56" width="40" height="8" rx="3" fill="#3a3d44"/>
<path d="M120 300 L160 250 Q190 222 250 220 L380 220 Q430 222 460 252 L520 268 Q545 275 545 298 L545 318 L120 318Z" fill="#1f4a33"/>
<path d="M190 252 L222 230 L300 228 L300 254Z M312 228 L380 228 Q410 232 430 254 L312 256Z" fill="#0b1a14" opacity=".9"/>
<circle cx="200" cy="320" r="26" fill="#0c0c0e"/><circle cx="200" cy="320" r="12" fill="#3b3e44"/><circle cx="470" cy="320" r="26" fill="#0c0c0e"/><circle cx="470" cy="320" r="12" fill="#3b3e44"/>
<ellipse cx="538" cy="285" rx="16" ry="8" fill="#fff4cf"/><ellipse cx="560" cy="290" rx="70" ry="22" fill="#fff4cf" opacity=".12"/>
<rect x="300" y="292" width="62" height="16" rx="2" fill="#e8e8e8"/><text x="331" y="305" font-family="monospace" font-size="11" font-weight="700" fill="#14305e" text-anchor="middle">46EEK572</text>
<rect width="${W}" height="${H}" filter="url(#n7)"/>`,
  cctv: () => `<defs>${noise(11, 0.4)}<pattern id="sl" width="4" height="4" patternUnits="userSpaceOnUse"><rect width="4" height="2" fill="#000" opacity=".22"/></pattern></defs>
<rect width="${W}" height="${H}" fill="#3c3f42"/><rect y="250" width="${W}" height="170" fill="#55585b"/>
<rect x="30" y="60" width="160" height="190" fill="#2c2e30"/><rect x="40" y="80" width="140" height="10" fill="#6c6f72"/><rect x="40" y="130" width="140" height="10" fill="#6c6f72"/><rect x="40" y="180" width="140" height="10" fill="#6c6f72"/>
<rect x="380" y="200" width="240" height="70" fill="#26282a"/><rect x="400" y="170" width="60" height="30" fill="#7a7d80"/>
<circle cx="300" cy="150" r="22" fill="#18191a"/><path d="M262 300 Q262 190 300 180 Q338 190 338 300Z" fill="#18191a"/><path d="M330 220 L395 205 L398 214 L334 232Z" fill="#18191a"/>
<rect width="${W}" height="${H}" filter="url(#n11)"/><rect width="${W}" height="${H}" fill="url(#sl)"/>
<text x="16" y="28" font-family="monospace" font-size="15" fill="#f1f1f1">CAM 02  24/7 INNOCENCE BLVD</text><text x="16" y="404" font-family="monospace" font-size="15" fill="#f1f1f1">2026-10-11  02:14:33</text>
<circle cx="604" cy="22" r="6" fill="#ff3b30"/><text x="592" y="27" font-family="monospace" font-size="13" fill="#f1f1f1" text-anchor="end">REC</text>`,
  wall: () => `<defs><linearGradient id="w" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#a69a86"/><stop offset="1" stop-color="#6d6455"/></linearGradient>${noise(5, 0.5)}</defs>
<rect width="${W}" height="${H}" fill="url(#w)"/><rect width="${W}" height="${H}" filter="url(#n5)"/>
${[[190, 160], [250, 190], [232, 120], [410, 210]].map(([x, y]) => `<circle cx="${x}" cy="${y}" r="13" fill="#8c8270"/><circle cx="${x}" cy="${y}" r="7" fill="#1b1814"/>`).join('')}
${marker(520, 120, 'A')}${ruler(160, 330, 300)}`,
  mask: () => `<defs><linearGradient id="t" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#4b4f55"/><stop offset="1" stop-color="#2a2d31"/></linearGradient>${noise(9, 0.3)}</defs>
<rect width="${W}" height="${H}" fill="url(#t)"/><rect width="${W}" height="${H}" filter="url(#n9)"/>
<path d="M250 80 Q330 50 400 85 Q440 140 430 250 Q420 330 325 345 Q230 330 220 250 Q210 140 250 80Z" fill="#151619"/>
<ellipse cx="290" cy="185" rx="26" ry="16" fill="#3f434a"/><ellipse cx="365" cy="185" rx="26" ry="16" fill="#3f434a"/><ellipse cx="327" cy="268" rx="30" ry="12" fill="#3f434a"/>
<rect x="470" y="60" width="140" height="70" fill="#f3efe2"/><text x="482" y="86" font-family="monospace" font-size="13" fill="#222">CASE 312</text><text x="482" y="106" font-family="monospace" font-size="13" fill="#222">ITEM 02 · MASK</text>
${ruler(60, 370, 220)}`,
  pistol: () => `<defs><linearGradient id="t2" x1="0" y1="0" x2="1" y2="1"><stop offset="0" stop-color="#3a3e44"/><stop offset="1" stop-color="#1f2226"/></linearGradient>${noise(13, 0.3)}</defs>
<rect width="${W}" height="${H}" fill="url(#t2)"/><rect width="${W}" height="${H}" filter="url(#n13)"/>
<path d="M170 150 L470 150 L470 190 L300 190 L290 210 L250 210 L235 300 L180 300 L200 200 L170 190Z" fill="#0f1012"/>
<rect x="200" y="160" width="250" height="8" fill="#26282c"/><circle cx="268" cy="220" r="14" fill="none" stroke="#26282c" stroke-width="5"/>
<rect x="470" y="60" width="140" height="70" fill="#f3efe2"/><text x="482" y="86" font-family="monospace" font-size="13" fill="#222">SERIAL</text><text x="482" y="106" font-family="monospace" font-size="13" fill="#222">PLK-21-0093</text>
${ruler(300, 360, 260)}`,
  bag: () => `<defs><linearGradient id="t3" x1="0" y1="0" x2="0" y2="1"><stop offset="0" stop-color="#52565c"/><stop offset="1" stop-color="#303338"/></linearGradient>${noise(15, 0.3)}</defs>
<rect width="${W}" height="${H}" fill="url(#t3)"/><rect width="${W}" height="${H}" filter="url(#n15)"/>
<rect x="190" y="70" width="260" height="280" rx="10" fill="#dfe8ee" opacity=".22" stroke="#e8f0f5" stroke-opacity=".6" stroke-width="2"/><rect x="190" y="70" width="260" height="26" fill="#c23b3b" opacity=".85"/>
${Array.from({ length: 22 }, (_, i) => `<ellipse cx="${230 + ((i * 47) % 180)}" cy="${150 + ((i * 31) % 170)}" rx="9" ry="6" fill="#f2f2f2" transform="rotate(${(i * 37) % 180} ${230 + ((i * 47) % 180)} ${150 + ((i * 31) % 170)})"/>`).join('')}
${ruler(70, 380, 200)}`,
};

const kinds = Object.keys(scenes);

function hex() {
  let s = '';
  for (let i = 0; i < 32; i++) s += Math.floor(Math.random() * 16).toString(16);
  return s;
}

function render(kind) {
  const body = (scenes[kind] || scenes.casings)();
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(`<svg xmlns="http://www.w3.org/2000/svg" width="${W}" height="${H}" viewBox="0 0 ${W} ${H}">${body}</svg>`)}`;
}

export function mockPhoto(kind) {
  const id = hex();
  images.set(id, render(kind));
  return id;
}

export function dropPhoto(id) {
  images.delete(id);
}

let captures = 0;

export default function (reg, regCallback) {
  regCallback('capture', async (d) => {
    if (d?.kind === 'mugshot') return undefined;
    await new Promise((r) => setTimeout(r, 350));
    const kind = kinds[captures++ % kinds.length];
    const id = mockPhoto(kind);
    return { ok: true, data: { id, url: images.get(id) } };
  });
  regCallback('image', (d) => {
    const url = images.get(d.id);
    return url ? { ok: true, data: url } : undefined;
  });
}
