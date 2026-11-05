const now = () => Math.floor(Date.now() / 1000);
const MIN = 60;
const HOUR = 3600;
const DAY = 86400;

function hash(s) {
  let h = 2166136261;
  for (const c of String(s)) {
    h ^= c.charCodeAt(0);
    h = Math.imul(h, 16777619) >>> 0;
  }
  return h;
}

export function hexId(seed) {
  let out = '';
  let h = hash(seed);
  while (out.length < 32) {
    h = Math.imul(h ^ (h >>> 13), 2654435761) >>> 0;
    out += h.toString(16).padStart(8, '0');
  }
  return out.slice(0, 32);
}

const skins = ['#e2b79c', '#c88f6c', '#a9704f', '#8b5b3d', '#f0c8a6', '#6f4731'];
const hairs = ['#1c1511', '#3a291d', '#6a492a', '#a6824e', '#2b2b2b', '#5b2f1d'];
const shirts = ['#3d4f66', '#5b3d3d', '#3c5a46', '#4f4a63', '#5d5446', '#2f3d4a'];
const placards = new Map();

export function placardFor(id, text) {
  placards.set(id, text);
}

export function portrait(id) {
  const h = hash(id);
  const skin = skins[h % 6];
  const hair = hairs[(h >>> 3) % 6];
  const shirt = shirts[(h >>> 6) % 6];
  const long = (h >>> 9) % 3 === 0;
  const label = placards.get(id) || id.slice(0, 8).toUpperCase();
  const lines = [40, 60, 80, 100, 120, 140]
    .map((y, i) => `<line x1='0' x2='200' y1='${y}' y2='${y}' stroke='#5b6880' stroke-width='1' opacity='0.45'/><text x='6' y='${y - 3}' font-family='monospace' font-size='8' fill='#8a9ab0'>${6 - Math.floor(i / 2)}'${i % 2 ? 0 : 6}</text>`)
    .join('');
  const hairBack = long ? `<path d='M60 90 C 56 130, 70 150, 80 150 L 120 150 C 130 150, 144 130, 140 90 Z' fill='${hair}'/>` : '';
  const svg = `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 200 200'><defs><linearGradient id='g' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#3b475a'/><stop offset='1' stop-color='#202937'/></linearGradient></defs><rect width='200' height='200' fill='url(#g)'/>${lines}${hairBack}<path d='M28 200 C 34 152, 70 140, 100 140 C 130 140, 166 152, 172 200 Z' fill='${shirt}'/><rect x='86' y='112' width='28' height='34' rx='9' fill='${skin}'/><ellipse cx='100' cy='88' rx='33' ry='41' fill='${skin}'/><path d='M66 86 C 62 52, 84 42, 100 42 C 122 42, 140 54, 134 86 C 128 68, 116 62, 100 62 C 86 62, 72 68, 66 86 Z' fill='${hair}'/><ellipse cx='87' cy='90' rx='4' ry='2.6' fill='#1b1b1f' opacity='0.75'/><ellipse cx='113' cy='90' rx='4' ry='2.6' fill='#1b1b1f' opacity='0.75'/><path d='M82 82 h10 M108 82 h10' stroke='${hair}' stroke-width='3' stroke-linecap='round'/><path d='M100 94 l-3 12 h6' fill='none' stroke='#000' stroke-opacity='0.2' stroke-width='2'/><path d='M91 115 q9 4 18 0' fill='none' stroke='#5a2f2a' stroke-opacity='0.6' stroke-width='2.4' stroke-linecap='round'/><rect x='56' y='160' width='88' height='32' rx='2' fill='#0d121a' stroke='#2b3a50'/><text x='100' y='173' font-family='monospace' font-size='9' font-weight='bold' fill='#f5a524' text-anchor='middle'>LSPD</text><text x='100' y='186' font-family='monospace' font-size='9' fill='#e6edf5' text-anchor='middle'>${label}</text></svg>`;
  return `data:image/svg+xml;charset=utf-8,${encodeURIComponent(svg)}`;
}

export const images = new Set();

function mug(cid) {
  const id = hexId(`mug-${cid}`);
  images.add(id);
  placardFor(id, cid);
  return id;
}

const t = now();

export const people = [
  { cid: 'DCR40219', name: 'Dana Cruz', dob: '1994-05-02', phone: '555-0142', gender: 1, nationality: 'American', job: 'unemployed', jobLabel: 'Civilian', gradeName: 'Freelancer', online: true, fingerprint: 'FP-7D21-C4A9', bloodtype: 'O+', licences: { driver: true, weapon: false }, mugshot: mug('DCR40219'), flags: ['Armed and dangerous', 'Known to flee'], notes: 'Known associate of the Families on Grove Street. Has fled on foot twice during traffic stops.\n\nCarries a folding knife in her left jacket pocket.', updatedBy: 'Marco Ortega', updatedAt: t - 2 * HOUR },
  { cid: 'MWB18823', name: 'Marcus Webb', dob: '1988-11-30', phone: '555-0177', gender: 0, nationality: 'American', job: 'mechanic', jobLabel: "Hayes Autos", gradeName: 'Mechanic', online: true, fingerprint: 'FP-1B90-E2F3', bloodtype: 'A-', licences: { driver: false, weapon: true, business: false }, mugshot: mug('MWB18823'), flags: ['Violent towards officers'], notes: 'Assaulted an officer during arrest on 3 Oct. Approach with two units.', updatedBy: 'Rae Hale', updatedAt: t - 6 * DAY },
  { cid: 'LOZ44210', name: 'Lena Ortiz', dob: '2000-01-09', phone: '555-0110', gender: 1, nationality: 'Mexican', job: 'beanmachine', jobLabel: 'Bean Machine', gradeName: 'Barista', online: false, fingerprint: 'FP-55AC-0D17', bloodtype: 'B+', licences: { driver: true, pilot: true }, mugshot: null, flags: [], notes: '', updatedBy: null, updatedAt: null },
  { cid: 'TBK77204', name: 'Tyrell Banks', dob: '1997-07-21', phone: '555-0193', gender: 0, nationality: 'American', job: 'unemployed', jobLabel: 'Civilian', gradeName: 'Freelancer', online: true, fingerprint: 'FP-90EE-71B2', bloodtype: 'O-', licences: { driver: true }, mugshot: mug('TBK77204'), flags: ['Gang affiliated', 'Parolee'], notes: 'On parole until March. Parole officer: S. Lind.', updatedBy: 'Sara Lind', updatedAt: t - 3 * DAY },
  { cid: 'SMC19031', name: 'Sofia Marchetti', dob: '1985-03-15', phone: '555-0121', gender: 1, nationality: 'Italian', job: 'realestate', jobLabel: 'Dynasty 8', gradeName: 'Broker', online: false, fingerprint: 'FP-3C3C-A881', bloodtype: 'AB+', licences: { driver: true, weapon: true, business: true }, mugshot: null, flags: [], notes: '', updatedBy: null, updatedAt: null },
  { cid: 'JRY55301', name: 'Jonah Reyes', dob: '1999-09-04', phone: '555-0168', gender: 0, nationality: 'American', job: 'taxi', jobLabel: 'Downtown Cab Co.', gradeName: 'Driver', online: true, fingerprint: 'FP-0A4B-6E6E', bloodtype: 'A+', licences: { driver: true }, mugshot: null, flags: [], notes: '', updatedBy: null, updatedAt: null },
  { cid: 'PNR22087', name: 'Priya Nair', dob: '1992-12-11', phone: '555-0155', gender: 1, nationality: 'British', job: 'weazel', jobLabel: 'Weazel News', gradeName: 'Reporter', online: false, fingerprint: 'FP-8F12-9D04', bloodtype: 'B-', licences: { driver: true }, mugshot: null, flags: [], notes: '', updatedBy: null, updatedAt: null },
  { cid: 'EKW66140', name: 'Eddie Kowalski', dob: '1979-02-27', phone: '555-0104', gender: 0, nationality: 'Polish', job: 'trucker', jobLabel: 'PostOP', gradeName: 'Driver', online: false, fingerprint: 'FP-2E77-B310', bloodtype: 'O+', licences: { driver: true, weapon: true, hunting: true }, mugshot: mug('EKW66140'), flags: ['Mental health concern'], notes: 'Veteran. Responds well to calm, slow instructions.', updatedBy: 'Dee Walsh', updatedAt: t - 12 * DAY },
  { cid: 'MZH33918', name: 'Mei Zhou', dob: '1996-06-18', phone: '555-0186', gender: 1, nationality: 'Chinese', job: 'unicorn', jobLabel: 'Vanilla Unicorn', gradeName: 'Bartender', online: true, fingerprint: 'FP-6D6D-1F08', bloodtype: 'A+', licences: { driver: true, business: false }, mugshot: null, flags: [], notes: '', updatedBy: null, updatedAt: null },
  { cid: 'FDY88066', name: 'Frankie Doyle', dob: '1983-10-02', phone: '555-0139', gender: 0, nationality: 'Irish', job: 'unemployed', jobLabel: 'Civilian', gradeName: 'Freelancer', online: true, fingerprint: 'FP-C0DE-44A1', bloodtype: 'B+', licences: { driver: false }, mugshot: mug('FDY88066'), flags: ['Armed and dangerous', 'Violent towards officers', 'Gang affiliated'], notes: 'Shot at officers during the Paleto bank job. Always treat as armed.', updatedBy: 'Marco Ortega', updatedAt: t - 9 * DAY },
  { cid: 'RAB11502', name: 'Ruth Abernathy', dob: '1958-04-08', phone: '555-0112', gender: 1, nationality: 'American', job: 'unemployed', jobLabel: 'Retired', gradeName: '', online: false, fingerprint: 'FP-4411-0B0B', bloodtype: 'O+', licences: { driver: true, fishing: true }, mugshot: null, flags: [], notes: 'Reported missing on 28 Sep, found safe at Sandy Shores.', updatedBy: 'Ivan Kerr', updatedAt: t - 14 * DAY },
  { cid: 'APL44771', name: 'Andre Pollard', dob: '1990-08-25', phone: '555-0147', gender: 0, nationality: 'American', job: 'burgershot', jobLabel: 'Burger Shot', gradeName: 'Cook', online: true, fingerprint: 'FP-7777-AB12', bloodtype: 'A-', licences: { driver: true }, mugshot: mug('APL44771'), flags: ['Known to flee'], notes: '', updatedBy: 'Rae Hale', updatedAt: t - 1 * DAY },
  { cid: 'VRZ90241', name: 'Valentina Ruiz', dob: '2001-01-30', phone: '555-0160', gender: 1, nationality: 'Colombian', job: 'unemployed', jobLabel: 'Student', gradeName: '', online: true, fingerprint: 'FP-1010-CAFE', bloodtype: 'O+', licences: { driver: false }, mugshot: mug('VRZ90241'), flags: [], notes: '', updatedBy: null, updatedAt: null },
  { cid: 'GHL33150', name: 'Gus Halloran', dob: '1975-12-19', phone: '555-0109', gender: 0, nationality: 'American', job: 'lscustoms', jobLabel: 'Los Santos Customs', gradeName: 'Owner', online: false, fingerprint: 'FP-9A9A-3E5D', bloodtype: 'AB-', licences: { driver: true, business: true }, mugshot: mug('GHL33150'), flags: [], notes: 'Runs a chop shop out of the La Mesa garage after hours.', updatedBy: 'Ivan Kerr', updatedAt: t - 4 * DAY },
  { cid: 'CDN55120', name: 'Cole Dana', dob: '1993-04-17', phone: '555-0131', gender: 0, nationality: 'Canadian', job: 'unemployed', jobLabel: 'Civilian', gradeName: '', online: false, fingerprint: 'FP-2C2C-7F00', bloodtype: 'A+', licences: { driver: true }, mugshot: null, flags: [], notes: '', updatedBy: null, updatedAt: null },
];

export function person(cid) {
  return people.find((p) => p.cid === cid) || null;
}

export const vehicles = [
  { plate: '82LSK104', model: 'sultanrs', label: 'Karin Sultan RS', ownerCid: 'DCR40219', garage: 'Pillbox Hill', state: 0, flags: [], notes: '' },
  { plate: '46EEK572', model: 'sultanrs', label: 'Karin Sultan RS', ownerCid: 'EKW66140', garage: 'Legion Square', state: 0, flags: ['Stolen', 'BOLO'], notes: 'Reported stolen by the owner on 11 Oct. Used as the getaway car in the Fleeca robbery.', updatedBy: 'Rae Hale', updatedAt: t - 3 * HOUR },
  { plate: '12WEB881', model: 'adder', label: 'Truffade Adder', ownerCid: 'MWB18823', garage: 'Impound lot', state: 2, flags: ['Impounded'], notes: 'Impounded after reckless driving on the Del Perro freeway.', updatedBy: 'Dee Walsh', updatedAt: t - 2 * DAY },
  { plate: '7LEN0K19', model: 'blista', label: 'Dinka Blista', ownerCid: 'LOZ44210', garage: 'Alta Street', state: 1, flags: [], notes: '' },
  { plate: '3TBX992', model: 'emperor', label: 'Albany Emperor', ownerCid: 'TBK77204', garage: 'Grove Street', state: 0, flags: ['Suspended registration'], notes: 'Registration suspended until insurance is renewed.', updatedBy: 'Sara Lind', updatedAt: t - 5 * DAY },
  { plate: '63JRC404', model: 'taxi', label: 'Vapid Taxi', ownerCid: 'JRY55301', garage: 'Downtown Cab Co.', state: 0, flags: [], notes: '' },
  { plate: '5MZH118', model: 'schafter2', label: 'Benefactor Schafter', ownerCid: 'MZH33918', garage: 'Vinewood Hills', state: 1, flags: [], notes: '' },
  { plate: '9FDY773', model: 'vigero', label: 'Declasse Vigero', ownerCid: 'FDY88066', garage: 'Sandy Shores', state: 1, flags: ['BOLO'], notes: '', updatedBy: 'Marco Ortega', updatedAt: t - 9 * DAY },
  { plate: '21SMR500', model: 'cognoscenti', label: 'Enus Cognoscenti', ownerCid: 'SMC19031', garage: 'Rockford Hills', state: 1, flags: [], notes: '' },
  { plate: 'GHST404', model: null, label: null, ownerCid: null, garage: null, state: null, flags: ['BOLO'], notes: 'Red two-door coupe with fake plates. Seen leaving the Grove Street drive-by.', updatedBy: 'Ivan Kerr', updatedAt: t - 40 * MIN },
];

export const vehicleFlags = ['Stolen', 'BOLO', 'Impounded', 'Suspended registration'];
export const weaponFlags = ['Stolen', 'Used in crime'];

export const weapons = [
  { serial: '482913HXQ104827', item: 'WEAPON_PISTOL', label: 'Pistol', ownerCid: 'DCR40219', registeredAt: t - 41 * DAY, source: 'auto', flags: ['Used in crime'], notes: 'Casings at the Fleeca scene match this model. Not yet recovered.', updatedBy: 'Rae Hale', updatedAt: t - 2 * HOUR },
  { serial: '173550KLM992018', item: 'WEAPON_COMBATPISTOL', label: 'Combat pistol', ownerCid: 'MWB18823', registeredAt: t - 120 * DAY, source: 'auto', flags: [], notes: '' },
  { serial: '338104TRB551920', item: 'WEAPON_MICROSMG', label: 'Micro SMG', ownerCid: 'TBK77204', registeredAt: t - 18 * DAY, source: 'auto', flags: ['Stolen'], notes: 'Reported stolen from Ammu-Nation Cypress Flats stock.', updatedBy: 'Sara Lind', updatedAt: t - 10 * DAY },
  { serial: '610274ABD738215', item: 'WEAPON_PISTOL50', label: 'Pistol .50', ownerCid: 'SMC19031', registeredAt: t - 64 * DAY, source: 'auto', flags: [], notes: '' },
  { serial: 'FOUND-0091', item: null, label: 'Sawn-off shotgun', ownerCid: null, registeredAt: t - 6 * DAY, source: 'manual', flags: ['Used in crime'], notes: 'Recovered from a dumpster behind the Grove Street liquor store.', updatedBy: 'Ivan Kerr', updatedAt: t - 6 * DAY },
  { serial: '277915EKW130644', item: 'WEAPON_HEAVYPISTOL', label: 'Heavy pistol', ownerCid: 'EKW66140', registeredAt: t - 300 * DAY, source: 'auto', flags: [], notes: '' },
  { serial: '840022FDY661901', item: 'WEAPON_PUMPSHOTGUN', label: 'Pump shotgun', ownerCid: 'FDY88066', registeredAt: t - 22 * DAY, source: 'auto', flags: ['Stolen', 'Used in crime'], notes: '' },
  { serial: '905521POL300177', item: 'WEAPON_CARBINERIFLE', label: 'Carbine rifle', ownerCid: 'APL44771', registeredAt: t - 2 * DAY, source: 'manual', flags: [], notes: '' },
];

export const warrants = [
  { id: 122, cid: 'TBK77204', name: 'Tyrell Banks', reason: 'Seen carrying a micro SMG reported stolen from Ammu-Nation during a stop on Forum Drive. Violates parole conditions.', charges: [{ title: 'Possession of a stolen firearm', count: 1 }, { title: 'Parole violation', count: 1 }], report_id: 1043, status: 'pending', created_by_cid: 'COP3', created_by_name: 'Dee Walsh', created_at: t - 25 * MIN },
  { id: 121, cid: 'JRY55301', name: 'Jonah Reyes', reason: 'Hit and run on Vespucci Blvd. A witness gave plate 63JRC404 and front-end damage on the taxi matches the scene.', charges: [{ title: 'Hit and run', count: 1 }, { title: 'Reckless driving', count: 1 }], report_id: 1040, status: 'pending', created_by_cid: 'COP4', created_by_name: 'Ivan Kerr', created_at: t - 2 * HOUR },
  { id: 118, cid: 'DCR40219', name: 'Dana Cruz', reason: 'Armed robbery of the Fleeca bank on Great Ocean Hwy. Identified on branch CCTV; the getaway car 46EEK572 was later found with her prints on the wheel.', charges: [{ title: 'Armed robbery', count: 1 }, { title: 'Kidnapping', count: 2 }, { title: 'Evading police', count: 1 }], report_id: 1041, status: 'active', created_by_cid: 'COP1', created_by_name: 'Rae Hale', approved_by_cid: 'JUD1', approved_by_name: 'Harlan Price', decision_note: 'Probable cause established by CCTV and forensic match.', created_at: t - 6 * HOUR, decided_at: t - 5 * HOUR, expires_at: t - 5 * HOUR + 7 * DAY },
  { id: 119, cid: 'APL44771', name: 'Andre Pollard', reason: 'Failed to appear for arraignment on 9 Oct for the Burger Shot assault case.', charges: [{ title: 'Failure to appear', count: 1 }], report_id: null, status: 'active', created_by_cid: 'COP2', created_by_name: 'Marco Ortega', approved_by_cid: 'JUD2', approved_by_name: 'Celeste Hart', decision_note: null, created_at: t - 5 * DAY, decided_at: t - 5 * DAY + 2 * HOUR, expires_at: t + 2 * DAY },
  { id: 115, cid: 'FDY88066', name: 'Frankie Doyle', reason: 'Shooting at officers during the Paleto Bay bank robbery.', charges: [{ title: 'Attempted murder of an officer', count: 2 }, { title: 'Armed robbery', count: 1 }], report_id: 1012, status: 'served', created_by_cid: 'COP2', created_by_name: 'Marco Ortega', approved_by_cid: 'JUD1', approved_by_name: 'Harlan Price', created_at: t - 10 * DAY, decided_at: t - 10 * DAY + HOUR, expires_at: t - 3 * DAY, served_at: t - 9 * DAY, closed_by_name: 'Dee Walsh' },
  { id: 112, cid: 'EKW66140', name: 'Eddie Kowalski', reason: 'Neighbour reported threats with a hunting rifle.', charges: [{ title: 'Brandishing a firearm', count: 1 }], report_id: null, status: 'denied', created_by_cid: 'COP4', created_by_name: 'Ivan Kerr', approved_by_cid: 'JUD2', approved_by_name: 'Celeste Hart', decision_note: 'Single witness with a history of disputes. Interview him first.', created_at: t - 13 * DAY, decided_at: t - 12 * DAY },
  { id: 110, cid: 'MZH33918', name: 'Mei Zhou', reason: 'Serving alcohol to minors at the Vanilla Unicorn.', charges: [{ title: 'Sale of alcohol to a minor', count: 3 }], report_id: 998, status: 'expired', created_by_cid: 'COP5', created_by_name: 'Sara Lind', approved_by_cid: 'JUD1', approved_by_name: 'Harlan Price', created_at: t - 20 * DAY, decided_at: t - 19 * DAY, expires_at: t - 12 * DAY },
  { id: 108, cid: 'LOZ44210', name: 'Lena Ortiz', reason: 'Suspected of the Bean Machine till theft.', charges: [{ title: 'Petty theft', count: 1 }], report_id: null, status: 'revoked', created_by_cid: 'COP1', created_by_name: 'Rae Hale', approved_by_cid: 'JUD1', approved_by_name: 'Harlan Price', decision_note: 'Owner found the cash in the safe.', created_at: t - 25 * DAY, decided_at: t - 24 * DAY, expires_at: t - 17 * DAY, closed_by_name: 'Harlan Price' },
];

export const bolos = [
  { id: 44, kind: 'vehicle', subject: 'Red coupe GHST404', plate: 'GHST404', cid: null, title: 'Drive-by on Grove Street', details: 'Red two-door coupe, fake plates, two occupants. Shots fired at a group outside the liquor store.', status: 'active', created_by_name: 'Ivan Kerr', created_at: t - 40 * MIN },
  { id: 43, kind: 'other', subject: 'Vangelico jewellery', plate: null, cid: null, title: 'Stolen jewellery from Vangelico', details: 'Three diamond necklaces and a gold Pendulus watch. Check pawn shops and the Paleto flea market.', status: 'active', created_by_name: 'Sara Lind', created_at: t - 5 * HOUR },
  { id: 42, kind: 'person', subject: 'Dana Cruz', plate: null, cid: 'DCR40219', title: 'Fleeca robbery suspect', details: 'Grey hoodie, red backpack. Considered armed. Do not approach alone.', status: 'active', created_by_name: 'Rae Hale', created_at: t - 6 * HOUR },
  { id: 41, kind: 'vehicle', subject: 'Karin Sultan RS 46EEK572', plate: '46EEK572', cid: null, title: 'Fleeca getaway vehicle', details: 'Dark green, tinted windows, last seen northbound on Great Ocean Hwy.', status: 'active', created_by_name: 'Rae Hale', created_at: t - 6 * HOUR },
  { id: 38, kind: 'person', subject: 'Ruth Abernathy', plate: null, cid: 'RAB11502', title: 'Missing person', details: '66-year-old woman with dementia, last seen at Mirror Park.', status: 'closed', created_by_name: 'Ivan Kerr', created_at: t - 15 * DAY, closed_at: t - 14 * DAY, closed_by_name: 'Ivan Kerr' },
  { id: 36, kind: 'vehicle', subject: 'Vapid Speedo 81KLA223', plate: '81KLA223', cid: null, title: 'Van used in a kidnapping', details: 'White van, rust on the rear doors.', status: 'closed', created_by_name: 'Marco Ortega', created_at: t - 21 * DAY, closed_at: t - 19 * DAY, closed_by_name: 'Dee Walsh' },
];

export const inmates = [
  { cid: 'VRZ90241', name: 'Valentina Ruiz', months: 3, remaining: 95, since: t - 85, reason: 'Shoplifting at the Rob\'s Liquor on Prosperity St, resisting arrest', reportId: 1039, byName: 'Sara Lind', online: true },
  { cid: 'GHL33150', name: 'Gus Halloran', months: 12, remaining: 540, since: t - 2 * DAY, reason: 'Insurance fraud, operating a chop shop', reportId: 1021, byName: 'Ivan Kerr', online: false },
  { cid: 'MWB18823', name: 'Marcus Webb', months: 24, remaining: 1022, since: t - 7 * MIN, reason: 'Assault with a deadly weapon, resisting arrest', reportId: 1038, byName: 'Marco Ortega', online: true },
  { cid: 'FDY88066', name: 'Frankie Doyle', months: 60, remaining: 3110, since: t - 9 * DAY, reason: 'Armed robbery, attempted murder of an officer', reportId: 1012, byName: 'Marco Ortega', online: true },
];

export const released = [
  { cid: 'APL44771', name: 'Andre Pollard', months: 8, reason: 'Assault at the Burger Shot', by_name: 'Rae Hale', started_at: t - 3 * HOUR, released_at: t - 2 * HOUR, release_reason: 'Sentence served' },
  { cid: 'EKW66140', name: 'Eddie Kowalski', months: 15, reason: 'Reckless endangerment', by_name: 'Dee Walsh', started_at: t - 30 * HOUR, released_at: t - 26 * HOUR, release_reason: 'Released early by Marco Ortega: Plea deal' },
  { cid: 'TBK77204', name: 'Tyrell Banks', months: 20, reason: 'Possession of narcotics with intent to sell', by_name: 'Sara Lind', started_at: t - 4 * DAY, released_at: t - 4 * DAY + 1200, release_reason: 'Sentence served' },
];

export const reportsFor = {
  DCR40219: [
    { id: 1041, title: 'Fleeca bank robbery, Great Ocean Hwy', type: 'incident', role: 'suspect', created_at: t - 6 * HOUR, author: 'Rae Hale' },
    { id: 1022, title: 'Pursuit ending at Del Perro pier', type: 'arrest', role: 'suspect', created_at: t - 40 * DAY, author: 'Marco Ortega' },
    { id: 980, title: 'Noise complaint, Grove Street', type: 'incident', role: 'witness', created_at: t - 75 * DAY, author: 'Dee Walsh' },
  ],
  FDY88066: [
    { id: 1012, title: 'Paleto Bay bank robbery, shots fired at officers', type: 'arrest', role: 'suspect', created_at: t - 9 * DAY, author: 'Marco Ortega' },
  ],
  MWB18823: [
    { id: 1038, title: 'Assault outside Hayes Autos', type: 'arrest', role: 'suspect', created_at: t - 8 * MIN, author: 'Marco Ortega' },
  ],
};

export const sentencesFor = {
  DCR40219: [
    { id: 31, reportId: 1022, charges: [{ title: 'Grand theft auto', class: 'felony', count: 1 }, { title: 'Evading police', class: 'misdemeanor', count: 1 }], fine: 4500, months: 15, at: t - 40 * DAY, officer: 'Marco Ortega' },
  ],
  FDY88066: [
    { id: 35, reportId: 1012, charges: [{ title: 'Attempted murder of an officer', class: 'felony', count: 2 }, { title: 'Armed robbery', class: 'felony', count: 1 }], fine: 25000, months: 60, at: t - 9 * DAY, officer: 'Marco Ortega' },
  ],
  MWB18823: [
    { id: 37, reportId: 1038, charges: [{ title: 'Assault with a deadly weapon', class: 'felony', count: 1 }, { title: 'Resisting arrest', class: 'misdemeanor', count: 1 }], fine: 7500, months: 24, at: t - 7 * MIN, officer: 'Marco Ortega' },
  ],
};

export const propertiesFor = {
  DCR40219: [
    { id: '14', label: 'Grove Street 14', street: 'Grove Street', region: 'Davis', role: 'owner' },
    { id: '27', label: 'Alta Street Apartments #27', apartment: 'Alta Street Apartments', role: 'keyholder' },
  ],
  SMC19031: [
    { id: '3', label: 'North Rockford Drive 3', street: 'North Rockford Drive', region: 'Richman', role: 'owner' },
    { id: '9', label: 'Del Perro Heights #9', apartment: 'Del Perro Heights', role: 'owner' },
  ],
  MWB18823: [{ id: '31', label: 'Mirror Park Blvd 31', street: 'Mirror Park Blvd', region: 'Mirror Park', role: 'owner' }],
};

export const licenceLabels = { driver: 'Driver licence', weapon: 'Weapon licence', business: 'Business licence', pilot: 'Pilot licence', hunting: 'Hunting licence', fishing: 'Fishing licence' };

export function publicPerson(p) {
  if (!p) return null;
  return { cid: p.cid, name: p.name, dob: p.dob, phone: p.phone, gender: p.gender, nationality: p.nationality, job: p.job, jobLabel: p.jobLabel, gradeName: p.gradeName, online: p.online };
}

export function hasActiveWarrant(cid) {
  return warrants.some((w) => w.cid === cid && w.status === 'active' && w.expires_at > now());
}

export function me(dept) {
  if (dept === 'doj') return { cid: 'JUD1', name: 'Harlan Price' };
  if (dept === 'ems') return { cid: 'MED1', name: 'Tess Moreau' };
  return { cid: 'COP1', name: 'Rae Hale' };
}

export function matches(text, q) {
  return String(text || '').toLowerCase().includes(String(q || '').toLowerCase());
}

export { now };
