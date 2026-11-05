<script>
  let { card, bank = 'ValRavn Bank', small = false } = $props();
  const tones = { personal: 'a', savings: 'b', shared: 'c', job: 'd', gang: 'e' };
</script>

<div class="bc tone-{tones[card.account?.type] || 'a'}" class:small class:dim={card.status !== 'active'}>
  <div class="top">
    <span class="bank"><i class="fa-solid fa-building-columns"></i>{bank}</span>
    {#if card.status === 'frozen'}<span class="state"><i class="fa-solid fa-snowflake"></i>Frozen</span>
    {:else if card.locked}<span class="state"><i class="fa-solid fa-lock"></i>Locked</span>{/if}
  </div>
  <div class="chip-ic"><span></span></div>
  <div class="num mono">•••• •••• •••• {card.last4}</div>
  <div class="foot">
    <div><span class="k">Holder</span><span class="v">{card.holder}</span></div>
    <div class="r"><span class="k">Account</span><span class="v">{card.account?.label || '—'}</span></div>
  </div>
</div>

<style>
  .bc { position: relative; aspect-ratio: 1.586; border-radius: 12px; padding: 16px 18px; display: flex; flex-direction: column; overflow: hidden; color: #F2F6FB; border: 1px solid rgba(255, 255, 255, 0.08); box-shadow: 0 10px 24px rgba(0, 0, 0, 0.45); }
  .bc::after { content: ''; position: absolute; inset: 0; background: radial-gradient(120% 80% at 100% 0%, rgba(255, 255, 255, 0.12), transparent 55%); pointer-events: none; }
  .tone-a { background: linear-gradient(135deg, #1B2738, #0E151F 70%); }
  .tone-a::before, .tone-b::before, .tone-c::before, .tone-d::before, .tone-e::before { content: ''; position: absolute; left: 0; right: 0; bottom: 0; height: 4px; }
  .tone-a::before { background: var(--accent); }
  .tone-b { background: linear-gradient(135deg, #14302A, #0B1A17 70%); }
  .tone-b::before { background: var(--ok); }
  .tone-c { background: linear-gradient(135deg, #1A2A47, #0D1526 70%); }
  .tone-c::before { background: var(--info); }
  .tone-d { background: linear-gradient(135deg, #2F2414, #17110A 70%); }
  .tone-d::before { background: var(--accent-2); }
  .tone-e { background: linear-gradient(135deg, #2A1B3D, #140D1F 70%); }
  .tone-e::before { background: var(--doj); }
  .dim { filter: saturate(0.4) brightness(0.8); }
  .top { display: flex; justify-content: space-between; align-items: center; font-size: 12px; font-weight: 700; letter-spacing: 0.04em; }
  .bank { display: inline-flex; align-items: center; gap: 7px; text-transform: uppercase; }
  .bank i { color: var(--accent); }
  .state { display: inline-flex; align-items: center; gap: 5px; padding: 2px 8px; border-radius: 999px; background: rgba(0, 0, 0, 0.35); font-size: 11px; color: #CFE3FF; }
  .chip-ic { margin-top: 14px; width: 38px; height: 28px; border-radius: 6px; background: linear-gradient(135deg, #E9C46A, #B8862B); position: relative; }
  .chip-ic span { position: absolute; inset: 6px 9px; border: 1px solid rgba(60, 40, 0, 0.45); border-radius: 3px; }
  .num { margin-top: auto; font-size: 17px; letter-spacing: 0.08em; }
  .foot { display: flex; justify-content: space-between; margin-top: 10px; gap: 10px; }
  .foot div { display: flex; flex-direction: column; min-width: 0; }
  .foot .r { text-align: right; }
  .k { font-size: 9px; text-transform: uppercase; letter-spacing: 0.1em; color: rgba(242, 246, 251, 0.55); }
  .v { font-size: 13px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .small { padding: 12px 14px; border-radius: 10px; }
  .small .num { font-size: 14px; }
  .small .chip-ic { margin-top: 8px; width: 30px; height: 22px; }
</style>
