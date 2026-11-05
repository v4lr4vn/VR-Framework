<script>
  import { ui, STATS, statVisible, pinned } from '../lib/store.svelte.js';
  import Chip from './Chip.svelte';

  const flow = $derived(ui.edit ? [] : STATS.filter((s) => statVisible(s) && !pinned(s)));
</script>

<div class="status">
  {#each flow as s (s.key)}<Chip {s} />{/each}
</div>
