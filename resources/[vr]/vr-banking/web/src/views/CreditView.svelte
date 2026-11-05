<script>
  import { call } from '../lib/api.js';
  import { money, ago, date } from '../lib/format.js';
  import { app } from '../lib/store.svelte.js';

  let rep = $state(null);
  let stamp = $derived(app.stamp);

  $effect(() => {
    stamp;
    call('credit').then((r) => { if (r.ok) rep = r.data; });
  });

  const R = 92;
  const CX = 120;
  const CY = 116;
  const pt = (f) => {
    const a = Math.PI * (1 - f);
    return [CX + R * Math.cos(a), CY - R * Math.sin(a)];
  };
  const arc = (f0, f1) => {
    const [x0, y0] = pt(f0);
    const [x1, y1] = pt(f1);
    return `M ${x0} ${y0} A ${R} ${R} 0 0 1 ${x1} ${y1}`;
  };
  const tone = { exceptional: '#3DD68C', verygood: '#84E8B6', good: '#5AA9FF', fair: '#F5A524', poor: '#FF5A52' };

  let frac = $derived(rep ? (rep.score - rep.min) / (rep.max - rep.min) : 0);
  let bands = $derived(rep ? [...rep.tiers].reverse().map((t, i, arr) => {
    const lo = Math.max(t.min, rep.min);
    const hi = i < arr.length - 1 ? arr[i + 1].min : rep.max;
    return { ...t, f0: (lo - rep.min) / (rep.max - rep.min), f1: (hi - rep.min) / (rep.max - rep.min) };
  }) : []);
</script>

{#if !rep}
  <div class="empty"><i class="fa-solid fa-circle-notch fa-spin"></i>Loading your credit report</div>
{:else}
  <div class="h"><h2>Credit report</h2><span class="hint">Lenders use this score to decide how much you can borrow and at what rate</span></div>
  <div class="top">
    <div class="gauge box">
      <svg viewBox="0 0 240 140" width="280" height="164" aria-hidden="true">
        {#each bands as b}
          <path d={arc(b.f0 + 0.004, b.f1 - 0.004)} stroke={tone[b.key]} stroke-opacity="0.28" stroke-width="16" fill="none" />
        {/each}
        <path d={arc(0.001, Math.max(0.01, frac))} stroke={tone[rep.tier.key]} stroke-width="16" fill="none" stroke-linecap="round" />
        {#if true}
          {@const p = pt(frac)}
          <circle cx={p[0]} cy={p[1]} r="7" fill="#0A0E14" stroke={tone[rep.tier.key]} stroke-width="3" />
        {/if}
        <text x={CX} y={CY - 18} text-anchor="middle" class="score">{rep.score}</text>
        <text x={CX} y={CY + 4} text-anchor="middle" class="tier" fill={tone[rep.tier.key]}>{rep.tier.label.toUpperCase()}</text>
        <text x={CX - R} y={CY + 22} text-anchor="middle" class="end">{rep.min}</text>
        <text x={CX + R} y={CY + 22} text-anchor="middle" class="end">{rep.max}</text>
      </svg>
      {#if rep.nextTier}
        <p class="next"><strong class="num">{rep.nextTier.min - rep.score}</strong> points to <strong>{rep.nextTier.label}</strong></p>
      {:else}
        <p class="next">You are in the top band</p>
      {/if}
    </div>

    <div class="side">
      <div class="facts box">
        <div><span class="k">Can borrow up to</span><span class="v num">{money(rep.tier.maxLoan)}</span></div>
        <div><span class="k">Unsecured rate</span><span class="v num">{rep.tier.rate}%</span></div>
        <div><span class="k">Payments on time</span><span class="v num">{rep.stats.payments}</span></div>
        <div><span class="k">Missed payments</span><span class="v num" class:danger-text={rep.stats.missed > 0}>{rep.stats.missed}</span></div>
        <div><span class="k">Loans repaid</span><span class="v num">{rep.stats.paid}</span></div>
        <div><span class="k">Defaults</span><span class="v num" class:danger-text={rep.stats.defaults > 0}>{rep.stats.defaults}</span></div>
        <div><span class="k">Customer since</span><span class="v">{date(rep.stats.since)}</span></div>
        <div><span class="k">Active loans</span><span class="v num">{rep.stats.active}</span></div>
      </div>
      <div class="ladder">
        {#each rep.tiers as t}
          <div class="rung" class:on={t.key === rep.tier.key}>
            <span class="dot" style="background:{tone[t.key]}"></span>
            <span class="tl">{t.label}</span>
            <span class="num muted">{t.min > 0 ? `${t.min}+` : `< ${rep.tiers[rep.tiers.length - 2]?.min}`}</span>
            <span class="num">{money(t.maxLoan)}</span>
            <span class="num muted">{t.rate}%</span>
          </div>
        {/each}
      </div>
    </div>
  </div>

  <div class="tips">
    <div class="tip"><i class="fa-solid fa-arrow-trend-up"></i><span>Every on-time installment and every loan paid off raises your score.</span></div>
    <div class="tip"><i class="fa-solid fa-arrow-trend-down"></i><span>Missed payments, defaults and repossessions drop it hard.</span></div>
    <div class="tip"><i class="fa-solid fa-car"></i><span>A vehicle as collateral raises your limit and lowers your rate.</span></div>
  </div>

  <div class="box hist">
    <div class="box-head"><h3>History</h3></div>
    {#if !rep.history.length}
      <div class="empty"><i class="fa-solid fa-clock-rotate-left"></i>No changes yet. Everyone starts at the same score.</div>
    {:else}
      {#each rep.history as h}
        <div class="hrow">
          <span class="delta num" class:pos={h.delta > 0} class:danger-text={h.delta < 0}>{h.delta > 0 ? '+' : ''}{h.delta}</span>
          <span class="reason">{h.reason}</span>
          <span class="num muted">{h.score}</span>
          <span class="muted when">{ago(h.at)}</span>
        </div>
      {/each}
    {/if}
  </div>
{/if}

<style>
  .h { display: flex; align-items: baseline; gap: 10px; margin-bottom: 14px; flex-wrap: wrap; }
  h2 { font-size: 20px; font-weight: 700; }
  .top { display: grid; grid-template-columns: 320px 1fr; gap: 16px; }
  .gauge { display: flex; flex-direction: column; align-items: center; justify-content: center; padding: 16px; }
  .score { font-family: var(--mono); font-size: 40px; font-weight: 600; fill: var(--text); }
  .tier { font-family: var(--font); font-size: 12px; font-weight: 700; letter-spacing: 0.12em; }
  .end { font-family: var(--mono); font-size: 10px; fill: var(--faint); }
  .next { font-size: 13px; color: var(--text-2); margin-top: 4px; }
  .side { display: flex; flex-direction: column; gap: 12px; }
  .facts { display: grid; grid-template-columns: repeat(4, 1fr); gap: 12px; padding: 14px; }
  .facts div { display: flex; flex-direction: column; gap: 2px; }
  .k { font-size: 10px; text-transform: uppercase; letter-spacing: 0.08em; color: var(--muted); font-weight: 600; }
  .v { font-size: 16px; font-weight: 600; }
  .ladder { display: flex; flex-direction: column; border: 1px solid var(--line-2); border-radius: var(--radius-lg); overflow: hidden; }
  .rung { display: grid; grid-template-columns: 14px 1fr 70px 90px 46px; align-items: center; gap: 10px; padding: 7px 12px; font-size: 13px; background: var(--panel); border-bottom: 1px solid var(--line); }
  .rung:last-child { border-bottom: 0; }
  .rung.on { background: var(--accent-soft); }
  .rung.on .tl { font-weight: 700; }
  .rung span:nth-child(4), .rung span:nth-child(5) { text-align: right; }
  .dot { width: 10px; height: 10px; border-radius: 50%; }
  .tips { display: grid; grid-template-columns: repeat(3, 1fr); gap: 10px; margin: 16px 0; }
  .tip { display: flex; gap: 10px; align-items: flex-start; padding: 10px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); font-size: 12px; color: var(--text-2); line-height: 1.45; }
  .tip i { color: var(--accent); margin-top: 2px; }
  .hrow { display: grid; grid-template-columns: 56px 1fr 50px 90px; gap: 10px; align-items: center; padding: 9px 14px; border-bottom: 1px solid var(--line); font-size: 13px; }
  .hrow:last-child { border-bottom: 0; }
  .delta { font-weight: 700; }
  .when { text-align: right; font-size: 12px; }
</style>
