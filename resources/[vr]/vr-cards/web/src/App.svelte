<script>
  import { isGame, post } from './lib/nui.js';
  import { packPayload, binderPayload, shopPayload, cardPayload } from './lib/mock.js';
  import { sfx } from './lib/sfx.js';
  import Pack from './views/Pack.svelte';
  import Binder from './views/Binder.svelte';
  import Shop from './views/Shop.svelte';
  import Viewer from './views/Viewer.svelte';

  const MOCK = { pack: packPayload, binder: binderPayload, shop: shopPayload, card: cardPayload };
  const q = new URLSearchParams(location.search);
  const start = q.get('mode') || 'pack';

  let visible = $state(!isGame);
  let mode = $state(isGame ? null : start);
  let data = $state(isGame ? null : MOCK[start]);
  let stamp = $state(0);

  function close() {
    if (isGame) post('close');
    visible = false;
  }

  $effect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      if (d.action === 'open') {
        mode = d.mode;
        data = d.data;
        if (d.sound != null) sfx.setVolume(d.sound);
        stamp += 1;
        visible = true;
      } else if (d.action === 'close') visible = false;
    };
    const onKey = (e) => {
      if (e.key !== 'Escape' || !visible) return;
      if (document.querySelector('[role="dialog"]')) return;
      close();
    };
    window.addEventListener('message', onMsg);
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('message', onMsg);
      window.removeEventListener('keydown', onKey);
    };
  });
</script>

{#if visible && data}
  {#key stamp}
    {#if mode === 'pack'}
      <Pack p={data} onclose={close} />
    {:else if mode === 'binder'}
      <Binder p={data} onclose={close} />
    {:else if mode === 'shop'}
      <Shop p={data} onclose={close} />
    {:else if mode === 'card'}
      <Viewer c={data.card} meta={data.meta} onclose={close} />
    {/if}
  {/key}
{/if}
