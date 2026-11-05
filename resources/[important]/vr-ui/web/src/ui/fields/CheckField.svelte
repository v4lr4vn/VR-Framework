<script>
  import Glyph from '../Glyph.svelte';
  import { plain } from '../../lib/md.js';
  let { value = $bindable(false), row, error = '' } = $props();
</script>

<button type="button" class="cb" class:on={value} class:bad={error} disabled={row.disabled} onclick={() => (value = !value)}>
  <span class="box">{#if value}<Glyph name="check" size={12} stroke={3} />{/if}</span>
  <span class="txt">{plain(row.label || '')}{#if row.required}<b>*</b>{/if}</span>
</button>

<style>
  .cb { display: inline-flex; align-items: center; gap: 10px; min-height: 30px; padding: 0; border: 0; background: transparent; color: var(--text-2); text-align: left; }
  .cb:hover .box { border-color: var(--accent); }
  .box { flex: none; width: 18px; height: 18px; border-radius: 4px; border: 1px solid var(--line-3); background: var(--bg-2); display: inline-flex; align-items: center; justify-content: center; color: var(--accent-ink); }
  .on .box { background: var(--accent); border-color: var(--accent); }
  .on .txt { color: var(--text); }
  .bad .box { border-color: var(--danger); }
  .txt { font-size: 14px; font-weight: 500; }
  .txt b { color: var(--accent); margin-left: 3px; }
  .cb:disabled { opacity: 0.55; }
</style>
