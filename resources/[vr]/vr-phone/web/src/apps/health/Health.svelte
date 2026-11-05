<script>
  import { onMount } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import Switch from '../../ui/kit/Switch.svelte';
  import { phone, saveSettings } from '../../lib/store.svelte.js';
  import { post } from '../../lib/nui.js';
  import { t } from '../../lib/i18n.js';
  import { DAY_LETTERS, activeText, dayOfWeek, distanceText, ease, heartRate, nudgeGoal, progress } from './model.js';

  // Steps from the player's own walking, the daily goal, and how the character is doing right now.
  // The heart rate is an estimate from what the player is doing (there is no real heart in the game).
  let data = $state(null);
  let loaded = $state(false);
  let vitals = $state(null);
  let bpm = $state(null);

  const cfg = $derived(phone.features?.health ?? {});
  const resting = $derived(cfg.restingRate ?? data?.restingRate ?? 64);
  const imperial = $derived(phone.settings.health?.imperial === true);
  const goal = $derived(phone.settings.health?.goal ?? data?.goal ?? 8000);
  const range = $derived(cfg.goalRange ?? [1000, 40000]);
  const today = $derived(data?.today ?? { steps: 0, metres: 0, active: 0, kcal: 0 });
  const done = $derived(progress(today.steps, goal));
  const tops = $derived(Math.max(goal, ...(data?.week ?? []).map((d) => d.steps), 1));

  const RING = 2 * Math.PI * 78;

  async function load() {
    const r = await post('healthOverview');
    if (r?.ok) data = r.health;
    loaded = true;
  }

  async function sample() {
    const v = await post('healthVitals');
    if (!v || typeof v.health !== 'number') return;
    vitals = v;
    bpm = ease(bpm, heartRate(v, resting));
  }

  onMount(() => {
    load();
    sample();
    const a = setInterval(sample, 1500);
    const b = setInterval(load, 20000);
    return () => {
      clearInterval(a);
      clearInterval(b);
    };
  });

  function setGoal(delta) {
    saveSettings({ health: { goal: nudgeGoal(goal, delta, range) } });
  }

  const bars = $derived([
    { key: 'health', value: vitals?.health ?? 0, color: '#2fa84f', glyph: 'heart' },
    { key: 'armour', value: vitals?.armour ?? 0, color: '#3b82f6', glyph: 'shield' },
    { key: 'food', value: vitals?.hunger ?? 0, color: '#e0922a', glyph: 'food' },
    { key: 'water', value: vitals?.thirst ?? 0, color: '#1fa596', glyph: 'drop' },
    { key: 'stress', value: vitals?.stress ?? 0, color: '#7a5cff', glyph: 'bolt2' },
  ]);
</script>

{#snippet hero()}
  <div class="hero">
    <div class="ring">
      <svg viewBox="0 0 180 180" width="180" height="180">
        <circle cx="90" cy="90" r="78" class="track" />
        <circle cx="90" cy="90" r="78" class="fill" stroke-dasharray={RING} stroke-dashoffset={RING * (1 - done)} transform="rotate(-90 90 90)" />
      </svg>
      <div class="inside">
        <Glyph name="steps" size={26} stroke={1.9} />
        <b>{today.steps.toLocaleString('en-US')}</b>
        <span>{t('health.ofGoal', { goal: goal.toLocaleString('en-US') })}</span>
      </div>
    </div>
    {#if done >= 1}<p class="hit">{t('health.goalHit')}</p>{/if}
    <div class="tiles">
      <div class="tile"><span>{t('health.distance')}</span><b>{distanceText(today.metres, imperial)}</b></div>
      <div class="tile"><span>{t('health.energy')}</span><b>{today.kcal} <small>kcal</small></b></div>
      <div class="tile"><span>{t('health.active')}</span><b>{activeText(today.active)}</b></div>
    </div>
    {#if (data?.streak ?? 0) > 0}
      <p class="streak"><Glyph name="flame" size={16} stroke={2} />{t('health.streak', { n: data.streak })}</p>
    {/if}
  </div>
{/snippet}

{#snippet more()}
  <div class="ap-label first">{t('health.now')}</div>
  <div class="heart">
    <span class="beat" style:animation-duration="{bpm ? Math.max(0.3, 60 / bpm) : 1}s"><Glyph name="heart" size={30} stroke={2} /></span>
    <div>
      <b>{bpm ? Math.round(bpm) : '–'}</b> <small>{t('health.bpm')}</small>
      <div class="sub">{t(`health.state.${vitals?.state ?? 'rest'}`)} · {t('health.estimate')}</div>
    </div>
  </div>

  <div class="bars">
    {#each bars as b (b.key)}
      <div class="bar">
        <span class="name"><Glyph name={b.glyph} size={15} stroke={2.1} />{t(`health.vital.${b.key}`)}</span>
        <span class="track"><span class="fill" style:width="{b.value}%" style:background={b.color}></span></span>
        <span class="num">{b.value}%</span>
      </div>
    {/each}
  </div>

  <div class="ap-label">{t('health.week')}</div>
  <div class="week">
    {#each data?.week ?? [] as d, i (d.day)}
      <div class="col" class:today={i === (data?.week.length ?? 1) - 1}>
        <span class="top">{d.steps ? (d.steps >= 1000 ? `${(d.steps / 1000).toFixed(1)}k` : d.steps) : ''}</span>
        <span class="stick"><span class="col-fill" class:met={d.steps >= goal} style:height="{Math.max(d.steps ? 4 : 0, (d.steps / tops) * 100)}%"></span><span class="goalline" style:bottom="{(goal / tops) * 100}%"></span></span>
        <span class="day">{DAY_LETTERS[dayOfWeek(d.day)]}</span>
      </div>
    {/each}
  </div>

  <div class="ap-label">{t('health.settings')}</div>
  <div class="goal">
    <div class="g-text"><b>{t('health.dailyGoal')}</b><span>{t('health.steps')}</span></div>
    <button class="ap-round" onclick={() => setGoal(-500)} disabled={goal <= range[0]} aria-label={t('health.less')}><Glyph name="minus" size={18} stroke={2.4} /></button>
    <span class="g-val">{goal.toLocaleString('en-US')}</span>
    <button class="ap-round" onclick={() => setGoal(500)} disabled={goal >= range[1]} aria-label={t('health.more')}><Glyph name="plus" size={18} stroke={2.4} /></button>
  </div>
  <div class="goal">
    <div class="g-text"><b>{t('health.miles')}</b><span>{t('health.milesHint')}</span></div>
    <Switch checked={imperial} onchange={(v) => saveSettings({ health: { imperial: v } })} label={t('health.miles')} />
  </div>
  {#if !loaded}<p class="ap-empty">{t('common.loading')}</p>{/if}
  <p class="ap-note foot">{t('health.note')}</p>
{/snippet}

<TwoPane list={more} detail={hero} cover="stack" />

<style>
  .hero {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    padding: 6px 0 4px;
  }
  .ring {
    position: relative;
    width: 180px;
    height: 180px;
  }
  .ring svg circle {
    fill: none;
    stroke-width: 14;
  }
  .track {
    stroke: var(--surface-2);
  }
  .fill {
    stroke: var(--accent);
    stroke-linecap: round;
    transition: stroke-dashoffset 0.6s ease;
  }
  .inside {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 2px;
    color: var(--accent);
  }
  .inside b {
    font-size: 34px;
    line-height: 1.05;
    letter-spacing: -0.02em;
    color: var(--ink);
  }
  .inside span {
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .hit {
    margin: 0;
    font-size: 13.5px;
    font-weight: 700;
    color: #2fa84f;
  }
  .tiles {
    width: 100%;
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }
  .tile {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 10px 8px;
    border-radius: 14px;
    background: var(--surface);
    text-align: center;
  }
  .tile span {
    font-size: 11.5px;
    font-weight: 700;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .tile b {
    font-size: 15.5px;
  }
  .tile small {
    font-size: 11px;
    color: var(--ink-3);
  }
  .streak {
    display: flex;
    align-items: center;
    gap: 6px;
    margin: 0;
    font-size: 13.5px;
    font-weight: 700;
    color: #e0722a;
  }
  .heart {
    display: flex;
    align-items: center;
    gap: 14px;
    padding: 12px 14px;
    border-radius: var(--r-l);
    background: var(--surface);
  }
  .heart b {
    font-size: 30px;
  }
  .heart small {
    font-size: 13px;
    color: var(--ink-3);
  }
  .sub {
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .beat {
    color: #e8527a;
    animation: beat 1s ease-in-out infinite;
  }
  @keyframes beat {
    0%,
    100% {
      transform: scale(1);
    }
    30% {
      transform: scale(1.22);
    }
  }
  .bars {
    display: flex;
    flex-direction: column;
    gap: 10px;
    margin-top: 12px;
  }
  .bar {
    display: grid;
    grid-template-columns: 96px 1fr 40px;
    align-items: center;
    gap: 10px;
    font-size: 13.5px;
  }
  .name {
    display: flex;
    align-items: center;
    gap: 6px;
    font-weight: 600;
  }
  .bar .track {
    height: 9px;
    border-radius: 5px;
    background: var(--surface-2);
    overflow: hidden;
    stroke: none;
  }
  .bar .fill {
    display: block;
    height: 100%;
    border-radius: 5px;
    transition: width 0.5s ease;
  }
  .num {
    text-align: right;
    font-weight: 700;
    color: var(--ink-3);
    font-variant-numeric: tabular-nums;
  }
  .week {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 6px;
    padding: 10px 6px;
    border-radius: var(--r-l);
    background: var(--surface);
  }
  .col {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
  }
  .top {
    height: 14px;
    font-size: 10.5px;
    color: var(--ink-3);
  }
  .stick {
    position: relative;
    width: 100%;
    max-width: 26px;
    height: 90px;
    display: flex;
    align-items: flex-end;
    border-radius: 7px;
    background: var(--surface-2);
    overflow: hidden;
  }
  .col-fill {
    width: 100%;
    border-radius: 7px;
    background: var(--ink-3);
    opacity: 0.55;
  }
  .col-fill.met {
    background: #2fa84f;
    opacity: 1;
  }
  .today .col-fill:not(.met) {
    background: var(--accent);
    opacity: 1;
  }
  .goalline {
    position: absolute;
    left: 0;
    right: 0;
    height: 2px;
    background: var(--ink);
    opacity: 0.35;
  }
  .day {
    font-size: 12px;
    font-weight: 700;
    color: var(--ink-3);
  }
  .today .day {
    color: var(--accent);
  }
  .goal {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 10px 14px;
    margin-bottom: 8px;
    border-radius: var(--r-l);
    background: var(--surface);
  }
  .g-text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
  }
  .g-text b {
    font-size: 15px;
  }
  .g-text span {
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .g-val {
    min-width: 54px;
    text-align: center;
    font-size: 15px;
    font-weight: 700;
    font-variant-numeric: tabular-nums;
  }
  .foot {
    margin: 10px 4px 24px;
  }
</style>
