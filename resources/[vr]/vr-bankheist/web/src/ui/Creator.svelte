<script>
  import { errorText, rgb } from '../lib/format.js';
  import { bus } from '../lib/bus.js';

  let { data, call, post, locked, hidden = false, onclose } = $props();

  let banks = $state(data.banks || []);
  let schema = $state(data.schema);
  let doors = $state(data.doors || []);
  let doorlock = $state(data.doorlock !== false);
  let bank = $state(data.bank || null);
  let status = $state(data.status || null);
  let openEl = $state(null);
  let settings = $state(false);
  let busy = $state(false);
  let toast = $state(null);
  let newName = $state('');
  let confirm = $state(null);
  let toastTimer;

  const types = $derived(Object.fromEntries(schema.types.map((t) => [t.id, t])));
  const n1 = (v) => (Math.round(v * 10) / 10).toString();
  const spot = (e) => `${n1(e.x)}, ${n1(e.y)}, ${n1(e.z)}`;

  const say = (text, kind = 'ok') => {
    clearTimeout(toastTimer);
    toast = { text, kind };
    toastTimer = setTimeout(() => (toast = null), 2600);
  };

  function apply(d) {
    if (d.banks) banks = d.banks;
    if (d.doors) doors = d.doors;
    if (d.doorlock !== undefined) doorlock = d.doorlock;
    if (d.bank) bank = d.bank;
    if (d.status) status = d.status;
  }

  async function run(action, payload, success) {
    if (busy) return null;
    busy = true;
    const r = await call(action, payload);
    busy = false;
    if (!r || !r.ok) {
      say(errorText(r && r.error), 'err');
      return null;
    }
    apply(r.data);
    if (success) say(success);
    return r.data;
  }

  async function enter(id) {
    const d = await run('bank', { id });
    if (d) {
      openEl = null;
      settings = false;
      confirm = null;
      post('creatorSelect', { bank: id, el: null });
    }
  }

  function leave() {
    bank = null;
    status = null;
    openEl = null;
    confirm = null;
    post('creatorSelect', { bank: null, el: null });
    run('open', {});
  }

  async function create() {
    const name = newName.trim();
    if (name.length < 2) return say(errorText('bad_name'), 'err');
    const d = await run('create', { name }, 'Bank created at your position');
    if (d) {
      newName = '';
      openEl = null;
      post('creatorSelect', { bank: d.bank.id, el: null });
    }
  }

  async function removeBank() {
    const id = bank.id;
    const d = await run('delete', { id }, 'Bank deleted');
    if (d) {
      bank = null;
      status = null;
      confirm = null;
      post('creatorSelect', { bank: null, el: null });
    }
  }

  const place = (mode, type, el) => post('creatorPlace', { mode, type, id: bank.id, el: el ? el.id : undefined });
  const aimDoor = (el, double) => post('creatorPickDoor', { id: bank.id, el: el.id, double });

  $effect(() =>
    bus.on((m) => {
      if (m.action !== 'creatorPlaced') return;
      if (!m.ok) return say(errorText(m.error), 'err');
      apply(m.data);
      say(m.mode === 'door' ? 'Door added' : m.mode === 'move' ? 'Moved' : m.mode === 'center' ? 'Alert point moved' : 'Placed');
      if (m.data && m.data.added) {
        openEl = m.data.added;
        post('creatorSelect', { bank: bank.id, el: openEl });
      }
    }),
  );

  function pick(id) {
    openEl = openEl === id ? null : id;
    post('creatorSelect', { bank: bank.id, el: openEl });
  }

  const patchEl = (el, patch) => run('update', { id: bank.id, el: el.id, patch }, 'Saved');
  const dropEl = async (el) => {
    const d = await run('remove', { id: bank.id, el: el.id }, 'Removed');
    if (d && openEl === el.id) pick(el.id);
  };
  const patchBank = (patch) => run('bankset', { id: bank.id, patch }, 'Saved');
  const resetHeist = () => run('reset', { id: bank.id }, 'Heist reset, doors locked again');
  const go = (e) => post('creatorGo', { x: e.x, y: e.y, z: e.z });

  const commitNumber = (cur, set) => (e) => {
    const v = Number(e.currentTarget.value);
    if (!Number.isFinite(v)) {
      e.currentTarget.value = cur;
      return;
    }
    if (v !== cur) set(v);
  };

  const enterBlur = (e) => e.key === 'Enter' && e.currentTarget.blur();

  const needOptions = (el) => (bank ? bank.elements.filter((o) => o.id !== el.id && ['hack', 'drill', 'door'].includes(o.type)) : []);
  const byId = (id) => bank && bank.elements.find((o) => o.id === id);
  const label = (el) => `#${el.id} ${el.label || types[el.type].label}`;
  const doorsFree = (el) => doors.filter((d) => !(el.doors || []).includes(d.name));

  const counts = $derived(bank ? bank.elements.reduce((a, e) => ((a[e.type] = (a[e.type] || 0) + 1), a), {}) : {});
  const stateChip = $derived(status ? status.state : 'idle');
  const stat = (el) => (status && status.state === 'active' ? status.el[String(el.id)] : null);
</script>

<aside class="panel card" class:gone={hidden} aria-label="Heist creator">
  <header>
    <span class="logo"><i class="fa-solid fa-vault"></i></span>
    <div class="t">
      <h1>{bank ? bank.label : 'Heist creator'}</h1>
      <p class="sub">{bank ? `${bank.name} · ${bank.elements.length} placed` : 'Pick a heist or make a new one'}</p>
    </div>
    {#if bank}<span class="chip {stateChip === 'active' ? 'danger' : stateChip === 'cooldown' ? 'warn' : 'ok'}">{stateChip}</span>{/if}
    <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  <div class="mode" class:look={!locked}>
    <i class="fa-solid {locked ? 'fa-lock' : 'fa-person-walking'}"></i>
    <span>{locked ? 'Locked. Movement and camera are frozen while you use the panel.' : 'Free. Walk and look around to pick a spot.'}</span>
    <kbd class="key">ALT</kbd>
  </div>

  {#if !bank}
    <div class="body scroll">
      <div class="make box">
        <div class="box-head"><h3>New heist</h3></div>
        <div class="box-body col">
          <p class="hint">Stand at the building first. The alert point is set to where you stand.</p>
          <div class="btns">
            <input class="input" maxlength="40" placeholder="Name, for example fleeca-legion" bind:value={newName} onkeydown={(e) => e.key === 'Enter' && create()} />
            <button class="btn primary" disabled={busy} onclick={create}><i class="fa-solid fa-plus"></i>Create</button>
          </div>
        </div>
      </div>

      {#if !doorlock}
        <div class="notice warn"><i class="fa-solid fa-triangle-exclamation"></i><span>vr-doorlock is not running. Vault doors can not be picked until it starts.</span></div>
      {/if}

      <div class="list">
        {#each banks as b (b.id)}
          <button class="bank" onclick={() => enter(b.id)}>
            <div class="bh">
              <strong>{b.label}</strong>
              <span class="chip {b.state === 'active' ? 'danger' : b.state === 'cooldown' ? 'warn' : ''}">{b.state}</span>
              {#if !b.enabled}<span class="chip">off</span>{/if}
            </div>
            <div class="bc">
              {#each schema.types as t}
                {#if b.counts[t.id]}<span class="mini" style="color:{rgb(t.color)}"><i class="fa-solid {t.icon}"></i>{b.counts[t.id]}</span>{/if}
              {/each}
              {#if !b.count}<span class="muted">Nothing placed yet</span>{/if}
            </div>
          </button>
        {:else}
          <div class="empty"><i class="fa-solid fa-building-columns"></i>No heists yet. Make the first one above.</div>
        {/each}
      </div>
    </div>
  {:else}
    <div class="body scroll">
      <div class="top">
        <button class="btn small ghost" onclick={leave}><i class="fa-solid fa-arrow-left"></i>All heists</button>
        <button class="btn small ghost" onclick={() => (settings = !settings)}><i class="fa-solid fa-sliders"></i>Settings</button>
      </div>

      {#if settings}
        <div class="box">
          <div class="box-body grid">
            {#each schema.bank as f}
              {#if f.kind === 'bool'}
                <label class="chk"><input type="checkbox" checked={bank[f.key]} onchange={(e) => patchBank({ [f.key]: e.currentTarget.checked })} /><span>{f.label}</span></label>
              {:else if f.kind === 'number'}
                <label class="fld"><span>{f.label}</span>
                  <input class="input num" type="number" min={f.min} max={f.max} value={bank[f.key]} onblur={commitNumber(bank[f.key], (v) => patchBank({ [f.key]: v }))} onkeydown={enterBlur} /></label>
              {:else if f.kind === 'choice'}
                <label class="fld"><span>{f.label}</span>
                  <select class="input" value={bank[f.key] || f.options[0]} onchange={(e) => patchBank({ [f.key]: e.currentTarget.value })}>
                    {#each f.options as o}<option value={o}>{o}</option>{/each}
                  </select></label>
              {:else}
                <label class="fld wide"><span>{f.label}</span>
                  <input class="input" maxlength={f.max} value={bank[f.key]} onblur={(e) => e.currentTarget.value !== bank[f.key] && patchBank({ [f.key]: e.currentTarget.value })} onkeydown={enterBlur} /></label>
              {/if}
            {/each}
            <div class="wide btns">
              <span class="coords num">Alert point {n1(bank.center.x)}, {n1(bank.center.y)}, {n1(bank.center.z)}</span>
              <button class="btn small" disabled={busy} onclick={() => place('center')}><i class="fa-solid fa-crosshairs"></i>Aim and set</button>
            </div>
            <div class="wide btns">
              {#if confirm === 'delete'}
                <span class="danger-text">Delete this heist for good?</span>
                <button class="btn small danger" disabled={busy} onclick={removeBank}>Yes, delete</button>
                <button class="btn small ghost" onclick={() => (confirm = null)}>Keep</button>
              {:else}
                <button class="btn small danger" onclick={() => (confirm = 'delete')}><i class="fa-solid fa-trash"></i>Delete heist</button>
              {/if}
            </div>
          </div>
        </div>
      {/if}

      <div class="adds">
        <span class="label">Aim and place</span>
        <div class="addgrid">
          {#each schema.types as t}
            <button class="add" style="--c:{rgb(t.color)};--cs:{rgb(t.color, 0.12)}" disabled={busy} onclick={() => place('add', t.id)} title={t.hint}>
              <i class="fa-solid {t.icon}"></i>
              <span>{t.label}</span>
              {#if counts[t.id]}<b class="num">{counts[t.id]}</b>{/if}
            </button>
          {/each}
        </div>
      </div>

      <div class="els">
        {#each bank.elements as el (el.id)}
          {@const t = types[el.type]}
          {@const st = stat(el)}
          <section class="el" class:on={openEl === el.id} style="--c:{rgb(t.color)}">
            <div class="eh">
              <button class="ebtn" onclick={() => pick(el.id)}>
                <span class="ico"><i class="fa-solid {t.icon}"></i></span>
                <span class="en">
                  <strong>{label(el)}</strong>
                  <small class="num">{spot(el)}</small>
                </span>
                {#if el.needs && byId(el.needs)}<span class="chip info" title="Needs this first"><i class="fa-solid fa-link"></i>{label(byId(el.needs))}</span>{/if}
                {#if st}<span class="chip {st.d ? 'ok' : 'accent'}">{st.d ? 'done' : st.l != null ? st.l + ' left' : 'live'}</span>{/if}
              </button>
              <span class="ia">
                <button class="btn small icon" title="Go there" onclick={() => go(el)}><i class="fa-solid fa-person-walking-arrow-right"></i></button>
                <button class="btn small icon" title="Aim and move" disabled={busy} onclick={() => place('move', null, el)}><i class="fa-solid fa-crosshairs"></i></button>
                <button class="btn small icon danger" title="Remove" disabled={busy} onclick={() => dropEl(el)}><i class="fa-solid fa-trash"></i></button>
              </span>
            </div>

            {#if openEl === el.id}
              <div class="eb">
                <p class="hint">{t.hint}</p>
                <div class="grid">
                  <label class="fld wide"><span>Name</span>
                    <input class="input" maxlength="40" value={el.label} onblur={(e) => e.currentTarget.value !== el.label && patchEl(el, { label: e.currentTarget.value })} onkeydown={enterBlur} /></label>

                  {#if t.radius}
                    <label class="fld"><span>Radius (m)</span>
                      <input class="input num" type="number" min={t.rMin} max={t.rMax} step={t.rStep} value={el.r} onblur={commitNumber(el.r, (v) => patchEl(el, { r: v }))} onkeydown={enterBlur} /></label>
                  {/if}

                  <label class="fld wide"><span>Needs first</span>
                    <select class="input" value={el.needs || 0} onchange={(e) => patchEl(el, { needs: Number(e.currentTarget.value) })}>
                      <option value={0}>Nothing, open from the start</option>
                      {#each needOptions(el) as o}<option value={o.id}>{label(o)}</option>{/each}
                    </select></label>

                  {#each t.fields.filter((x) => !x.hidden) as f}
                    {#if f.kind === 'number'}
                      <label class="fld"><span>{f.label}</span>
                        <input class="input num" type="number" min={f.min} max={f.max} value={el[f.key]} onblur={commitNumber(el[f.key], (v) => patchEl(el, { [f.key]: v }))} onkeydown={enterBlur} /></label>
                    {:else if f.kind === 'choice'}
                      <label class="fld"><span>{f.label}</span>
                        <select class="input" value={el[f.key]} onchange={(e) => patchEl(el, { [f.key]: e.currentTarget.value })}>
                          {#each f.options as o}<option value={o}>{o}</option>{/each}
                        </select></label>
                    {:else if f.kind === 'text'}
                      <label class="fld wide"><span>{f.label}</span>
                        <input class="input" maxlength={f.max} list={f.presets ? `dl-${el.id}-${f.key}` : undefined} value={el[f.key] || ''} onblur={(e) => e.currentTarget.value !== (el[f.key] || '') && patchEl(el, { [f.key]: e.currentTarget.value })} onkeydown={enterBlur} />
                        {#if f.presets}<datalist id="dl-{el.id}-{f.key}">{#each f.presets as o}<option value={o}></option>{/each}</datalist>{/if}</label>
                    {:else if f.kind === 'doors'}
                      <div class="fld wide">
                        <span>{f.label}</span>
                        <div class="dchips">
                          {#each el.doors || [] as name}
                            <span class="chip info">{#if (el.made || []).includes(name)}<i class="fa-solid fa-wand-magic-sparkles" title="Made here"></i>{/if}{name}<button class="cx" aria-label="Remove {name}" onclick={() => patchEl(el, { doors: (el.doors || []).filter((n) => n !== name) })}><i class="fa-solid fa-xmark"></i></button></span>
                          {:else}
                            <span class="muted">No door yet</span>
                          {/each}
                        </div>
                        {#if !doorlock}
                          <div class="notice warn"><i class="fa-solid fa-triangle-exclamation"></i><span>vr-doorlock is not running.</span></div>
                        {:else if (el.doors || []).length < (f.max || 6)}
                          <div class="btns">
                            <button class="btn small primary" disabled={busy} onclick={() => aimDoor(el, false)}><i class="fa-solid fa-crosshairs"></i>Aim at a door</button>
                            <button class="btn small" disabled={busy} onclick={() => aimDoor(el, true)}><i class="fa-solid fa-door-open"></i>Double door</button>
                          </div>
                          {#if doorsFree(el).length}
                            <select class="input" value="" onchange={(e) => { const v = e.currentTarget.value; e.currentTarget.value = ''; if (v) patchEl(el, { doors: [...(el.doors || []), v] }); }}>
                              <option value="">Or pick one that exists…</option>
                              {#each doorsFree(el) as d}<option value={d.name}>{d.name}</option>{/each}
                            </select>
                          {/if}
                        {/if}
                        {#if f.hint}<small class="hint">{f.hint}</small>{/if}
                      </div>
                    {/if}
                  {/each}
                </div>
              </div>
            {/if}
          </section>
        {:else}
          <div class="empty"><i class="fa-solid fa-location-dot"></i>Nothing placed yet. Press a button above, then aim in the world and click.</div>
        {/each}
      </div>
    </div>

    <footer>
      <span class="muted">{status && status.state === 'cooldown' ? 'On cooldown' : status && status.state === 'active' ? 'Heist running' : 'Idle'}</span>
      <button class="btn small" disabled={busy} onclick={resetHeist}><i class="fa-solid fa-rotate-left"></i>Reset heist</button>
    </footer>
  {/if}

  {#if toast}
    <div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>
  {/if}
</aside>

<style>
  .panel.gone { display: none; }
  .panel { position: fixed; top: 16px; right: 16px; bottom: 16px; width: 430px; display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 12px; padding: 12px 14px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 34px; height: 34px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 14px; flex: none; }
  .t { flex: 1; min-width: 0; }
  h1 { font-size: 15px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.04em; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .sub { font-size: 11.5px; color: var(--muted); }
  .x { width: 30px; height: 30px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .mode { display: flex; align-items: center; gap: 9px; margin: 10px 12px 0; padding: 7px 10px; border-radius: var(--radius); background: var(--info-bg); border: 1px solid var(--info-line); color: var(--info-text); font-size: 12px; }
  .mode.look { background: var(--accent-soft); border-color: var(--accent-line); color: var(--accent-2); }
  .mode span { flex: 1; }
  .body { flex: 1; min-height: 0; padding: 10px 12px; display: flex; flex-direction: column; gap: 10px; }
  .col { display: flex; flex-direction: column; gap: 8px; }
  .btns { display: flex; gap: 6px; align-items: center; flex-wrap: wrap; }
  .btns .input { flex: 1; min-width: 0; }
  .hint { font-size: 12px; color: var(--muted); line-height: 1.45; }
  .list { display: flex; flex-direction: column; gap: 6px; }
  .bank { text-align: left; padding: 10px 12px; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: var(--panel); display: flex; flex-direction: column; gap: 6px; }
  .bank:hover { border-color: var(--accent-line); background: var(--panel-2); }
  .bh { display: flex; gap: 8px; align-items: center; }
  .bh strong { flex: 1; font-size: 14px; }
  .bc { display: flex; gap: 12px; font-size: 12px; }
  .mini { display: inline-flex; gap: 5px; align-items: center; font-weight: 600; }
  .top { display: flex; justify-content: space-between; }
  .grid { display: grid; grid-template-columns: 1fr 1fr; gap: 9px 10px; }
  .wide { grid-column: 1 / -1; }
  .fld { display: flex; flex-direction: column; gap: 4px; }
  .fld > span { font-size: 10.5px; color: var(--muted); text-transform: uppercase; letter-spacing: 0.06em; font-weight: 600; }
  .fld .input { height: 30px; font-size: 13px; padding: 0 9px; }
  .chk { display: flex; align-items: center; gap: 8px; font-size: 13px; }
  .chk input { accent-color: var(--accent); width: 15px; height: 15px; }
  .coords { flex: 1; font-size: 12px; color: var(--text-2); }
  .adds { display: flex; flex-direction: column; gap: 6px; }
  .addgrid { display: grid; grid-template-columns: repeat(3, 1fr); gap: 6px; }
  .add { position: relative; display: flex; flex-direction: column; align-items: center; gap: 5px; padding: 9px 4px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--c); font-size: 11.5px; font-weight: 600; }
  .add i { font-size: 16px; }
  .add span { color: var(--text-2); }
  .add:hover:not(:disabled) { background: var(--cs); border-color: var(--c); }
  .add:disabled { opacity: 0.5; }
  .add b { position: absolute; top: 3px; right: 6px; font-size: 10px; color: var(--muted); }
  .els { display: flex; flex-direction: column; gap: 6px; padding-bottom: 4px; }
  .el { border: 1px solid var(--line-2); border-radius: var(--radius-lg); background: var(--panel); }
  .el.on { border-color: var(--c); }
  .eh { display: flex; align-items: center; gap: 6px; padding: 6px 8px 6px 4px; }
  .ebtn { flex: 1; min-width: 0; display: flex; align-items: center; gap: 9px; background: none; border: 0; text-align: left; padding: 3px 4px; }
  .ico { width: 30px; height: 30px; border-radius: var(--radius); display: grid; place-items: center; background: var(--bg-2); color: var(--c); border: 1px solid var(--line-2); flex: none; font-size: 13px; }
  .en { flex: 1; min-width: 0; display: flex; flex-direction: column; }
  .en strong { font-size: 13px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .en small { font-size: 11px; color: var(--muted); }
  .ia { display: flex; gap: 4px; flex: none; }
  .eb { padding: 4px 11px 12px; display: flex; flex-direction: column; gap: 9px; }
  .dchips { display: flex; flex-wrap: wrap; gap: 5px; align-items: center; }
  .cx { background: none; border: 0; color: var(--muted); padding: 0 0 0 3px; font-size: 10px; }
  .cx:hover { color: var(--danger-text); }
  footer { display: flex; justify-content: space-between; align-items: center; padding: 10px 14px; border-top: 1px solid var(--line-2); font-size: 12px; }
  .toast { position: absolute; left: 50%; bottom: 58px; transform: translateX(-50%); display: flex; align-items: center; gap: 8px; padding: 8px 13px; border-radius: var(--radius); background: var(--ok-bg); border: 1px solid var(--ok-line); color: var(--ok-text); font-size: 12.5px; font-weight: 600; white-space: nowrap; z-index: 3; }
  .toast.err { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }
</style>
