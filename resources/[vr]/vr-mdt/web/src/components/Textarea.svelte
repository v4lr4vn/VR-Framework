<script>
  let { value = $bindable(''), id, placeholder = '', rows = 4, maxlength, disabled = false, ...rest } = $props();
</script>

<textarea {id} class="ta scroll" bind:value {placeholder} {rows} {maxlength} {disabled} spellcheck="false" {...rest}></textarea>

<style>
  .ta { width: 100%; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text); outline: none; resize: vertical; line-height: 1.5; min-height: 72px; }
  .ta::placeholder { color: var(--faint); }
  .ta:focus { border-color: var(--accent); }
</style>
