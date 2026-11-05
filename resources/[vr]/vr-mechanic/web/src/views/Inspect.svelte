<script>
  import { nui } from '../lib/api.js';

  let { v, onclose } = $props();

  const pct = (n) => Math.max(0, Math.min(100, Math.round(Number(n) || 0)));
  const km = (m) => `${(Math.round((Number(m) || 0) / 100) / 10).toLocaleString('en-US', { minimumFractionDigits: 1 })} km`;
  const tone = (n) => (n < v.warnAt ? 'danger' : n < 60 ? 'warn' : 'ok');
  const word = (n) => (n < v.warnAt ? 'Replace' : n < 60 ? 'Worn' : 'Good');

  let engine = $derived(pct((v.engine ?? 1000) / 10));
  let body = $derived(pct((v.body ?? 1000) / 10));
  let worst = $derived(v.parts.reduce((m, p) => Math.min(m, v.status[p.key] ?? 100), 100));
  let needs = $derived(v.parts.filter((p) => (v.status[p.key] ?? 100) < v.warnAt).length);

  function work(kind, part) {
    nui('work', { kind, part });
  }
</script>

<section class="ins card" aria-label="Vehicle inspection">
  <header>
    <span class="logo"><i class="fa-solid fa-stethoscope"></i></span>
    <div class="title">
      <h1>{v.label || 'Vehicle'}</h1>
      <p class="sub">{v.workshop || 'Roadside inspection'}</p>
    </div>
    {#if v.plate}<span class="plate num">{v.plate}</span>{/if}
    <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  <div class="body">
    <div class="summary">
      <div class="stat"><span class="label">Odometer</span><span class="num big">{km(v.mileage)}</span></div>
      <div class="stat"><span class="label">Weakest part</span><span class="num big {tone(worst)}-text">{pct(worst)}%</span></div>
      <div class="stat"><span class="label">Needs work</span><span class="num big">{needs}<span class="of">&nbsp;/ {v.parts.length}</span></span></div>
    </div>

    <div class="health">
      {#each [['engine', 'Engine block', 'fa-oil-can', engine, v.repairs.engine], ['body', 'Bodywork', 'fa-car-burst', body, v.repairs.body]] as [kind, label, ic, n, item]}
        <div class="h">
          <div class="hh">
            <i class="fa-solid {ic}"></i><span>{label}</span>
            <span class="num {tone(n)}-text">{n}%</span>
          </div>
          <div class="bar {tone(n)}"><span style="width:{n}%"></span></div>
          <button class="btn small" disabled={n >= 100 || !(v.items[item] > 0)} onclick={() => work(kind)} title={v.items[item] > 0 ? '' : 'You have no parts for this'}>
            <i class="fa-solid fa-screwdriver-wrench"></i>Repair<span class="have num">{v.items[item] || 0}</span>
          </button>
        </div>
      {/each}
    </div>

    <div class="list">
      <span class="label">Parts</span>
      {#each v.parts as p (p.key)}
        {@const n = pct(v.status[p.key] ?? 100)}
        <div class="row">
          <span class="pi {tone(n)}"><i class="fa-solid fa-{p.icon}"></i></span>
          <div class="pm">
            <div class="pt"><span class="pn">{p.label}</span><span class="chip {tone(n) === 'ok' ? 'ok' : tone(n)}">{word(n)}</span></div>
            <div class="bar {tone(n)}"><span style="width:{n}%"></span></div>
          </div>
          <span class="num pv {tone(n)}-text">{n}%</span>
          <button class="btn small" disabled={n >= 100 || !(v.items[p.item] > 0)} onclick={() => work('part', p.key)} title={v.items[p.item] > 0 ? '' : 'You have no parts for this'}>
            Replace<span class="have num">{v.items[p.item] || 0}</span>
          </button>
        </div>
      {/each}
    </div>
  </div>

  <footer>
    <button class="btn ghost" onclick={() => nui('openInvoice')}><i class="fa-solid fa-file-invoice-dollar"></i>Bill a customer</button>
    <span class="grow"></span>
    {#if v.canTune}
      <button class="btn primary" onclick={() => nui('openTune')}><i class="fa-solid fa-paint-roller"></i>Customise</button>
    {/if}
  </footer>
</section>

<style>
  .ins { width: 600px; max-width: calc(100vw - 32px); max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 15px; }
  .title { flex: 1; min-width: 0; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .plate { padding: 4px 10px; border-radius: 4px; background: #e9eef4; color: #18212d; font-size: 13px; font-weight: 600; letter-spacing: 0.1em; border: 2px solid #9fb0c4; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .body { padding: 16px; display: flex; flex-direction: column; gap: 16px; overflow-y: auto; }
  .summary { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .stat { display: flex; flex-direction: column; gap: 4px; padding: 10px 12px; border-radius: var(--radius-lg); background: var(--bg-2); border: 1px solid var(--line-2); }
  .big { font-size: 20px; font-weight: 600; }
  .of { font-size: 13px; color: var(--faint); }
  .health { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
  .h { display: flex; flex-direction: column; gap: 8px; padding: 12px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .hh { display: flex; align-items: center; gap: 8px; font-size: 13px; font-weight: 600; }
  .hh i { color: var(--muted); }
  .hh span:first-of-type { flex: 1; }
  .h .btn { align-self: flex-start; }
  .list { display: flex; flex-direction: column; gap: 6px; }
  .row { display: grid; grid-template-columns: 34px 1fr 48px 112px; align-items: center; gap: 12px; padding: 8px 10px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); }
  .pi { width: 34px; height: 34px; border-radius: var(--radius); display: grid; place-items: center; background: var(--panel-2); color: var(--muted); font-size: 14px; }
  .pi.danger { background: var(--danger-bg); color: var(--danger-text); }
  .pi.warn { background: rgba(255, 138, 61, 0.12); color: var(--warn-text); }
  .pi.ok { color: var(--ok-text); }
  .pm { display: flex; flex-direction: column; gap: 6px; min-width: 0; }
  .pt { display: flex; align-items: center; gap: 8px; }
  .pn { font-size: 13px; font-weight: 600; flex: 1; }
  .pt .chip { height: 18px; font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .pv { text-align: right; font-size: 14px; font-weight: 600; }
  .row .btn { width: 100%; }
  .have { margin-left: 2px; padding: 0 5px; border-radius: 3px; background: var(--bg-2); color: var(--muted); font-size: 10px; line-height: 16px; }
  .bar.warn > span { background: var(--warn); }
  .ok-text { color: var(--ok-text); }
  footer { display: flex; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line-2); }
  .grow { flex: 1; }
</style>
