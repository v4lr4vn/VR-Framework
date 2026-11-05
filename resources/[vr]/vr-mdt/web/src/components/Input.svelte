<script>
  let { value = $bindable(''), id, type = 'text', placeholder = '', maxlength, mono = false, disabled = false, autofocus = false, oninput, onkeydown, ...rest } = $props();
  let el;
  $effect(() => { if (autofocus && el) el.focus(); });
</script>

<input bind:this={el} {id} {type} class="input" class:mono bind:value {placeholder} {maxlength} {disabled} {oninput} {onkeydown} spellcheck="false" autocomplete="off" {...rest} />

<style>
  .input { height: 36px; width: 100%; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--text); outline: none; }
  .input::placeholder { color: var(--faint); }
  .input:focus { border-color: var(--accent); }
  .input:disabled { opacity: 0.6; }
  .mono { font-family: var(--mono); }
</style>
