<script>
  import { call, close, trace as traceWaypoint } from '../lib/api.js';
  import { app, toast } from '../lib/store.svelte.js';
  import { money, ago, until } from '../lib/format.js';
  import { errorText } from '../lib/errors.js';
  import Toast from '../ui/Toast.svelte';

  let { embedded = false } = $props();
  let data = $state(null);
  let sel = $state(null);
  let filter = $state('all');
  let noteText = $state('');
  let busy = $state(false);

  async function load() {
    const r = await call('collections.list');
    if (!r.ok) return toast(errorText(r.error), 'err');
    data = r.data;
    if (!sel || !data.cases.find((c) => c.id === sel)) sel = data.cases[0]?.id ?? null;
  }

  $effect(() => {
    load();
    const id = setInterval(load, 20000);
    return () => clearInterval(id);
  });

  let list = $derived(data ? data.cases.filter((c) => filter === 'all' || (filter === 'mine' && c.claimed?.mine) || (filter === 'free' && !c.claimed)) : []);
  let c = $derived(data?.cases.find((x) => x.id === sel));
  let total = $derived(data ? data.cases.reduce((s, x) => s + x.amount, 0) : 0);
  let mine = $derived(data ? data.cases.filter((x) => x.claimed?.mine).length : 0);
  let lockedOut = $derived(c?.claimed && !c.claimed.mine);

  async function run(action, payload, success) {
    if (busy) return null;
    busy = true;
    const r = await call(action, payload);
    busy = false;
    if (!r.ok) {
      toast(errorText(r.error), 'err');
      return null;
    }
    if (success) toast(typeof success === 'function' ? success(r.data) : success, 'ok');
    await load();
    return r;
  }

  async function doTrace(plate) {
    const r = await run('collections.trace', { case: c.id, plate });
    if (!r) return;
    if (r.data.found) {
      traceWaypoint(r.data);
      toast(`Signal found. Waypoint set within ${Math.round(r.data.radius)}m`, 'ok');
    } else toast(`${plate} is not out in the city right now`, 'err');
  }

  async function doLocate(plate) {
    const r = await run('collections.locate', { case: c.id, plate });
    if (!r) return;
    if (r.data.found) {
      traceWaypoint(r.data);
      toast(`Tracker ping on ${plate}. Waypoint set on the car`, 'ok');
    } else toast(`No signal from ${plate} right now`, 'err');
  }

  async function addNote(e) {
    e.preventDefault();
    const r = await run('collections.note', { case: c.id, text: noteText }, 'Note added');
    if (r) noteText = '';
  }

  function shut() {
    close();
    app.visible = false;
  }
</script>

<section class:shell={!embedded} class:card={!embedded} class:embedded aria-label="Collections board">
  {#if !embedded}
    <header class="top">
      <div class="brand">
        <span class="logo"><i class="fa-solid fa-file-invoice-dollar"></i></span>
        <div><h1>Collections board</h1><p class="sub">Debt recovery · {data?.me.name || ''}</p></div>
      </div>
      <button class="x" onclick={shut} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    </header>
  {/if}

  <div class="statrow" class:pad={!embedded}>
    <div class="st"><span class="k">Open cases</span><span class="v num">{data?.cases.length ?? '—'}</span></div>
    <div class="st"><span class="k">Total owed</span><span class="v num">{money(total)}</span></div>
    <div class="st"><span class="k">Claimed by you</span><span class="v num">{mine}</span></div>
    <div class="st"><span class="k">Your cut</span><span class="v">{data ? `${data.settings.commission}% collected · ${money(data.settings.repoPay)} per repo` : '—'}</span></div>
  </div>

  <div class="grid" class:pad={!embedded}>
    <div class="list box">
      <div class="filters">
        {#each [['all', 'All'], ['free', 'Unclaimed'], ['mine', 'Mine']] as [k, t]}
          <button class="pill" class:on={filter === k} onclick={() => (filter = k)}>{t}</button>
        {/each}
      </div>
      <div class="items scroll">
        {#if data && !list.length}
          <div class="empty"><i class="fa-solid fa-mug-hot"></i>No cases here</div>
        {/if}
        {#each list as x (x.id)}
          <button class="item" class:on={sel === x.id} onclick={() => (sel = x.id)}>
            <div class="l1">
              <span class="name"><span class="dot" class:online={x.online}></span>{x.name}</span>
              <span class="amt num">{money(x.amount)}</span>
            </div>
            <div class="l2">
              <span class="muted">#{x.id} · {ago(x.created)}</span>
              <span class="tags">
                <span class="chip"><i class="fa-solid fa-car"></i>{x.vehicles.filter((v) => !v.held).length}</span>
                {#if x.claimed}<span class="chip {x.claimed.mine ? 'accent' : ''}"><i class="fa-solid fa-user-tag"></i>{x.claimed.mine ? 'You' : x.claimed.by}</span>{/if}
              </span>
            </div>
          </button>
        {/each}
      </div>
    </div>

    <div class="detail box">
      {#if !c}
        <div class="empty"><i class="fa-solid fa-file-invoice-dollar"></i>Pick a case</div>
      {:else}
        <div class="dhead">
          <div>
            <span class="label">Case #{c.id}{c.loanId ? ` · defaulted loan #${c.loanId}` : ''}</span>
            <h2>{c.name}</h2>
            <span class="muted small num">{c.cid} · {c.online ? 'in the city' : 'not in the city'}</span>
          </div>
          <div class="owed">
            <span class="label">Owed</span>
            <span class="num big">{money(c.amount)}</span>
          </div>
        </div>

        <div class="claim">
          {#if c.claimed?.mine}
            <span class="chip accent"><i class="fa-solid fa-user-tag"></i>Claimed by you · expires {until(c.claimed.expires)}</span>
            <button class="btn small ghost" disabled={busy} onclick={() => run('collections.release', { case: c.id }, 'Case released')}>Release</button>
          {:else if c.claimed}
            <span class="chip"><i class="fa-solid fa-lock"></i>{c.claimed.by} is working this case · {until(c.claimed.expires)}</span>
          {:else}
            <span class="muted small">Unclaimed. Claim it so nobody else works it for {data.settings.claimMinutes} minutes.</span>
            <button class="btn small primary" disabled={busy} onclick={() => run('collections.claim', { case: c.id }, 'Case claimed')}><i class="fa-solid fa-hand"></i>Claim</button>
          {/if}
        </div>

        <span class="label">Vehicles</span>
        {#if !c.vehicles.length}
          <div class="notice"><i class="fa-solid fa-circle-info"></i><span>No vehicles on record. Collect the money in person instead.</span></div>
        {/if}
        <div class="veh">
          {#each c.vehicles as v}
            <div class="vrow" class:held={v.held}>
              <i class="fa-solid fa-car"></i>
              <span class="vn">{v.name}</span>
              <span class="num plate">{v.plate}</span>
              {#if v.held}
                <span class="chip danger">Seized</span>
              {:else if v.tracked}
                <span class="chips">
                  <span class="chip live"><i class="fa-solid fa-tower-broadcast"></i>Tracker</span>
                  {#if v.staged}<span class="chip warn">Parked by bank</span>{:else}<span class="chip warn">Collateral</span>{/if}
                </span>
                <button class="btn small primary" disabled={busy || lockedOut} onclick={() => doLocate(v.plate)}><i class="fa-solid fa-location-crosshairs"></i>Locate</button>
              {:else}
                {#if v.collateral}<span class="chip warn">Collateral</span>{:else}<span></span>{/if}
                <button class="btn small" disabled={busy || lockedOut} onclick={() => doTrace(v.plate)}><i class="fa-solid fa-satellite-dish"></i>Trace</button>
              {/if}
            </div>
          {/each}
        </div>

        <div class="howto">
          <div><i class="fa-solid fa-tower-broadcast"></i><span>Collateral cars carry a <strong>bank tracker</strong>. They show on your map as red car icons while you are on duty, and the bank parks them on the street if they were in a garage.</span></div>
          <div><i class="fa-solid fa-truck-pickup"></i><span>Find the vehicle and use your eye on it to <strong>Repossess</strong>. Nobody can be in the driver seat. Adds a {money(data.settings.repoFee)} fee to the debt.</span></div>
          <div><i class="fa-solid fa-handshake"></i><span>Meet the debtor and use your eye on them to <strong>Collect debt</strong>. They pay in full from bank or cash.</span></div>
        </div>

        <span class="label">Case log</span>
        <div class="log scroll">
          {#each [...c.log].reverse() as e}
            <div class="lrow"><span class="muted when">{ago(e.at)}</span><span>{e.text}</span></div>
          {/each}
        </div>
        <form class="note" onsubmit={addNote}>
          <input class="input" maxlength="140" placeholder="Add a note for other collectors" bind:value={noteText} disabled={lockedOut} />
          <button class="btn" disabled={busy || noteText.trim().length < 2 || lockedOut}>Add</button>
        </form>
      {/if}
    </div>
  </div>
  {#if !embedded}<Toast />{/if}
</section>

<style>
  .shell { position: relative; width: 1120px; height: 700px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  .embedded { display: flex; flex-direction: column; height: 100%; }
  .top { display: flex; align-items: center; gap: 18px; padding: 14px 18px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .brand { display: flex; align-items: center; gap: 12px; flex: 1; }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--danger-bg); border: 1px solid var(--danger-line); color: var(--danger); font-size: 16px; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .pad { padding-left: 18px; padding-right: 18px; }
  .statrow { display: grid; grid-template-columns: 1fr 1fr 1fr 2fr; gap: 10px; padding-top: 14px; }
  .st { display: flex; flex-direction: column; gap: 2px; padding: 10px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .k { font-size: 10px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); font-weight: 600; }
  .v { font-size: 15px; font-weight: 600; }
  .grid { flex: 1; min-height: 0; display: grid; grid-template-columns: 330px 1fr; gap: 12px; padding-top: 12px; padding-bottom: 16px; }
  .embedded .grid { min-height: 520px; }
  .list { display: flex; flex-direction: column; min-height: 0; }
  .filters { display: flex; gap: 6px; padding: 10px; border-bottom: 1px solid var(--line); }
  .pill { height: 26px; padding: 0 10px; border-radius: 999px; border: 1px solid var(--line-3); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; }
  .pill.on { background: var(--accent-soft); border-color: var(--accent); color: var(--accent-2); }
  .items { flex: 1; min-height: 0; padding: 6px; display: flex; flex-direction: column; gap: 4px; }
  .item { display: flex; flex-direction: column; gap: 4px; padding: 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; text-align: left; color: inherit; }
  .item:hover { background: var(--panel-2); }
  .item.on { background: var(--panel-2); border-color: var(--line-3); }
  .l1, .l2 { display: flex; justify-content: space-between; align-items: center; gap: 8px; }
  .name { display: flex; align-items: center; gap: 8px; font-weight: 600; font-size: 13px; }
  .dot { width: 7px; height: 7px; border-radius: 50%; background: var(--line-3); }
  .dot.online { background: var(--ok); box-shadow: 0 0 0 3px var(--ok-bg); }
  .amt { font-weight: 600; color: var(--danger-text); font-size: 13px; }
  .l2 { font-size: 11px; }
  .tags { display: flex; gap: 4px; }
  .detail { padding: 16px; display: flex; flex-direction: column; gap: 10px; min-height: 0; overflow: auto; }
  .dhead { display: flex; justify-content: space-between; align-items: flex-start; }
  h2 { font-size: 22px; font-weight: 700; margin-top: 2px; }
  .small { font-size: 12px; }
  .owed { display: flex; flex-direction: column; align-items: flex-end; }
  .big { font-size: 28px; font-weight: 600; color: var(--danger-text); }
  .claim { display: flex; align-items: center; justify-content: space-between; gap: 10px; padding: 10px 12px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); }
  .veh { display: flex; flex-direction: column; gap: 6px; }
  .vrow { display: grid; grid-template-columns: 18px 1fr 96px auto auto; align-items: center; gap: 10px; padding: 8px 10px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--line-2); font-size: 13px; }
  .vrow.held { opacity: 0.6; grid-template-columns: 18px 1fr 96px auto; }
  .vrow i { color: var(--muted); }
  .vn { font-weight: 600; }
  .plate { color: var(--accent-2); }
  .howto { display: grid; grid-template-columns: 1fr 1fr 1fr; gap: 8px; }
  .chips { display: flex; gap: 4px; justify-content: flex-end; }
  .chip.live { color: var(--danger-text); border-color: var(--danger-line); background: var(--danger-bg); }
  .chip.live i { animation: pulse 1.6s ease-in-out infinite; }
  @keyframes pulse { 0%, 100% { opacity: 1; } 50% { opacity: 0.35; } }
  .howto div { display: flex; gap: 10px; padding: 10px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); font-size: 12px; color: var(--text-2); line-height: 1.45; }
  .howto i { color: var(--accent); margin-top: 2px; }
  .log { max-height: 150px; display: flex; flex-direction: column; border: 1px solid var(--line-2); border-radius: var(--radius); background: var(--bg-2); }
  .lrow { display: grid; grid-template-columns: 70px 1fr; gap: 10px; padding: 7px 10px; font-size: 12px; border-bottom: 1px solid var(--line); }
  .lrow:last-child { border-bottom: 0; }
  .when { font-size: 11px; }
  .note { display: grid; grid-template-columns: 1fr auto; gap: 8px; }
</style>
