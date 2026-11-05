<script>
  let { value = $bindable(), id, options = [], disabled = false, onchange, ...rest } = $props();
</script>

<select {id} class="sel" bind:value {disabled} {onchange} {...rest}>
  {#each options as o}
    <option value={o.value}>{o.label}</option>
  {/each}
</select>

<style>
  .sel { height: 36px; width: 100%; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text); outline: none; }
  .sel:focus { border-color: var(--accent); }
  option { background: var(--panel); color: var(--text); }
</style>
