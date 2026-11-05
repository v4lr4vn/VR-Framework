<script>
  let { w = 220 } = $props();
</script>

<div class="back" style="--w:{w}px" aria-label="Card back">
  <div class="in">
    <div class="emblem">
      <svg viewBox="0 0 100 100" aria-hidden="true">
        <path d="M50 4 L96 50 L50 96 L4 50 Z" class="d1" />
        <path d="M50 16 L84 50 L50 84 L16 50 Z" class="d2" />
        <path d="M36 30 V70 M64 30 V70 M36 30 L50 46 L64 30" class="rune" />
      </svg>
    </div>
    <span class="wm">VALRAVN</span>
    <span class="sub">TRADING CARDS</span>
  </div>
</div>

<style>
  .back { width: var(--w); height: calc(var(--w) * 1.4); border-radius: calc(var(--w) * 0.055); padding: calc(var(--w) * 0.028); background: linear-gradient(140deg, #ffd56b, #f5a524 40%, #9a5d05); box-shadow: 0 calc(var(--w) * 0.04) calc(var(--w) * 0.1) rgba(0, 0, 0, 0.55); }
  .in { position: relative; width: 100%; height: 100%; border-radius: calc(var(--w) * 0.035); overflow: hidden; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: calc(var(--w) * 0.03);
    background:
      repeating-linear-gradient(45deg, rgba(245, 165, 36, 0.09) 0 1px, transparent 1px calc(var(--w) * 0.06)),
      repeating-linear-gradient(-45deg, rgba(245, 165, 36, 0.09) 0 1px, transparent 1px calc(var(--w) * 0.06)),
      radial-gradient(circle at 50% 42%, #1d2a3c, #0a0e14 70%); }
  .in::after { content: ''; position: absolute; inset: calc(var(--w) * 0.04); border: 1px solid rgba(245, 165, 36, 0.35); border-radius: calc(var(--w) * 0.025); }
  .emblem { width: calc(var(--w) * 0.5); height: calc(var(--w) * 0.5); filter: drop-shadow(0 0 calc(var(--w) * 0.05) rgba(245, 165, 36, 0.45)); }
  svg { width: 100%; height: 100%; }
  .d1 { fill: rgba(245, 165, 36, 0.1); stroke: #f5a524; stroke-width: 2.5; }
  .d2 { fill: #0d121a; stroke: rgba(245, 165, 36, 0.6); stroke-width: 1.5; }
  .rune { fill: none; stroke: #ffc85c; stroke-width: 5; stroke-linecap: round; stroke-linejoin: round; }
  .wm { font-weight: 700; font-size: calc(var(--w) * 0.1); letter-spacing: 0.22em; color: #ffc85c; padding-left: 0.22em; }
  .sub { font-family: var(--mono); font-size: calc(var(--w) * 0.04); letter-spacing: 0.3em; color: rgba(255, 200, 92, 0.6); padding-left: 0.3em; }
</style>
