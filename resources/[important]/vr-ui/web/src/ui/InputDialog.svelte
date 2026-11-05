<script>
  import { onMount, tick } from 'svelte';
  import { on } from '../lib/bus.js';
  import { post } from '../lib/nui.js';
  import { toDate, fmtDate } from '../lib/date.js';
  import Modal from './Modal.svelte';
  import Button from './Button.svelte';
  import Field from './fields/Field.svelte';
  import TextField from './fields/TextField.svelte';
  import NumberField from './fields/NumberField.svelte';
  import CheckField from './fields/CheckField.svelte';
  import SelectField from './fields/SelectField.svelte';
  import SliderField from './fields/SliderField.svelte';
  import ColorField from './fields/ColorField.svelte';
  import DateField from './fields/DateField.svelte';
  import TimeField from './fields/TimeField.svelte';
  import TextareaField from './fields/TextareaField.svelte';

  let dialog = $state(null);
  let values = $state([]);
  let errors = $state([]);
  let run = $state(0);
  let bodyEl = $state();

  const normal = (row) => (typeof row === 'string' ? { type: 'input', label: row } : { type: 'input', ...row });

  const initial = (r) => {
    switch (r.type) {
      case 'number': return typeof r.default === 'number' ? r.default : r.default !== undefined && r.default !== null && r.default !== '' && !isNaN(Number(r.default)) ? Number(r.default) : null;
      case 'checkbox': return !!r.checked;
      case 'select': return r.default ?? null;
      case 'multi-select': return Array.isArray(r.default) ? [...r.default] : [];
      case 'slider': return typeof r.default === 'number' ? r.default : typeof r.min === 'number' ? r.min : 0;
      case 'color': return typeof r.default === 'string' ? r.default : '';
      case 'date': { const d = toDate(r.default); return d ? d.getTime() : null; }
      case 'date-range': return Array.isArray(r.default) ? r.default.slice(0, 2).map((x) => toDate(x)?.getTime() ?? null) : [null, null];
      case 'time': {
        if (typeof r.default === 'string' && /^\d{1,2}:\d{2}/.test(r.default)) { const [h, m] = r.default.split(':').map(Number); const d = new Date(); d.setHours(h, m, 0, 0); return d.getTime(); }
        const d = toDate(r.default); return d ? d.getTime() : null;
      }
      default: return r.default !== undefined && r.default !== null ? String(r.default) : '';
    }
  };

  const empty = (r, v) => {
    switch (r.type) {
      case 'checkbox': return !v;
      case 'multi-select': return !v || !v.length;
      case 'date-range': return !v || !v[0] || !v[1];
      case 'number': case 'select': case 'date': case 'time': return v === null || v === undefined || v === '';
      case 'slider': return false;
      default: return !String(v ?? '').trim();
    }
  };

  const validate = () => {
    const errs = dialog.rows.map((r, i) => {
      const v = values[i];
      if (r.required && empty(r, v)) return 'Required';
      if ((r.type === 'input' || r.type === 'textarea') && v) {
        if (r.type === 'input' && typeof r.min === 'number' && String(v).length < r.min) return `At least ${r.min} characters`;
        if (r.type === 'input' && typeof r.max === 'number' && String(v).length > r.max) return `At most ${r.max} characters`;
      }
      if (r.type === 'number' && v !== null && v !== undefined) {
        if (typeof r.min === 'number' && v < r.min) return `Minimum ${r.min}`;
        if (typeof r.max === 'number' && v > r.max) return `Maximum ${r.max}`;
      }
      if (r.type === 'multi-select' && r.maxSelectedValues && v && v.length > r.maxSelectedValues) return `Pick at most ${r.maxSelectedValues}`;
      return '';
    });
    errors = errs;
    return errs.every((e) => !e);
  };

  const output = () =>
    dialog.rows.map((r, i) => {
      const v = values[i];
      if (r.type === 'date') return v === null ? null : r.returnString ? fmtDate(new Date(v), r.format || 'DD/MM/YYYY') : v;
      if (r.type === 'date-range') return !v || !v[0] ? null : v.map((x) => (x === null ? null : r.returnString ? fmtDate(new Date(x), r.format || 'DD/MM/YYYY') : x));
      if (r.type === 'time') return v === null ? null : v;
      if (r.type === 'number' && v !== null && typeof r.precision === 'number') return Number(v.toFixed(r.precision));
      if (r.type === 'multi-select') return v && v.length ? v : null;
      return v;
    });

  const submit = () => {
    if (!dialog) return;
    if (!validate()) return;
    post('input:submit', { id: dialog.id, values: output() });
  };

  const cancel = () => {
    if (!dialog || dialog.options?.allowCancel === false) return;
    post('input:cancel', { id: dialog.id });
  };

  const onKey = (e) => {
    if (e.defaultPrevented) return;
    if (!dialog) return;
    if (e.key === 'Escape') cancel();
  };

  onMount(() => {
    const a = on('input:open', async (d) => {
      const rows = (d?.rows || []).map(normal);
      dialog = { id: d?.id, heading: d?.heading || '', rows, options: d?.options || {} };
      values = rows.map(initial);
      errors = rows.map(() => '');
      run += 1;
      await tick();
      bodyEl?.querySelector('input:not([disabled]), textarea:not([disabled]), [tabindex="0"]')?.focus();
    });
    const b = on('input:close', () => (dialog = null));
    window.addEventListener('keydown', onKey);
    return () => (a(), b(), window.removeEventListener('keydown', onKey));
  });
</script>

{#if dialog}
  {#key run}
    <Modal title={dialog.heading} size={dialog.options.size || 'sm'} closable={dialog.options.allowCancel !== false} onclose={cancel}>
      <div class="rows" bind:this={bodyEl}>
        {#each dialog.rows as row, i}
          {#if row.type === 'checkbox'}
            <Field description={row.description} error={errors[i]} inline>
              <CheckField bind:value={values[i]} {row} error={errors[i]} />
            </Field>
          {:else}
            <Field label={row.label} description={row.description} required={row.required} error={errors[i]}>
              {#if row.type === 'number'}
                <NumberField bind:value={values[i]} {row} error={errors[i]} onenter={submit} />
              {:else if row.type === 'select'}
                <SelectField bind:value={values[i]} {row} error={errors[i]} />
              {:else if row.type === 'multi-select'}
                <SelectField bind:value={values[i]} {row} error={errors[i]} multi />
              {:else if row.type === 'slider'}
                <SliderField bind:value={values[i]} {row} error={errors[i]} />
              {:else if row.type === 'color'}
                <ColorField bind:value={values[i]} {row} error={errors[i]} />
              {:else if row.type === 'date'}
                <DateField bind:value={values[i]} {row} error={errors[i]} />
              {:else if row.type === 'date-range'}
                <DateField bind:value={values[i]} {row} error={errors[i]} range />
              {:else if row.type === 'time'}
                <TimeField bind:value={values[i]} {row} error={errors[i]} />
              {:else if row.type === 'textarea'}
                <TextareaField bind:value={values[i]} {row} error={errors[i]} />
              {:else}
                <TextField bind:value={values[i]} {row} error={errors[i]} onenter={submit} />
              {/if}
            </Field>
          {/if}
        {/each}
      </div>
      {#snippet footer()}
        {#if dialog.options.allowCancel !== false}<Button kind="ghost" onclick={cancel}>Cancel</Button>{/if}
        <Button kind="primary" onclick={submit}>Confirm</Button>
      {/snippet}
    </Modal>
  {/key}
{/if}

<style>
  .rows { display: flex; flex-direction: column; gap: 14px; }
</style>
