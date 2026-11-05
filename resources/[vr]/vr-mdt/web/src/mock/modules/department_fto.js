import { fail } from '../index.js';
import { push } from '../state.js';
import { now, members, me, log } from './department_data.js';

const categories = ['Driving', 'Officer safety', 'Report writing', 'Radio', 'Knowledge of law', 'Conduct'];
const D = 86400;

const notes = [
  'Rode along on a felony stop on Grove St. Good cover position, called it in clearly.',
  'Report on the store robbery was missing the suspect description. Went over it together.',
  'Radio traffic too long, keep it short. Very good with the public at the crash scene.',
  'Drove too fast to a code 2 call. Talked about risk vs reward. Otherwise solid shift.',
  'Knew the penal code for every charge we wrote today. Confident on the stop.',
  'Handled a mental health call calmly and got the subject to EMS without force.',
];

let nextId = 1;

function ev(trainee, fto, daysAgo, phase, values, rec, note) {
  const ratings = categories.map((category, i) => ({ category, value: values[i] }));
  const score = Math.round((values.reduce((a, b) => a + b, 0) / values.length) * 100) / 100;
  return { id: nextId++, traineeCid: trainee, ftoName: fto, at: now() - daysAgo * D - 3600 * (phase + 2), phase, ratings, score, notes: note, recommendation: rec };
}

const evals = {
  COP5: [
    ev('COP5', 'Rosa Diaz', 18, 1, [3, 2, 3, 2, 3, 4], 'continue', notes[1]),
    ev('COP5', 'Nadia Brooks', 13, 1, [3, 3, 3, 3, 3, 4], 'continue', notes[3]),
    ev('COP5', 'Rosa Diaz', 8, 2, [4, 3, 3, 3, 4, 4], 'continue', notes[2]),
    ev('COP5', 'Rosa Diaz', 3, 2, [4, 4, 4, 3, 4, 5], 'continue', notes[0]),
    ev('COP5', 'Owen Marsh', 1, 3, [4, 4, 5, 4, 4, 5], 'signoff', notes[4]),
  ],
  COP9: [
    ev('COP9', 'Nadia Brooks', 10, 1, [2, 3, 2, 3, 2, 3], 'continue', notes[3]),
    ev('COP9', 'Rosa Diaz', 4, 1, [2, 2, 3, 3, 2, 3], 'extend', 'Struggling with report structure and law knowledge. Extending phase 1 by a week.'),
  ],
  COP10: [ev('COP10', 'Rosa Diaz', 2, 1, [4, 3, 3, 4, 3, 4], 'continue', notes[5])],
  COP16: [],
  MED7: [ev('MED7', 'Owen Price', 5, 1, [4, 4, 3, 4, 3, 5], 'continue', 'Good patient handling. Needs to speed up the handover report.')],
  MED9: [],
};

function trainees(s) {
  return members[s.dept].filter((m) => m.divisions.includes('Trainee'));
}

function summary(m) {
  const list = evals[m.cid] || [];
  const last = list[list.length - 1];
  const avg = list.length ? Math.round((list.reduce((a, e) => a + e.score, 0) / list.length) * 100) / 100 : undefined;
  return {
    cid: m.cid, name: m.name, callsign: m.callsign, gradeName: m.gradeName, grade: m.grade, hiredAt: m.hiredAt, online: m.online, onduty: m.onduty, status: m.status,
    phase: last ? last.phase : 1, evals: list.length, average: avg,
    last: last ? { id: last.id, at: last.at, phase: last.phase, recommendation: last.recommendation, ftoName: last.ftoName, score: last.score } : undefined,
  };
}

export default function (reg, regCallback, s) {
  reg('fto.list', () => {
    if (s.dept !== 'police') return fail('not_allowed');
    return { trainees: trainees(s).map(summary).sort((a, b) => b.hiredAt - a.hiredAt), categories, phases: 4, division: 'Trainee' };
  });

  reg('fto.get', (d) => {
    const m = members[s.dept].find((x) => x.cid === d.cid);
    if (!m) return fail('not_found');
    const list = [...(evals[m.cid] || [])].reverse();
    const averages = categories.map((category, i) => {
      const vals = list.map((e) => e.ratings[i].value).filter((v) => v != null);
      return { category, value: vals.length ? Math.round((vals.reduce((a, b) => a + b, 0) / vals.length) * 100) / 100 : undefined };
    });
    return {
      trainee: { cid: m.cid, name: m.name, callsign: m.callsign, gradeName: m.gradeName, divisions: m.divisions, hiredAt: m.hiredAt, online: m.online, onduty: m.onduty, isTrainee: m.divisions.includes('Trainee'), isSelf: m.cid === me(s).cid },
      evals: list,
      averages,
      average: list.length ? Math.round((list.reduce((a, e) => a + e.score, 0) / list.length) * 100) / 100 : undefined,
      phase: list[0]?.phase || 1,
      categories,
      phases: 4,
    };
  });

  reg('fto.evaluate', (d) => {
    if (!s.boss) return fail('not_allowed');
    const m = members[s.dept].find((x) => x.cid === d.cid);
    if (!m) return fail('not_found');
    if (!m.divisions.includes('Trainee')) return fail('not_trainee');
    const values = categories.map((c) => Number(d.ratings?.[c]));
    if (values.some((v) => !(v >= 1 && v <= 5))) return fail('bad_request');
    const e = ev(m.cid, me(s).name, 0, Number(d.phase) || 1, values, d.recommendation, String(d.notes || '').trim() || undefined);
    e.at = now();
    (evals[m.cid] = evals[m.cid] || []).push(e);
    log(s, 'fto.evaluate', m.cid, { name: m.name, phase: e.phase, score: e.score, recommendation: e.recommendation });
    push('fto:changed', { cid: m.cid });
    return e;
  });

  reg('fto.signoff', (d) => {
    if (!s.boss) return fail('not_allowed');
    const m = members[s.dept].find((x) => x.cid === d.cid);
    if (!m) return fail('not_found');
    if (!m.divisions.includes('Trainee')) return fail('not_trainee');
    const from = [...m.divisions];
    m.divisions = m.divisions.filter((x) => x !== 'Trainee');
    if (!m.divisions.includes('Patrol')) m.divisions.unshift('Patrol');
    log(s, 'fto.signoff', m.cid, { name: m.name, from, to: m.divisions });
    push('fto:changed', { cid: m.cid });
    push('roster:changed', { cid: m.cid });
    return { cid: m.cid, divisions: m.divisions };
  });
}
