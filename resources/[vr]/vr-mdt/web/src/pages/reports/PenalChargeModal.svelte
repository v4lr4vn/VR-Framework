<script>
  import { untrack } from 'svelte';
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Select from '../../components/Select.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Checkbox from '../../components/Checkbox.svelte';
  import { request } from '../../lib/state.svelte.js';
  import { classes } from './util.js';
  import { dateTime } from '../../lib/format.js';

  let { open = $bindable(false), charge = null, categories = [], categoryId = null, onsaved } = $props();

  let form = $state({ category: '', title: '', class: 'misdemeanor', fine: '0', months: '0', points: '0', description: '', active: true });
  let busy = $state(false);
  let touched = $state(false);

  function reset() {
    touched = false;
    form = charge
      ? { category: String(charge.categoryId), title: charge.title, class: charge.class, fine: String(charge.fine), months: String(charge.months), points: String(charge.points), description: charge.description || '', active: charge.active !== false }
      : { category: String(categoryId || categories[0]?.id || ''), title: '', class: 'misdemeanor', fine: '', months: '0', points: '0', description: '', active: true };
  }

  $effect(() => {
    if (open) untrack(reset);
  });

  const whole = (v, max) => /^\d+$/.test(String(v).trim()) && Number(v) <= max;
  const infraction = $derived(form.class === 'infraction');
  const errors = $derived({
    title: form.title.trim().length < 3 ? 'At least 3 characters.' : '',
    fine: whole(form.fine, 1000000) ? '' : 'Whole dollars, up to 1,000,000.',
    months: infraction ? '' : whole(form.months, 300) ? '' : 'Whole months, up to 300.',
    points: whole(form.points, 20) ? '' : '0 to 20.',
    category: form.category ? '' : 'Pick a category.',
  });
  const valid = $derived(!Object.values(errors).some(Boolean));

  async function save(e) {
    e?.preventDefault();
    touched = true;
    if (!valid || busy) return;
    busy = true;
    const res = await request('penal.chargeSave', {
      id: charge?.id,
      category: Number(form.category),
      title: form.title.trim(),
      class: form.class,
      fine: Number(form.fine),
      months: infraction ? 0 : Number(form.months),
      points: Number(form.points),
      description: form.description.trim(),
      active: form.active,
    }, { success: charge ? 'Charge updated' : 'Charge added' });
    busy = false;
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title={charge ? `Edit charge` : 'New charge'} width={600}>
  <form class="form" onsubmit={save}>
    <Field label="Title" id="ch-title" error={touched ? errors.title : ''}>
      <Input id="ch-title" bind:value={form.title} maxlength={96} placeholder="Grand theft auto" autofocus={!charge} />
    </Field>
    <div class="two">
      <Field label="Category" id="ch-cat" error={touched ? errors.category : ''}>
        <Select id="ch-cat" bind:value={form.category} options={categories.map((c) => ({ value: String(c.id), label: c.name }))} />
      </Field>
      <Field label="Class" id="ch-class">
        <Select id="ch-class" bind:value={form.class} options={classes} />
      </Field>
    </div>
    <div class="three">
      <Field label="Fine ($)" id="ch-fine" error={touched ? errors.fine : ''}>
        <Input id="ch-fine" bind:value={form.fine} maxlength={7} inputmode="numeric" placeholder="0" mono />
      </Field>
      <Field label="Jail (months)" id="ch-months" error={touched ? errors.months : ''} hint={infraction ? 'Infractions carry no jail time.' : ''}>
        <Input id="ch-months" value={infraction ? '0' : form.months} oninput={(e) => (form.months = e.currentTarget.value)} maxlength={3} inputmode="numeric" disabled={infraction} mono />
      </Field>
      <Field label="Licence points" id="ch-points" error={touched ? errors.points : ''}>
        <Input id="ch-points" bind:value={form.points} maxlength={2} inputmode="numeric" mono />
      </Field>
    </div>
    <Field label="Description" id="ch-desc" hint="Shown to officers when they pick the charge.">
      <Textarea id="ch-desc" bind:value={form.description} rows={3} maxlength={1000} placeholder="What the offence covers, in one or two sentences." />
    </Field>
    {#if charge}
      <div class="foot">
        <Checkbox id="ch-active" bind:checked={form.active} label="Active: officers can add this charge to reports" />
        <span class="faint small">Last changed {dateTime(charge.updatedAt)}{charge.updatedBy ? ` by ${charge.updatedBy}` : ''}</span>
      </div>
    {/if}
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon="save" busy={busy} onclick={save}>{charge ? 'Save charge' : 'Add charge'}</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .two { display: grid; grid-template-columns: repeat(2, minmax(0, 1fr)); gap: 12px; }
  .three { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 12px; }
  .foot { display: flex; flex-direction: column; gap: 6px; }
  .small { font-size: 12px; }
</style>
