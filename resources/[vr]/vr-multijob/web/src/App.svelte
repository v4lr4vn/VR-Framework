<script>
  import { isGame, post } from './lib/nui.js';
  import { mockPayload, mockCall } from './lib/mock.js';
  import { money, errorText } from './lib/format.js';
  import Modal from './ui/Modal.svelte';

  let visible = $state(!isGame);
  let p = $state(isGame ? null : mockPayload());
  let sel = $state(null);
  let search = $state('');
  let busy = $state(false);
  let toast = $state(null);
  let confirm = $state(null);

  const call = async (action, data = {}) => {
    if (!isGame) return mockCall(action, data);
    const r = await post('api', { action, data });
    return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
  };

  let toastTimer;
  function say(text, kind = 'ok') {
    clearTimeout(toastTimer);
    toast = { text, kind };
    toastTimer = setTimeout(() => (toast = null), 3000);
  }

  let all = $derived(p ? p.jobs : []);
  let list = $derived.by(() => {
    const s = search.trim().toLowerCase();
    return s ? all.filter((j) => `${j.label} ${j.gradeLabel}`.toLowerCase().includes(s)) : all;
  });
  let white = $derived(list.filter((j) => j.whitelist));
  let civil = $derived(list.filter((j) => !j.whitelist));
  let job = $derived(all.find((j) => j.name === sel) || null);
  let working = $derived(p ? p.current.name !== p.fallback : false);

  $effect(() => {
    if (!p) return;
    if (all.length && !all.find((j) => j.name === sel)) sel = (all.find((j) => j.current) || all[0]).name;
    if (!all.length) sel = null;
  });

  async function refresh() {
    const r = await call('list', {});
    if (r.ok) p = r.data;
  }

  async function run(action, data, success) {
    if (busy) return null;
    busy = true;
    const r = await call(action, data);
    busy = false;
    confirm = null;
    if (!r.ok) {
      say(errorText(r.error), 'err');
      return r;
    }
    if (success) say(typeof success === 'function' ? success(r.data) : success, 'ok');
    await refresh();
    return r;
  }

  function close() {
    if (isGame) post('close');
    visible = false;
  }

  const switchTo = () => run('select', { job: job.name }, (d) => `You are now working as ${d.label}`);
  const stop = () => run('select', { job: p.fallback }, 'You are not working a job now');
  const duty = () => run('duty', {}, (d) => (d.onduty ? 'You are on duty' : 'You are off duty'));
  const leave = () =>
    (confirm = {
      title: `Leave ${job.label}`,
      lead: `Leave your job as ${job.label}? It comes off your job menu. A manager or the Job Centre can put you back on.`,
      go: () => run('leave', { job: job.name }, (d) => `You left ${d.label}`),
    });

  $effect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      if (d.action === 'open') {
        p = d.data;
        sel = null;
        search = '';
        confirm = null;
        toast = null;
        visible = true;
      } else if (d.action === 'update') p = d.data;
      else if (d.action === 'close') visible = false;
    };
    const onKey = (e) => {
      if (e.key !== 'Escape' || !visible) return;
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
</script>

{#snippet row(j)}
  <button class="item" class:on={sel === j.name} onclick={() => (sel = j.name)}>
    <span class="ic"><i class={j.icon || 'fa-solid fa-briefcase'}></i></span>
    <span class="info"><span class="name">{j.label}</span><span class="meta"><span>{j.gradeLabel}</span><span class="num pos">{money(j.salary)}</span></span></span>
    {#if j.current}
      <span class="chip {j.onduty ? 'ok' : 'warn'}">{j.onduty ? 'On duty' : 'Off duty'}</span>
    {/if}
  </button>
{/snippet}

{#if visible && p}
  <div class="stage">
    <section class="shell card" aria-label="Job menu">
      <header class="top">
        <span class="logo"><i class="fa-solid fa-briefcase"></i></span>
        <div class="title">
          <h1>Job menu</h1>
          <p class="sub">{working ? `Working as ${p.current.label}${p.current.listed ? '' : ' (not on your list)'}` : 'Not working a job right now'}</p>
        </div>
        <span class="count" title="Jobs on your list"><b class="num">{all.length}</b> of <b class="num">{p.max}</b> jobs</span>
        <button class="x" onclick={close} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
      </header>

      <div class="body">
        <aside class="left">
          <div class="search">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input class="input" placeholder="Search your jobs" bind:value={search} />
          </div>
          <div class="list scroll">
            {#if white.length}
              <div class="label sect">Whitelisted</div>
              {#each white as j (j.name)}{@render row(j)}{/each}
            {/if}
            {#if civil.length}
              {#if white.length}<div class="label sect">Civilian</div>{/if}
              {#each civil as j (j.name)}{@render row(j)}{/each}
            {/if}
            {#if !list.length}
              <div class="empty"><i class="fa-solid fa-briefcase"></i>{all.length ? 'No jobs match' : 'You have no jobs yet'}</div>
            {/if}
          </div>
          <div class="foot">
            {#if working}
              <button class="btn ghost wide" disabled={busy} onclick={stop}><i class="fa-solid fa-person-walking"></i>Not working for now</button>
            {/if}
            {#if p.hint}<p class="hint">{p.hint}</p>{/if}
          </div>
        </aside>

        <main class="detail scroll">
          {#if job}
            <div class="dhead">
              <span class="vic"><i class={job.icon || 'fa-solid fa-briefcase'}></i></span>
              <div class="dtitle">
                <h2>{job.label}</h2>
                <div class="sub2">{job.gradeLabel}</div>
              </div>
              <div class="chips">
                {#if job.whitelist}<span class="chip big info"><i class="fa-solid fa-shield-halved"></i>Whitelisted</span>{/if}
                {#if job.current}<span class="chip big {job.onduty ? 'ok' : 'warn'}"><i class="fa-solid fa-circle"></i>{job.onduty ? 'On duty' : 'Off duty'}</span>{/if}
              </div>
            </div>

            {#if job.description}<p class="lead">{job.description}</p>{/if}

            <div class="facts">
              <div><span class="k">Rank</span><span class="v">{job.gradeLabel}</span></div>
              <div><span class="k">Pay per cheque</span><span class="v num pos">{money(job.salary)}</span></div>
              <div><span class="k">Colleagues on duty</span><span class="v num">{job.active}</span></div>
            </div>

            {#if job.current}
              <div class="notice ok"><i class="fa-solid fa-circle-check"></i><span>This is the job you are working. {job.canDuty ? 'You are paid while you are on duty.' : 'Go on and off duty at your own station.'}</span></div>
            {:else}
              <div class="notice"><i class="fa-solid fa-circle-info"></i><span>Switch to this job to start working it. Your rank and pay stay as they are.</span></div>
            {/if}

            <div class="actions">
              {#if job.current}
                <button class="btn primary big" disabled={busy || !job.canDuty} onclick={duty}><i class="fa-solid fa-clock"></i>{job.onduty ? 'Go off duty' : 'Go on duty'}</button>
              {:else}
                <button class="btn primary big" disabled={busy} onclick={switchTo}><i class="fa-solid fa-right-left"></i>Switch to this job</button>
              {/if}
              {#if p.canLeave}
                <button class="btn danger" disabled={busy} onclick={leave}><i class="fa-solid fa-door-open"></i>Leave job</button>
              {/if}
            </div>
          {:else}
            <div class="empty big">
              <i class="fa-solid fa-briefcase"></i>
              <span>You have no jobs yet.</span>
              {#if p.hint}<span class="hint">{p.hint}</span>{/if}
            </div>
          {/if}
        </main>
      </div>

      {#if confirm}
        <Modal title={confirm.title} icon="fa-door-open" onclose={() => (confirm = null)} width={420}>
          <p class="msg">{confirm.lead}</p>
          <div class="row">
            <button class="btn ghost" onclick={() => (confirm = null)}>Cancel</button>
            <button class="btn danger" disabled={busy} onclick={confirm.go}>Leave job</button>
          </div>
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
  .shell { position: relative; width: 940px; height: 580px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  .top { display: flex; align-items: center; gap: 12px; padding: 14px 18px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 16px; }
  .title { flex: 1; min-width: 0; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .count { padding: 6px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); font-size: 13px; color: var(--muted); }
  .count b { color: var(--text); font-weight: 600; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .body { flex: 1; display: grid; grid-template-columns: 330px 1fr; min-height: 0; }
  .left { display: flex; flex-direction: column; border-right: 1px solid var(--line-2); background: rgba(13, 18, 26, 0.55); min-height: 0; }
  .search { position: relative; padding: 10px 12px; }
  .search i { position: absolute; left: 24px; top: 50%; transform: translateY(-50%); color: var(--faint); font-size: 12px; }
  .search .input { padding-left: 32px; height: 34px; font-size: 13px; }
  .list { flex: 1; min-height: 0; padding: 0 8px 10px; display: flex; flex-direction: column; gap: 3px; }
  .sect { padding: 8px 8px 4px; }
  .item { display: grid; grid-template-columns: 34px 1fr auto; align-items: center; gap: 10px; padding: 9px 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: inherit; text-align: left; }
  .item:hover { background: var(--panel); }
  .item.on { background: var(--panel-2); border-color: var(--line-3); }
  .ic { width: 34px; height: 34px; border-radius: var(--radius); display: grid; place-items: center; background: var(--panel-3); color: var(--text-2); font-size: 14px; }
  .item.on .ic { background: var(--accent-soft); color: var(--accent); }
  .info { display: flex; flex-direction: column; min-width: 0; gap: 2px; }
  .name { font-size: 13px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .meta { display: flex; gap: 8px; font-size: 11px; color: var(--muted); white-space: nowrap; overflow: hidden; }
  .foot { padding: 10px 12px 12px; border-top: 1px solid var(--line); display: flex; flex-direction: column; gap: 8px; }
  .btn.wide { width: 100%; }
  .detail { padding: 20px 22px; display: flex; flex-direction: column; gap: 16px; min-height: 0; overflow: auto; }
  .empty.big { flex: 1; }
  .dhead { display: flex; align-items: flex-start; gap: 14px; }
  .vic { width: 54px; height: 54px; border-radius: var(--radius-lg); display: grid; place-items: center; background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--accent); font-size: 22px; flex: none; }
  .dtitle { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 6px; }
  h2 { font-size: 22px; font-weight: 700; }
  .sub2 { color: var(--muted); font-size: 13px; }
  .chips { flex: none; display: flex; gap: 6px; justify-content: flex-end; }
  .chip.big { height: 28px; padding: 0 12px; font-size: 12px; }
  .chip.big i.fa-circle { font-size: 7px; }
  .lead { font-size: 14px; color: var(--text-2); line-height: 1.5; }
  .facts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; padding: 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .facts div { display: flex; flex-direction: column; gap: 3px; }
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
