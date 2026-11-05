<script>
  import { on } from '../lib/nui.js';
  import { loadSession, ui, toast } from '../lib/state.svelte.js';

  $effect(() =>
    on('session:refresh', async () => {
      if (!ui.open) return;
      const res = await loadSession();
      if (res.ok) toast('Your permissions were updated.', 'info');
    }),
  );
</script>
