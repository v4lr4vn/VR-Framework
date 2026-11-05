<script>
  import { isGame, post } from './lib/nui.js';
  import { mockPayload, mockCall, mockBuilder } from './lib/mock.js';
  import { money, miles, until, ago, STATUS, errorText } from './lib/format.js';
  import Modal from './ui/Modal.svelte';
  import Builder from './Builder.svelte';

  const q = new URLSearchParams(location.search);
  let visible = $state(!isGame && !q.get('builder'));
  let p = $state(isGame ? null : mockPayload(q.get('garage') || 'alta'));
  let sel = $state(null);
  let tab = $state('here');
  let search = $state('');
  let busy = $state(false);
  let toast = $state(null);
  let renaming = $state(false);
  let newName = $state('');
  let confirmMove = $state(null);
  let jsel = $state(null);
  let builder = $state(!isGame && q.get('builder') ? mockBuilder() : null);
  let builderHidden = $state(false);
  let placed = $state(null);

  const call = async (action, data = {}) => {
    if (!isGame) return mockCall(action, data, p.garage.id);
    const r = await post('api', { action, data });
    return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
  };

  let toastTimer;
  function say(text, kind = 'ok') {
    clearTimeout(toastTimer);
    toast = { text, kind };
    toastTimer = setTimeout(() => (toast = null), 3200);
  }

  let g = $derived(p?.garage);
  let impound = $derived(g?.type === 'impound');
  let group = $derived(g?.type === 'job' || g?.type === 'gang');
  let jobOnly = $derived(g?.type === 'job');
  let all = $derived(p ? p.vehicles : []);
  let jobs = $derived(p?.jobVehicles || []);
  let tabs = $derived.by(() => {
    if (!p) return [];
    if (impound) return [['here', 'Waiting for you', all.length]];
    const jobTab = ['job', g.type === 'gang' ? 'Gang vehicles' : 'Job vehicles', jobs.length];
    if (jobOnly) return [jobTab];
    const t = [
      ['here', 'Parked here', all.filter((v) => v.status === 'stored' && v.here).length],
      ['elsewhere', 'Elsewhere', all.filter((v) => !(v.status === 'stored' && v.here)).length],
    ];
    if (group && jobs.length) t.unshift(jobTab);
    return t;
  });
  let list = $derived.by(() => {
    if (!p) return [];
    let l = all;
    if (!impound) {
      if (tab === 'here') l = l.filter((v) => v.status === 'stored' && v.here);
      else l = l.filter((v) => !(v.status === 'stored' && v.here));
    }
    const s = search.trim().toLowerCase();
    if (s) l = l.filter((v) => `${v.label} ${v.nickname || ''} ${v.plate}`.toLowerCase().includes(s));
    return l;
  });
  let v = $derived(all.find((x) => x.plate === sel) || null);
  let jobList = $derived.by(() => {
    const s = search.trim().toLowerCase();
    return s ? jobs.filter((j) => `${j.label} ${j.name}`.toLowerCase().includes(s)) : jobs;
  });
  let jv = $derived(tab === 'job' ? jobs.find((j) => j.id === jsel) || null : null);

  $effect(() => {
    if (jobList.length && !jobList.find((j) => j.id === jsel)) jsel = jobList[0].id;
    if (!jobList.length) jsel = null;
  });

  $effect(() => {
    if (list.length && !list.find((x) => x.plate === sel)) sel = list[0].plate;
    if (!list.length) sel = null;
  });

  async function refresh() {
    const r = await call('open', { garage: g.id });
    if (r.ok) p = r.data;
  }

  async function run(action, data, success, after) {
    if (busy) return null;
    busy = true;
    const r = await call(action, data);
    busy = false;
    if (!r.ok) {
      if (r.error === 'elsewhere') {
        confirmMove = { plate: data.plate, fee: r.data?.fee ?? p.fees.transfer };
        return r;
      }
      say(r.error === 'not_ready' && r.data?.readyAt ? `Released ${until(r.data.readyAt)}` : errorText(r.error), 'err');
      return r;
    }
    if (success) say(success, 'ok');
    if (after) after(r);
    else await refresh();
    return r;
  }

  function close() {
    if (isGame) post('close');
    visible = false;
  }

  async function takeOut(transfer = false) {
    confirmMove = null;
    await run('takeOut', { plate: v.plate, transfer }, null, () => {
      if (!isGame) refresh();
    });
  }

  async function takeJob() {
    await run('jobveh.take', { id: jv.id }, null, () => {
      if (!isGame) say('Vehicle ready outside', 'ok');
    });
  }

  async function locate() {
    const r = await run('locate', { plate: v.plate }, null, () => {});
    if (r?.ok && isGame) post('waypoint', r.data);
    if (r?.ok) say('Waypoint set', 'ok');
  }

  async function release(method) {
    await run('impound.release', { plate: v.plate, method }, null, () => {
      if (!isGame) refresh();
    });
  }

  async function rename(e) {
    e.preventDefault();
    const r = await run('rename', { plate: v.plate, name: newName }, 'Renamed');
    if (r?.ok) renaming = false;
  }

  const catIcon = { car: 'fa-car-side', air: 'fa-helicopter', boat: 'fa-ship' };
  const typeText = (gg) => (gg.type === 'public' ? (gg.category === 'air' ? 'Hangar' : gg.category === 'boat' ? 'Boat house' : 'Public garage') : gg.type === 'impound' ? 'Impound lot' : gg.type === 'house' ? 'House garage' : `${gg.groupLabel} garage`);
  const headIcon = (gg) => (gg.type === 'impound' ? 'fa-truck-ramp-box' : gg.category === 'air' ? 'fa-plane' : gg.category === 'boat' ? 'fa-anchor' : 'fa-warehouse');
  const tone = (n) => (n >= 70 ? 'ok' : n >= 35 ? 'warn' : 'danger');

  $effect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      if (d.action === 'open') {
        p = d.data;
        tab = (d.data.jobVehicles || []).length || d.data.garage.type === 'job' ? 'job' : 'here';
        search = '';
        sel = null;
        jsel = null;
        renaming = false;
        confirmMove = null;
        toast = null;
        visible = true;
      } else if (d.action === 'close') visible = false;
      else if (d.action === 'builder') {
        visible = false;
        builder = d.data;
        builderHidden = false;
        placed = null;
      } else if (d.action === 'builderHide') builderHidden = true;
      else if (d.action === 'builderPlaced') {
        builderHidden = false;
        placed = { ...d.data };
      } else if (d.action === 'builderClose') builder = null;
    };
    const onKey = (e) => {
      if (e.key !== 'Escape' || !visible || builder) return;
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

  $effect(() => {
    if (!tabs.length) return;
    if (!tabs.find((t) => t[0] === tab)) {
      tab = tabs[0][0];
      return;
    }
    const here = tabs.find((t) => t[0] === 'here');
    if (tab === 'here' && here && here[2] === 0 && tabs.length > 1) {
      const next = tabs.find((t) => t[2] > 0);
      if (next) tab = next[0];
    }
  });
</script>

{#if builder}
  {#key builder}
    <Builder data={builder} hidden={builderHidden} {placed} onclose={() => { builder = null; if (isGame) post('builder:close'); }} />
  {/key}
{/if}

{#if visible && p}
  <div class="stage">
    <section class="shell card" aria-label="Garage">
      <header class="top">
        <span class="logo" class:imp={impound}><i class="fa-solid {headIcon(g)}"></i></span>
        <div class="title">
          <h1>{g.label}</h1>
          <p class="sub">{typeText(g)}{g.category !== 'all' ? ` · ${g.category === 'air' ? 'aircraft' : g.category === 'boat' ? 'boats' : 'cars and bikes'}` : ''}</p>
        </div>
        <button class="x" onclick={close} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
      </header>

      <div class="body">
        <aside class="left">
          <div class="tabs">
            {#each tabs as [k, t, n]}
              <button class="tab" class:on={tab === k} onclick={() => (tab = k)}>{t} <span class="count">{n}</span></button>
            {/each}
          </div>
          <div class="search">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input class="input" placeholder="Search name or plate" bind:value={search} />
          </div>
          <div class="list scroll">
            {#if tab === 'job'}
              {#if !jobList.length}
                <div class="empty"><i class="fa-solid fa-car-on"></i>{jobs.length ? 'No vehicles match' : 'No vehicles have been set up for this garage yet'}</div>
              {/if}
              {#each jobList as j (j.id)}
                <button class="item" class:on={jsel === j.id} onclick={() => (jsel = j.id)}>
                  <span class="ic"><i class="fa-solid {catIcon[j.category] || 'fa-car-side'}"></i></span>
                  <span class="info">
                    <span class="name">{j.label}</span>
                    <span class="meta"><span class="muted">{j.name}</span></span>
                  </span>
                  {#if j.allowed}<span class="chip ok">Ready</span>{:else}<span class="chip warn"><i class="fa-solid fa-lock"></i>Grade {j.grade}+</span>{/if}
                </button>
              {/each}
            {:else}
            {#if !list.length}
              <div class="empty">
                <i class="fa-solid {impound ? 'fa-circle-check' : 'fa-car-side'}"></i>
                {impound ? 'Nothing of yours is here' : tab === 'here' ? 'No vehicles parked here' : 'Nothing to show'}
              </div>
            {/if}
            {#each list as x (x.plate)}
              <button class="item" class:on={sel === x.plate} onclick={() => { sel = x.plate; renaming = false; }}>
                <span class="ic"><i class="fa-solid {catIcon[x.category] || 'fa-car-side'}"></i></span>
                <span class="info">
                  <span class="name">{x.nickname || x.label}</span>
                  <span class="meta"><span class="plate num">{x.plate}</span>{#if x.nickname}<span class="muted">{x.label}</span>{/if}</span>
                </span>
                <span class="chip {STATUS[x.status].tone}">{x.status === 'stored' && !x.here ? x.garageLabel : STATUS[x.status].label}</span>
              </button>
            {/each}
            {/if}
          </div>
        </aside>

        <main class="detail">
          {#if tab === 'job'}
            {#if !jv}
              <div class="empty big"><i class="fa-solid fa-car-on"></i>Pick a vehicle</div>
            {:else}
              <div class="dhead">
                <div class="vic"><i class="fa-solid {catIcon[jv.category] || 'fa-car-side'}"></i></div>
                <div class="dtitle">
                  <h2>{jv.label}</h2>
                  <div class="sub2"><span>{jv.name}</span><span class="chip accent"><i class="fa-solid fa-people-group"></i>{g.groupLabel}</span></div>
                </div>
                <span class="chip big {jv.allowed ? 'ok' : 'warn'}"><i class="fa-solid {jv.allowed ? 'fa-key' : 'fa-lock'}"></i>{jv.allowed ? 'Ready' : 'Locked'}</span>
              </div>

              <div class="facts">
                <div><span class="k">Rank needed</span><span class="v">{jv.grade > 0 ? `Grade ${jv.grade} or higher` : 'Any grade'}</span></div>
                <div><span class="k">Plate</span><span class="v num">{jv.plate ? `${jv.plate.toUpperCase()}…` : 'Random'}</span></div>
                <div><span class="k">Comes out</span><span class="v">Full tank, repaired</span></div>
              </div>

              {#if jv.allowed}
                <div class="notice"><i class="fa-solid fa-circle-info"></i><span>This is a {g.groupLabel} vehicle. Drive it back into any {g.groupLabel} garage and press E to return it.{#if p.jobLimit > 0}{' '}You can have {p.jobLimit === 1 ? 'one' : p.jobLimit} out at a time. Taking another sends your empty one back.{/if}</span></div>
              {:else}
                <div class="notice warn"><i class="fa-solid fa-lock"></i><span>Your rank is too low for this vehicle. It unlocks at grade {jv.grade}.</span></div>
              {/if}

              <div class="actions">
                <button class="btn primary big" disabled={busy || !jv.allowed} onclick={takeJob}><i class="fa-solid fa-key"></i>Take out</button>
              </div>
            {/if}
          {:else if !v}
            <div class="empty big"><i class="fa-solid fa-warehouse"></i>Pick a vehicle</div>
          {:else}
            <div class="dhead">
              <div class="vic"><i class="fa-solid {catIcon[v.category] || 'fa-car-side'}"></i></div>
              <div class="dtitle">
                {#if renaming}
                  <form class="rename" onsubmit={rename}>
                    <input class="input" maxlength="24" placeholder={v.label} bind:value={newName} />
                    <button class="btn small primary">Save</button>
                    <button type="button" class="btn small ghost" onclick={() => (renaming = false)}>Cancel</button>
                  </form>
                {:else}
                  <h2>{v.nickname || v.label}{#if v.mine}<button class="pen" title="Rename" onclick={() => { renaming = true; newName = v.nickname || ''; }}><i class="fa-solid fa-pen"></i></button>{/if}</h2>
                {/if}
                <div class="sub2"><span class="plateBig num">{v.plate}</span>{#if v.nickname}<span>{v.label}</span>{/if}</div>
              </div>
              <span class="chip big {STATUS[v.status].tone}"><i class="fa-solid {STATUS[v.status].icon}"></i>{STATUS[v.status].label}</span>
            </div>

            <div class="stats">
              {#each [['Fuel', v.fuel, 'fa-gas-pump'], ['Engine', v.engine, 'fa-gear'], ['Body', v.body, 'fa-car-burst']] as [k, n, ic]}
                <div class="stat">
                  <div class="sh"><span><i class="fa-solid {ic}"></i>{k}</span><span class="num">{Math.max(0, Math.min(100, n))}%</span></div>
                  <div class="bar {tone(n)}"><span style="width:{Math.max(0, Math.min(100, n))}%"></span></div>
                </div>
              {/each}
            </div>

            <div class="facts">
              <div><span class="k">Mileage</span><span class="v num">{miles(v.mileage)}</span></div>
              <div><span class="k">Kept at</span><span class="v">{v.garageLabel || 'Unknown'}</span></div>
              <div><span class="k">Owner</span><span class="v">{v.mine ? 'You' : 'Someone else'}</span></div>
            </div>

            {#if v.status === 'impounded' || v.status === 'held'}
              <div class="notice {v.status === 'held' ? 'danger' : 'warn'}">
                <i class="fa-solid {v.status === 'held' ? 'fa-building-columns' : 'fa-truck-ramp-box'}"></i>
                <span>
                  <strong>{v.impound?.reason || 'Impounded'}</strong><br />
                  {#if v.impound?.by}By {v.impound.by}{/if}{#if v.impound?.at} · {ago(v.impound.at)}{/if}
                  {#if v.status === 'held'}<br />Clear your debt at any bank branch, then collect it here.{/if}
                </span>
              </div>
            {:else if v.status === 'lost'}
              <div class="notice warn"><i class="fa-solid fa-circle-question"></i><span>This vehicle was left out and nobody has it. The impound lot can recover it for {money(p.fees.recover)}.</span></div>
            {:else if v.status === 'out'}
              <div class="notice"><i class="fa-solid fa-road"></i><span>This vehicle is out in the city. Park it in any garage to keep it safe.</span></div>
            {:else if v.status === 'stored' && !v.here && !impound}
              <div class="notice"><i class="fa-solid fa-route"></i><span>Parked at {v.garageLabel}. You can have it brought here for {money(p.fees.transfer)}.</span></div>
            {/if}

            <div class="actions">
              {#if impound}
                {#if v.status === 'impounded'}
                  {#if v.impound.readyAt > p.now}
                    <button class="btn" disabled><i class="fa-solid fa-clock"></i>Released {until(v.impound.readyAt)}</button>
                  {:else}
                    <button class="btn primary" disabled={busy} onclick={() => release('bank')}><i class="fa-solid fa-building-columns"></i>{v.impound.fee > 0 ? `Pay ${money(v.impound.fee)} from bank` : 'Release vehicle'}</button>
                    {#if v.impound.fee > 0}<button class="btn" disabled={busy} onclick={() => release('cash')}><i class="fa-solid fa-money-bill-wave"></i>Pay cash</button>{/if}
                  {/if}
                {:else if v.status === 'lost'}
                  <button class="btn primary" disabled={busy} onclick={() => release('bank')}><i class="fa-solid fa-truck-pickup"></i>Recover for {money(p.fees.recover)}</button>
                  <button class="btn" disabled={busy} onclick={() => release('cash')}><i class="fa-solid fa-money-bill-wave"></i>Pay cash</button>
                {/if}
              {:else if v.status === 'stored' && v.usable !== false}
                {#if v.here}
                  <button class="btn primary big" disabled={busy} onclick={() => takeOut(false)}><i class="fa-solid fa-key"></i>Take out</button>
                {:else}
                  <button class="btn primary big" disabled={busy} onclick={() => (confirmMove = { plate: v.plate, fee: p.fees.transfer })}><i class="fa-solid fa-route"></i>Bring it here · {money(p.fees.transfer)}</button>
                {/if}
              {:else if v.status === 'out'}
                <button class="btn" disabled={busy} onclick={locate}><i class="fa-solid fa-location-dot"></i>Set waypoint</button>
              {/if}

            </div>
          {/if}
        </main>
      </div>

      {#if confirmMove}
        <Modal title="Bring it here" icon="fa-route" onclose={() => (confirmMove = null)} width={400}>
          <p class="msg">Have <strong>{v?.nickname || v?.label}</strong> brought from {v?.garageLabel} for <strong class="num">{money(confirmMove.fee)}</strong>? It is paid from your bank, or cash if the bank is short.</p>
          <div class="row"><button class="btn ghost" onclick={() => (confirmMove = null)}>Cancel</button><button class="btn primary" disabled={busy} onclick={() => takeOut(true)}>Pay and take out</button></div>
        </Modal>
      {/if}

      {#if toast}
        <div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>
      {/if}
    </section>
  </div>
{/if}

<style>
  .stage { position: fixed; inset: 0; display: grid; place-items: center; background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.35), rgba(10, 14, 20, 0.65)); }
  .shell { position: relative; width: 1060px; height: 640px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  .top { display: flex; align-items: center; gap: 12px; padding: 14px 18px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 16px; }
  .logo.imp { background: var(--danger-bg); color: var(--danger); border: 1px solid var(--danger-line); }
  .title { flex: 1; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .body { flex: 1; display: grid; grid-template-columns: 400px 1fr; min-height: 0; }
  .left { display: flex; flex-direction: column; border-right: 1px solid var(--line-2); background: rgba(13, 18, 26, 0.55); min-height: 0; }
  .tabs { padding: 0 12px; }
  .tabs .tab { white-space: nowrap; padding: 0 10px; }
  .search { position: relative; padding: 10px 12px; }
  .search i { position: absolute; left: 24px; top: 50%; transform: translateY(-50%); color: var(--faint); font-size: 12px; }
  .search .input { padding-left: 32px; height: 34px; font-size: 13px; }
  .list { flex: 1; min-height: 0; padding: 0 8px 10px; display: flex; flex-direction: column; gap: 3px; }
  .item { display: grid; grid-template-columns: 34px 1fr auto; align-items: center; gap: 10px; padding: 9px 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: inherit; text-align: left; }
  .item:hover { background: var(--panel); }
  .item.on { background: var(--panel-2); border-color: var(--line-3); }
  .ic { width: 34px; height: 34px; border-radius: var(--radius); display: grid; place-items: center; background: var(--panel-3); color: var(--text-2); font-size: 14px; }
  .item.on .ic { background: var(--accent-soft); color: var(--accent); }
  .info { display: flex; flex-direction: column; min-width: 0; gap: 2px; }
  .name { font-size: 13px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .meta { display: flex; gap: 8px; font-size: 11px; white-space: nowrap; overflow: hidden; }
  .plate { color: var(--accent-2); }
  .item .chip { max-width: 130px; overflow: hidden; text-overflow: ellipsis; }
  .detail { padding: 20px 22px; display: flex; flex-direction: column; gap: 16px; min-height: 0; overflow: auto; }
  .empty.big { flex: 1; }
  .dhead { display: flex; align-items: flex-start; gap: 14px; }
  .vic { width: 54px; height: 54px; border-radius: var(--radius-lg); display: grid; place-items: center; background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--accent); font-size: 22px; }
  .dtitle { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 6px; }
  h2 { font-size: 22px; font-weight: 700; display: flex; align-items: center; gap: 8px; }
  .pen { width: 26px; height: 26px; border-radius: var(--radius); border: 1px solid var(--line-3); background: transparent; color: var(--muted); font-size: 11px; }
  .pen:hover { color: var(--text); background: var(--panel-2); }
  .sub2 { display: flex; align-items: center; gap: 10px; color: var(--muted); font-size: 13px; }
  .plateBig { padding: 2px 8px; border-radius: 4px; background: #F2F2EA; color: #1A2A6C; font-weight: 700; letter-spacing: 0.08em; font-size: 13px; border: 1px solid #c9c9bd; }
  .chip.big { height: 28px; padding: 0 12px; font-size: 12px; }
  .rename { display: flex; gap: 6px; }
  .rename .input { height: 32px; max-width: 260px; }
  .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
  .stat { padding: 12px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); display: flex; flex-direction: column; gap: 8px; }
  .sh { display: flex; justify-content: space-between; font-size: 12px; color: var(--text-2); font-weight: 600; }
  .sh i { margin-right: 7px; color: var(--muted); }
  .bar.warn > span { background: var(--warn); }
  .facts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; }
  .facts div { display: flex; flex-direction: column; gap: 2px; }
  .k { font-size: 10px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); font-weight: 600; }
  .v { font-size: 14px; font-weight: 600; }
  .actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: auto; padding-top: 4px; }
  .btn.big { height: 42px; padding: 0 22px; font-size: 14px; }
  .msg { font-size: 14px; color: var(--text-2); line-height: 1.5; }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
  .toast { position: absolute; left: 50%; bottom: 18px; transform: translateX(-50%); z-index: 40; display: flex; align-items: center; gap: 10px; padding: 10px 16px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--ok-line); color: var(--text); font-size: 13px; font-weight: 600; box-shadow: var(--shadow); }
  .toast i { color: var(--ok); }
  .toast.err { border-color: var(--danger-line); }
  .toast.err i { color: var(--danger); }
</style>
