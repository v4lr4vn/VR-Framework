<script>
  import { hud } from '../lib/store.svelte.js';
  let { s } = $props();
  const v = $derived(hud[s.key]);
</script>

<div class="chip" class:low={s.dir === 'low' && v <= 20} style:--c={s.color} title={s.label}>
  <span class="fill" style:height="{v}%"></span>
  <i class="fa-solid {s.icon}"></i>
  <b>{Math.round(v)}</b>
</div>
