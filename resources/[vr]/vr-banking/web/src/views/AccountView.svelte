<script>
  import { app, act, go } from '../lib/store.svelte.js';
  import { call } from '../lib/api.js';
  import { money, signed, acct, dateTime, until, TYPE, KIND } from '../lib/format.js';
  import { errorText } from '../lib/errors.js';
  import MoveMoney from './MoveMoney.svelte';
  import Modal from '../ui/Modal.svelte';

  let detail = $state(null);
  let tab = $state('activity');
  let moving = $state(null);
  let renaming = $state(false);
  let closing = $state(false);
  let newLabel = $state('');
  let memberCid = $state('');
  let memberRole = $state('member');
  let copied = $state(false);

  let base = $derived(app.overview?.accounts.find((a) => a.id === app.accountId));
  let a = $derived(detail?.account && base ? { ...base, ...detail.account, balance: base.balance } : base);
  let r = $derived(a?.rights || {});
  let stamp = $derived(app.stamp);

  async function load() {
    if (!app.accountId) return;
    const res = await call('history', { account: app.accountId });
    if (res.ok) detail = res.data;
  }

  $effect(() => {
    stamp;
    load();
  });

  function copy() {
    const t = document.createElement('textarea');
    t.value = a.number;
    document.body.appendChild(t);
    t.select();
    try { document.execCommand('copy'); } catch {}
    t.remove();
    copied = true;
    setTimeout(() => (copied = false), 1400);
  }

  async function rename(e) {
    e.preventDefault();
    const res = await act('account.rename', { account: a.id, label: newLabel }, 'Account renamed');
    if (res.ok) renaming = false;
  }

  async function closeAccount() {
    const res = await act('account.close', { account: a.id }, (d) => (d.moved ? `Closed. ${money(d.moved)} moved to your personal account` : 'Account closed'));
    if (res.ok) {
      closing = false;
      go('account', app.overview?.accounts[0]?.id);
    }
  }

  async function addMember(e) {
    e.preventDefault();
    const res = await act('members.add', { account: a.id, cid: memberCid.trim(), role: memberRole }, (d) => `${d.name} added`);
    if (res.ok) memberCid = '';
  }

  const roleIcon = { owner: 'fa-crown', manager: 'fa-user-shield', member: 'fa-user' };
  const roleText = { owner: 'Owner', manager: 'Manager', member: 'Member' };
  const describe = (t) => t.reason || KIND[t.kind]?.label || t.kind;
</script>

{#if a}
  <div class="head">
    <div class="ident">
      <span class="chip t-{a.type}"><i class="fa-solid {TYPE[a.type].icon}"></i>{TYPE[a.type].label}</span>
      {#if a.frozen}<span class="chip info"><i class="fa-solid fa-snowflake"></i>Frozen</span>{/if}
      {#if a.myRole}<span class="chip"><i class="fa-solid {roleIcon[a.myRole]}"></i>{roleText[a.myRole]}</span>{/if}
    </div>
    <div class="title-row">
      <h2>{a.label}</h2>
      {#if (a.type === 'shared' || a.type === 'savings') && r.manage}
        <button class="btn small ghost icon" title="Rename" onclick={() => { newLabel = a.label; renaming = true; }}><i class="fa-solid fa-pen"></i></button>
      {/if}
    </div>
    <button class="number num" onclick={copy} title="Copy account number">
      {acct(a.number)} <i class="fa-regular {copied ? 'fa-circle-check' : 'fa-copy'}"></i>{#if copied}<span class="copied">Copied</span>{/if}
    </button>

    <div class="balance-row">
      <div>
        <span class="label">Available balance</span>
        <div class="balance num">{money(a.balance)}</div>
      </div>
      <div class="actions">
        <button class="btn" disabled={!r.deposit} onclick={() => (moving = 'deposit')}><i class="fa-solid fa-arrow-down"></i>Deposit</button>
        <button class="btn" disabled={!r.withdraw || a.frozen} onclick={() => (moving = 'withdraw')}><i class="fa-solid fa-arrow-up"></i>Withdraw</button>
        <button class="btn primary" disabled={!r.transfer || a.frozen} onclick={() => (moving = 'transfer')}><i class="fa-solid fa-arrow-right-arrow-left"></i>Send money</button>
      </div>
    </div>

    {#if a.type === 'savings'}
      <div class="notice ok">
        <i class="fa-solid fa-piggy-bank"></i>
        <span>Earning <strong>{a.rate}%</strong> every {app.overview.settings.savings.periodHours}h on balances over {money(app.overview.settings.savings.minBalance)}. Next interest {until(a.nextInterest)}.</span>
      </div>
    {:else if a.type === 'personal'}
      <div class="notice"><i class="fa-solid fa-circle-info"></i><span>This is your main account. Wages, card payments and loan installments use it.</span></div>
    {:else if a.type === 'job' || a.type === 'gang'}
      <div class="notice"><i class="fa-solid fa-briefcase"></i><span>You can manage this account because of your rank. Everything you do here is logged.</span></div>
    {/if}
  </div>

  <div class="tabs">
    <button class="tab" class:on={tab === 'activity'} onclick={() => (tab = 'activity')}><i class="fa-solid fa-list"></i>Activity</button>
    {#if a.type === 'shared'}
      <button class="tab" class:on={tab === 'members'} onclick={() => (tab = 'members')}><i class="fa-solid fa-users"></i>Members <span class="count">{a.members?.length || 0}</span></button>
    {/if}
    {#if r.manage && detail?.cards?.length}
      <button class="tab" class:on={tab === 'cards'} onclick={() => (tab = 'cards')}><i class="fa-solid fa-credit-card"></i>Cards <span class="count">{detail.cards.length}</span></button>
    {/if}
    {#if (a.type === 'shared' || a.type === 'savings') && r.owner}
      <button class="tab right" onclick={() => (closing = true)}><i class="fa-solid fa-door-closed"></i>Close account</button>
    {/if}
  </div>

  {#if tab === 'activity'}
    {#if !detail}
      <div class="empty"><i class="fa-solid fa-circle-notch fa-spin"></i>Loading activity</div>
    {:else if !detail.history.length}
      <div class="empty"><i class="fa-solid fa-receipt"></i>No transactions yet</div>
    {:else}
      <div class="tx">
        {#each detail.history as t (t.id)}
          <div class="trow">
            <span class="tic" class:in={t.amount > 0}><i class="fa-solid {KIND[t.kind]?.icon || 'fa-circle'}"></i></span>
            <div class="tdesc">
              <span class="tname">{describe(t)}</span>
              <span class="tmeta">
                {KIND[t.kind]?.label || t.kind}
                {#if t.other} · <span class="num">{acct(t.other)}</span>{/if}
                {#if t.card} · card {t.card}{/if}
                {#if t.actor_name && a.type !== 'personal'} · {t.actor_name}{/if}
              </span>
            </div>
            <span class="tdate num">{dateTime(t.at)}</span>
            <span class="tamt num" class:pos={t.amount > 0}>{t.amount === 0 ? '—' : signed(t.amount)}</span>
            <span class="tbal num">{t.balance != null ? money(t.balance) : ''}</span>
          </div>
        {/each}
      </div>
    {/if}
  {:else if tab === 'members' && a.type === 'shared'}
    <div class="members">
      {#each a.members || [] as m (m.cid)}
        <div class="mrow">
          <span class="mic"><i class="fa-solid {roleIcon[m.role]}"></i></span>
          <div class="minfo"><strong>{m.name}{m.me ? ' (you)' : ''}</strong><span class="num">{m.cid}</span></div>
          <span class="chip {m.role === 'owner' ? 'accent' : m.role === 'manager' ? 'info' : ''}">{roleText[m.role]}</span>
          <div class="mact">
            {#if r.manage && m.role !== 'owner'}
              <select class="input small" value={m.role} onchange={(e) => act('members.role', { account: a.id, cid: m.cid, role: e.currentTarget.value }, 'Role updated')}>
                <option value="member">Member</option>
                <option value="manager">Manager</option>
              </select>
              <button class="btn small danger" onclick={() => act('members.remove', { account: a.id, cid: m.cid }, `${m.name} removed`)}>Remove</button>
            {:else if m.me && m.role !== 'owner'}
              <button class="btn small danger" onclick={() => act('members.remove', { account: a.id, cid: m.cid }, 'You left the account')}>Leave</button>
            {/if}
          </div>
        </div>
      {/each}
      <p class="hint roles"><strong>Members</strong> can deposit and see activity. <strong>Managers</strong> can also withdraw, send money and order a card.</p>
      {#if r.manage}
        <form class="add" onsubmit={addMember}>
          <input class="input num" placeholder="State ID" maxlength="16" bind:value={memberCid} />
          <select class="input" bind:value={memberRole}>
            <option value="member">Member</option>
            <option value="manager">Manager</option>
          </select>
          <button class="btn primary" disabled={app.busy || memberCid.trim().length < 3}><i class="fa-solid fa-user-plus"></i>Add</button>
        </form>
      {/if}
    </div>
  {:else if tab === 'cards'}
    <div class="members">
      {#each detail.cards as c (c.id)}
        <div class="mrow">
          <span class="mic"><i class="fa-solid fa-credit-card"></i></span>
          <div class="minfo"><strong>{c.holder}</strong><span class="num">•••• {c.last4}</span></div>
          <span class="chip {c.status === 'active' ? 'ok' : 'info'}">{c.status === 'active' ? 'Active' : 'Frozen'}</span>
          <div class="mact">
            <button class="btn small" onclick={() => act('cards.freeze', { card: c.id, frozen: c.status === 'active' }, c.status === 'active' ? 'Card frozen' : 'Card unfrozen')}>{c.status === 'active' ? 'Freeze' : 'Unfreeze'}</button>
            <button class="btn small danger" onclick={() => act('cards.cancel', { card: c.id }, 'Card cancelled')}>Cancel</button>
          </div>
        </div>
      {/each}
    </div>
  {/if}

  {#if moving}
    <MoveMoney account={a} mode={moving} onclose={() => (moving = null)} />
  {/if}

  {#if renaming}
    <Modal title="Rename account" icon="fa-pen" onclose={() => (renaming = false)} width={400}>
      <form class="f" onsubmit={rename}>
        <label class="field"><span>Name</span><input class="input" maxlength="32" bind:value={newLabel} /></label>
        <div class="row"><button type="button" class="btn ghost" onclick={() => (renaming = false)}>Cancel</button><button class="btn primary" disabled={newLabel.trim().length < 2}>Save</button></div>
      </form>
    </Modal>
  {/if}

  {#if closing}
    <Modal title="Close account" icon="fa-door-closed" onclose={() => (closing = false)} width={420}>
      <p class="msg">Close <strong>{a.label}</strong>? {a.balance > 0 ? `The ${money(a.balance)} left in it moves to your personal account.` : ''} Cards linked to it stop working.</p>
      <div class="row"><button class="btn ghost" onclick={() => (closing = false)}>Keep it</button><button class="btn danger" disabled={app.busy} onclick={closeAccount}>Close account</button></div>
    </Modal>
  {/if}
{:else}
  <div class="empty"><i class="fa-solid fa-building-columns"></i>Pick an account</div>
{/if}

<style>
  .head { display: flex; flex-direction: column; gap: 6px; margin-bottom: 16px; }
  .ident { display: flex; gap: 6px; }
  .t-personal { color: var(--accent-2); background: var(--accent-soft); border-color: var(--accent-line); }
  .t-savings { color: var(--ok-text); background: var(--ok-bg); border-color: var(--ok-line); }
  .t-shared { color: var(--info-text); background: var(--info-bg); border-color: var(--info-line); }
  .t-gang { color: var(--doj-text); background: var(--doj-bg); border-color: #3d2f66; }
  .title-row { display: flex; align-items: center; gap: 8px; margin-top: 4px; }
  h2 { font-size: 22px; font-weight: 700; }
  .number { align-self: flex-start; display: inline-flex; align-items: center; gap: 8px; padding: 0; background: none; border: 0; color: var(--muted); font-size: 13px; }
  .number:hover { color: var(--text); }
  .copied { font-family: var(--font); font-size: 11px; color: var(--ok-text); }
  .balance-row { display: flex; align-items: flex-end; justify-content: space-between; gap: 16px; margin: 10px 0 6px; }
  .balance { font-size: 34px; font-weight: 600; line-height: 1.15; }
  .actions { display: flex; gap: 8px; }
  .tab.right { margin-left: auto; color: var(--danger-text); }

  .tx { display: flex; flex-direction: column; }
  .trow { display: grid; grid-template-columns: 34px 1fr 96px 110px 110px; align-items: center; gap: 12px; padding: 10px 4px; border-bottom: 1px solid var(--line); }
  .tic { width: 30px; height: 30px; border-radius: 50%; display: grid; place-items: center; background: var(--panel-2); color: var(--muted); font-size: 11px; }
  .tic.in { background: var(--ok-bg); color: var(--ok); }
  .tdesc { display: flex; flex-direction: column; min-width: 0; }
  .tname { font-size: 13px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .tmeta { font-size: 11px; color: var(--faint); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .tdate { font-size: 11px; color: var(--muted); }
  .tamt { text-align: right; font-size: 13px; font-weight: 600; color: var(--text-2); }
  .tbal { text-align: right; font-size: 12px; color: var(--faint); }

  .members { display: flex; flex-direction: column; gap: 6px; padding-top: 12px; }
  .mrow { display: grid; grid-template-columns: 32px 1fr auto auto; align-items: center; gap: 12px; padding: 8px 10px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .mic { width: 30px; height: 30px; border-radius: 50%; display: grid; place-items: center; background: var(--panel-2); color: var(--muted); font-size: 12px; }
  .minfo { display: flex; flex-direction: column; }
  .minfo strong { font-size: 13px; }
  .minfo span { font-size: 11px; color: var(--faint); }
  .mact { display: flex; gap: 6px; }
  .input.small { height: 28px; font-size: 12px; width: 110px; }
  .roles { margin: 6px 2px; }
  .add { display: grid; grid-template-columns: 1fr 140px auto; gap: 8px; margin-top: 4px; }
  .f { display: flex; flex-direction: column; gap: 14px; }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
  .msg { font-size: 14px; color: var(--text-2); line-height: 1.5; }
</style>
