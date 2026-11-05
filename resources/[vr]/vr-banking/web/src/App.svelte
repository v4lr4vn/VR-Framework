<script>
  import { isGame } from './lib/nui.js';
  import { app, refresh } from './lib/store.svelte.js';
  import { close } from './lib/api.js';
  import { mockCall, mockDebt } from './lib/mock.js';
  import Bank from './views/Bank.svelte';
  import Atm from './views/Atm.svelte';
  import Collections from './views/Collections.svelte';

  $effect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      if (d.action === 'open') {
        app.mode = d.mode;
        app.data = d.data || {};
        app.overview = null;
        app.view = 'account';
        app.toast = null;
        app.visible = true;
      } else if (d.action === 'close') {
        app.visible = false;
        app.overview = null;
      }
    };
    const onKey = (e) => {
      if (e.key !== 'Escape' || !app.visible || app.mode === 'atm') return;
      if (document.querySelector('[role="dialog"]')) return;
      close();
      app.visible = false;
      app.overview = null;
    };
    window.addEventListener('message', onMsg);
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('message', onMsg);
      window.removeEventListener('keydown', onKey);
    };
  });

  if (!isGame) {
    const q = new URLSearchParams(location.search);
    const mode = q.get('mode') || 'bank';
    if (q.get('debt')) mockDebt();
    app.mode = mode;
    app.view = q.get('view') || 'account';
    if (q.get('account')) app.accountId = Number(q.get('account'));
    if (mode === 'atm') mockCall('atm.cards').then((r) => { app.data = r.data; app.visible = true; });
    else app.visible = true;
  }
</script>

{#if app.visible}
  <div class="stage" class:atm={app.mode === 'atm'}>
    {#if app.mode === 'bank'}
      <Bank />
    {:else if app.mode === 'atm'}
      {#key app.data}
        <Atm />
      {/key}
    {:else if app.mode === 'collections'}
      <Collections />
    {/if}
  </div>
{/if}

<style>
  .stage { position: fixed; inset: 0; display: grid; place-items: center; background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.45), rgba(10, 14, 20, 0.72)); }
  .stage.atm { background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.2), rgba(10, 14, 20, 0.55)); }
</style>
