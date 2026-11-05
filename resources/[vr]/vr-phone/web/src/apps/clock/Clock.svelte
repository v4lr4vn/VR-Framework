<script>
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import ClockText from '../../ui/ClockText.svelte';
  import { phone, shownClock } from '../../lib/store.svelte.js';
  import { dateText } from '../../lib/time.js';
  import { watch, elapsed, toggle, lap, reset, format } from './stopwatch.svelte.js';
  import { t } from '../../lib/i18n.js';

  // Clock face on one side, stopwatch on the other. When the phone is half open the face sits on top and the stopwatch below.
  const c = $derived(shownClock());
  const hourDeg = $derived(((c.h % 12) + c.m / 60) * 30);
  const minDeg = $derived((c.m + c.s / 60) * 6);
  const secDeg = $derived(c.s * 6);

  let now = $state(Date.now());
  $effect(() => {
    if (!watch.running) {
      now = Date.now();
      return;
    }
    const id = setInterval(() => (now = Date.now()), 40);
    return () => clearInterval(id);
  });
  const shown = $derived(format(elapsed(now)));
</script>

{#snippet face()}
  <div class="faceWrap" class:small={phone.fold !== 'open'}>
    <svg viewBox="-100 -100 200 200" class="face" aria-hidden="true">
      <circle r="96" fill="var(--surface)" stroke="var(--line)" stroke-width="2" />
      {#each Array(12) as _, i}
        <line
          x1="0" y1="-82" x2="0" y2={i % 3 === 0 ? -70 : -76}
          stroke="var(--ink-3)" stroke-width={i % 3 === 0 ? 3.4 : 2} stroke-linecap="round"
          transform="rotate({i * 30})"
        />
      {/each}
      <line x1="0" y1="8" x2="0" y2="-44" stroke="var(--ink)" stroke-width="6" stroke-linecap="round" transform="rotate({hourDeg})" />
      <line x1="0" y1="10" x2="0" y2="-66" stroke="var(--ink)" stroke-width="4" stroke-linecap="round" transform="rotate({minDeg})" />
      <line x1="0" y1="16" x2="0" y2="-72" stroke="var(--accent)" stroke-width="2" stroke-linecap="round" transform="rotate({secDeg})" />
      <circle r="5" fill="var(--accent)" />
    </svg>
    <div class="digital"><ClockText variant="row" size={46} /></div>
    <div class="date">{dateText(c)}</div>
  </div>
{/snippet}

{#snippet stopwatch()}
  <div class="sw">
    <h2>{t('clock.stopwatch')}</h2>
    <div class="big" class:run={watch.running}>{shown}</div>
    <div class="ctrls">
      <button class="round" onclick={watch.running ? lap : reset} disabled={!watch.running && elapsed(now) === 0} aria-label={watch.running ? t('clock.lap') : t('clock.reset')}>
        <Glyph name={watch.running ? 'lap' : 'reset'} size={24} />
      </button>
      <button class="round main" onclick={toggle} aria-label={watch.running ? t('clock.pause') : t('clock.start')}>
        <Glyph name={watch.running ? 'pause' : 'play'} size={28} />
      </button>
    </div>
    <ul class="laps">
      {#each watch.laps as l (l.n)}
        <li><span>{t('clock.lapN', { n: l.n })}</span><span class="mono">{format(l.split)}</span></li>
      {/each}
    </ul>
  </div>
{/snippet}

<TwoPane list={stopwatch} detail={face} swap cover="stack" />

<style>
  .faceWrap {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
  }
  .face {
    width: min(100%, 250px);
    max-height: 250px;
    aspect-ratio: 1;
  }
  .small .face {
    width: 176px;
    max-height: 176px;
  }
  .digital {
    margin-top: 4px;
  }
  .date {
    font-size: 14px;
    color: var(--ink-3);
    font-weight: 600;
  }
  .sw {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 14px;
  }
  h2 {
    margin: 0;
    align-self: flex-start;
    font-size: 22px;
    font-weight: 700;
  }
  .big {
    font-family: var(--mono);
    font-size: 44px;
    font-weight: 600;
    letter-spacing: 0.02em;
    color: var(--ink-2);
  }
  .big.run {
    color: var(--ink);
  }
  .ctrls {
    display: flex;
    gap: 22px;
  }
  .round {
    width: 56px;
    height: 56px;
    border-radius: 50%;
    display: grid;
    place-items: center;
    background: var(--surface-2);
    color: var(--ink);
  }
  .round.main {
    background: var(--accent);
    color: var(--on-accent);
  }
  .round:disabled {
    opacity: 0.4;
  }
  .laps {
    list-style: none;
    margin: 6px 0 0;
    padding: 0;
    width: 100%;
  }
  .laps li {
    display: flex;
    justify-content: space-between;
    padding: 9px 4px;
    border-top: 1px solid var(--line);
    font-size: 15px;
    color: var(--ink-2);
  }
  .mono {
    font-family: var(--mono);
  }
</style>
