const state = {
  current: 'taxi',
  onduty: true,
  jobs: {
    police: { label: 'Law Enforcement', gradeLabel: 'Officer', salary: 90, whitelist: true, canDuty: false, icon: 'fa-solid fa-handcuffs', description: 'Shoot some criminals or maybe be a good cop and arrest them', active: 6 },
    taxi: { label: 'Taxi', gradeLabel: 'Senior Driver', salary: 80, whitelist: false, canDuty: true, icon: 'fa-solid fa-taxi', description: 'Pickup people around the city and drive them to their destination', active: 2 },
    garbage: { label: 'Sanitation', gradeLabel: 'Collector', salary: 45, whitelist: false, canDuty: true, icon: 'fa-solid fa-trash-can', description: 'Drive a garbage truck', active: 0 },
  },
};

export function mockPayload() {
  const list = Object.entries(state.jobs)
    .map(([name, j]) => ({
      name,
      ...j,
      grade: 0,
      current: state.current === name,
      onduty: state.current === name ? state.onduty : false,
    }))
    .sort((a, b) => (a.whitelist === b.whitelist ? a.label.localeCompare(b.label) : a.whitelist ? -1 : 1));
  return {
    jobs: list,
    current: { name: state.current, label: state.jobs[state.current]?.label || 'Civilian', onduty: state.onduty, listed: !!state.jobs[state.current] },
    max: 3,
    canLeave: true,
    fallback: 'unemployed',
    hint: 'Look for new work at the City Hall Job Centre.',
  };
}

const ok = (data) => ({ ok: true, data });
const fail = (error) => ({ ok: false, error });

export function mockCall(action, data) {
  if (action === 'list') return ok(mockPayload());
  if (action === 'select') {
    if (data.job === 'unemployed') {
      if (state.current === 'unemployed') return fail('already');
      state.current = 'unemployed';
      return ok({ job: 'unemployed', label: 'Civilian' });
    }
    const j = state.jobs[data.job];
    if (!j) return fail('not_held');
    if (state.current === data.job) return fail('already');
    state.current = data.job;
    state.onduty = data.job !== 'police';
    return ok({ job: data.job, label: j.label });
  }
  if (action === 'leave') {
    const j = state.jobs[data.job];
    if (!j) return fail('not_held');
    delete state.jobs[data.job];
    if (state.current === data.job) {
      state.current = Object.keys(state.jobs)[0] || 'unemployed';
    }
    return ok({ job: data.job, label: j.label });
  }
  if (action === 'duty') {
    const j = state.jobs[state.current];
    if (!j) return fail('no_duty');
    if (!j.canDuty) return fail('deny_duty');
    state.onduty = !state.onduty;
    return ok({ onduty: state.onduty });
  }
  return fail('bad_request');
}
