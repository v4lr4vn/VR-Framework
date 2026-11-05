<script>
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { phone } from '../../lib/store.svelte.js';
  import { celsius, degrees, glyphFor, kmh, windWord } from './model.js';
  import { clockText, pad } from '../../lib/time.js';
  import { t } from '../../lib/i18n.js';

  // Today's weather from the game, with a rough temperature (see model.js). Hours follow the game clock.
  const cfg = $derived(phone.features?.weather ?? {});
  const c = $derived(phone.clock);
  const time24 = $derived(phone.settings.general.time24);

  function saved() {
    try {
      const v = localStorage.getItem('vr-phone:fahrenheit');
      return v === null ? null : v === '1';
    } catch {
      return null;
    }
  }
  let fahrenheit = $state(saved() ?? false);
  let chosen = $state(saved() !== null);
  const useF = $derived(chosen ? fahrenheit : cfg.fahrenheit === true);

  function toggleUnit() {
    fahrenheit = !useF;
    chosen = true;
    try {
      localStorage.setItem('vr-phone:fahrenheit', fahrenheit ? '1' : '0');
    } catch {
      /* the unit just is not remembered */
    }
  }

  const kind = $derived(c.weather ?? 'clear');
  const nowC = $derived(celsius(kind, c.h + c.m / 60, cfg));
  const hours = $derived(
    Array.from({ length: 12 }, (_, i) => {
      const h = (c.h + i) % 24;
      return { h, label: i === 0 ? t('weather.now') : clockText({ h, m: 0 }, time24), temp: degrees(celsius(kind, h, cfg), useF) };
    }),
  );
  const lowHigh = $derived.by(() => {
    const temps = Array.from({ length: 24 }, (_, h) => celsius(kind, h, cfg));
    return { low: degrees(Math.min(...temps), useF), high: degrees(Math.max(...temps), useF) };
  });
  const wind = $derived(kmh(c.wind));
  const rain = $derived(Math.round((Number(c.rain) || 0) * 100));
  const turning = $derived(c.nextWeather && c.nextWeather !== kind ? c.nextWeather : null);
  const unit = $derived(useF ? '°F' : '°C');
</script>

{#snippet now()}
  <div class="now">
    <div class="place">{cfg.place || t('weather.place')}</div>
    <div class="icon"><Glyph name={glyphFor(kind, c.h)} size={64} stroke={1.5} /></div>
    <div class="temp">{degrees(nowC, useF)}<small>{unit}</small></div>
    <div class="cond">{t(`weather.${kind}`)}</div>
    <div class="lh">{t('weather.lowHigh', { low: lowHigh.low, high: lowHigh.high })}</div>
    {#if turning}<div class="next">{t('weather.turning', { weather: t(`weather.${turning}`) })}</div>{/if}
    <button class="unit" onclick={toggleUnit}>{useF ? t('weather.toCelsius') : t('weather.toFahrenheit')}</button>
  </div>
{/snippet}

{#snippet more()}
  <div class="ap-label first">{t('weather.hourly')}</div>
  <div class="strip">
    {#each hours as h, i (i)}
      <div class="hour" class:cur={i === 0}>
        <span class="hl">{h.label}</span>
        <Glyph name={glyphFor(kind, h.h)} size={22} />
        <b>{h.temp}°</b>
      </div>
    {/each}
  </div>

  <div class="ap-label">{t('weather.details')}</div>
  <div class="tiles">
    <div class="tile"><span>{t('weather.wind')}</span><b>{wind} <small>km/h</small></b><em>{t(`weather.wind.${windWord(c.wind)}`)}</em></div>
    <div class="tile"><span>{t('weather.rain')}</span><b>{rain}<small>%</small></b><em>{rain >= 50 ? t('weather.rain.heavy') : rain > 5 ? t('weather.rain.light') : t('weather.rain.dry')}</em></div>
    <div class="tile"><span>{t('weather.time')}</span><b>{pad(c.h)}:{pad(c.m)}</b><em>{c.h < 6 || c.h >= 21 ? t('weather.night') : t('weather.day')}</em></div>
  </div>
  <p class="ap-note foot">{t('weather.estimate')}</p>
{/snippet}

<TwoPane list={more} detail={now} cover="stack" />

<style>
  .now {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 6px 0 4px;
    text-align: center;
  }
  .place {
    font-size: 18px;
    font-weight: 700;
  }
  .icon {
    margin: 6px 0 0;
    color: var(--accent);
  }
  .temp {
    font-size: 78px;
    font-weight: 300;
    line-height: 1;
    letter-spacing: -0.02em;
  }
  .temp small {
    font-size: 28px;
    font-weight: 400;
    vertical-align: top;
    margin-left: 2px;
    color: var(--ink-3);
  }
  .cond {
    font-size: 20px;
    font-weight: 600;
  }
  .lh,
  .next {
    font-size: 14px;
    color: var(--ink-3);
  }
  .next {
    padding: 4px 12px;
    border-radius: 12px;
    background: var(--accent-soft);
    color: var(--ink);
    font-weight: 600;
  }
  .unit {
    margin-top: 8px;
    padding: 7px 14px;
    border-radius: 12px;
    background: var(--surface-2);
    font-size: 13px;
    font-weight: 700;
    color: var(--ink-2);
  }
  .first {
    margin-top: 0;
  }
  .strip {
    display: flex;
    gap: 8px;
    overflow-x: auto;
    padding-bottom: 6px;
  }
  .hour {
    flex: none;
    width: 62px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    padding: 10px 0;
    border-radius: 16px;
    background: var(--surface);
    border: 1px solid var(--line);
    color: var(--ink);
  }
  .hour.cur {
    background: var(--accent-soft);
    border-color: transparent;
  }
  .hl {
    font-size: 12px;
    font-weight: 600;
    color: var(--ink-3);
  }
  .hour b {
    font-size: 16px;
  }
  .tiles {
    display: grid;
    grid-template-columns: repeat(auto-fit, minmax(110px, 1fr));
    gap: 8px;
  }
  .tile {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 12px;
    border-radius: 16px;
    background: var(--surface);
    border: 1px solid var(--line);
  }
  .tile span {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .tile b {
    font-size: 24px;
    font-weight: 600;
  }
  .tile small {
    font-size: 13px;
    font-weight: 500;
    color: var(--ink-3);
  }
  .tile em {
    font-style: normal;
    font-size: 13px;
    color: var(--ink-3);
  }
  .foot {
    margin-top: 12px;
  }
</style>
