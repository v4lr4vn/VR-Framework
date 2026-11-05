export const citizens = [
  { cid: 'DCR40219', name: 'Dana Cruz', dob: '1994-05-02', gender: 1, phone: '555-0142', nationality: 'American', jobLabel: 'Taxi driver', bloodtype: 'O+' },
  { cid: 'RTL20917', name: 'Milo Grant', dob: '1988-11-20', gender: 0, phone: '555-0177', nationality: 'American', jobLabel: 'Mechanic', bloodtype: 'AB-' },
  { cid: 'PQA77310', name: 'Lena Varga', dob: '1999-02-14', gender: 1, phone: '555-0110', nationality: 'Hungarian', jobLabel: 'Bartender', bloodtype: 'A+' },
  { cid: 'BCE10442', name: 'Marcus Bell', dob: '1982-07-30', gender: 0, phone: '555-0163', nationality: 'American', jobLabel: 'Unemployed', bloodtype: 'B+' },
  { cid: 'JHO55128', name: 'Jade Okoro', dob: '2001-09-09', gender: 1, phone: '555-0128', nationality: 'Nigerian', jobLabel: 'Courier', bloodtype: 'O-' },
  { cid: 'VHL33019', name: 'Victor Hale', dob: '1975-03-18', gender: 0, phone: '555-0191', nationality: 'American', jobLabel: 'Real estate', bloodtype: 'A-' },
  { cid: 'RDL61840', name: 'Rosa Delgado', dob: '1991-12-01', gender: 1, phone: '555-0136', nationality: 'Mexican', jobLabel: 'Nurse', bloodtype: 'O+' },
  { cid: 'TMK90215', name: 'Tyrone Mack', dob: '1996-06-22', gender: 0, phone: '555-0104', nationality: 'American', jobLabel: 'Tow driver', bloodtype: 'B-' },
  { cid: 'EFN47731', name: 'Elise Fontaine', dob: '1987-01-27', gender: 1, phone: '555-0158', nationality: 'French', jobLabel: 'Gallery owner', bloodtype: 'A+' },
  { cid: 'KMR12094', name: 'Kenji Mori', dob: '1993-10-05', gender: 0, phone: '555-0183', nationality: 'Japanese', jobLabel: 'Chef', bloodtype: 'AB+' },
  { cid: 'HRZ88402', name: 'Hector Ruiz', dob: '1979-04-11', gender: 0, phone: '555-0121', nationality: 'American', jobLabel: 'Trucker', bloodtype: 'O+' },
  { cid: 'NPT30586', name: 'Nina Petrova', dob: '1998-08-19', gender: 1, phone: '555-0149', nationality: 'Russian', jobLabel: 'Student', bloodtype: 'B+' },
  { cid: 'CSH71163', name: 'Callum Shaw', dob: '1985-05-23', gender: 0, phone: '555-0172', nationality: 'British', jobLabel: 'Security guard', bloodtype: 'A-' },
];

export const staff = [
  { cid: 'JUD1', name: 'Harlan Price', job: 'judge', jobLabel: 'Judiciary', grade: 2, gradeName: 'Chief Justice', online: true, onduty: true },
  { cid: 'JUD3', name: 'Omar Reyes', job: 'judge', jobLabel: 'Judiciary', grade: 1, gradeName: 'Judge', online: true, onduty: true },
  { cid: 'JUD4', name: 'Mira Stone', job: 'judge', jobLabel: 'Judiciary', grade: 0, gradeName: 'Magistrate' },
  { cid: 'DA1', name: 'Colin Ward', job: 'prosecutor', jobLabel: "District Attorney's Office", grade: 2, gradeName: 'District Attorney', online: true, onduty: true },
  { cid: 'DA2', name: 'Priya Natarajan', job: 'prosecutor', jobLabel: "District Attorney's Office", grade: 1, gradeName: 'Deputy DA' },
  { cid: 'DA3', name: 'Jonah Pike', job: 'prosecutor', jobLabel: "District Attorney's Office", grade: 0, gradeName: 'Assistant DA', online: true, onduty: true },
  { cid: 'LAW1', name: 'Saul Becker', job: 'lawyer', jobLabel: 'Defense Attorney', grade: 2, gradeName: 'Senior Partner', online: true, onduty: true },
  { cid: 'LAW2', name: 'Grace Abbott', job: 'lawyer', jobLabel: 'Defense Attorney', grade: 1, gradeName: 'Attorney' },
  { cid: 'LAW3', name: 'Theo Marsh', job: 'lawyer', jobLabel: 'Defense Attorney', grade: 1, gradeName: 'Attorney', online: true, onduty: true },
  { cid: 'LAW4', name: 'Petra Lind', job: 'lawyer', jobLabel: 'Defense Attorney', grade: 0, gradeName: 'Associate' },
];

export function personByCid(cid) {
  return citizens.find((p) => p.cid === cid) || staff.find((p) => p.cid === cid) || null;
}

export default function (reg) {
  reg('people.search', (d) => {
    const q = String(d.q || '').trim().toLowerCase();
    if (q.length < 2) return [];
    return citizens
      .filter((p) => p.name.toLowerCase().includes(q) || p.cid.toLowerCase().includes(q) || p.phone.includes(q))
      .slice(0, 20)
      .map(({ cid, name, dob, gender, phone, jobLabel }) => ({ cid, name, dob, gender, phone, jobLabel }));
  });
  reg('people.staff', (d, st) => {
    if ((d.dept || st.dept) !== 'doj') return [];
    const q = String(d.q || '').trim().toLowerCase();
    return staff.filter((p) => !q || p.name.toLowerCase().includes(q));
  });
}
