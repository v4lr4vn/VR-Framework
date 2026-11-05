<script>
  import { untrack } from 'svelte';
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import PersonSearch from './PersonSearch.svelte';
  import { request, session } from '../../lib/state.svelte.js';

  let { open = $bindable(false), file = null, onsaved } = $props();

  let subject = $state(null);
  let complainant = $state('');
  let summary = $state('');
  let busy = $state(false);

  const editing = $derived(!!file?.id);
  const valid = $derived((editing || !!subject) && summary.trim().length >= 3);

  $effect(() => {
    if (!open) return;
    untrack(() => {
      subject = null;
      complainant = file?.complainant || '';
      summary = file?.summary || '';
      busy = false;
    });
  });

  function blocked(p) {
    return p.cid === session.me?.cid ? "That's you" : null;
  }

  async function submit() {
    if (!valid || busy) return;
    busy = true;
    const data = editing ? { id: file.id, complainant, summary } : { subjectCid: subject.cid, complainant, summary };
    const res = await request('ia.save', data, { success: editing ? 'File updated' : 'File opened' });
    busy = false;
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title={editing ? 'Edit file' : 'Open an Internal Affairs file'} width={600}>
  {#if !editing}
    <Field label="Subject officer" id="ia-subject">
      <PersonSearch id="ia-subject" action="people.staff" extra={{ dept: 'police' }} minLength={0} bind:selected={subject} {blocked} placeholder="Search officers by name or callsign" />
    </Field>
  {:else}
    <p class="subj">Subject: <strong>{file.subjectName}</strong></p>
  {/if}
  <Field label="Complainant" id="ia-comp" hint="Who raised it. Leave empty for internal referrals.">
    <Input id="ia-comp" bind:value={complainant} maxlength={400} placeholder="Dana Cruz, citizen · or Anonymous" />
  </Field>
  <Field label="Allegation" id="ia-sum">
    <Textarea id="ia-sum" bind:value={summary} rows={6} maxlength={8000} placeholder="What happened, when and where, and what policy may have been broken" />
  </Field>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon={editing ? 'check' : 'folder'} busy={busy} disabled={!valid} onclick={submit}>{editing ? 'Save changes' : 'Open file'}</Button>
  {/snippet}
</Modal>

<style>
  .subj { color: var(--muted); }
  .subj strong { color: var(--text); }
</style>
