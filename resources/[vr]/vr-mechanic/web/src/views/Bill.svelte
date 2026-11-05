<script>
  import { isGame, post } from '../lib/nui.js';
  import { money, errorText } from '../lib/api.js';

  let { b, onclose } = $props();

  let method = $state(b.bank >= b.amount ? 'bank' : 'cash');
  let left = $state(b.seconds || 60);
  let busy = $state(false);
  let err = $state('');

  $effect(() => {
    const id = setInterval(() => {
      left = Math.max(0, left - 1);
      if (left === 0) clearInterval(id);
    }, 1000);
    return () => clearInterval(id);
  });

  let canPay = $derived(left > 0 && (method === 'bank' ? b.bank : b.cash) >= b.amount);

  async function answer(accept) {
    if (busy) return;
    busy = true;
    err = '';
    const r = isGame ? await post('billAnswer', { accept, method }) : { ok: true };
    busy = false;
    if (!r || !r.ok) return (err = errorText(r?.error));
    if (!isGame) onclose();
  }
</script>

<section class="bill card" aria-label="Mechanic bill">
  <header>
    <span class="logo"><i class="fa-solid fa-file-invoice-dollar"></i></span>
    <div><h1>{b.mechanic} sent you a bill</h1><p class="sub">{b.workshop || b.business}</p></div>
    <span class="timer num" class:low={left <= 10}><i class="fa-solid fa-stopwatch"></i>{left}s</span>
  </header>
  <div class="body">
    {#if b.vehicle || b.plate}
      <div class="veh">
        <i class="fa-solid fa-car-side"></i>
        <span>{b.vehicle || 'Vehicle'}</span>
        {#if b.plate}<span class="plate num">{b.plate}</span>{/if}
      </div>
    {/if}
    <div class="lines">
      {#each b.items || [] as it}
        <div class="ln"><span>{it.label}</span><span class="num">{money(it.price)}</span></div>
      {/each}
    </div>
    <div class="sum"><span>Total</span><span class="num">{money(b.amount)}</span></div>
    {#if b.kind === 'order'}<p class="hint">{b.note ? `${b.note}. ` : ''}The mechanic fits everything once you pay.</p>{/if}
    <div class="methods">
      <button class="m" class:on={method === 'bank'} onclick={() => (method = 'bank')}><i class="fa-solid fa-building-columns"></i><span>Bank</span><span class="num sub">{money(b.bank)}</span></button>
      <button class="m" class:on={method === 'cash'} onclick={() => (method = 'cash')}><i class="fa-solid fa-money-bill-wave"></i><span>Cash</span><span class="num sub">{money(b.cash)}</span></button>
    </div>
    {#if err}<div class="notice danger"><i class="fa-solid fa-circle-exclamation"></i><span>{err}</span></div>{/if}
  </div>
  <footer>
    <button class="btn ghost" disabled={busy} onclick={() => answer(false)}>Decline</button>
    <button class="btn primary" disabled={busy || !canPay} onclick={() => answer(true)}><i class="fa-solid fa-check"></i>Pay {money(b.amount)}</button>
  </footer>
</section>

<style>
  .bill { width: 440px; max-width: calc(100vw - 32px); display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); }
  header > div { flex: 1; }
  .logo { width: 36px; height: 36px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); }
  h1 { font-size: 15px; font-weight: 700; }
  .sub { color: var(--muted); font-size: 12px; }
  .timer { display: inline-flex; gap: 6px; align-items: center; color: var(--text-2); font-size: 13px; }
  .timer.low { color: var(--danger-text); }
  .body { padding: 16px; display: flex; flex-direction: column; gap: 12px; }
  .veh { display: flex; align-items: center; gap: 10px; font-size: 14px; font-weight: 700; }
  .veh i { color: var(--muted); }
  .veh span:first-of-type { flex: 1; }
  .plate { padding: 2px 8px; border-radius: 4px; background: #e9eef4; color: #18212d; font-size: 12px; font-weight: 600; letter-spacing: 0.1em; border: 2px solid #9fb0c4; }
  .lines { display: flex; flex-direction: column; gap: 5px; padding: 12px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); max-height: 200px; overflow-y: auto; }
  .ln { display: flex; justify-content: space-between; gap: 12px; font-size: 13px; color: var(--text-2); }
  .ln .num { color: var(--muted); }
  .sum { display: flex; justify-content: space-between; align-items: baseline; font-size: 14px; color: var(--text-2); font-weight: 600; }
  .sum .num { font-size: 28px; color: var(--accent-2); }
  .methods { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .m { display: flex; flex-direction: column; align-items: flex-start; gap: 3px; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: inherit; font-size: 13px; font-weight: 600; text-align: left; }
  .m i { color: var(--muted); }
  .m .sub { color: var(--muted); font-weight: 500; font-size: 11px; }
  .m.on { border-color: var(--accent); background: var(--accent-soft); }
  .m.on i { color: var(--accent); }
  footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line-2); }
</style>
