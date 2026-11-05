<script>
  let { pack, w = 260, torn = false } = $props();
</script>

<div class="pack" class:torn style="--w:{w}px" aria-label={pack?.label}>
  <div class="crimp top"></div>
  <div class="body">
    <div class="foil"></div>
    <div class="band">
      <span class="brand">VALRAVN</span>
      <span class="set">{pack?.set || 'Trading Cards'}</span>
      <div class="emb">
        <svg viewBox="0 0 100 100" aria-hidden="true">
          <path d="M50 6 L94 50 L50 94 L6 50 Z" class="d1" />
          <path d="M36 32 V68 M64 32 V68 M36 32 L50 46 L64 32" class="rune" />
        </svg>
      </div>
      <span class="kind">BOOSTER PACK</span>
      <span class="code num">{pack?.code || ''}</span>
    </div>
  </div>
  <div class="crimp bottom"></div>
</div>

<style>
  .pack { position: relative; width: var(--w); height: calc(var(--w) * 1.62); filter: drop-shadow(0 calc(var(--w) * 0.06) calc(var(--w) * 0.1) rgba(0, 0, 0, 0.6)); }
  .crimp { position: absolute; left: 0; right: 0; height: calc(var(--w) * 0.09); background: linear-gradient(90deg, #8f96a0, #e9eef4 30%, #a9b0ba 55%, #f2f5f8 80%, #8f96a0); z-index: 2; }
  .crimp::after { content: ''; position: absolute; left: 0; right: 0; top: 0; bottom: 0; background: repeating-linear-gradient(90deg, rgba(0, 0, 0, 0.22) 0 2px, transparent 2px 6px); }
  .top { top: 0; border-radius: calc(var(--w) * 0.03) calc(var(--w) * 0.03) 0 0; transition: transform 0.6s cubic-bezier(0.3, 0.7, 0.3, 1), opacity 0.6s; transform-origin: 10% 100%; }
  .bottom { bottom: 0; border-radius: 0 0 calc(var(--w) * 0.03) calc(var(--w) * 0.03); }
  .torn .top { transform: translate(calc(var(--w) * 0.4), calc(var(--w) * -0.5)) rotate(28deg); opacity: 0; }
  .body { position: absolute; top: calc(var(--w) * 0.08); bottom: calc(var(--w) * 0.08); left: 0; right: 0; overflow: hidden; background: linear-gradient(160deg, #1c2a3e, #0b1018 60%, #1a2232); }
  .foil { position: absolute; inset: -20%; background: repeating-linear-gradient(115deg, rgba(255, 40, 120, 0.35) 0%, rgba(255, 210, 40, 0.35) 5%, rgba(40, 255, 160, 0.35) 10%, rgba(40, 190, 255, 0.35) 15%, rgba(170, 90, 255, 0.35) 20%, rgba(255, 40, 120, 0.35) 25%); background-size: 300% 300%; mix-blend-mode: color-dodge; animation: drift 8s linear infinite; }
  @keyframes drift { from { background-position: 0% 50%; } to { background-position: 300% 50%; } }
  .band { position: absolute; left: calc(var(--w) * 0.08); right: calc(var(--w) * 0.08); top: 12%; bottom: 12%; border-radius: calc(var(--w) * 0.04); background: linear-gradient(180deg, rgba(10, 14, 20, 0.92), rgba(18, 26, 38, 0.92)); border: 2px solid rgba(245, 165, 36, 0.7); display: flex; flex-direction: column; align-items: center; justify-content: center; gap: calc(var(--w) * 0.03); text-align: center; padding: calc(var(--w) * 0.05); }
  .brand { font-weight: 700; letter-spacing: 0.25em; padding-left: 0.25em; color: #ffc85c; font-size: calc(var(--w) * 0.09); }
  .set { font-weight: 700; text-transform: uppercase; color: #e6edf5; font-size: calc(var(--w) * 0.075); line-height: 1.1; }
  .emb { width: calc(var(--w) * 0.4); height: calc(var(--w) * 0.4); margin: calc(var(--w) * 0.03) 0; filter: drop-shadow(0 0 calc(var(--w) * 0.05) rgba(245, 165, 36, 0.6)); }
  .emb svg { width: 100%; height: 100%; }
  .d1 { fill: rgba(245, 165, 36, 0.12); stroke: #f5a524; stroke-width: 3; }
  .rune { fill: none; stroke: #ffc85c; stroke-width: 6; stroke-linecap: round; stroke-linejoin: round; }
  .kind { font-family: var(--mono); font-size: calc(var(--w) * 0.045); letter-spacing: 0.25em; color: #8a9ab0; padding-left: 0.25em; }
  .code { font-size: calc(var(--w) * 0.05); color: #f5a524; }
</style>
