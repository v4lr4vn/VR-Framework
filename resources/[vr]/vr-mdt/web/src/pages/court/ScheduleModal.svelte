<script>
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Select from '../../components/Select.svelte';
  import { request } from '../../lib/state.svelte.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { toInputs, fromInputs, hearingParts } from './meta.js';

  let { open = $bindable(false), kase, courtrooms = [], onsaved } = $props();

  let date = $state('');
  let time = $state('');
  let room = $state('');
  let busy = $state('');
  let wasOpen = false;

  $effect(() => {
    if (open && !wasOpen) {
      const v = toInputs(kase?.hearingAt);
      date = v.date;
      time = v.time;
      room = kase?.courtroom || courtrooms[0] || '';
    }
    wasOpen = open;
  });

  const at = $derived(fromInputs(date, time));
  const past = $derived(at != null && at < Math.floor(Date.now() / 1000) - 300);
  const preview = $derived(at && !past ? hearingParts(at) : null);
  const rooms = $derived(courtrooms.map((r) => ({ value: r, label: r })));

  async function save(e) {
    e?.preventDefault();
    if (!at || past || !room || busy) return;
    busy = 'save';
    const res = await request('court.schedule', { id: kase.id, hearingAt: at, courtroom: room }, { success: 'Hearing scheduled' });
    busy = '';
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }

  async function cancelHearing() {
    const ok = await confirm({ title: 'Cancel the hearing?', text: `The hearing for ${kase.number} will be removed and the case goes back to filed.`, yes: 'Cancel hearing', no: 'Keep it', danger: true });
    if (!ok) return;
    busy = 'clear';
    const res = await request('court.schedule', { id: kase.id, clear: true }, { success: 'Hearing cancelled' });
    busy = '';
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title={kase?.hearingAt ? 'Reschedule hearing' : 'Schedule a hearing'} width={480}>
  <form class="form" onsubmit={save}>
    <div class="two">
      <Field label="Date" id="sc-date" error={past ? 'That time has already passed.' : ''}><input id="sc-date" class="dt mono" type="date" bind:value={date} /></Field>
      <Field label="Time" id="sc-time"><input id="sc-time" class="dt mono" type="time" bind:value={time} step="300" /></Field>
    </div>
    <Field label="Courtroom" id="sc-room"><Select id="sc-room" bind:value={room} options={rooms} /></Field>
    {#if preview}
      <div class="preview">
        <span class="day mono">{preview.day}</span>
        <span class="when"><b>{preview.date}</b>{' · '}<span class="mono">{preview.time}</span>{#if preview.rel}{' · '}{preview.rel}{/if}</span>
        <span class="room">{room}</span>
      </div>
    {/if}
  </form>
  {#snippet footer()}
    {#if kase?.hearingAt}
      <Button variant="danger" icon="x" busy={busy === 'clear'} onclick={cancelHearing}>Cancel hearing</Button>
      <span class="grow"></span>
    {/if}
    <Button variant="ghost" onclick={() => (open = false)}>Close</Button>
    <Button variant="primary" icon="calendar" busy={busy === 'save'} disabled={!at || past || !room} onclick={save}>Save hearing</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .two { display: grid; grid-template-columns: 1.3fr 1fr; gap: 12px; }
  .dt { height: 36px; width: 100%; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text); outline: none; color-scheme: dark; }
  .dt:focus { border-color: var(--accent); }
  .preview { display: flex; align-items: center; gap: 12px; padding: 10px 12px; border-radius: var(--radius); background: var(--info-bg); border: 1px solid var(--info-line); color: var(--info-text); }
  .day { font-weight: 600; font-size: 12px; padding: 2px 6px; border-radius: 4px; background: var(--info); color: var(--accent-ink); }
  .when { color: var(--text); }
  .room { margin-left: auto; color: var(--info-text); font-size: 13px; }
  .grow { flex: 1; }
</style>
