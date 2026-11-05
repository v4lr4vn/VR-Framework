<script>
  import { isGame, post } from './lib/nui.js';
  import { shopPayload, offerPayload } from './lib/mock.js';
  import Shop from './views/Shop.svelte';
  import Offer from './views/Offer.svelte';

  const q = new URLSearchParams(location.search);
  let visible = $state(!isGame);
  let mode = $state(isGame ? null : q.get('mode') || 'shop');
  let data = $state(isGame ? null : (q.get('mode') === 'offer' ? offerPayload : shopPayload(q.get('staff') === '1')));
  let colors = $state(isGame ? [] : shopPayload().colors);
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
        if (d.data?.colors) colors = d.data.colors;
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
  <div class="stage" class:clear={mode === 'offer'}>
    {#key stamp}
      {#if mode === 'shop'}
        <Shop p={data} onclose={close} />
      {:else if mode === 'offer'}
        <Offer o={data} {colors} onclose={close} />
      {/if}
    {/key}
  </div>
{/if}

<style>
  .stage { position: fixed; inset: 0; display: grid; place-items: center; }
  .stage.clear { background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.2), rgba(10, 14, 20, 0.5)); }
</style>
