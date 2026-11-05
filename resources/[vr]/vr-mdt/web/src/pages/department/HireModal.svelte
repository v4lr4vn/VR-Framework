<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Select from '../../components/Select.svelte';
  import PersonSearch from './PersonSearch.svelte';
  import { request, session } from '../../lib/state.svelte.js';

  let { open = $bindable(false), meta, onhired } = $props();

  let person = $state(null);
  let job = $state('');
  let grade = $state(0);
  let busy = $state(false);

  const hireJobs = $derived((meta?.jobs || []).filter((j) => j.hire !== false));
  const jobOptions = $derived(hireJobs.map((j) => ({ value: j.name, label: j.label })));
  const grades = $derived.by(() => {
    const j = meta?.jobs?.find((x) => x.name === job);
    const me = session.me || {};
    return (j?.grades || []).filter((g) => me.isboss || g.level < me.grade);
  });
  const gradeOptions = $derived(grades.map((g) => ({ value: g.level, label: `${g.level} · ${g.name}` })));
  const deptType = $derived(session.dept?.type);

  $effect(() => {
    if (open) {
      person = null;
      job = hireJobs[0]?.name || '';
      busy = false;
    }
  });

  $effect(() => {
    if (!grades.some((g) => g.level === Number(grade))) grade = grades[0]?.level ?? 0;
  });

  function blocked(p) {
    if (p.jobType === deptType) return 'Already in the department';
    return null;
  }

  async function hire() {
    if (!person || !job || busy) return;
    busy = true;
    const g = grades.find((x) => x.level === Number(grade));
    const res = await request('roster.hire', { cid: person.cid, job, grade: Number(grade) }, { success: `${person.name} hired as ${g?.name || 'member'}` });
    busy = false;
    if (res.ok) {
      open = false;
      onhired?.(res.data);
    }
  }
</script>

<Modal bind:open title="Hire a new member" width={560}>
  <Field label="Citizen" id="hire-search">
    <PersonSearch id="hire-search" bind:selected={person} {blocked} autofocus placeholder="Search by name, citizen ID or phone" />
  </Field>
  <div class="two">
    <Field label="Job" id="hire-job"><Select id="hire-job" bind:value={job} options={jobOptions} disabled={jobOptions.length < 2} /></Field>
    <Field label="Starting rank" id="hire-grade" hint={session.me?.isboss ? '' : 'Only ranks below your own.'}>
      <Select id="hire-grade" bind:value={grade} options={gradeOptions} disabled={!gradeOptions.length} />
    </Field>
  </div>
  {#if person}
    <p class="sum">
      <strong>{person.name}</strong> joins the {session.dept?.short} as <strong>{grades.find((g) => g.level === Number(grade))?.name || '—'}</strong>{#if meta?.hireDivisions?.length}{' '}in {meta.hireDivisions.join(', ')}{/if}. Their current job ({person.jobLabel || 'Unemployed'}) is replaced.
    </p>
  {/if}
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="userplus" busy={busy} disabled={!person || !gradeOptions.length} onclick={hire}>Hire</Button>
  {/snippet}
</Modal>

<style>
  .two { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .sum { color: var(--text-2); line-height: 1.5; padding: 10px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .sum strong { color: var(--text); }
</style>
