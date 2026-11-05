<script>
  import { call, money, errorText } from '../lib/api.js';

  let { p, onclose } = $props();

  let customers = $state(p.customers || []);
  let target = $state(p.customers?.[0]?.id ?? null);
  let amount = $state('');
  let note = $state('');
  let busy = $state(false);
  let err = $state('');
  let sent = $state(null);

  let n = $derived(Math.floor(Number(amount) || 0));
  let valid = $derived(target !== null && n >= 1 && n <= p.max);

  async function refresh() {
    const r = await call('customers');
    if (r.ok) {
      customers = r.data;
      if (!customers.some((c) => c.id === target)) target = customers[0]?.id ?? null;
    }
  }

  async function send() {
    if (!valid || busy) return;
    busy = true;
    err = '';
    const r = await call('bill.labour', { target, amount: n, note: note.trim() });
    busy = false;
    if (!r.ok) return (err = errorText(r.error));
    sent = { amount: r.data.amount, id: target };
  }
</script>

<section class="inv card" aria-label="Bill a customer">
  <header>
    <span class="logo"><i class="fa-solid fa-file-invoice-dollar"></i></span>
    <div class="title"><h1>Bill a customer</h1><p class="sub">Labour, call-outs and anything else</p></div>
    <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  {#if sent}
    <div class="body done">
      <span class="big-ic"><i class="fa-solid fa-paper-plane"></i></span>
      <h2>Bill sent</h2>
      <p class="hint">Customer #{sent.id} has {p.seconds} seconds to pay <span class="num">{money(sent.amount)}</span>. You get a message when they answer.</p>
      <button class="btn primary" onclick={onclose}>Done</button>
    </div>
  {:else}
    <div class="body">
      <div class="field">
        <span class="lab">Customer <button class="link" onclick={refresh}><i class="fa-solid fa-arrows-rotate"></i>Refresh</button></span>
        {#if customers.length}
          <div class="people">
            {#each customers as c}
              <button class="person" class:on={target === c.id} onclick={() => (target = c.id)}>
                <i class="fa-solid fa-user"></i><span>Customer #{c.id}</span><span class="num hint">{c.distance} m</span>
              </button>
            {/each}
          </div>
        {:else}
          <div class="empty"><i class="fa-solid fa-user-slash"></i>Nobody is close enough. Stand next to the customer.</div>
        {/if}
      </div>
      <label class="field">
        <span>Amount</span>
        <div class="amt"><span class="cur">$</span><input class="input num" inputmode="numeric" placeholder="0" bind:value={amount} /></div>
        <p class="hint">Up to {money(p.max)}. You earn {p.commission}%{n > 0 ? `: ${money(Math.floor((n * p.commission) / 100))}` : ''}.</p>
      </label>
      <label class="field">
        <span>What for</span>
        <input class="input" maxlength="120" placeholder="Roadside repair, tow, diagnostics…" bind:value={note} />
      </label>
      {#if err}<div class="notice danger"><i class="fa-solid fa-circle-exclamation"></i><span>{err}</span></div>{/if}
    </div>
    <footer>
      <button class="btn ghost" onclick={onclose}>Cancel</button>
      <button class="btn primary" disabled={!valid || busy} onclick={send}><i class="fa-solid fa-paper-plane"></i>Send bill{n > 0 ? ` ${money(n)}` : ''}</button>
    </footer>
  {/if}
</section>

<style>
  .inv { width: 460px; max-width: calc(100vw - 32px); display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 15px; }
  .title { flex: 1; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .body { padding: 16px; display: flex; flex-direction: column; gap: 14px; }
  .lab { display: flex; justify-content: space-between; align-items: center; color: var(--text-2); font-size: 12px; font-weight: 600; }
  .link { display: inline-flex; align-items: center; gap: 6px; background: none; border: 0; color: var(--muted); font-size: 12px; font-weight: 600; padding: 0; }
  .link:hover { color: var(--accent-2); }
  .people { display: flex; flex-direction: column; gap: 6px; }
  .person { display: grid; grid-template-columns: 18px 1fr auto; align-items: center; gap: 10px; height: 38px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 13px; font-weight: 600; text-align: left; }
  .person i { color: var(--muted); }
  .person.on { border-color: var(--accent); background: var(--accent-soft); color: var(--text); }
  .person.on i { color: var(--accent); }
  .amt { position: relative; }
  .cur { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--muted); font-family: var(--mono); }
  .amt .input { padding-left: 26px; font-size: 18px; height: 42px; }
  .empty { padding: 16px; border-radius: var(--radius); border: 1px dashed var(--line-3); }
  footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line-2); }
  .done { align-items: center; text-align: center; padding: 28px 24px; }
  .big-ic { width: 52px; height: 52px; border-radius: 50%; display: grid; place-items: center; background: var(--ok-bg); border: 1px solid var(--ok-line); color: var(--ok); font-size: 20px; }
  h2 { font-size: 18px; }
</style>
