<script>
  import { app, refresh, go } from '../lib/store.svelte.js';
  import { close } from '../lib/api.js';
  import { money, acct, TYPE } from '../lib/format.js';
  import AccountView from './AccountView.svelte';
  import CardsView from './CardsView.svelte';
  import LoansView from './LoansView.svelte';
  import CreditView from './CreditView.svelte';
  import DebtView from './DebtView.svelte';
  import Collections from './Collections.svelte';
  import OpenAccount from './OpenAccount.svelte';
  import Toast from '../ui/Toast.svelte';

  let opening = $state(false);
  let o = $derived(app.overview);
  let activeLoans = $derived(o ? o.loans.filter((l) => l.status === 'active').length : 0);
  let debtTotal = $derived(o ? o.debts.reduce((s, d) => s + d.amount, 0) : 0);

  const tierTone = { exceptional: 'ok', verygood: 'ok', good: 'info', fair: 'warn', poor: 'danger' };

  $effect(() => {
    if (!app.overview) refresh();
  });

  function shut() {
    close();
    app.visible = false;
    app.overview = null;
  }

  const groups = [
    ['personal', 'Personal'],
    ['savings', 'Savings'],
    ['shared', 'Shared'],
    ['job', 'Business'],
    ['gang', 'Organisation'],
  ];
</script>

<section class="shell card" aria-label="Bank">
  <header class="top">
    <div class="brand">
      <span class="logo"><i class="fa-solid fa-building-columns"></i></span>
      <div>
        <h1>{o?.bank || 'ValRavn Bank'}</h1>
        <p class="sub">{o?.branch ? `${o.branch} branch` : 'Branch'}{o ? ` · ${o.me.name}` : ''}</p>
      </div>
    </div>
    {#if o}
      <div class="stats">
        <div class="stat"><span class="k">Cash on you</span><span class="v num">{money(o.me.cash)}</span></div>
        <button class="stat link" onclick={() => go('credit')}>
          <span class="k">Credit score</span>
          <span class="v"><span class="num">{o.me.credit.score}</span><span class="chip {tierTone[o.me.credit.key]}">{o.me.credit.tier}</span></span>
        </button>
      </div>
    {/if}
    <button class="x" onclick={shut} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  <div class="body">
    <nav class="side scroll" aria-label="Accounts and services">
      <div class="side-head">
        <span class="label">Accounts</span>
        <button class="btn small ghost" onclick={() => (opening = true)}><i class="fa-solid fa-plus"></i>Open</button>
      </div>
      {#if o}
        {#each groups as [type]}
          {#each o.accounts.filter((a) => a.type === type) as a (a.id)}
            <button class="acc" class:on={app.view === 'account' && app.accountId === a.id} onclick={() => go('account', a.id)}>
              <span class="aic t-{a.type}"><i class="fa-solid {TYPE[a.type].icon}"></i></span>
              <span class="ainfo">
                <span class="aname">{a.label}</span>
                <span class="anum num">{acct(a.number)}</span>
              </span>
              <span class="abal num">{money(a.balance)}</span>
              {#if a.frozen}<i class="fa-solid fa-snowflake frz" title="Frozen"></i>{/if}
            </button>
          {/each}
        {/each}
      {/if}

      <div class="side-head svc"><span class="label">Services</span></div>
      <button class="nav" class:on={app.view === 'cards'} onclick={() => go('cards')}>
        <i class="fa-solid fa-credit-card"></i><span>Cards</span>{#if o}<span class="count num">{o.cards.length}</span>{/if}
      </button>
      <button class="nav" class:on={app.view === 'loans'} onclick={() => go('loans')}>
        <i class="fa-solid fa-hand-holding-dollar"></i><span>Loans</span>{#if activeLoans}<span class="count num">{activeLoans} active</span>{/if}
      </button>
      <button class="nav" class:on={app.view === 'credit'} onclick={() => go('credit')}>
        <i class="fa-solid fa-gauge-high"></i><span>Credit report</span>
      </button>
      {#if o && (o.debts.length || o.held.length)}
        <button class="nav alert" class:on={app.view === 'debt'} onclick={() => go('debt')}>
          <i class="fa-solid fa-triangle-exclamation"></i><span>Debt</span><span class="count num">{money(debtTotal)}</span>
        </button>
      {/if}
      {#if o?.collector}
        <button class="nav" class:on={app.view === 'collections'} onclick={() => go('collections')}>
          <i class="fa-solid fa-file-invoice-dollar"></i><span>Collections board</span>
        </button>
      {/if}
    </nav>

    <main class="main scroll">
      {#if !o}
        <div class="empty"><i class="fa-solid fa-circle-notch fa-spin"></i>Loading your accounts</div>
      {:else if app.view === 'account'}
        {#key app.accountId}
          <AccountView />
        {/key}
      {:else if app.view === 'cards'}
        <CardsView />
      {:else if app.view === 'loans'}
        <LoansView />
      {:else if app.view === 'credit'}
        <CreditView />
      {:else if app.view === 'debt'}
        <DebtView />
      {:else if app.view === 'collections'}
        <Collections embedded={true} />
      {/if}
    </main>
  </div>

  {#if opening}
    <OpenAccount onclose={() => (opening = false)} />
  {/if}
  <Toast />
</section>

<style>
  .shell { position: relative; width: 1220px; height: 740px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  .top { display: flex; align-items: center; gap: 18px; padding: 14px 18px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .brand { display: flex; align-items: center; gap: 12px; flex: 1; min-width: 0; }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 17px; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .stats { display: flex; gap: 8px; }
  .stat { display: flex; flex-direction: column; gap: 1px; padding: 6px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); text-align: left; color: inherit; }
  .stat.link:hover { border-color: var(--line-3); background: var(--panel-2); }
  .stat .k { font-size: 10px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); font-weight: 600; }
  .stat .v { display: flex; align-items: center; gap: 8px; font-size: 15px; font-weight: 600; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }

  .body { flex: 1; display: grid; grid-template-columns: 300px 1fr; min-height: 0; }
  .side { padding: 12px 10px; border-right: 1px solid var(--line-2); background: rgba(13, 18, 26, 0.55); display: flex; flex-direction: column; gap: 4px; }
  .side-head { display: flex; align-items: center; justify-content: space-between; padding: 2px 6px 6px; }
  .side-head.svc { margin-top: 12px; padding-top: 12px; border-top: 1px solid var(--line-2); }
  .acc { display: grid; grid-template-columns: 32px 1fr auto; align-items: center; gap: 10px; padding: 9px 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; text-align: left; color: inherit; position: relative; }
  .acc:hover { background: var(--panel); }
  .acc.on { background: var(--panel-2); border-color: var(--line-3); }
  .acc.on::before { content: ''; position: absolute; left: -10px; top: 8px; bottom: 8px; width: 3px; border-radius: 0 3px 3px 0; background: var(--accent); }
  .aic { width: 32px; height: 32px; border-radius: var(--radius); display: grid; place-items: center; font-size: 13px; background: var(--panel-3); }
  .t-personal { color: var(--accent); background: var(--accent-soft); }
  .t-savings { color: var(--ok); background: var(--ok-bg); }
  .t-shared { color: var(--info); background: var(--info-bg); }
  .t-job { color: var(--accent-2); background: rgba(255, 200, 92, 0.1); }
  .t-gang { color: var(--doj); background: var(--doj-bg); }
  .ainfo { display: flex; flex-direction: column; min-width: 0; }
  .aname { font-size: 13px; font-weight: 600; color: var(--text); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .anum { font-size: 11px; color: var(--faint); }
  .abal { font-size: 13px; font-weight: 600; color: var(--text-2); }
  .frz { position: absolute; right: 8px; top: 6px; font-size: 9px; color: var(--info); }
  .nav { display: flex; align-items: center; gap: 10px; height: 38px; padding: 0 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--text-2); font-size: 13px; font-weight: 600; text-align: left; }
  .nav i { width: 18px; color: var(--muted); }
  .nav span:first-of-type { flex: 1; }
  .nav .count { font-size: 11px; color: var(--faint); font-weight: 500; }
  .nav:hover { background: var(--panel); color: var(--text); }
  .nav.on { background: var(--panel-2); border-color: var(--line-3); color: var(--text); }
  .nav.on i { color: var(--accent); }
  .nav.alert i, .nav.alert .count { color: var(--danger-text); }
  .main { padding: 18px 20px; min-height: 0; }
</style>
