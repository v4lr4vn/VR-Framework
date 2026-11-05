<script>
  import { app } from '../lib/store.svelte.js';
  import { call, close } from '../lib/api.js';
  import { money, signed, dateTime, acct, KIND } from '../lib/format.js';
  import { errorText } from '../lib/errors.js';

  let init = app.data || {};
  let cards = $state(init.cards || []);
  let len = init.pinLength || 4;
  let step = $state('cards');
  let card = $state(null);
  let pin = $state('');
  let err = $state('');
  let st = $state(null);
  let entry = $state('');
  let entryMode = $state('withdraw');
  let statement = $state([]);
  let message = $state(null);
  let busy = $state(false);

  $effect(() => {
    if (step === 'cards' && cards.length === 1 && !card) pick(cards[0]);
  });

  function pick(c) {
    if (c.status === 'frozen') { err = errorText('card_frozen'); return; }
    if (c.status !== 'active') { err = errorText('card_invalid'); return; }
    card = c;
    pin = '';
    err = '';
    step = 'pin';
  }

  async function submitPin() {
    if (pin.length !== len || busy) return;
    busy = true;
    const r = await call('atm.pin', { card: card.id, pin });
    busy = false;
    pin = '';
    if (!r.ok) {
      err = r.error === 'bad_pin' ? `Wrong PIN. ${r.data} ${r.data === 1 ? 'try' : 'tries'} left` : errorText(r.error);
      if (r.error !== 'bad_pin') { step = 'error'; }
      return;
    }
    err = '';
    st = r.data;
    step = 'menu';
  }

  async function withdraw(n) {
    if (busy) return;
    busy = true;
    const r = await call('atm.withdraw', { amount: n });
    busy = false;
    if (!r.ok) { err = errorText(r.error); return; }
    st = r.data;
    err = '';
    flash(`Take your cash`, money(n), 'fa-money-bill-wave');
  }

  async function deposit(n) {
    if (busy) return;
    busy = true;
    const r = await call('atm.deposit', { amount: n });
    busy = false;
    if (!r.ok) { err = errorText(r.error); return; }
    st = r.data;
    err = '';
    flash('Deposited', money(n), 'fa-circle-check');
  }

  function flash(title, sub, icon) {
    message = { title, sub, icon };
    step = 'message';
    setTimeout(() => { if (step === 'message') { message = null; step = 'menu'; } }, 1800);
  }

  async function openStatement() {
    const r = await call('atm.history');
    if (!r.ok) { err = errorText(r.error); return; }
    statement = r.data;
    step = 'statement';
  }

  function amountEntry(mode) {
    entryMode = mode;
    entry = '';
    err = '';
    step = 'amount';
  }

  function submitAmount() {
    const n = parseInt(entry, 10) || 0;
    if (!n) return;
    if (entryMode === 'withdraw') withdraw(n);
    else deposit(n);
  }

  function key(k) {
    if (step === 'pin') {
      if (k === 'clear') pin = pin.slice(0, -1);
      else if (k === 'enter') submitPin();
      else if (pin.length < len) {
        pin += k;
        if (pin.length === len) setTimeout(submitPin, 120);
      }
    } else if (step === 'amount') {
      if (k === 'clear') entry = entry.slice(0, -1);
      else if (k === 'enter') submitAmount();
      else if (entry.length < 7 && !(entry === '' && k === '0')) entry += k;
    }
  }

  function exit() {
    close();
    app.visible = false;
  }

  function back() {
    err = '';
    if (step === 'amount' || step === 'statement') step = 'menu';
    else exit();
  }

  const onKey = (e) => {
    if (/^\d$/.test(e.key)) key(e.key);
    else if (e.key === 'Backspace') key('clear');
    else if (e.key === 'Enter') key('enter');
    else if (e.key === 'Escape') back();
  };
</script>

<svelte:window onkeydown={onKey} />

<section class="atm" aria-label="ATM">
  <div class="brandbar">
    <span><i class="fa-solid fa-building-columns"></i>{init.bank || 'ValRavn Bank'}</span>
    <span class="num">{card ? `•••• ${card.last4}` : 'ATM'}</span>
  </div>

  <div class="screen">
    {#if step === 'cards'}
      <div class="scr-title">Select a card</div>
      <div class="cards">
        {#each cards as c}
          <button class="cardpick" disabled={c.status !== 'active'} onclick={() => pick(c)}>
            <i class="fa-solid fa-credit-card"></i>
            <span><strong class="num">•••• {c.last4}</strong><em>{c.holder} · {acct(c.account)}</em></span>
            {#if c.status !== 'active'}<span class="chip {c.status === 'frozen' ? 'info' : 'danger'}">{c.status === 'frozen' ? 'Frozen' : 'Not valid'}</span>{/if}
          </button>
        {/each}
      </div>
    {:else if step === 'pin'}
      <div class="scr-title">Enter your PIN</div>
      <div class="dots">
        {#each Array(len) as _, i}<span class:on={i < pin.length}></span>{/each}
      </div>
      <p class="scr-sub">{busy ? 'Checking…' : 'Shield the keypad while you type'}</p>
    {:else if step === 'menu' && st}
      <div class="hello">
        <span class="scr-sub">Hello, {st.holder}</span>
        <span class="scr-acc">{st.account.label} · <span class="num">{acct(st.account.number)}</span></span>
        <span class="bal num">{money(st.account.balance)}</span>
      </div>
      <div class="fast">
        {#each st.fastCash as n}
          <button class="fc num" disabled={busy || n > st.dailyLeft || n > st.account.balance} onclick={() => withdraw(n)}>{money(n)}</button>
        {/each}
        <button class="fc" onclick={() => amountEntry('withdraw')}>Other</button>
      </div>
      <div class="menu">
        {#if st.allowDeposit}<button class="mi" onclick={() => amountEntry('deposit')}><i class="fa-solid fa-arrow-down"></i>Deposit cash</button>{/if}
        <button class="mi" onclick={openStatement}><i class="fa-solid fa-receipt"></i>Mini statement</button>
      </div>
      <p class="limit">Daily limit left <span class="num">{money(st.dailyLeft)}</span> of <span class="num">{money(st.dailyLimit)}</span></p>
    {:else if step === 'amount'}
      <div class="scr-title">{entryMode === 'withdraw' ? 'Withdraw' : 'Deposit'} amount</div>
      <div class="entry num">{entry ? money(entry) : '$0'}</div>
      <p class="scr-sub">{entryMode === 'withdraw' ? `Up to ${money(Math.min(st.dailyLeft, st.account.balance))} today` : 'Cash from your pocket'}</p>
    {:else if step === 'statement'}
      <div class="scr-title">Mini statement</div>
      <div class="stmt scroll">
        {#each statement as t}
          <div class="srow"><span class="num muted">{dateTime(t.at)}</span><span class="sd">{t.reason || KIND[t.kind]?.label}</span><span class="num" class:pos={t.amount > 0}>{signed(t.amount)}</span></div>
        {/each}
        {#if !statement.length}<p class="scr-sub">No transactions</p>{/if}
      </div>
    {:else if step === 'message' && message}
      <div class="msg">
        <i class="fa-solid {message.icon}"></i>
        <span class="scr-title">{message.title}</span>
        <span class="num big">{message.sub}</span>
      </div>
    {:else if step === 'error'}
      <div class="msg bad">
        <i class="fa-solid fa-circle-exclamation"></i>
        <span class="scr-title">{err}</span>
        <span class="scr-sub">Visit any branch for help with your card</span>
      </div>
    {/if}
    {#if err && step !== 'error'}<div class="err"><i class="fa-solid fa-triangle-exclamation"></i>{err}</div>{/if}
  </div>

  <div class="pad">
    <div class="keys">
      {#each ['1', '2', '3', '4', '5', '6', '7', '8', '9'] as k}
        <button class="key num" onclick={() => key(k)} disabled={step !== 'pin' && step !== 'amount'}>{k}</button>
      {/each}
      <button class="key fn clear" onclick={() => key('clear')} disabled={step !== 'pin' && step !== 'amount'} aria-label="Delete"><i class="fa-solid fa-delete-left"></i></button>
      <button class="key num" onclick={() => key('0')} disabled={step !== 'pin' && step !== 'amount'}>0</button>
      <button class="key fn enter" onclick={() => key('enter')} disabled={step !== 'pin' && step !== 'amount'} aria-label="Enter"><i class="fa-solid fa-check"></i></button>
    </div>
    <div class="side">
      <button class="sk" onclick={back}><i class="fa-solid {step === 'amount' || step === 'statement' ? 'fa-arrow-left' : 'fa-eject'}"></i>{step === 'amount' || step === 'statement' ? 'Back' : 'Take card'}</button>
      <div class="slot"><span></span></div>
      <div class="cash"><span></span></div>
    </div>
  </div>
</section>

<style>
  .atm { width: 470px; padding: 18px; border-radius: 16px; background: linear-gradient(180deg, #1A2433, #0F1620); border: 1px solid var(--line-3); box-shadow: 0 30px 60px rgba(0, 0, 0, 0.6), inset 0 1px 0 rgba(255, 255, 255, 0.05); display: flex; flex-direction: column; gap: 14px; }
  .brandbar { display: flex; justify-content: space-between; align-items: center; color: var(--text-2); font-size: 12px; font-weight: 700; letter-spacing: 0.08em; text-transform: uppercase; }
  .brandbar span:first-child { display: inline-flex; gap: 8px; align-items: center; }
  .brandbar i { color: var(--accent); }
  .screen { position: relative; height: 330px; border-radius: 10px; padding: 18px; background: radial-gradient(120% 100% at 50% 0%, #142238, #0A111B); border: 2px solid #05080C; box-shadow: inset 0 0 30px rgba(90, 169, 255, 0.08); display: flex; flex-direction: column; gap: 12px; overflow: hidden; }
  .scr-title { font-size: 18px; font-weight: 700; color: var(--text); text-align: center; }
  .scr-sub { font-size: 12px; color: var(--muted); text-align: center; }
  .cards { display: flex; flex-direction: column; gap: 8px; }
  .cardpick { display: flex; align-items: center; gap: 12px; padding: 12px; border-radius: var(--radius); border: 1px solid var(--line-3); background: rgba(26, 36, 51, 0.7); color: inherit; text-align: left; }
  .cardpick:hover:not(:disabled) { border-color: var(--accent); }
  .cardpick:disabled { opacity: 0.6; }
  .cardpick i { font-size: 18px; color: var(--accent); }
  .cardpick span:nth-of-type(1) { display: flex; flex-direction: column; flex: 1; }
  .cardpick em { font-style: normal; font-size: 11px; color: var(--muted); }
  .dots { display: flex; justify-content: center; gap: 16px; margin-top: 40px; }
  .dots span { width: 18px; height: 18px; border-radius: 50%; border: 2px solid var(--line-3); transition: background 0.1s, border-color 0.1s; }
  .dots span.on { background: var(--accent); border-color: var(--accent); }
  .hello { display: flex; flex-direction: column; align-items: center; gap: 2px; }
  .scr-acc { font-size: 12px; color: var(--text-2); }
  .bal { font-size: 30px; font-weight: 600; color: var(--text); margin-top: 4px; }
  .fast { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; }
  .fc { height: 38px; border-radius: var(--radius); border: 1px solid var(--line-3); background: rgba(26, 36, 51, 0.8); color: var(--text); font-size: 14px; font-weight: 600; }
  .fc:hover:not(:disabled) { border-color: var(--accent); background: var(--accent-soft); }
  .fc:disabled { opacity: 0.35; }
  .menu { display: grid; grid-template-columns: 1fr 1fr; gap: 6px; }
  .mi { display: flex; align-items: center; justify-content: center; gap: 8px; height: 36px; border-radius: var(--radius); border: 1px solid var(--line-2); background: transparent; color: var(--text-2); font-size: 13px; font-weight: 600; }
  .mi:hover { border-color: var(--line-3); color: var(--text); }
  .limit { text-align: center; font-size: 11px; color: var(--faint); margin-top: auto; }
  .entry { text-align: center; font-size: 36px; font-weight: 600; margin-top: 30px; color: var(--text); }
  .stmt { display: flex; flex-direction: column; flex: 1; min-height: 0; }
  .srow { display: grid; grid-template-columns: 80px 1fr auto; gap: 8px; padding: 6px 2px; border-bottom: 1px dashed var(--line-2); font-size: 12px; }
  .sd { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; color: var(--text-2); }
  .msg { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; }
  .msg i { font-size: 34px; color: var(--ok); }
  .msg.bad i { color: var(--danger); }
  .big { font-size: 26px; font-weight: 600; }
  .err { position: absolute; left: 12px; right: 12px; bottom: 12px; display: flex; align-items: center; gap: 8px; padding: 8px 10px; border-radius: var(--radius); background: var(--danger-bg); border: 1px solid var(--danger-line); color: var(--danger-text); font-size: 12px; font-weight: 600; }
  .pad { display: grid; grid-template-columns: 1fr 130px; gap: 14px; }
  .keys { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .key { height: 46px; border-radius: 8px; border: 1px solid #2B3A50; border-bottom-width: 3px; background: linear-gradient(180deg, #24324A, #1A2433); color: var(--text); font-size: 18px; font-weight: 600; }
  .key:active:not(:disabled) { transform: translateY(2px); border-bottom-width: 1px; }
  .key:disabled { opacity: 0.5; }
  .key.clear { background: linear-gradient(180deg, #4a3816, #33270F); border-color: #5C4416; color: var(--accent-2); font-size: 15px; }
  .key.enter { background: linear-gradient(180deg, #1F5B3E, #133A28); border-color: #1F5B3E; color: var(--ok-text); font-size: 15px; }
  .side { display: flex; flex-direction: column; gap: 10px; }
  .sk { height: 46px; border-radius: 8px; border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); font-size: 13px; font-weight: 600; display: flex; align-items: center; justify-content: center; gap: 8px; }
  .sk:hover { color: var(--text); background: var(--panel-3); }
  .slot { height: 46px; border-radius: 8px; background: #070B10; border: 1px solid var(--line-2); display: grid; place-items: center; }
  .slot span { width: 76px; height: 5px; border-radius: 3px; background: #000; box-shadow: 0 0 6px rgba(61, 214, 140, 0.6); }
  .cash { flex: 1; border-radius: 8px; background: #070B10; border: 1px solid var(--line-2); display: grid; place-items: center; }
  .cash span { width: 96px; height: 8px; border-radius: 3px; background: #000; }
</style>
