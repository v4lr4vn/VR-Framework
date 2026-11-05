<script>
  import { isGame, post } from './lib/nui.js';
  import { mockPayload } from './lib/mock.js';

  const ICONS = {
    EXTRASUNNY: 'sun', CLEAR: 'cloud-sun', NEUTRAL: 'cloud-sun', SMOG: 'industry', FOGGY: 'smog',
    CLOUDS: 'cloud', OVERCAST: 'cloud', CLEARING: 'cloud-sun-rain', RAIN: 'cloud-rain', THUNDER: 'cloud-bolt',
    SNOWLIGHT: 'snowflake', SNOW: 'snowflake', BLIZZARD: 'wind', XMAS: 'gifts', HALLOWEEN: 'ghost',
  };
  const TONES = {
    EXTRASUNNY: 'sun', CLEAR: 'sun', NEUTRAL: 'sun', SMOG: 'haze', FOGGY: 'haze', CLOUDS: 'cloud', OVERCAST: 'dark',
    CLEARING: 'cloud', RAIN: 'rain', THUNDER: 'storm', SNOWLIGHT: 'snow', SNOW: 'snow', BLIZZARD: 'snow', XMAS: 'snow', HALLOWEEN: 'spooky',
  };

  let visible = $state(!isGame);
  let p = $state(isGame ? null : mockPayload());
  let minute = $state(isGame ? 0 : 872);
  let sliderMinute = $state(null);
  let customLength = $state('');

  const icon = (w) => ICONS[w] || 'cloud';
  const tone = (w) => TONES[w] || 'cloud';
  const pad = (n) => String(n).padStart(2, '0');
  const clock = (m) => {
    m = ((m % 1440) + 1440) % 1440;
    return `${pad(Math.floor(m / 60))}:${pad(Math.floor(m % 60))}`;
  };
  const dur = (s) => {
    if (s == null) return '';
    const m = Math.max(1, Math.round(s / 60));
    if (m < 60) return `${m}m`;
    return `${Math.floor(m / 60)}h ${pad(m % 60)}m`;
  };
  const temp = (c) => (p?.units === 'F' ? `${Math.round((c * 9) / 5 + 32)}°F` : `${c}°C`);
  const lengthLabel = (n) => (n >= 1440 ? 'Real time' : n < 60 ? `${n} min` : `${Math.floor(n / 60)}h${n % 60 ? ` ${n % 60}m` : ''}`);

  let isNight = $derived(p ? minute < (p.time.ne ?? 6) * 60 || minute >= (p.time.ns ?? 21) * 60 : false);
  let shownMinute = $derived(sliderMinute ?? minute);
  let gameMinsPerReal = $derived(p ? (1440 / p.time.dayLength).toFixed(1) : '0');

  function act(name, value) {
    if (isGame) post('action', { name, value });
    else mockAct(name, value);
  }

  function mockAct(name, value) {
    if (name === 'weather') {
      const t = p.types.find((x) => x.name === value);
      p.weather.weather = value;
      p.weather.label = t.label;
      p.forecast[0] = { ...p.forecast[0], weather: value, label: t.label };
    } else if (name === 'time') minute = value.hour * 60 + value.minute;
    else if (name === 'freezeTime') p.time.freeze = value;
    else if (name === 'freezeWeather') p.weather.freeze = value;
    else if (name === 'dynamic') p.weather.dynamic = value;
    else if (name === 'blackout') p.weather.blackout = value;
    else if (name === 'dayLength') p.time.dayLength = value;
  }

  function close() {
    if (isGame) post('close');
    visible = false;
  }

  function commitSlider() {
    if (sliderMinute == null) return;
    const m = Math.round(sliderMinute);
    act('time', { hour: Math.floor(m / 60), minute: m % 60 });
    if (!isGame) minute = m;
    sliderMinute = null;
  }

  function setCustomLength(e) {
    e.preventDefault();
    const n = parseInt(customLength, 10);
    if (!n || !p) return;
    act('dayLength', Math.max(p.limits.min, Math.min(p.limits.max, n)));
    customLength = '';
  }

  $effect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      if (d.action === 'open') {
        p = d.data;
        minute = d.minute ?? d.data.time.minute;
        visible = true;
      } else if (d.action === 'state') {
        p = d.data;
        if (d.minute != null) minute = d.minute;
      } else if (d.action === 'clock') {
        minute = d.minute;
      } else if (d.action === 'close') {
        visible = false;
      }
    };
    const onKey = (e) => {
      if (e.key === 'Escape' && visible) close();
    };
    window.addEventListener('message', onMsg);
    window.addEventListener('keydown', onKey);
    return () => {
      window.removeEventListener('message', onMsg);
      window.removeEventListener('keydown', onKey);
    };
  });

  $effect(() => {
    if (isGame || !p || p.time.freeze) return;
    const id = setInterval(() => (minute = (minute + 1440 / (p.time.dayLength * 60)) % 1440), 1000);
    return () => clearInterval(id);
  });
</script>

{#if visible && p}
  <div class="wrap">
    <section class="panel card" aria-label="Weather control">
      <header class="top">
        <div class="title">
          <span class="badge"><i class="fa-solid fa-cloud-sun"></i></span>
          <div>
            <h1>Weather Control</h1>
            <p class="sub">Synced for every player</p>
          </div>
        </div>
        <div class="chips">
          <span class="chip"><i class="fa-solid fa-leaf"></i>{p.seasonLabel}</span>
          <span class="chip"><i class="fa-solid fa-temperature-half"></i>{temp(p.weather.temp)}</span>
          {#if p.holiday}<span class="chip accent"><i class="fa-solid fa-star"></i>Holiday</span>{/if}
          <button class="x" onclick={close} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
        </div>
      </header>

      <div class="body">
        <aside class="left">
          <div class="clock-block">
            <div class="label">In-game time</div>
            <div class="clock mono">
              <i class="fa-solid {isNight ? 'fa-moon' : 'fa-sun'}" class:night={isNight}></i>
              {clock(shownMinute)}
            </div>
            <div class="meta">
              {#if p.time.real}
                Following real UK time
              {:else if p.time.freeze}
                Clock frozen
              {:else}
                {gameMinsPerReal} game min per real min · day lasts {lengthLabel(p.time.dayLength)}
              {/if}
            </div>
          </div>

          <div class="dayline" style="--ns:{(p.time.ns / 24) * 100}%; --ne:{(p.time.ne / 24) * 100}%">
            <div class="track">
              <span class="night n1"></span>
              <span class="night n2"></span>
              <span class="mark" style="left:{(shownMinute / 1440) * 100}%"></span>
            </div>
            <input
              type="range" min="0" max="1439" step="5"
              value={shownMinute}
              disabled={p.time.real}
              oninput={(e) => (sliderMinute = +e.currentTarget.value)}
              onchange={commitSlider}
              aria-label="Set time"
            />
            <div class="ticks mono"><span>00</span><span>06</span><span>12</span><span>18</span><span>24</span></div>
          </div>

          <div class="presets">
            {#each p.presets as pr}
              <button class="btn" disabled={p.time.real} onclick={() => act('time', { hour: pr.hour, minute: pr.minute })}>
                {pr.label}<span class="mono">{pad(pr.hour)}:{pad(pr.minute)}</span>
              </button>
            {/each}
          </div>

          <div class="group">
            <div class="label">Day length <span class="hint">real time for one in-game day</span></div>
            <div class="lengths">
              {#each p.dayLengths as n}
                <button class="pill" class:on={p.time.dayLength === n} onclick={() => act('dayLength', n)}>{lengthLabel(n)}</button>
              {/each}
            </div>
            <form class="custom" onsubmit={setCustomLength}>
              <input class="mono" inputmode="numeric" placeholder="Custom minutes" bind:value={customLength} />
              <button class="btn small" type="submit">Set</button>
            </form>
          </div>

          <div class="group toggles">
            {#each [
              ['freezeTime', 'Freeze time', 'fa-clock', p.time.freeze],
              ['freezeWeather', 'Freeze weather', 'fa-snowflake', p.weather.freeze],
              ['dynamic', 'Dynamic weather', 'fa-shuffle', p.weather.dynamic],
              ['blackout', 'Blackout', 'fa-power-off', p.weather.blackout],
            ] as [key, text, ic, on]}
              <button class="toggle" class:on class:danger={key === 'blackout' && on} onclick={() => act(key, !on)}>
                <i class="fa-solid {ic}"></i><span>{text}</span><span class="sw"><span></span></span>
              </button>
            {/each}
          </div>
        </aside>

        <div class="right">
          <div class="label row">Weather <span class="hint">changes blend over {p.weather.transition}s</span></div>
          <div class="grid">
            {#each p.types as t}
              <button class="tile {tone(t.name)}" class:active={p.weather.weather === t.name} onclick={() => act('weather', t.name)} title={t.name}>
                <i class="fa-solid fa-{icon(t.name)}"></i>
                <span>{t.label}</span>
              </button>
            {/each}
          </div>

          <div class="label row fc-head">
            <span>Forecast</span>
            <span class="actions">
              <button class="btn small" onclick={() => act('reroll')} disabled={!p.weather.dynamic || p.weather.freeze}><i class="fa-solid fa-rotate"></i>Re-roll</button>
              <button class="btn small accent" onclick={() => act('skip')}><i class="fa-solid fa-forward"></i>Next stage</button>
            </span>
          </div>
          <ol class="forecast scroll">
            {#each p.forecast as f, i}
              <li class:now={f.current}>
                <span class="when mono">{f.current ? 'Now' : `+${dur(f.startsIn)}`}</span>
                <span class="ic {tone(f.weather)}"><i class="fa-solid fa-{icon(f.weather)}"></i></span>
                <span class="name">{f.label}</span>
                <span class="t mono">{temp(f.temp)}</span>
                <span class="len mono">{f.endsIn != null ? (f.current ? `ends in ${dur(f.endsIn)}` : dur(f.endsIn - f.startsIn)) : 'held'}</span>
              </li>
            {/each}
            {#if !p.weather.dynamic || p.weather.freeze}
              <li class="note"><i class="fa-solid fa-circle-info"></i>{p.weather.freeze ? 'Weather is frozen, it will not change by itself.' : 'Dynamic weather is off.'}</li>
            {/if}
          </ol>
        </div>
      </div>
    </section>
  </div>
{/if}

<style>
  .wrap { position: fixed; inset: 0; display: grid; place-items: center; background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.35), rgba(10, 14, 20, 0.6)); }
  .panel { width: 880px; max-width: calc(100vw - 32px); height: 580px; max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  .top { display: flex; align-items: center; justify-content: space-between; padding: 14px 18px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .title { display: flex; align-items: center; gap: 12px; }
  .badge { width: 34px; height: 34px; border-radius: var(--radius); background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--accent); display: grid; place-items: center; font-size: 16px; }
  h1 { font-size: 17px; font-weight: 700; letter-spacing: 0.02em; text-transform: uppercase; }
  .sub { color: var(--muted); font-size: 12px; }
  .chips { display: flex; align-items: center; gap: 8px; }
  .chip { display: inline-flex; align-items: center; gap: 6px; height: 26px; padding: 0 10px; border-radius: 999px; background: var(--panel-2); border: 1px solid var(--line-3); color: var(--text-2); font-size: 12px; font-weight: 600; }
  .chip i { color: var(--muted); font-size: 11px; }
  .chip.accent { background: var(--accent-soft); border-color: var(--accent-line); color: var(--accent-2); }
  .chip.accent i { color: var(--accent); }
  .x { width: 30px; height: 30px; margin-left: 4px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }

  .body { flex: 1; display: grid; grid-template-columns: 330px 1fr; min-height: 0; }
  .left { padding: 16px 18px; border-right: 1px solid var(--line-2); display: flex; flex-direction: column; gap: 14px; background: rgba(13, 18, 26, 0.5); }
  .right { padding: 16px 18px; display: flex; flex-direction: column; min-height: 0; }
  .label { color: var(--muted); font-size: 11px; font-weight: 600; letter-spacing: 0.08em; text-transform: uppercase; }
  .label .hint, .hint { text-transform: none; letter-spacing: 0; font-weight: 400; color: var(--faint); margin-left: 6px; }
  .row { display: flex; align-items: center; justify-content: space-between; margin-bottom: 8px; }

  .clock { font-size: 44px; font-weight: 600; line-height: 1.1; display: flex; align-items: center; gap: 12px; color: var(--text); }
  .clock i { font-size: 24px; color: var(--accent); }
  .clock i.night { color: var(--info); }
  .meta { color: var(--text-2); font-size: 12px; margin-top: 2px; }

  .dayline { position: relative; }
  .track { position: relative; height: 8px; border-radius: 4px; background: linear-gradient(90deg, var(--accent-line), var(--accent) 50%, var(--accent-line)); overflow: hidden; }
  .night { position: absolute; top: 0; bottom: 0; background: #1D3F6B; }
  .n1 { left: 0; width: var(--ne); }
  .n2 { left: var(--ns); right: 0; }
  .mark { position: absolute; top: -3px; width: 3px; height: 14px; margin-left: -1px; background: var(--text); border-radius: 2px; box-shadow: 0 0 0 2px var(--bg); }
  .dayline input[type='range'] { position: absolute; left: 0; right: 0; top: -6px; width: 100%; height: 20px; opacity: 0; cursor: pointer; margin: 0; }
  .dayline input:disabled { cursor: not-allowed; }
  .ticks { display: flex; justify-content: space-between; color: var(--faint); font-size: 10px; margin-top: 4px; }

  .presets { display: grid; grid-template-columns: repeat(4, 1fr); gap: 6px; }
  .btn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; height: 32px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); font-weight: 600; font-size: 12px; transition: background 0.15s var(--ease), border-color 0.15s var(--ease); }
  .presets .btn { flex-direction: column; height: 42px; gap: 0; }
  .presets .btn .mono { font-size: 10px; color: var(--muted); font-weight: 500; }
  .btn:hover:not(:disabled) { background: var(--panel-3); color: var(--text); }
  .btn:disabled { opacity: 0.45; }
  .btn.small { height: 28px; font-size: 12px; }
  .btn.accent { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }
  .btn.accent:hover { background: var(--accent-2); color: var(--accent-ink); }

  .group { display: flex; flex-direction: column; gap: 8px; }
  .lengths { display: flex; flex-wrap: wrap; gap: 6px; }
  .pill { height: 26px; padding: 0 10px; border-radius: 999px; border: 1px solid var(--line-3); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; }
  .pill:hover { border-color: var(--accent-line); color: var(--text); }
  .pill.on { background: var(--accent-soft); border-color: var(--accent); color: var(--accent-2); }
  .custom { display: flex; gap: 6px; }
  .custom input { flex: 1; height: 28px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--bg-2); padding: 0 10px; font-size: 12px; }
  .custom input:focus { outline: none; border-color: var(--accent); }

  .toggles { gap: 6px; margin-top: auto; }
  .toggle { display: flex; align-items: center; gap: 10px; height: 34px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 13px; text-align: left; }
  .toggle i { width: 16px; color: var(--muted); }
  .toggle span:nth-of-type(1) { flex: 1; }
  .toggle:hover { border-color: var(--line-3); }
  .sw { width: 30px; height: 16px; border-radius: 999px; background: var(--line-3); position: relative; transition: background 0.15s var(--ease); }
  .sw span { position: absolute; top: 2px; left: 2px; width: 12px; height: 12px; border-radius: 50%; background: var(--muted); transition: transform 0.15s var(--ease), background 0.15s; }
  .toggle.on { border-color: var(--accent-line); color: var(--text); }
  .toggle.on i { color: var(--accent); }
  .toggle.on .sw { background: var(--accent-soft); box-shadow: inset 0 0 0 1px var(--accent); }
  .toggle.on .sw span { transform: translateX(14px); background: var(--accent); }
  .toggle.danger { border-color: var(--danger-line); background: var(--danger-bg); }
  .toggle.danger i { color: var(--danger); }
  .toggle.danger .sw { box-shadow: inset 0 0 0 1px var(--danger); background: var(--p1-soft); }
  .toggle.danger .sw span { background: var(--danger); }

  .grid { display: grid; grid-template-columns: repeat(5, 1fr); gap: 6px; }
  .tile { height: 64px; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 6px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; transition: border-color 0.15s var(--ease), background 0.15s var(--ease); }
  .tile i { font-size: 18px; }
  .tile:hover { border-color: var(--line-3); background: var(--panel-2); color: var(--text); }
  .tile.active { border-color: var(--accent); background: var(--accent-soft); color: var(--text); box-shadow: inset 0 0 0 1px var(--accent); }
  .sun i { color: #FFC85C; }
  .haze i { color: #B9A88A; }
  .cloud i { color: #C3CEDC; }
  .dark i { color: #8A9AB0; }
  .rain i { color: var(--info); }
  .storm i { color: #B79CFF; }
  .snow i { color: #DDEBFF; }
  .spooky i { color: #FF8A3D; }

  .fc-head { margin-top: 16px; }
  .actions { display: flex; gap: 6px; text-transform: none; letter-spacing: 0; }
  .forecast { list-style: none; margin: 0; padding: 0; flex: 1; min-height: 0; border: 1px solid var(--line-2); border-radius: var(--radius); background: var(--bg-2); }
  .forecast li { display: grid; grid-template-columns: 64px 28px 1fr 56px 110px; align-items: center; gap: 8px; height: 38px; padding: 0 12px; border-bottom: 1px solid var(--line); font-size: 13px; }
  .forecast li:last-child { border-bottom: 0; }
  .forecast li.now { background: var(--accent-soft); }
  .forecast li.now .when { color: var(--accent-2); font-weight: 600; }
  .when { color: var(--muted); font-size: 12px; }
  .ic { text-align: center; }
  .name { color: var(--text); font-weight: 600; }
  .t { color: var(--text-2); text-align: right; }
  .len { color: var(--faint); font-size: 11px; text-align: right; }
  .forecast li.note { display: flex; gap: 8px; color: var(--muted); font-size: 12px; }
</style>
