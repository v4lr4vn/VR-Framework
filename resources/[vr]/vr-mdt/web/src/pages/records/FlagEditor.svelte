<script>
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import Checkbox from '../../components/Checkbox.svelte';
  import { flagTone } from './shared.js';

  let { flags = [], options = [], editable = false, onsave, idPrefix = 'flag', empty = 'No flags' } = $props();

  let editing = $state(false);
  let picked = $state({});
  let busy = $state(false);

  const extra = $derived(flags.filter((f) => !options.includes(f)));

  function start() {
    const next = {};
    for (const o of options) next[o] = flags.includes(o);
    picked = next;
    editing = true;
  }

  async function save() {
    busy = true;
    const list = options.filter((o) => picked[o]);
    const ok = await onsave?.(list);
    busy = false;
    if (ok !== false) editing = false;
  }
</script>

<div class="flags">
  {#if editing}
    <div class="opts">
      {#each options as o, i}
        <Checkbox id="{idPrefix}-{i}" bind:checked={picked[o]} label={o} />
      {/each}
    </div>
    {#if extra.length}
      <p class="faint note">Retired flags will be removed: {extra.join(', ')}</p>
    {/if}
    <div class="row">
      <Button size="sm" variant="ghost" onclick={() => (editing = false)} disabled={busy}>Cancel</Button>
      <Button size="sm" variant="primary" icon="check" {busy} onclick={save}>Save flags</Button>
    </div>
  {:else}
    <div class="chips">
      {#each flags as f}
        <Badge tone={flagTone(f)}>{f}</Badge>
      {:else}
        <span class="faint">{empty}</span>
      {/each}
    </div>
    {#if editable}
      <Button size="sm" variant="ghost" icon="edit" onclick={start}>Edit flags</Button>
    {/if}
  {/if}
</div>

<style>
  .flags { display: flex; flex-direction: column; gap: 10px; align-items: flex-start; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .opts { display: grid; grid-template-columns: 1fr; gap: 2px; width: 100%; }
  .row { display: flex; gap: 8px; align-self: flex-end; }
  .note { font-size: 12px; }
</style>
