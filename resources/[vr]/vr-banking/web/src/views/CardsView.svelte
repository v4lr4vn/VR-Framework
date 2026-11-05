<script>
  import { app, act } from '../lib/store.svelte.js';
  import { money, acct, date } from '../lib/format.js';
  import BankCard from '../ui/BankCard.svelte';
  import Modal from '../ui/Modal.svelte';

  let o = $derived(app.overview);
  let eligible = $derived(o ? o.accounts.filter((a) => a.rights.withdraw) : []);
  let account = $state(null);
  let pin = $state('');
  let pin2 = $state('');
  let pinFor = $state(null);
  let newPin = $state('');
  let cancelling = $state(null);
  let len = $derived(o?.settings.pinLength || 4);

  $effect(() => {
    if (account == null && eligible.length) account = eligible[0].id;
  });

  const digits = (v) => v.replace(/\D/g, '').slice(0, len);
  let replaces = $derived(o ? o.cards.find((c) => c.account && eligible.find((a) => a.id === account)?.number === c.account.number) : null);

  async function order(e) {
    e.preventDefault();
    const r = await act('cards.order', { account, pin }, (d) => `Card ending ${d.last4} is in your pocket`);
    if (r.ok) { pin = ''; pin2 = ''; }
  }

  async function changePin(e) {
    e.preventDefault();
    const r = await act('cards.pin', { card: pinFor.id, pin: newPin }, 'PIN changed');
    if (r.ok) { pinFor = null; newPin = ''; }
  }
</script>

<div class="wrap">
  <div class="list">
    <div class="h"><h2>Your cards</h2><span class="hint">Use them with your PIN at any ATM</span></div>
    {#if !o.cards.length}
      <div class="empty box"><i class="fa-solid fa-credit-card"></i>You have no cards yet. Order one on the right.</div>
    {/if}
    <div class="grid">
      {#each o.cards as c (c.id)}
        <div class="item">
          <BankCard card={c} bank={o.bank} />
          <div class="meta">
            <span class="num">{acct(c.account?.number)}</span>
            <span class="muted">Issued {date(c.created)}</span>
          </div>
          <div class="acts">
            {#if c.locked}
              <button class="btn small ok" onclick={() => act('cards.unlock', { card: c.id }, 'Card unlocked')}><i class="fa-solid fa-lock-open"></i>Unlock</button>
            {/if}
            <button class="btn small" onclick={() => act('cards.freeze', { card: c.id, frozen: c.status === 'active' }, c.status === 'active' ? 'Card frozen' : 'Card unfrozen')}>
              <i class="fa-solid {c.status === 'active' ? 'fa-snowflake' : 'fa-fire'}"></i>{c.status === 'active' ? 'Freeze' : 'Unfreeze'}
            </button>
            {#if c.mine}
              <button class="btn small" onclick={() => { pinFor = c; newPin = ''; }}><i class="fa-solid fa-key"></i>PIN</button>
            {/if}
            <button class="btn small danger" onclick={() => (cancelling = c)}><i class="fa-solid fa-ban"></i>Lost or stolen</button>
          </div>
        </div>
      {/each}
    </div>
  </div>

  <aside class="order box">
    <div class="box-head"><h3>Order a card</h3><span class="chip accent">{money(o.settings.cardFee)}</span></div>
    <form class="box-body f" onsubmit={order}>
      {#if !eligible.length}
        <div class="notice"><i class="fa-solid fa-circle-info"></i><span>You need withdraw access on an account to get a card for it.</span></div>
      {:else}
        <label class="field">
          <span>Account</span>
          <select class="input" bind:value={account}>
            {#each eligible as a}<option value={a.id}>{a.label} · {acct(a.number)}</option>{/each}
          </select>
        </label>
        <label class="field">
          <span>Choose a {len}-digit PIN</span>
          <input class="input num pin" type="password" inputmode="numeric" maxlength={len} value={pin} oninput={(e) => (pin = e.currentTarget.value = digits(e.currentTarget.value))} />
        </label>
        <label class="field">
          <span>Repeat PIN</span>
          <input class="input num pin" type="password" inputmode="numeric" maxlength={len} value={pin2} oninput={(e) => (pin2 = e.currentTarget.value = digits(e.currentTarget.value))} />
        </label>
        {#if pin2.length === len && pin !== pin2}<p class="danger-text small">The PINs do not match</p>{/if}
        {#if replaces}
          <div class="notice warn"><i class="fa-solid fa-rotate"></i><span>This replaces your card ending {replaces.last4}. The old card stops working.</span></div>
        {/if}
        <p class="hint">The fee comes from your personal account, or your cash if that is short. Never share your PIN: anyone with your card and PIN can use it.</p>
        <button class="btn primary" disabled={app.busy || pin.length !== len || pin !== pin2}><i class="fa-solid fa-credit-card"></i>Order card</button>
      {/if}
    </form>
  </aside>
</div>

{#if pinFor}
  <Modal title="Change PIN" icon="fa-key" onclose={() => (pinFor = null)} width={380}>
    <form class="f" onsubmit={changePin}>
      <p class="muted">Card ending {pinFor.last4}. This also clears any lock from wrong attempts.</p>
      <label class="field"><span>New PIN</span><input class="input num pin" type="password" inputmode="numeric" maxlength={len} value={newPin} oninput={(e) => (newPin = e.currentTarget.value = digits(e.currentTarget.value))} /></label>
      <div class="row"><button type="button" class="btn ghost" onclick={() => (pinFor = null)}>Cancel</button><button class="btn primary" disabled={newPin.length !== len}>Save PIN</button></div>
    </form>
  </Modal>
{/if}

{#if cancelling}
  <Modal title="Cancel card" icon="fa-ban" onclose={() => (cancelling = null)} width={400}>
    <p class="msg">Cancel the card ending <strong>{cancelling.last4}</strong>? It stops working straight away and cannot be turned back on. You can order a new one any time.</p>
    <div class="row">
      <button class="btn ghost" onclick={() => (cancelling = null)}>Keep it</button>
      <button class="btn danger" onclick={async () => { const r = await act('cards.cancel', { card: cancelling.id }, 'Card cancelled'); if (r.ok) cancelling = null; }}>Cancel card</button>
    </div>
  </Modal>
{/if}

<style>
  .wrap { display: grid; grid-template-columns: 1fr 320px; gap: 20px; align-items: start; }
  .h { display: flex; align-items: baseline; gap: 10px; margin-bottom: 14px; }
  h2 { font-size: 20px; font-weight: 700; }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(240px, 256px)); gap: 18px; }
  .item { display: flex; flex-direction: column; gap: 8px; }
  .meta { display: flex; justify-content: space-between; font-size: 12px; color: var(--text-2); }
  .acts { display: flex; flex-wrap: wrap; gap: 6px; }
  .order { position: sticky; top: 0; }
  .f { display: flex; flex-direction: column; gap: 12px; }
  .pin { letter-spacing: 0.5em; font-size: 18px; }
  .small { font-size: 12px; }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
  .msg { font-size: 14px; color: var(--text-2); line-height: 1.5; }
</style>
