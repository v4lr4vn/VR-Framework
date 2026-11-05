export const citizens = [
  { cid: 'DCR40219', name: 'Dana Cruz', dob: '1994-05-02', phone: '555-0142', gender: 1 },
  { cid: 'TBK77204', name: 'Tyrell Banks', dob: '1998-11-17', phone: '555-0177', gender: 0 },
  { cid: 'OKF8812', name: 'Mina Okafor', dob: '1991-03-09', phone: '555-0109', gender: 1 },
  { cid: 'NVR5530', name: 'Luis Navarro', dob: '1987-07-23', phone: '555-0163', gender: 0 },
  { cid: 'WTL1904', name: 'Jack Whitlow', dob: '1979-01-30', phone: '555-0121', gender: 0 },
  { cid: 'SHA7731', name: 'Priya Shah', dob: '1996-09-14', phone: '555-0188', gender: 1 },
  { cid: 'MRT6620', name: 'Grace Marten', dob: '2000-02-11', phone: '555-0135', gender: 1 },
  { cid: 'PLK3301', name: 'Victor Pollack', dob: '1983-06-05', phone: '555-0156', gender: 0 },
  { cid: 'DSN1178', name: 'Ellis Dawson', dob: '1992-12-01', phone: '555-0194', gender: 0 },
  { cid: 'KMR4456', name: 'Rosa Kimura', dob: '1989-04-27', phone: '555-0117', gender: 1 },
  { cid: 'FRD9902', name: 'Calvin Ford', dob: '1975-08-19', phone: '555-0128', gender: 0 },
  { cid: 'ADL3087', name: 'Ayla Demir', dob: '1999-10-08', phone: '555-0170', gender: 1 },
  { cid: 'HGN5521', name: 'Wes Hagan', dob: '1990-05-15', phone: '555-0103', gender: 0 },
  { cid: 'VLD2043', name: 'Marisol Valdez', dob: '1993-01-22', phone: '555-0149', gender: 1 },
  { cid: 'HRZ88402', name: 'Hector Ruiz', dob: '1968-03-03', phone: '555-0111', gender: 0 },
  { cid: 'LNG8890', name: 'Bobby Lang', dob: '2001-07-07', phone: '555-0199', gender: 0 },
];

export const officers = [
  { cid: 'COP1', name: 'Rae Hale', callsign: '1-ADAM-12', grade: 4, gradeName: 'Chief', online: true, onduty: true },
  { cid: 'COP6', name: 'Owen Brandt', callsign: '2-EDWARD-5', grade: 3, gradeName: 'Lieutenant', online: false },
  { cid: 'COP2', name: 'Marco Ortega', callsign: '1-LINCOLN-4', grade: 2, gradeName: 'Sergeant', online: true, onduty: true },
  { cid: 'COP7', name: 'Nadia Reyes', callsign: '4-TOM-3', grade: 2, gradeName: 'Detective', online: true, onduty: true },
  { cid: 'COP3', name: 'Dee Walsh', callsign: '2-DAVID-7', grade: 1, gradeName: 'Officer', online: true, onduty: true },
  { cid: 'COP4', name: 'Ivan Kerr', callsign: '1-KING-2', grade: 1, gradeName: 'Officer', online: true, onduty: true },
  { cid: 'COP5', name: 'Sara Lind', callsign: '3-MARY-1', grade: 0, gradeName: 'Recruit', online: true, onduty: true },
];

export const vehicles = [
  { plate: '46EEK572', model: 'sultanrs', label: 'Karin Sultan RS · green', owner: 'Dana Cruz', ownerCid: 'DCR40219' },
  { plate: '81KTR093', model: 'buffalo2', label: 'Bravado Buffalo S · black', owner: 'Tyrell Banks', ownerCid: 'TBK77204' },
  { plate: '12LMN440', model: 'pigalle', label: 'Lampadati Pigalle · white', owner: 'Mina Okafor', ownerCid: 'OKF8812' },
  { plate: '66PQX201', model: 'emperor2', label: 'Albany Emperor · rusted', owner: 'Jack Whitlow', ownerCid: 'WTL1904' },
  { plate: '09ZXC118', model: 'sentinel2', label: 'Ubermacht Sentinel XS · grey', owner: 'Luis Navarro', ownerCid: 'NVR5530' },
  { plate: '77BRA555', model: 'kuruma', label: 'Karin Kuruma · silver', owner: 'Victor Pollack', ownerCid: 'PLK3301' },
  { plate: '30HJK862', model: 'faggio', label: 'Pegassi Faggio · mint', owner: 'Grace Marten', ownerCid: 'MRT6620' },
  { plate: '52WRT319', model: 'bison', label: 'Bravado Bison · white', owner: 'Calvin Ford', ownerCid: 'FRD9902' },
  { plate: '20GHL774', model: 'blista', label: 'Dinka Blista · red', owner: 'Ayla Demir', ownerCid: 'ADL3087' },
];

const policePerms = ['reports.create', 'reports.edit_any', 'reports.delete', 'sentencing.apply', 'cases.view', 'cases.manage', 'evidence.manage', 'penal.manage', 'records.view'];

export function mockCan(s, perm) {
  if (s.dept === 'doj') return ['reports.view', 'cases.view', 'records.view'].includes(perm);
  if (s.dept === 'dispatch') return ['reports.view', 'cases.view', 'records.view', 'bolos.manage'].includes(perm);
  if (s.dept !== 'police') return false;
  const list = s.boss ? policePerms : policePerms.filter((p) => !p.includes('manage') && p !== 'reports.delete');
  return list.includes(perm);
}

export function meOf(s) {
  if (s.dept === 'doj') return { cid: 'JUD1', name: 'Harlan Price', callsign: null };
  return officers[0];
}

export function personByCid(cid) {
  return citizens.find((c) => c.cid === cid) || officers.find((o) => o.cid === cid) || null;
}

export default function (reg) {
  reg('people.search', (d) => {
    const q = String(d.q || '').trim().toLowerCase();
    if (q.length < 2) return [];
    return citizens
      .filter((c) => c.name.toLowerCase().includes(q) || c.cid.toLowerCase().includes(q) || c.phone.includes(q))
      .slice(0, Number(d.limit) || 20)
      .map((c) => ({ ...c, job: 'unemployed', jobLabel: 'Civilian' }));
  });
  reg('people.staff', (d, st) => {
    if ((d.dept || st.dept) !== 'police') return [];
    const q = String(d.q || '').trim().toLowerCase();
    return officers
      .filter((o) => !q || o.name.toLowerCase().includes(q) || o.callsign.toLowerCase().includes(q))
      .map((o) => ({ ...o, job: 'police', jobLabel: 'Law Enforcement' }));
  });
  reg('vehicles.search', (d) => {
    const q = String(d.q || '').trim().toLowerCase().replace(/\s+/g, '');
    if (q.length < 2) return [];
    return vehicles.filter((v) => v.plate.toLowerCase().includes(q) || v.label.toLowerCase().replace(/\s+/g, '').includes(q) || v.owner.toLowerCase().replace(/\s+/g, '').includes(q)).slice(0, 10);
  });
}
