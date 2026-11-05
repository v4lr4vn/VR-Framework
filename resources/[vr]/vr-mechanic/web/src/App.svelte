<script>
  import { isGame, post } from './lib/nui.js';
  import { inspectPayload, tunePayload, designPayload, shopPayload, invoicePayload, billPayload, orderPayload, boardPayload } from './lib/mock.js';
  import Inspect from './views/Inspect.svelte';
  import Tune from './views/Tune.svelte';
  import Shop from './views/Shop.svelte';
  import Invoice from './views/Invoice.svelte';
  import Bill from './views/Bill.svelte';
  import Order from './views/Order.svelte';
  import Board from './views/Board.svelte';

  const q = new URLSearchParams(location.search);
  const role = q.get('role') || 'mechanic';
  const MOCK = { inspect: inspectPayload, tune: tunePayload, design: designPayload, shop: shopPayload, invoice: invoicePayload, bill: billPayload, order: orderPayload(q.get('status') || 'paid', role), board: boardPayload };
  const asked = q.get('mode') || 'inspect';
  const start = asked === 'design' ? 'tune' : asked;

  let visible = $state(!isGame);
  let mode = $state(isGame ? null : start);
  let data = $state(isGame ? null : MOCK[asked]);
  let stamp = $state(0);
  let result = $state(null);

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
        result = null;
        stamp += 1;
        visible = true;
      } else if (d.action === 'close') visible = false;
      else if (d.action === 'billResult') result = { accepted: d.accepted, current: d.current, at: Date.now() };
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
  <div class="stage" class:side={mode === 'tune'} class:dim={mode !== 'tune'}>
    {#key stamp}
      {#if mode === 'inspect'}
        <Inspect v={data} onclose={close} />
      {:else if mode === 'tune'}
        <Tune p={data} {result} onclose={close} />
      {:else if mode === 'shop'}
        <Shop p={data} onclose={close} />
      {:else if mode === 'invoice'}
        <Invoice p={data} onclose={close} />
      {:else if mode === 'bill'}
        <Bill b={data} onclose={close} />
      {:else if mode === 'order'}
        <Order o={data} onclose={close} />
      {:else if mode === 'board'}
        <Board p={data} onclose={close} />
      {/if}
    {/key}
  </div>
{/if}

<style>
  .stage { position: fixed; inset: 0; display: grid; place-items: center; }
  .stage.dim { background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.25), rgba(10, 14, 20, 0.55)); }
  .stage.side { place-items: stretch end; padding: 20px; }
</style>
