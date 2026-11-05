<script>
  import { isGame, post } from '../lib/nui.js';
  import { money, errorText, reasonText } from '../lib/api.js';

  let { o, colors, onclose } = $props();

  let method = $state(o.bank >= o.price ? 'bank' : 'cash');
  let left = $state(o.seconds || 60);
  let busy = $state(false);
  let err = $state('');

  $effect(() => {
    const id = setInterval(() => {
      left = Math.max(0, left - 1);
      if (left === 0) clearInterval(id);
    }, 1000);
    return () => clearInterval(id);
  });

  let swatch = $derived((colors || []).find((c) => c.id === o.color));
  let off = $derived(Math.round(((o.base - o.price) / o.base) * 100));
  let canAccept = $derived(left > 0 && (o.payment === 'finance' ? o.finance?.approved : (method === 'bank' ? o.bank : o.cash) >= o.price));

  async function answer(accept) {
    if (busy) return;
    busy = true;
    err = '';
    const r = isGame ? await post('offerAnswer', { accept, method }) : { ok: true };
    busy = false;
    if (!r || !r.ok) {
      err = errorText(r?.error);
      return;
    }
    onclose(false);
  }
</script>

<section class="offer card" aria-label="Vehicle offer">
  <header>
    <span class="logo"><i class="fa-solid fa-handshake"></i></span>
    <div><h1>{o.seller} has an offer for you</h1><p class="sub">{o.dealer}</p></div>
    <span class="timer num" class:low={left <= 10}><i class="fa-solid fa-stopwatch"></i>{left}s</span>
  </header>
  <div class="body">
    <div class="car">
      <span class="label">Vehicle</span>
      <h2>{o.label}</h2>
      {#if swatch}<span class="paint"><span class="dot" style="background:{swatch.hex}"></span>{swatch.label}</span>{/if}
    </div>
    <div class="pricebox">
      {#if off > 0}<span class="was num">{money(o.base)}</span>{/if}
      <span class="now num">{money(o.price)}</span>
      {#if off > 0}<span class="chip ok">{off}% off list</span>{:else if off < 0}<span class="chip warn">{-off}% over list</span>{/if}
    </div>

    {#if o.payment === 'finance'}
      <div class="quote" class:no={!o.finance?.approved}>
        <div class="q"><span>Down payment today</span><span class="num">{money(o.finance?.down)}</span></div>
        <div class="q big"><span>{o.finance?.term} payments of</span><span class="num">{money(o.finance?.installment)}</span></div>
        <div class="q"><span>Every</span><span class="num">{o.finance?.intervalHours}h</span></div>
        <div class="q"><span>Rate ({o.finance?.tier?.label} credit)</span><span class="num">{o.finance?.rate}%</span></div>
        <div class="q"><span>Total paid</span><span class="num">{money((o.finance?.total || 0) + (o.finance?.down || 0))}</span></div>
      </div>
      {#if o.finance?.approved}
        <div class="notice"><i class="fa-solid fa-circle-info"></i><span>Bank finance with the car as collateral. Miss payments and it can be repossessed.</span></div>
      {:else}
        <div class="notice danger"><i class="fa-solid fa-circle-xmark"></i><span>The bank declined: {(o.finance?.reasons || []).map(reasonText).join('. ')}</span></div>
      {/if}
    {:else}
      <div class="methods">
        <button class="m" class:on={method === 'bank'} onclick={() => (method = 'bank')}><i class="fa-solid fa-building-columns"></i><span>Bank</span><span class="num sub">{money(o.bank)}</span></button>
        <button class="m" class:on={method === 'cash'} onclick={() => (method = 'cash')}><i class="fa-solid fa-money-bill-wave"></i><span>Cash</span><span class="num sub">{money(o.cash)}</span></button>
      </div>
    {/if}
    {#if err}<div class="notice danger"><i class="fa-solid fa-circle-exclamation"></i><span>{err}</span></div>{/if}
  </div>
  <footer>
    <button class="btn ghost" disabled={busy} onclick={() => answer(false)}>Decline</button>
    <button class="btn primary" disabled={busy || !canAccept} onclick={() => answer(true)}><i class="fa-solid fa-signature"></i>{o.payment === 'finance' ? 'Sign the finance' : `Pay ${money(o.price)}`}</button>
  </footer>
</section>

<style>
  .offer { width: 480px; max-width: calc(100vw - 32px); display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); }
  header > div { flex: 1; }
  .logo { width: 36px; height: 36px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); }
  h1 { font-size: 15px; font-weight: 700; }
  .sub { color: var(--muted); font-size: 12px; }
  .timer { display: inline-flex; gap: 6px; align-items: center; color: var(--text-2); font-size: 13px; }
  .timer.low { color: var(--danger-text); }
  .body { padding: 16px; display: flex; flex-direction: column; gap: 14px; }
  h2 { font-size: 22px; font-weight: 700; }
  .paint { display: inline-flex; align-items: center; gap: 8px; color: var(--text-2); font-size: 13px; margin-top: 4px; }
  .dot { width: 14px; height: 14px; border-radius: 50%; border: 1px solid var(--line-3); }
  .pricebox { display: flex; align-items: baseline; gap: 12px; }
  .was { color: var(--faint); text-decoration: line-through; }
  .now { font-size: 30px; font-weight: 600; color: var(--accent-2); }
  .quote { display: flex; flex-direction: column; gap: 6px; padding: 12px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); }
  .quote.no { opacity: 0.7; }
  .q { display: flex; justify-content: space-between; font-size: 13px; color: var(--text-2); }
  .q.big { font-size: 15px; font-weight: 700; color: var(--text); padding: 6px 0; border-top: 1px solid var(--line-2); border-bottom: 1px solid var(--line-2); }
  .methods { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .m { display: flex; flex-direction: column; align-items: flex-start; gap: 3px; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: inherit; font-size: 13px; font-weight: 600; text-align: left; }
  .m i { color: var(--muted); }
  .m .sub { color: var(--muted); font-weight: 500; font-size: 11px; }
  .m.on { border-color: var(--accent); background: var(--accent-soft); }
  .m.on i { color: var(--accent); }
  footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line-2); }
</style>
