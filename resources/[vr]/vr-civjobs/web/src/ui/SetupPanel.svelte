<script>
  import { errorText } from '../lib/format.js';

  let { data, call, post, mouse, onclose } = $props();

  let jobs = $state(data.jobs);
  let job = $state(data.job || null);
  let open = $state(null);
  let busy = $state(false);
  let toast = $state(null);
  let draft = $state({});
  let toastTimer;

  let current = $derived(job);

  $effect(() => {
    if (!job && jobs.length) pickJob(jobs[0].id);
  });

  const say = (text, kind = 'ok') => {
    clearTimeout(toastTimer);
    toast = { text, kind };
    toastTimer = setTimeout(() => (toast = null), 2800);
  };

  async function pickJob(id) {
    const r = await call('job', { job: id });
    if (!r.ok) return say(errorText(r.error), 'err');
    job = r.data.job;
    jobs = r.data.jobs;
    open = null;
    draft = {};
    post('setupSelect', { job: id });
  }

  async function run(action, payload, success) {
    if (busy) return null;
    busy = true;
    const r = await call(action, { job: job.id, ...payload });
    busy = false;
    if (!r.ok) {
      say(errorText(r.error), 'err');
      return r;
    }
    job = r.data.job;
    jobs = r.data.jobs;
    if (success) say(success);
    return r;
  }

  function toggle(f) {
    open = open === f.id ? null : f.id;
    post('setupSelect', { job: job.id, field: open });
    if (open && f.kind === 'list') initDraft(f);
  }

  function initDraft(f) {
    if (draft[f.id]) return;
    const d = {};
    for (const e of f.item.extra || []) d[e.key] = e.default;
    if (f.item.radius) d.r = f.item.defaultR || 50;
    draft[f.id] = d;
  }

  const n1 = (v) => (Math.round(v * 10) / 10).toString();
  const spot = (c) => `${n1(c.x)}, ${n1(c.y)}, ${n1(c.z)}`;
  const go = (c) => post('setupGo', { x: c.x, y: c.y, z: c.z });
  const typing = (on) => post('setupTyping', { on });

  const setHere = (f) => run('set', { field: f.id }, `${f.label} set to your position`);
  const setNumber = (f, v) => run('set', { field: f.id, value: Number(v) }, `${f.label} saved`);
  const addHere = (f) => run('add', { field: f.id, data: draft[f.id] || {} }, 'Added at your position');
  const moveHere = (f, i) => run('move', { field: f.id, index: i + 1 }, 'Moved to your position');
  const removeAt = (f, i) => run('remove', { field: f.id, index: i + 1 }, 'Removed');
  const patch = (f, i, p) => run('update', { field: f.id, index: i + 1, patch: p }, 'Saved');
  const reset = (f) => run('reset', { field: f.id }, 'Back to the default');
  const resetAll = () => run('resetJob', {}, 'Job reset to the defaults');

  const changed = $derived(job ? job.fields.filter((f) => f.custom).length : 0);
</script>

<aside class="panel card" aria-label="Job setup">
  <header>
    <span class="logo"><i class="fa-solid fa-screwdriver-wrench"></i></span>
    <div class="t">
      <h1>Job setup</h1>
      <p class="sub">Stand where you want it, then press the button</p>
    </div>
    <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  <div class="mode" class:look={!mouse}>
    <i class="fa-solid {mouse ? 'fa-lock' : 'fa-person-walking'}"></i>
    <span>{mouse ? 'Locked. Movement and camera are frozen while you use the panel.' : 'Free. Walk and look around to pick a spot.'}</span>
    <kbd class="key">ALT</kbd>
  </div>

  <div class="pick">
    <select class="input" value={job?.id} onchange={(e) => pickJob(e.currentTarget.value)}>
      {#each jobs as j}
        <option value={j.id}>{j.label}{j.changed ? `  (${j.changed} changed)` : ''}</option>
      {/each}
    </select>
  </div>

  <div class="fields scroll">
    {#if current}
      {#each current.fields as f (f.id)}
        <section class="field" class:on={open === f.id}>
          <button class="fh" onclick={() => toggle(f)}>
            <span class="fl">{f.label}</span>
            {#if f.custom}<span class="chip accent">Custom</span>{/if}
            {#if f.kind === 'list'}<span class="chip num">{f.value.length}</span>{/if}
            <i class="fa-solid {open === f.id ? 'fa-chevron-up' : 'fa-chevron-down'}"></i>
          </button>

          {#if open === f.id}
            <div class="fb">
              {#if f.hint}<p class="hint">{f.hint}</p>{/if}

              {#if f.kind === 'vec3' || f.kind === 'vec4'}
                <div class="row">
                  <span class="coords num">{spot(f.value)}{f.kind === 'vec4' ? `  h ${n1(f.value.w)}` : ''}</span>
                </div>
                <div class="btns">
                  <button class="btn primary small" disabled={busy} onclick={() => setHere(f)}><i class="fa-solid fa-location-crosshairs"></i>Set to my position</button>
                  <button class="btn small" onclick={() => go(f.value)}><i class="fa-solid fa-person-walking-arrow-right"></i>Go there</button>
                  {#if f.custom}<button class="btn small ghost" disabled={busy} onclick={() => reset(f)}><i class="fa-solid fa-rotate-left"></i>Default</button>{/if}
                </div>
              {:else if f.kind === 'number'}
                <div class="btns">
                  <input class="input num" type="number" step="1" min={f.min} max={f.max} value={f.value}
                    onfocus={() => typing(true)} onblur={(e) => { typing(false); if (Number(e.currentTarget.value) !== f.value) setNumber(f, e.currentTarget.value); }}
                    onkeydown={(e) => e.key === 'Enter' && e.currentTarget.blur()} />
                  <span class="muted lim num">{f.min}-{f.max}</span>
                  {#if f.custom}<button class="btn small ghost" disabled={busy} onclick={() => reset(f)}><i class="fa-solid fa-rotate-left"></i>Default</button>{/if}
                </div>
              {:else}
                <div class="items">
                  {#each f.value as item, i}
                    <div class="item">
                      <div class="ih">
                        <span class="ix num">{i + 1}</span>
                        <span class="coords num">{spot(item)}{f.item.pos === 'vec4' ? `  h ${n1(item.w)}` : ''}</span>
                        <span class="ia">
                          <button class="btn small icon" title="Go there" onclick={() => go(item)}><i class="fa-solid fa-person-walking-arrow-right"></i></button>
                          <button class="btn small icon" title="Move here" disabled={busy} onclick={() => moveHere(f, i)}><i class="fa-solid fa-location-crosshairs"></i></button>
                          <button class="btn small icon danger" title="Remove" disabled={busy} onclick={() => removeAt(f, i)}><i class="fa-solid fa-trash"></i></button>
                        </span>
                      </div>
                      {#if f.item.radius || f.item.extra.length}
                        <div class="extras">
                          {#if f.item.radius}
                            <label><span>Radius</span>
                              <input class="input num" type="number" min="2" max="1500" value={item.r}
                                onfocus={() => typing(true)} onblur={(e) => { typing(false); if (Number(e.currentTarget.value) !== item.r) patch(f, i, { r: Number(e.currentTarget.value) }); }}
                                onkeydown={(e) => e.key === 'Enter' && e.currentTarget.blur()} /></label>
                          {/if}
                          {#each f.item.extra as e}
                            <label><span>{e.label}</span>
                              {#if e.type === 'choice'}
                                <select class="input" value={item[e.key]} onchange={(ev) => patch(f, i, { [e.key]: ev.currentTarget.value })}>
                                  {#each e.options as o}<option value={o}>{o}</option>{/each}
                                </select>
                              {:else}
                                <input class="input" type={e.type === 'number' ? 'number' : 'text'} step={e.type === 'number' ? 0.1 : undefined} maxlength="40" value={item[e.key]}
                                  onfocus={() => typing(true)} onblur={(ev) => { typing(false); const v = e.type === 'number' ? Number(ev.currentTarget.value) : ev.currentTarget.value; if (v !== item[e.key]) patch(f, i, { [e.key]: v }); }}
                                  onkeydown={(ev) => ev.key === 'Enter' && ev.currentTarget.blur()} />
                              {/if}</label>
                          {/each}
                        </div>
                      {/if}
                    </div>
                  {:else}
                    <div class="empty small">Nothing here yet</div>
                  {/each}
                </div>

                {#if draft[f.id] && (f.item.radius || f.item.extra.length)}
                  <div class="newbox">
                    <span class="label">New entry</span>
                    <div class="extras">
                      {#if f.item.radius}
                        <label><span>Radius</span><input class="input num" type="number" min="2" max="1500" bind:value={draft[f.id].r} onfocus={() => typing(true)} onblur={() => typing(false)} /></label>
                      {/if}
                      {#each f.item.extra as e}
                        <label><span>{e.label}</span>
                          {#if e.type === 'choice'}
                            <select class="input" bind:value={draft[f.id][e.key]}>{#each e.options as o}<option value={o}>{o}</option>{/each}</select>
                          {:else if e.type === 'number'}
                            <input class="input num" type="number" step="0.1" bind:value={draft[f.id][e.key]} onfocus={() => typing(true)} onblur={() => typing(false)} />
                          {:else}
                            <input class="input" type="text" maxlength="40" bind:value={draft[f.id][e.key]} onfocus={() => typing(true)} onblur={() => typing(false)} />
                          {/if}</label>
                      {/each}
                    </div>
                  </div>
                {/if}
                <div class="btns">
                  <button class="btn primary small" disabled={busy || f.value.length >= (f.max || 40)} onclick={() => addHere(f)}><i class="fa-solid fa-plus"></i>Add at my position</button>
                  {#if f.custom}<button class="btn small ghost" disabled={busy} onclick={() => reset(f)}><i class="fa-solid fa-rotate-left"></i>Default list</button>{/if}
                </div>
                {#if f.min > 1}<p class="hint">Needs at least {f.min} entries.</p>{/if}
              {/if}
            </div>
          {/if}
        </section>
      {/each}
    {/if}
  </div>

  <footer>
    <span class="muted">{changed} changed from default</span>
    <button class="btn small danger" disabled={busy || !changed} onclick={resetAll}><i class="fa-solid fa-rotate-left"></i>Reset job</button>
  </footer>

  {#if toast}
    <div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>
  {/if}
</aside>

<style>
  .panel { position: fixed; top: 16px; right: 16px; bottom: 16px; width: 400px; display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 34px; height: 34px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 14px; flex: none; }
  .t { flex: 1; min-width: 0; }
  h1 { font-size: 15px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; }
  .sub { font-size: 11.5px; color: var(--muted); }
  .x { width: 30px; height: 30px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .mode { display: flex; align-items: center; gap: 9px; margin: 10px 12px 0; padding: 7px 10px; border-radius: var(--radius); background: var(--info-bg); border: 1px solid var(--info-line); color: var(--info-text); font-size: 12px; }
  .mode.look { background: var(--accent-soft); border-color: var(--accent-line); color: var(--accent-2); }
  .mode span { flex: 1; }
  .pick { padding: 10px 12px 6px; }
  .fields { flex: 1; min-height: 0; padding: 4px 12px 10px; display: flex; flex-direction: column; gap: 6px; }
  .field { border: 1px solid var(--line-2); border-radius: var(--radius-lg); background: var(--panel); }
  .field.on { border-color: var(--accent-line); }
  .fh { width: 100%; display: flex; align-items: center; gap: 8px; padding: 9px 11px; background: none; border: 0; color: inherit; text-align: left; }
  .fh i { color: var(--faint); font-size: 11px; }
  .fl { flex: 1; font-size: 13px; font-weight: 600; }
  .fb { padding: 2px 11px 11px; display: flex; flex-direction: column; gap: 9px; }
  .hint { font-size: 12px; color: var(--muted); line-height: 1.45; }
  .coords { font-size: 12px; color: var(--text-2); }
  .btns { display: flex; gap: 6px; flex-wrap: wrap; align-items: center; }
  .btns .input { width: 110px; height: 28px; }
  .lim { font-size: 11px; }
  .items { display: flex; flex-direction: column; gap: 6px; }
  .item { padding: 7px 8px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line); display: flex; flex-direction: column; gap: 7px; }
  .ih { display: flex; align-items: center; gap: 8px; }
  .ix { width: 20px; color: var(--accent-2); font-size: 12px; }
  .ih .coords { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .ia { display: flex; gap: 4px; }
  .extras { display: grid; grid-template-columns: 1fr 1fr; gap: 6px 8px; }
  .extras label { display: flex; flex-direction: column; gap: 3px; }
  .extras label span { font-size: 10.5px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 600; }
  .extras .input { height: 28px; font-size: 12px; padding: 0 8px; }
  .newbox { display: flex; flex-direction: column; gap: 6px; padding: 8px; border-radius: var(--radius); border: 1px dashed var(--line-3); }
  .empty.small { padding: 10px; }
  footer { display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; border-top: 1px solid var(--line-2); font-size: 12px; }
  .toast { position: absolute; left: 50%; bottom: 58px; transform: translateX(-50%); display: flex; align-items: center; gap: 8px; padding: 8px 13px; border-radius: var(--radius); background: var(--ok-bg); border: 1px solid var(--ok-line); color: var(--ok-text); font-size: 12.5px; font-weight: 600; white-space: nowrap; }
  .toast.err { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }
</style>
