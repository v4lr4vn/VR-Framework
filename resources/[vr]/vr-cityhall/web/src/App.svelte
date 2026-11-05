<script>
  import { isGame, post } from './lib/nui.js';
  import { mockPayload, mockCall } from './lib/mock.js';
  import { money, day, timeLeft, wait, STATUS, errorText } from './lib/format.js';
  import Modal from './ui/Modal.svelte';

  const q = new URLSearchParams(location.search);
  let visible = $state(!isGame);
  let p = $state(isGame ? null : mockPayload());
  let tab = $state(q.get('tab') || 'docs');
  let sel = $state({ docs: null, jobs: null, biz: null });
  let search = $state('');
  let busy = $state(false);
  let toast = $state(null);
  let confirm = $state(null);
  let creating = $state(false);
  let form = $state({ type: 'retail', name: '' });

  const call = async (action, data = {}) => {
    if (!isGame) return mockCall(action, data);
    const r = await post('api', { action, data });
    return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
  };

  let toastTimer;
  function say(text, kind = 'ok') {
    clearTimeout(toastTimer);
    toast = { text, kind };
    toastTimer = setTimeout(() => (toast = null), 3200);
  }

  let tabs = $derived.by(() => {
    if (!p) return [];
    const t = [];
    if (p.documents.enabled) t.push(['docs', 'Replace documents', 'fa-id-card']);
    if (p.jobcentre.enabled) t.push(['jobs', 'Job Centre', 'fa-briefcase']);
    if (p.business.enabled) t.push(['biz', 'Business licences', 'fa-store']);
    return t;
  });

  let docs = $derived(p ? p.documents.items : []);
  let jobs = $derived.by(() => {
    if (!p) return [];
    const s = search.trim().toLowerCase();
    const all = p.jobcentre.jobs;
    return s ? all.filter((j) => `${j.label} ${j.description || ''}`.toLowerCase().includes(s)) : all;
  });
  let lics = $derived(p ? p.business.licences : []);
  let doc = $derived(docs.find((d) => d.item === sel.docs) || null);
  let job = $derived(jobs.find((j) => j.job === sel.jobs) || null);
  let lic = $derived(lics.find((l) => l.id === sel.biz) || null);
  let type = $derived(p ? p.business.types.find((t) => t.id === form.type) : null);
  let total = $derived(p ? p.money.cash + p.money.bank : 0);

  $effect(() => {
    if (!p) return;
    if (docs.length && !docs.find((d) => d.item === sel.docs)) sel.docs = docs[0].item;
    if (jobs.length && !jobs.find((j) => j.job === sel.jobs)) sel.jobs = jobs[0].job;
    if (!jobs.length) sel.jobs = null;
    if (!lics.find((l) => l.id === sel.biz)) sel.biz = lics.length ? lics[0].id : null;
    if (!lics.length) creating = true;
    if (!tabs.find((t) => t[0] === tab) && tabs.length) tab = tabs[0][0];
  });

  async function refresh() {
    const r = await call('open', {});
    if (r.ok) p = r.data;
  }

  async function run(action, data, success, after) {
    if (busy) return null;
    busy = true;
    const r = await call(action, data);
    busy = false;
    confirm = null;
    if (!r.ok) {
      say(r.error === 'cooldown' && r.data?.wait ? `Wait ${wait(r.data.wait)} before asking again` : errorText(r.error), 'err');
      return r;
    }
    if (success) say(typeof success === 'function' ? success(r.data) : success, 'ok');
    if (after) after(r);
    await refresh();
    return r;
  }

  function close() {
    if (isGame) post('close');
    visible = false;
  }

  const ask = (c) => (confirm = c);

  const replaceDoc = () =>
    ask({ title: `Replace ${doc.label.toLowerCase()}`, icon: doc.icon, lead: `A new ${doc.label.toLowerCase()} costs`, price: doc.fee, label: 'Pay and replace', go: () => run('document.replace', { item: doc.item }, `${doc.label} replaced`) });

  const takeJob = () => run('job.take', { job: job.job }, (d) => `You are now working as ${d.label}`);

  const quitJob = () =>
    ask({ title: `Leave ${job.label}`, icon: 'fa-door-open', tone: 'danger', lead: `Leave your job as ${job.label}? You can pick it up again later at the Job Centre.`, label: 'Leave job', go: () => run('job.quit', { job: job.job }, (d) => `You left ${d.label}`) });

  const apply = () =>
    ask({
      title: 'Apply for a licence',
      icon: type.icon,
      lead: `${type.label} licence for ${form.name.trim() || 'your business'}, valid for ${type.days} days, costs`,
      price: type.fee,
      label: 'Pay and apply',
      go: () => run('business.apply', { type: form.type, name: form.name }, (d) => `${d.name} is now licensed`, (r) => { creating = false; sel.biz = r.data.id; form.name = ''; }),
    });

  const renew = () =>
    ask({ title: 'Renew licence', icon: 'fa-rotate', lead: `Renew ${lic.number} for another ${p.business.types.find((t) => t.id === lic.type)?.days || 30} days for`, price: lic.fee, label: 'Pay and renew', go: () => run('business.renew', { id: lic.id }, 'Licence renewed') });

  const reprint = () =>
    ask({ title: 'Replacement certificate', icon: 'fa-print', lead: `Print a new certificate for ${lic.number} for`, price: p.business.reprintFee, label: 'Pay and print', go: () => run('business.reprint', { id: lic.id }, 'Certificate reissued') });

  const surrender = () =>
    ask({ title: 'Surrender licence', icon: 'fa-file-circle-xmark', tone: 'danger', lead: `Hand back ${lic.number} for ${lic.name}? The business can no longer trade under it. To trade again you need a new licence.`, label: 'Surrender', go: () => run('business.surrender', { id: lic.id }, 'Licence surrendered') });

  $effect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      if (d.action === 'open') {
        p = d.data;
        tab = tabs[0]?.[0] || 'docs';
        search = '';
        confirm = null;
        toast = null;
        creating = false;
        sel = { docs: null, jobs: null, biz: null };
        visible = true;
      } else if (d.action === 'close') visible = false;
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

  const tone = (s) => STATUS[s]?.tone || 'ok';
</script>

{#if visible && p}
  <div class="stage">
    <section class="shell card" aria-label="City Hall">
      <header class="top">
        <span class="logo"><i class="fa-solid fa-landmark"></i></span>
        <div class="title">
          <h1>{p.desk.label}</h1>
          <p class="sub">Citizen services · {p.citizen.name}</p>
        </div>
        <div class="purse" title="Cash and bank">
          <span><i class="fa-solid fa-building-columns"></i><b class="num">{money(p.money.bank)}</b></span>
          <span><i class="fa-solid fa-money-bill-wave"></i><b class="num">{money(p.money.cash)}</b></span>
        </div>
        <button class="x" onclick={close} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
      </header>

      <nav class="tabs main" aria-label="Services">
        {#each tabs as [id, label, icon]}
          <button class="tab" class:on={tab === id} onclick={() => (tab = id)}><i class="fa-solid {icon}"></i>{label}</button>
        {/each}
      </nav>

      <div class="body">
        <aside class="left">
          {#if tab === 'jobs'}
            <div class="search">
              <i class="fa-solid fa-magnifying-glass"></i>
              <input class="input" placeholder="Search jobs" bind:value={search} />
            </div>
          {:else if tab === 'biz'}
            <div class="search">
              <button class="btn primary wide" disabled={lics.length === 0 && creating} onclick={() => (creating = true)}><i class="fa-solid fa-plus"></i>New licence</button>
            </div>
          {/if}

          <div class="list scroll">
            {#if tab === 'docs'}
              {#each docs as d}
                <button class="item" class:on={sel.docs === d.item} onclick={() => (sel.docs = d.item)}>
                  <span class="ic"><i class="fa-solid {d.icon}"></i></span>
                  <span class="info"><span class="name">{d.label}</span><span class="meta"><span class="num">{money(d.fee)}</span></span></span>
                  {#if !d.entitled}<span class="chip warn">Not held</span>{:else if d.carrying}<span class="chip ok">On you</span>{:else}<span class="chip accent">Missing</span>{/if}
                </button>
              {/each}
            {:else if tab === 'jobs'}
              {#each jobs as j}
                <button class="item" class:on={sel.jobs === j.job} onclick={() => (sel.jobs = j.job)}>
                  <span class="ic"><i class="fa-solid {j.icon}"></i></span>
                  <span class="info"><span class="name">{j.label}</span><span class="meta"><span>{j.gradeLabel}</span><span class="num pos">{money(j.salary)}/pay</span></span></span>
                  {#if j.current}<span class="chip ok">Working</span>{:else if j.held}<span class="chip info">On your list</span>{/if}
                </button>
              {:else}
                <div class="empty"><i class="fa-solid fa-briefcase"></i>No jobs match</div>
              {/each}
            {:else}
              {#each lics as l}
                <button class="item" class:on={sel.biz === l.id && !creating} onclick={() => { sel.biz = l.id; creating = false; }}>
                  <span class="ic"><i class="fa-solid {l.icon}"></i></span>
                  <span class="info"><span class="name">{l.name}</span><span class="meta"><span class="num plate">{l.number}</span></span></span>
                  <span class="chip {tone(l.status)}">{STATUS[l.status].label}</span>
                </button>
              {:else}
                <div class="empty"><i class="fa-solid fa-store"></i>You hold no business licences</div>
              {/each}
            {/if}
          </div>
        </aside>

        <main class="detail scroll">
          {#if tab === 'docs' && doc}
            <div class="dhead">
              <span class="vic"><i class="fa-solid {doc.icon}"></i></span>
              <div class="dtitle">
                <h2>{doc.label}</h2>
                <div class="sub2">{doc.description}</div>
              </div>
              {#if !doc.entitled}<span class="chip big warn"><i class="fa-solid fa-lock"></i>Not held</span>{:else if doc.carrying}<span class="chip big ok"><i class="fa-solid fa-circle-check"></i>On you</span>{:else}<span class="chip big accent"><i class="fa-solid fa-circle-question"></i>Not on you</span>{/if}
            </div>
            <div class="facts">
              <div><span class="k">Replacement fee</span><span class="v num">{money(doc.fee)}</span></div>
              <div><span class="k">Paid from</span><span class="v">Bank, then cash</span></div>
              <div><span class="k">You have</span><span class="v num">{money(total)}</span></div>
            </div>
            {#if !doc.entitled}
              <div class="notice warn"><i class="fa-solid fa-lock"></i><span>City Hall only replaces licences you already hold. You need to pass the test or get the permit first.</span></div>
            {:else if doc.blocked}
              <div class="notice"><i class="fa-solid fa-circle-info"></i><span>You are carrying one already. Come back if you lose it.</span></div>
            {:else if doc.wait > 0}
              <div class="notice warn"><i class="fa-solid fa-clock"></i><span>You replaced this a moment ago. Wait {wait(doc.wait)}.</span></div>
            {:else}
              <div class="notice"><i class="fa-solid fa-circle-info"></i><span>The new card shows your current details and goes straight into your pockets.</span></div>
            {/if}
            <div class="actions">
              <button class="btn primary big" disabled={busy || !doc.entitled || doc.blocked || doc.wait > 0} onclick={replaceDoc}><i class="fa-solid fa-rotate"></i>Replace · {money(doc.fee)}</button>
            </div>

          {:else if tab === 'jobs'}
            <div class="notice"><i class="fa-solid fa-circle-info"></i><span>You hold <b class="num">{p.jobcentre.count}</b> of <b class="num">{p.jobcentre.maxJobs}</b> jobs. Jobs you leave stay free to pick up again.</span></div>
            {#if job}
              <div class="dhead">
                <span class="vic"><i class="fa-solid {job.icon}"></i></span>
                <div class="dtitle">
                  <h2>{job.label}</h2>
                  <div class="sub2">Starting as {job.gradeLabel}</div>
                </div>
                {#if job.current}<span class="chip big ok"><i class="fa-solid fa-briefcase"></i>Working</span>{:else if job.held}<span class="chip big info"><i class="fa-solid fa-list"></i>On your list</span>{/if}
              </div>
              <p class="lead">{job.description}</p>
              <div class="facts">
                <div><span class="k">Pay per cheque</span><span class="v num pos">{money(job.salary)}</span></div>
                <div><span class="k">Rank</span><span class="v">{job.gradeLabel}</span></div>
                <div><span class="k">Cost</span><span class="v">Free</span></div>
              </div>
              <div class="actions">
                <button class="btn primary big" disabled={busy || job.current} onclick={takeJob}><i class="fa-solid fa-handshake"></i>{job.current ? 'You work here' : job.held ? 'Start working' : 'Take this job'}</button>
                {#if p.jobcentre.canQuit && job.held}
                  <button class="btn danger" disabled={busy} onclick={quitJob}><i class="fa-solid fa-door-open"></i>Leave job</button>
                {/if}
              </div>
            {:else}
              <div class="empty big"><i class="fa-solid fa-briefcase"></i>No jobs are listed right now</div>
            {/if}

          {:else if tab === 'biz'}
            {#if creating}
              <div class="dhead">
                <span class="vic"><i class="fa-solid fa-file-signature"></i></span>
                <div class="dtitle">
                  <h2>New business licence</h2>
                  <div class="sub2">You hold {p.business.active} of {p.business.max} licences</div>
                </div>
              </div>
              <div class="types">
                {#each p.business.types as t}
                  <button class="type" class:on={form.type === t.id} onclick={() => (form.type = t.id)}>
                    <span class="ic"><i class="fa-solid {t.icon}"></i></span>
                    <span class="tname">{t.label}</span>
                    <span class="num tfee">{money(t.fee)}</span>
                  </button>
                {/each}
              </div>
              {#if type}<p class="lead">{type.description}. Valid for {type.days} days.</p>{/if}
              <label class="field">
                <span>Business name</span>
                <input class="input" maxlength={p.business.nameMax} placeholder="Name on the licence" bind:value={form.name} />
              </label>
              <div class="actions">
                <button class="btn primary big" disabled={busy || form.name.trim().length < p.business.nameMin || p.business.active >= p.business.max} onclick={apply}><i class="fa-solid fa-file-signature"></i>Apply · {money(type?.fee)}</button>
                {#if lics.length}<button class="btn ghost" onclick={() => (creating = false)}>Cancel</button>{/if}
              </div>
              {#if p.business.active >= p.business.max}
                <div class="notice warn"><i class="fa-solid fa-triangle-exclamation"></i><span>You already hold the most licences allowed. Surrender one or let it run out first.</span></div>
              {/if}
            {:else if lic}
              <div class="dhead">
                <span class="vic"><i class="fa-solid {lic.icon}"></i></span>
                <div class="dtitle">
                  <h2>{lic.name}</h2>
                  <div class="sub2"><span class="plateBig num">{lic.number}</span><span>{lic.typeLabel}</span></div>
                </div>
                <span class="chip big {tone(lic.status)}"><i class="fa-solid {STATUS[lic.status].icon}"></i>{STATUS[lic.status].label}</span>
              </div>
              <div class="facts">
                <div><span class="k">Issued</span><span class="v">{day(lic.issued)}</span></div>
                <div><span class="k">{lic.status === 'active' ? 'Valid until' : 'Ended'}</span><span class="v">{day(lic.expires)}</span></div>
                <div><span class="k">Time</span><span class="v {lic.status === 'active' ? '' : 'danger-text'}">{lic.status === 'revoked' ? 'Revoked' : timeLeft(lic.expires, p.now)}</span></div>
              </div>
              {#if lic.status === 'revoked'}
                <div class="notice danger"><i class="fa-solid fa-ban"></i><span><strong>This licence was revoked.</strong>{#if lic.note}<br />{lic.note}{/if}<br />Contact the council to have it looked at.</span></div>
              {:else if lic.status === 'expired'}
                <div class="notice warn"><i class="fa-solid fa-clock"></i><span>This licence has run out. Renew it to trade again.</span></div>
              {:else if lic.renewable}
                <div class="notice"><i class="fa-solid fa-circle-info"></i><span>This licence runs out soon. You can renew it now and the new period starts when this one ends.</span></div>
              {:else}
                <div class="notice ok"><i class="fa-solid fa-circle-check"></i><span>This business is licensed to trade. You can renew in the last {p.business.renewWindowDays} days.</span></div>
              {/if}
              <div class="actions">
                {#if lic.status !== 'revoked'}
                  <button class="btn primary big" disabled={busy || !lic.renewable} onclick={renew}><i class="fa-solid fa-rotate"></i>Renew · {money(lic.fee)}</button>
                  {#if p.business.certificate}
                    <button class="btn" disabled={busy || lic.status !== 'active'} onclick={reprint}><i class="fa-solid fa-print"></i>Replace certificate · {money(p.business.reprintFee)}</button>
                  {/if}
                  <button class="btn danger" disabled={busy} onclick={surrender}><i class="fa-solid fa-file-circle-xmark"></i>Surrender</button>
                {/if}
              </div>
            {/if}
          {/if}
        </main>
      </div>

      {#if confirm}
        <Modal title={confirm.title} icon={confirm.icon} onclose={() => (confirm = null)} width={420}>
          <p class="msg">{confirm.lead}{#if confirm.price != null}{' '}<strong class="num">{money(confirm.price)}</strong>. It comes out of your bank, or cash if the bank is short.{/if}</p>
          <div class="row">
            <button class="btn ghost" onclick={() => (confirm = null)}>Cancel</button>
            <button class="btn {confirm.tone === 'danger' ? 'danger' : 'primary'}" disabled={busy} onclick={confirm.go}>{confirm.label}</button>
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
  .shell { position: relative; width: 1000px; height: 620px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  .top { display: flex; align-items: center; gap: 12px; padding: 14px 18px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 16px; }
  .title { flex: 1; min-width: 0; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .purse { display: flex; gap: 14px; padding: 6px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); font-size: 13px; }
  .purse span { display: inline-flex; align-items: center; gap: 7px; color: var(--muted); }
  .purse b { color: var(--text); font-weight: 600; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .tabs.main { padding: 0 18px; background: rgba(13, 18, 26, 0.4); }
  .body { flex: 1; display: grid; grid-template-columns: 340px 1fr; min-height: 0; }
  .left { display: flex; flex-direction: column; border-right: 1px solid var(--line-2); background: rgba(13, 18, 26, 0.55); min-height: 0; }
  .search { position: relative; padding: 10px 12px; }
  .search i { position: absolute; left: 24px; top: 50%; transform: translateY(-50%); color: var(--faint); font-size: 12px; }
  .search .input { padding-left: 32px; height: 34px; font-size: 13px; }
  .search .btn i { position: static; transform: none; color: inherit; }
  .btn.wide { width: 100%; }
  .list { flex: 1; min-height: 0; padding: 0 8px 10px; display: flex; flex-direction: column; gap: 3px; }
  .left > .list:first-child { padding-top: 10px; }
  .item { display: grid; grid-template-columns: 34px 1fr auto; align-items: center; gap: 10px; padding: 9px 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: inherit; text-align: left; }
  .item:hover { background: var(--panel); }
  .item.on { background: var(--panel-2); border-color: var(--line-3); }
  .ic { width: 34px; height: 34px; border-radius: var(--radius); display: grid; place-items: center; background: var(--panel-3); color: var(--text-2); font-size: 14px; }
  .item.on .ic { background: var(--accent-soft); color: var(--accent); }
  .info { display: flex; flex-direction: column; min-width: 0; gap: 2px; }
  .name { font-size: 13px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .meta { display: flex; gap: 8px; font-size: 11px; color: var(--muted); white-space: nowrap; overflow: hidden; }
  .plate { color: var(--accent-2); }
  .detail { padding: 20px 22px; display: flex; flex-direction: column; gap: 16px; min-height: 0; overflow: auto; }
  .empty.big { flex: 1; }
  .dhead { display: flex; align-items: flex-start; gap: 14px; }
  .vic { width: 54px; height: 54px; border-radius: var(--radius-lg); display: grid; place-items: center; background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--accent); font-size: 22px; flex: none; }
  .dtitle { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 6px; }
  h2 { font-size: 22px; font-weight: 700; }
  .sub2 { display: flex; align-items: center; gap: 10px; color: var(--muted); font-size: 13px; }
  .plateBig { padding: 2px 8px; border-radius: 4px; background: #F2F2EA; color: #1A2A6C; font-weight: 700; letter-spacing: 0.08em; font-size: 13px; border: 1px solid #c9c9bd; }
  .chip.big { height: 28px; padding: 0 12px; font-size: 12px; }
  .lead { font-size: 14px; color: var(--text-2); line-height: 1.5; }
  .facts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; padding: 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .facts div { display: flex; flex-direction: column; gap: 3px; }
  .k { font-size: 10px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); font-weight: 600; }
  .v { font-size: 14px; font-weight: 600; }
  .actions { display: flex; flex-wrap: wrap; gap: 8px; margin-top: auto; padding-top: 4px; }
  .btn.big { height: 42px; padding: 0 22px; font-size: 14px; }
  .types { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .type { display: grid; grid-template-columns: 34px 1fr; grid-template-rows: auto auto; column-gap: 10px; align-items: center; padding: 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: inherit; text-align: left; }
  .type:hover { background: var(--panel-2); }
  .type.on { border-color: var(--accent); background: var(--accent-soft); }
  .type .ic { grid-row: span 2; }
  .type.on .ic { background: var(--accent); color: var(--accent-ink); }
  .tname { font-size: 13px; font-weight: 600; }
  .tfee { font-size: 12px; color: var(--accent-2); }
  .msg { font-size: 14px; color: var(--text-2); line-height: 1.5; }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
  .toast { position: absolute; left: 50%; bottom: 18px; transform: translateX(-50%); z-index: 40; display: flex; align-items: center; gap: 10px; padding: 10px 16px; border-radius: var(--radius); background: var(--panel-2); border: 1px solid var(--ok-line); color: var(--text); font-size: 13px; font-weight: 600; box-shadow: var(--shadow); }
  .toast i { color: var(--ok); }
  .toast.err { border-color: var(--danger-line); }
  .toast.err i { color: var(--danger); }
</style>
