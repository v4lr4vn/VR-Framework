<script>
  import { onMount } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import Avatar from '../../ui/Avatar.svelte';
  import Segmented from '../../ui/kit/Segmented.svelte';
  import { phone } from '../../lib/store.svelte.js';
  import { comms, labelFor, nameFor } from '../../lib/comms.svelte.js';
  import { post } from '../../lib/nui.js';
  import { scopedError } from '../../lib/errors.js';
  import { stampDay } from '../../lib/time.js';
  import { money } from '../../lib/money.js';
  import { t } from '../../lib/i18n.js';

  // Your money, sending it to another phone number, and asking for it. The server moves the money; this screen only asks.
  let data = $state(null);
  let loaded = $state(false);
  let mode = $state('send'); // 'send' | 'request'
  let step = $state('form'); // 'form' | 'confirm' | 'done'
  let number = $state('');
  let amount = $state('');
  let note = $state('');
  let error = $state('');
  let busy = $state(false);
  let outcome = $state(null); // what the last transfer did, for the done page
  let timer = 0;

  const limits = $derived(data?.limits ?? phone.features?.wallet ?? { min: 1, max: 25000, note: 60 });
  const cents = $derived(Math.floor(Number(amount) || 0));
  const target = $derived(nameFor(number.trim()));
  const picks = $derived.by(() => {
    const seen = new Set();
    const out = [];
    for (const n of data?.recents ?? []) {
      if (!seen.has(n)) {
        seen.add(n);
        out.push(n);
      }
    }
    for (const c of comms.contacts) {
      if (out.length >= 10) break;
      if (c.blocked || seen.has(c.number)) continue;
      seen.add(c.number);
      out.push(c.number);
    }
    return out;
  });
  const ready = $derived(number.trim().length >= 3 && cents >= (limits.min ?? 1) && cents <= (limits.max ?? 25000));

  async function load() {
    const r = await post('walletOverview');
    if (r?.ok) data = r.wallet;
    loaded = true;
  }

  onMount(() => {
    load();
    timer = setInterval(load, 15000);
    return () => clearInterval(timer);
  });

  function onAmount(e) {
    amount = e.currentTarget.value.replace(/\D/g, '').slice(0, 7);
  }

  function review() {
    error = '';
    if (!ready) return;
    if (mode === 'send' && data && cents > data.bank) {
      error = t('wallet.err.no_funds');
      return;
    }
    step = 'confirm';
  }

  async function submit() {
    if (busy) return;
    busy = true;
    error = '';
    const body = { number: number.trim(), amount: cents, note: note.trim() };
    const r = await post(mode === 'send' ? 'walletSend' : 'walletRequest', body);
    busy = false;
    if (!r?.ok) {
      error = scopedError(r?.reason, 'wallet');
      step = 'form';
      return;
    }
    outcome = { mode, amount: cents, number: body.number };
    step = 'done';
    number = '';
    amount = '';
    note = '';
    load();
  }

  function again() {
    step = 'form';
    outcome = null;
    error = '';
  }

  async function answer(req, accept) {
    if (busy) return;
    busy = true;
    error = '';
    const r = await post('walletRespond', { id: req.id, accept });
    busy = false;
    if (!r?.ok) error = scopedError(r?.reason, 'wallet');
    load();
  }

  async function cancel(req) {
    const r = await post('walletCancel', { id: req.id });
    if (!r?.ok) error = scopedError(r?.reason, 'wallet');
    load();
  }

  const kindLabel = (k) => {
    const key = `wallet.kind.${k}`;
    const text = t(key);
    return text !== key ? text : String(k ?? '').replace(/_/g, ' ');
  };
</script>

{#snippet hero()}
  <div class="hero">
    <div class="lbl">{t('wallet.bank')}</div>
    <div class="big">{loaded && data ? money(data.bank) : '–'}</div>
    <div class="pills">
      <span class="pill"><Glyph name="bag" size={14} stroke={2} />{t('wallet.cash')} {data ? money(data.cash) : '–'}</span>
      {#if data?.account}<span class="pill soft">{t('wallet.account')} {data.account}</span>{/if}
    </div>
  </div>

  {#if step === 'form'}
    <div class="ap-form pay">
      <Segmented
        label={t('wallet.mode')}
        value={mode}
        onchange={(v) => {
          mode = v;
          error = '';
        }}
        options={[
          { value: 'send', label: t('wallet.send') },
          { value: 'request', label: t('wallet.request') },
        ]}
      />
      <label>
        <span>{mode === 'send' ? t('wallet.to') : t('wallet.from')}</span>
        <input type="text" inputmode="tel" bind:value={number} maxlength="20" placeholder={t('wallet.numberPlaceholder')} />
      </label>
      {#if target}<p class="who"><Avatar name={target} number={number} size={22} />{target}</p>{/if}
      {#if picks.length}
        <div class="picks">
          {#each picks as n (n)}
            <button class="pick" class:on={number.trim() === n} onclick={() => (number = n)}>
              <Avatar name={nameFor(n)} number={n} size={34} />
              <span>{labelFor(n)}</span>
            </button>
          {/each}
        </div>
      {/if}
      <label>
        <span>{t('wallet.amount')}</span>
        <div class="amt"><b>$</b><input type="text" inputmode="numeric" value={amount} oninput={onAmount} placeholder="0" /></div>
      </label>
      <div class="ap-chips">
        {#each [20, 50, 100, 500] as v (v)}
          <button class="ap-chip" class:on={cents === v} onclick={() => (amount = String(v))}>${v}</button>
        {/each}
      </div>
      <label>
        <span>{t('wallet.note')}</span>
        <input type="text" bind:value={note} maxlength={limits.note ?? 60} placeholder={t('wallet.notePlaceholder')} />
      </label>
      {#if mode === 'send' && data}<p class="ap-note">{t('wallet.left', { left: money(data.limits.left) })}</p>{/if}
      {#if error}<p class="ap-err">{error}</p>{/if}
      <div class="ap-btns">
        <button class="ap-btn main" disabled={!ready || busy} onclick={review}>
          {mode === 'send' ? t('wallet.review') : t('wallet.askFor')}
        </button>
      </div>
    </div>
  {:else if step === 'confirm'}
    <div class="ap-form sure">
      <h2>{mode === 'send' ? t('wallet.confirmSend') : t('wallet.confirmAsk')}</h2>
      <div class="sum">
        <Avatar name={target} number={number} size={54} />
        <div class="amount">{money(cents)}</div>
        <div class="to">{mode === 'send' ? t('wallet.toWho', { who: target || number }) : t('wallet.fromWho', { who: target || number })}</div>
        {#if target}<div class="num">{number}</div>{/if}
        {#if note.trim()}<div class="memo">“{note.trim()}”</div>{/if}
      </div>
      {#if error}<p class="ap-err">{error}</p>{/if}
      <div class="ap-btns">
        <button class="ap-btn" onclick={() => (step = 'form')} disabled={busy}>{t('common.back')}</button>
        <button class="ap-btn main" onclick={submit} disabled={busy}>{mode === 'send' ? t('wallet.sendNow') : t('wallet.askNow')}</button>
      </div>
    </div>
  {:else}
    <div class="ap-none done">
      <div class="tick"><Glyph name="check" size={34} stroke={2.6} /></div>
      <h2>{outcome?.mode === 'send' ? t('wallet.sent') : t('wallet.asked')}</h2>
      <p>{outcome?.mode === 'send'
          ? t('wallet.sentText', { amount: money(outcome.amount), who: labelFor(outcome.number) })
          : t('wallet.askedText', { amount: money(outcome?.amount), who: labelFor(outcome?.number) })}</p>
      <button class="ap-btn main" onclick={again}>{t('wallet.another')}</button>
    </div>
  {/if}
{/snippet}

{#snippet history()}
  {#if data?.incoming?.length}
    <div class="ap-label first">{t('wallet.requestsToYou')}</div>
    <ul class="ap-list">
      {#each data.incoming as r (r.id)}
        <li class="req">
          <Avatar name={nameFor(r.number)} number={r.number} size={38} />
          <span class="txt">
            <span class="ttl">{labelFor(r.number)}</span>
            <span class="sub">{money(r.amount)}{r.note ? ` · ${r.note}` : ''}</span>
          </span>
          <button class="mini" onclick={() => answer(r, false)} disabled={busy}>{t('wallet.decline')}</button>
          <button class="mini main" onclick={() => answer(r, true)} disabled={busy}>{t('wallet.pay')}</button>
        </li>
      {/each}
    </ul>
  {/if}
  {#if data?.outgoing?.length}
    <div class="ap-label" class:first={!data?.incoming?.length}>{t('wallet.yourRequests')}</div>
    <ul class="ap-list">
      {#each data.outgoing as r (r.id)}
        <li class="req">
          <Avatar name={nameFor(r.number)} number={r.number} size={38} />
          <span class="txt">
            <span class="ttl">{labelFor(r.number)}</span>
            <span class="sub">{t('wallet.waiting')} · {money(r.amount)}</span>
          </span>
          <button class="mini" onclick={() => cancel(r)}>{t('common.cancel')}</button>
        </li>
      {/each}
    </ul>
  {/if}
  {#if error && step !== 'form'}<p class="ap-err pad">{error}</p>{/if}

  <div class="ap-label" class:first={!data?.incoming?.length && !data?.outgoing?.length}>{t('wallet.transfers')}</div>
  {#if !loaded}
    <p class="ap-empty">{t('common.loading')}</p>
  {:else if !data?.transfers?.length}
    <p class="ap-empty">{t('wallet.noTransfers')}</p>
  {:else}
    <ul class="ap-list">
      {#each data.transfers as r (r.id)}
        <li class="line">
          <span class="dir" class:in={r.kind === 'received'}><Glyph name={r.kind === 'received' ? 'arrow-down' : 'arrow-up'} size={16} stroke={2.4} /></span>
          <span class="txt">
            <span class="ttl">{labelFor(r.number)}</span>
            <span class="sub">{stampDay(r.at, Date.now())}{r.note ? ` · ${r.note}` : ''}</span>
          </span>
          <b class="val" class:in={r.kind === 'received'}>{r.kind === 'received' ? '+' : '-'}{money(r.amount)}</b>
        </li>
      {/each}
    </ul>
  {/if}

  {#if data?.bankLines?.length}
    <div class="ap-label">{t('wallet.bankActivity')}</div>
    <ul class="ap-list">
      {#each data.bankLines as r (r.id)}
        <li class="line">
          <span class="dir" class:in={r.amount > 0}><Glyph name={r.amount > 0 ? 'arrow-down' : r.amount < 0 ? 'arrow-up' : 'minus'} size={16} stroke={2.4} /></span>
          <span class="txt">
            <span class="ttl">{r.reason || kindLabel(r.kind)}</span>
            <span class="sub">{stampDay(r.at, Date.now())} · {kindLabel(r.kind)}</span>
          </span>
          <b class="val" class:in={r.amount > 0}>{r.amount > 0 ? '+' : ''}{money(r.amount)}</b>
        </li>
      {/each}
    </ul>
  {/if}
{/snippet}

<TwoPane list={history} detail={hero} cover="stack" swap />

<style>
  .hero {
    padding: 8px 4px 14px;
    text-align: center;
  }
  .lbl {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .big {
    margin-top: 2px;
    font-size: 44px;
    font-weight: 700;
    letter-spacing: -0.02em;
  }
  .pills {
    display: flex;
    flex-wrap: wrap;
    justify-content: center;
    gap: 8px;
    margin-top: 8px;
  }
  .pill {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 6px 12px;
    border-radius: 16px;
    background: var(--accent-soft);
    font-size: 13px;
    font-weight: 700;
  }
  .pill.soft {
    background: var(--surface-2);
    color: var(--ink-3);
    font-weight: 600;
  }
  .pay,
  .sure {
    padding: 0 2px 10px;
  }
  .who {
    display: flex;
    align-items: center;
    gap: 8px;
    margin: -6px 0 0;
    font-size: 14px;
    font-weight: 700;
  }
  .picks {
    display: flex;
    gap: 10px;
    overflow-x: auto;
    padding: 2px 0 6px;
  }
  .pick {
    flex: none;
    width: 62px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 6px 2px;
    border-radius: 12px;
    font-size: 11.5px;
    font-weight: 600;
    color: var(--ink);
  }
  .pick span {
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .pick.on {
    background: var(--accent-soft);
  }
  .amt {
    display: flex;
    align-items: center;
    gap: 6px;
    padding: 0 14px;
    border-radius: 14px;
    background: var(--surface-2);
  }
  .amt b {
    font-size: 26px;
    color: var(--ink-3);
  }
  .amt input {
    flex: 1;
    min-width: 0;
    height: 52px;
    border: 0;
    background: none;
    font-size: 28px;
    font-weight: 700;
    color: var(--ink);
  }
  .amt input:focus-visible {
    outline: none;
  }
  .sum {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    padding: 18px 8px;
    border-radius: var(--r-l);
    background: var(--surface);
    text-align: center;
  }
  .amount {
    font-size: 40px;
    font-weight: 700;
    letter-spacing: -0.02em;
  }
  .to {
    font-size: 16px;
    font-weight: 700;
  }
  .num,
  .memo {
    font-size: 13px;
    color: var(--ink-3);
  }
  .done .tick {
    width: 64px;
    height: 64px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: #2fa84f;
    color: #fff;
  }
  .done h2 {
    margin: 0;
    font-size: 22px;
    color: var(--ink);
  }
  .req,
  .line {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 8px 6px;
  }
  .txt {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .ttl {
    font-size: 15px;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sub {
    font-size: 12.5px;
    color: var(--ink-3);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .mini {
    flex: none;
    padding: 7px 12px;
    border-radius: 12px;
    background: var(--surface-2);
    font-size: 13px;
    font-weight: 700;
    color: var(--ink);
  }
  .mini.main {
    background: var(--accent);
    color: var(--on-accent);
  }
  .mini:disabled {
    opacity: 0.5;
  }
  .dir {
    flex: none;
    width: 34px;
    height: 34px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: var(--surface-2);
    color: var(--ink-3);
  }
  .dir.in {
    background: rgba(47, 168, 79, 0.14);
    color: #2fa84f;
  }
  .val {
    flex: none;
    font-size: 15px;
    font-variant-numeric: tabular-nums;
  }
  .val.in {
    color: #2fa84f;
  }
  .pad {
    margin: 8px 6px;
  }
</style>
