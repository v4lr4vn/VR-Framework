<script>
  let { value = $bindable(''), row, error = '' } = $props();
  const minRows = $derived(Math.max(1, Number(row.min) || 3));
  const maxRows = $derived(Math.max(minRows, Number(row.max) || (row.autosize ? 8 : minRows)));
  let el = $state();
  const size = () => {
    if (!el || !row.autosize) return;
    el.style.height = 'auto';
    const line = 21;
    const h = Math.min(Math.max(el.scrollHeight, minRows * line + 20), maxRows * line + 20);
    el.style.height = `${h}px`;
  };
  $effect(() => {
    value;
    size();
  });
</script>

<textarea
  bind:this={el}
  bind:value
  class="ta scroll"
  class:bad={error}
  rows={minRows}
  placeholder={row.placeholder || ''}
  disabled={row.disabled}
  spellcheck="false"
></textarea>

<style>
  .ta { width: 100%; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text); outline: none; resize: none; line-height: 21px; }
  .ta::placeholder { color: var(--faint); }
  .ta:focus { border-color: var(--accent); }
  .ta.bad { border-color: var(--danger); }
  .ta:disabled { opacity: 0.55; }
</style>
