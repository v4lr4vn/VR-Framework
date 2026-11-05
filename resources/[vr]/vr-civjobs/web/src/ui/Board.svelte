<script>
  import { money, errorText } from '../lib/format.js';

  let { p, call, onclose } = $props();

  let sel = $state(null);
  let busy = $state(false);
  let toast = $state(null);
  let nearby = $state([]);
  let buy = $state(5);
  let toastTimer;

  let options = $derived(p.options || []);
  let active = $derived(p.active);
  let isHost = $derived(!!active && active.host === active.me);
  let chosen = $derived(options.find((o) => o.id === sel) || null);
  let pct = $derived(p.xpNext > 0 ? Math.min(100, Math.round((p.xp / p.xpNext) * 100)) : 0);
  let carried = $derived(p.extra?.carried || []);
  let carriedTotal = $derived(carried.reduce((a, c) => a + c.count * c.price, 0));
  let bait = $derived(p.extra?.bait || null);
  let blocked = $derived(!p.qualified || !!p.busyWith);

  $effect(() => {
    if (!options.length) {
      sel = null;
      return;
    }
    const cur = options.find((o) => o.id === sel);
    if (!cur || cur.locked) {
      const first = options.find((o) => !o.locked);
      sel = first ? first.id : options[0].id;
    }
  });

  $effect(() => {
    if (active && isHost && p.crew > 0) loadNearby();
    else nearby = [];
  });

  function say(text, kind = 'ok') {
    clearTimeout(toastTimer);
    toast = { text, kind };
    toastTimer = setTimeout(() => (toast = null), 3000);
  }

  async function run(action, data, success) {
    if (busy) return null;
    busy = true;
    const r = await call(action, data);
    busy = false;
    if (!r.ok) {
      say(errorText(r.error), 'err');
      return r;
    }
    if (success) say(typeof success === 'function' ? success(r.data) : success);
    return r;
  }

  async function loadNearby() {
    const r = await call('crew.nearby', {});
    nearby = r.ok && Array.isArray(r.data) ? r.data : [];
  }

  async function start() {
    const r = await run('start', { job: p.job, option: sel });
    if (r?.ok) onclose(true);
  }

  async function stop() {
    const r = await run('stop', {}, isHost ? 'Shift ended' : 'You left the crew');
    if (r?.ok && !isHost) onclose(true);
  }

  const invite = async (src) => {
    const r = await run('crew.invite', { target: src }, 'Invite sent');
    if (r?.ok) nearby = nearby.filter((n) => n.src !== src);
  };

  const kick = (src) => run('crew.kick', { target: src }, 'Removed from the crew');

  const sell = () => run('sell', { job: p.job }, (d) => `Sold for ${money(d.total)}`);

  const buyBait = () => run('shop', { job: p.job, count: buy }, (d) => `Bought ${d.count} for ${money(d.cost)}`);
</script>

<section class="shell card" aria-label={p.label}>
  <header class="top">
    <span class="logo"><i class="fa-solid {p.icon}"></i></span>
    <div class="title">
      <h1>{p.label}</h1>
      <p class="sub">{p.description}</p>
    </div>
    <span class="chip accent big"><i class="fa-solid fa-star"></i>Level {p.level}</span>
    <button class="x" onclick={() => onclose(false)} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  <div class="body">
    <aside class="left">
      <div class="lvl">
        <div class="row"><span class="label">Experience</span><span class="num xp">{p.xp} / {p.xpNext}</span></div>
        <div class="bar"><span style="width:{pct}%"></span></div>
        <div class="stats">
          <div><span class="k">Shifts</span><span class="v num">{p.done}</span></div>
          <div><span class="k">Earned</span><span class="v num pos">{money(p.earned)}</span></div>
          <div><span class="k">Pay boost</span><span class="v num">x{p.mult.toFixed(2)}</span></div>
        </div>
      </div>

      {#if options.length}
        <div class="label pad">Choose your shift</div>
        <div class="list scroll">
          {#each options as o}
            <button class="item" class:on={sel === o.id} class:lock={o.locked} disabled={o.locked || !!active} onclick={() => (sel = o.id)}>
              <span class="ic"><i class="fa-solid {o.locked ? 'fa-lock' : 'fa-route'}"></i></span>
              <span class="info"><span class="name">{o.label}</span><span class="meta">{o.detail}</span></span>
              {#if o.locked}<span class="chip warn">Lv {o.level}</span>{:else if o.level > 1}<span class="chip">Lv {o.level}</span>{/if}
            </button>
          {/each}
        </div>
      {/if}
    </aside>

    <main class="detail scroll">
      {#if !p.qualified}
        <div class="notice warn"><i class="fa-solid fa-briefcase"></i><span>You need this job first. Pick it up at the City Hall Job Centre, then come back to start a shift.</span></div>
      {:else if p.busyWith}
        <div class="notice warn"><i class="fa-solid fa-clock"></i><span>You are already on a <b>{p.busyWith}</b> shift. Finish it first.</span></div>
      {/if}

      {#if active}
        <div class="panel">
          <div class="phead">
            <h3><i class="fa-solid fa-circle-play"></i>Shift in progress</h3>
            <span class="chip ok num">{money(active.pool)} banked</span>
          </div>
          <div class="crew">
            {#each active.members as m}
              <div class="member">
                <span class="ic"><i class="fa-solid {m.host ? 'fa-crown' : 'fa-user'}"></i></span>
                <span class="info"><span class="name">{m.name}</span><span class="meta">{m.host ? 'Crew leader' : 'Crew'} · {m.tasks} tasks</span></span>
                {#if isHost && !m.host}
                  <button class="btn small danger" disabled={busy} onclick={() => kick(m.src)}><i class="fa-solid fa-user-xmark"></i>Remove</button>
                {/if}
              </div>
            {/each}
          </div>
          {#if p.crew > 1 && isHost}
            <div class="label pad0">Invite someone nearby</div>
            {#each nearby as n}
              <div class="member">
                <span class="ic"><i class="fa-solid fa-user-plus"></i></span>
                <span class="info"><span class="name">{n.name}</span><span class="meta">ID {n.src}</span></span>
                <button class="btn small primary" disabled={busy || active.members.length >= p.crew} onclick={() => invite(n.src)}>Invite</button>
              </div>
            {:else}
              <div class="hint">No one with this job is close enough. Players need the job and must stand within a few metres.</div>
            {/each}
            <button class="btn small ghost refresh" onclick={loadNearby}><i class="fa-solid fa-rotate"></i>Look again</button>
          {:else if p.crew <= 1}
            <div class="hint">This is a solo job.</div>
          {/if}
          <div class="actions">
            <button class="btn danger big" disabled={busy} onclick={stop}><i class="fa-solid fa-flag"></i>{isHost ? 'End shift' : 'Leave crew'}</button>
            <button class="btn ghost big" onclick={() => onclose(true)}>Back to work</button>
          </div>
        </div>
      {:else}
        <div class="panel">
          <div class="phead">
            <h3><i class="fa-solid fa-clipboard-list"></i>{chosen ? chosen.label : 'Start a shift'}</h3>
            {#if chosen && chosen.level > 1}<span class="chip">Level {chosen.level}+</span>{/if}
          </div>
          <p class="lead">{chosen ? chosen.detail : p.description}</p>
          <div class="facts">
            <div><span class="k">Crew size</span><span class="v">{p.crew > 1 ? `Up to ${p.crew}` : 'Solo'}</span></div>
            <div><span class="k">Pay</span><span class="v">Into your bank</span></div>
            <div><span class="k">Your boost</span><span class="v num">x{p.mult.toFixed(2)}</span></div>
          </div>
          {#if p.crew > 1}
            <div class="notice"><i class="fa-solid fa-people-group"></i><span>Work alone or invite crew once the shift starts. Pay is split between everyone who worked, and each extra crew member adds a bonus.</span></div>
          {/if}
          <div class="actions">
            <button class="btn primary big" disabled={busy || blocked || (options.length > 0 && (!chosen || chosen.locked))} onclick={start}><i class="fa-solid fa-play"></i>Start shift</button>
          </div>
        </div>
      {/if}

      {#if p.extra}
        <div class="panel">
          <div class="phead">
            <h3><i class="fa-solid fa-sack-dollar"></i>Your haul</h3>
            {#if carried.length}<span class="chip ok num">{money(Math.floor(carriedTotal * p.mult))}</span>{/if}
          </div>
          {#if carried.length}
            <table>
              <tbody>
                {#each carried as c}
                  <tr><td>{c.label}</td><td class="num r">x{c.count}</td><td class="num r muted">{money(c.price)} each</td></tr>
                {/each}
              </tbody>
            </table>
            <div class="hint">Sell value includes your level boost. Sell at the depot desk.</div>
            <div class="actions"><button class="btn ok big" disabled={busy} onclick={sell}><i class="fa-solid fa-hand-holding-dollar"></i>Sell everything</button></div>
          {:else}
            <div class="empty"><i class="fa-solid fa-box-open"></i>You are not carrying anything to sell</div>
          {/if}
        </div>

        {#if bait}
          <div class="panel">
            <div class="phead">
              <h3><i class="fa-solid fa-worm"></i>Bait shop</h3>
              <span class="chip info num">You have {p.extra.baitCount}</span>
            </div>
            <div class="hint">Bait improves your bite chance and your odds of a big catch. One is used per cast.</div>
            <div class="buy">
              <input class="input num" type="number" min="1" max="50" bind:value={buy} />
              <button class="btn primary" disabled={busy || !(buy >= 1)} onclick={buyBait}><i class="fa-solid fa-cart-shopping"></i>Buy · {money((buy || 0) * bait.price)}</button>
            </div>
          </div>
        {/if}
      {/if}
    </main>
  </div>

  {#if toast}
    <div class="toast {toast.kind}" role="status"><i class="fa-solid {toast.kind === 'err' ? 'fa-circle-exclamation' : 'fa-circle-check'}"></i>{toast.text}</div>
  {/if}
</section>

<style>
  .shell { position: relative; width: 940px; height: 600px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  .top { display: flex; align-items: center; gap: 12px; padding: 14px 18px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 16px; flex: none; }
  .title { flex: 1; min-width: 0; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .chip.big { height: 28px; padding: 0 12px; font-size: 12px; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .body { flex: 1; display: grid; grid-template-columns: 320px 1fr; min-height: 0; }
  .left { display: flex; flex-direction: column; border-right: 1px solid var(--line-2); background: rgba(13, 18, 26, 0.55); min-height: 0; }
  .lvl { padding: 14px; display: flex; flex-direction: column; gap: 9px; border-bottom: 1px solid var(--line); }
  .row { display: flex; justify-content: space-between; align-items: baseline; }
  .xp { font-size: 12px; color: var(--accent-2); }
  .stats { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; margin-top: 4px; }
  .stats div, .facts div { display: flex; flex-direction: column; gap: 3px; }
  .k { color: var(--muted); font-size: 11px; font-weight: 600; letter-spacing: 0.06em; text-transform: uppercase; }
  .v { font-size: 14px; font-weight: 600; }
  .pad { padding: 12px 14px 6px; }
  .pad0 { padding-top: 4px; }
  .list { flex: 1; min-height: 0; padding: 0 8px 10px; display: flex; flex-direction: column; gap: 3px; }
  .item { display: grid; grid-template-columns: 34px 1fr auto; align-items: center; gap: 10px; padding: 9px 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: inherit; text-align: left; }
  .item:hover:not(:disabled) { background: var(--panel); }
  .item.on { background: var(--panel-2); border-color: var(--line-3); }
  .item.lock { opacity: 0.55; }
  .item:disabled:not(.on):not(.lock) { opacity: 0.6; }
  .ic { width: 34px; height: 34px; border-radius: var(--radius); display: grid; place-items: center; background: var(--panel-3); color: var(--text-2); font-size: 14px; }
  .item.on .ic { background: var(--accent-soft); color: var(--accent); }
  .info { display: flex; flex-direction: column; min-width: 0; gap: 2px; }
  .name { font-size: 13px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .meta { font-size: 11px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .detail { padding: 18px 20px; display: flex; flex-direction: column; gap: 14px; min-height: 0; overflow: auto; }
  .panel { background: var(--panel); border: 1px solid var(--line-2); border-radius: var(--radius-lg); padding: 14px; display: flex; flex-direction: column; gap: 12px; }
  .phead { display: flex; align-items: center; justify-content: space-between; gap: 10px; }
  .phead h3 { display: flex; align-items: center; gap: 9px; font-size: 13px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.06em; color: var(--text-2); }
  .phead h3 i { color: var(--accent); font-size: 12px; }
  .lead { font-size: 14px; color: var(--text-2); line-height: 1.5; }
  .facts { display: grid; grid-template-columns: repeat(3, 1fr); gap: 12px; padding: 12px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line); }
  .actions { display: flex; gap: 10px; flex-wrap: wrap; }
  .btn.big { height: 38px; padding: 0 18px; font-size: 14px; }
  .crew { display: flex; flex-direction: column; gap: 6px; }
  .member { display: grid; grid-template-columns: 34px 1fr auto; align-items: center; gap: 10px; padding: 7px 8px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line); }
  .refresh { align-self: flex-start; }
  table { width: 100%; border-collapse: collapse; font-size: 13px; }
  td { padding: 6px 4px; border-bottom: 1px solid var(--line); }
  td.r { text-align: right; }
  .buy { display: flex; gap: 10px; }
  .buy .input { width: 90px; }
  .toast { position: absolute; left: 50%; bottom: 18px; transform: translateX(-50%); display: flex; align-items: center; gap: 8px; padding: 9px 14px; border-radius: var(--radius); background: var(--ok-bg); border: 1px solid var(--ok-line); color: var(--ok-text); font-size: 13px; font-weight: 600; animation: rise 0.16s var(--ease); }
  .toast.err { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }
  @keyframes rise { from { transform: translate(-50%, 6px); opacity: 0; } }
</style>
