<script>
  import { plain } from '../../lib/md.js';
  let { label = '', description = '', required = false, error = '', inline = false, children } = $props();
</script>

<div class="field" class:inline>
  {#if label && !inline}<span class="lbl">{plain(label)}{#if required}<b>*</b>{/if}</span>{/if}
  {@render children()}
  {#if description}<span class="hint">{plain(description)}</span>{/if}
  {#if error}<span class="err">{error}</span>{/if}
</div>

<style>
  .field { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .lbl { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
  .lbl b { color: var(--accent); margin-left: 3px; }
  .hint { color: var(--faint); font-size: 12px; line-height: 1.35; }
  .err { color: var(--danger-text); font-size: 12px; }
</style>
