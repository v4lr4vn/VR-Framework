<script>
  import Icon from './Icon.svelte';
  let { value = $bindable(''), placeholder = 'Search', onsearch, delay = 250, autofocus = false, id } = $props();
  let timer;
  let el;
  $effect(() => { if (autofocus && el) el.focus(); });

  function input() {
    clearTimeout(timer);
    timer = setTimeout(() => onsearch?.(value.trim()), delay);
  }

  function key(e) {
    if (e.key === 'Enter') {
      clearTimeout(timer);
      onsearch?.(value.trim());
    }
  }
</script>

<label class="search">
  <Icon name="search" size={15} />
  <span class="sr-only">{placeholder}</span>
  <input bind:this={el} {id} bind:value {placeholder} oninput={input} onkeydown={key} spellcheck="false" autocomplete="off" />
</label>

<style>
  .search { display: flex; align-items: center; gap: 10px; height: 36px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--bg-2); color: var(--muted); }
  .search:focus-within { border-color: var(--accent); }
  input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); }
  input::placeholder { color: var(--faint); }
</style>
