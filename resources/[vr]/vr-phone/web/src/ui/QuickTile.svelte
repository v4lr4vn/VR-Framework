<script>
  import Glyph from './Glyph.svelte';

  // One switch in the quick panel: an icon, a name, and a short line under it that says what it is doing.
  let { glyph, label, sub = '', on = false, disabled = false, onclick } = $props();
</script>

<button class="tile" class:on class:faded={disabled} {disabled} aria-pressed={on} {onclick}>
  <span class="ico"><Glyph name={glyph} size={24} stroke={2} /></span>
  <span class="label">{label}</span>
  <span class="sub">{sub || ' '}</span>
</button>

<style>
  .tile {
    display: flex;
    flex-direction: column;
    align-items: flex-start;
    gap: 2px;
    min-width: 0;
    padding: 12px 12px 10px;
    border-radius: 20px;
    background: var(--surface);
    color: var(--ink);
    box-shadow: inset 0 0 0 1px var(--line);
    transition: background 0.18s var(--ease-soft), color 0.18s var(--ease-soft);
  }
  .tile:hover:not(:disabled) {
    background: var(--surface-2);
  }
  .tile.on {
    background: var(--accent);
    color: var(--on-accent);
    box-shadow: none;
  }
  .tile.on:hover {
    background: var(--accent-light);
  }
  .tile.faded {
    opacity: 0.5;
  }
  .ico {
    margin-bottom: 6px;
  }
  .label {
    font-size: 14px;
    font-weight: 700;
    max-width: 100%;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sub {
    font-size: 11.5px;
    font-weight: 600;
    opacity: 0.72;
    max-width: 100%;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
</style>
