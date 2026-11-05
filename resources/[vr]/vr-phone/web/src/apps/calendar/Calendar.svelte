<script>
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import DatePicker from '../../ui/DatePicker.svelte';
  import TimePicker from '../../ui/TimePicker.svelte';
  import { phone, onBack } from '../../lib/store.svelte.js';
  import { post } from '../../lib/nui.js';
  import { scopedError } from '../../lib/errors.js';
  import { monthGrid, addMonths, todayOf, parse, dayText, monthText, timeText } from '../../lib/gamedate.js';
  import { t } from '../../lib/i18n.js';

  // A month on one side, the chosen day (or the event form) on the other. Dates are the game's own.
  const COLOURS = ['#7a5cff', '#e5484d', '#f0a22e', '#27a869', '#3b82f6', '#d6409f', '#14a38b', '#6b7280'];

  const today = $derived(todayOf(phone.clock));
  const time24 = $derived(phone.settings.general.time24);
  const remindChoices = $derived(phone.features?.planner?.remindChoices ?? [0, 5, 15, 30, 60, 1440]);

  const start = parse(todayOf(phone.clock)) ?? { y: 2026, m: 1, d: 1 };
  let view = $state({ y: start.y, m: start.m });
  let selected = $state(todayOf(phone.clock));
  let events = $state([]);
  let mode = $state('day'); // 'day' | 'new' | 'edit'
  let showDay = $state(false); // on the closed phone: the day is open over the month
  let form = $state(blank(selected));
  let editing = $state(null);
  let error = $state('');
  let busy = $state(false);
  let sure = $state(false);

  const rows = $derived(monthGrid(view.y, view.m, 1));
  const byDate = $derived.by(() => {
    const map = {};
    for (const e of events) (map[e.date] ??= []).push(e);
    return map;
  });
  const dayEvents = $derived(byDate[selected] ?? []);

  function blank(date) {
    return { title: '', place: '', note: '', date, minute: null, length: 60, colour: 0, remind: null };
  }

  async function load() {
    const first = rows[0][0].date;
    const last = rows[rows.length - 1][6].date;
    const r = await post('calList', { from: first, to: last });
    if (r?.ok) events = r.events;
  }

  // Loads when the app opens, and again for each new month.
  $effect(() => {
    view.y;
    view.m;
    load();
  });

  $effect(() => {
    return onBack(() => {
      if (phone.fold === 'cover' && (showDay || mode !== 'day')) {
        if (mode !== 'day') mode = 'day';
        else showDay = false;
        error = '';
        return true;
      }
      return false;
    });
  });

  function move(n) {
    const next = addMonths(view.y, view.m, n);
    if (next.y >= 2000 && next.y <= 2100) view = next;
  }

  function goToday() {
    const p = parse(today);
    if (!p) return;
    view = { y: p.y, m: p.m };
    selected = today;
  }

  function choose(date) {
    selected = date;
    mode = 'day';
    showDay = true;
    error = '';
    const p = parse(date);
    if (p && (p.y !== view.y || p.m !== view.m)) view = { y: p.y, m: p.m };
  }

  function startNew() {
    mode = 'new';
    editing = null;
    form = blank(selected);
    error = '';
    showDay = true;
  }

  function startEdit(e) {
    mode = 'edit';
    editing = e.id;
    form = {
      title: e.title,
      place: e.place ?? '',
      note: e.note ?? '',
      date: e.date,
      minute: e.minute ?? null,
      length: e.length ?? 60,
      colour: e.colour ?? 0,
      remind: e.remind ?? null,
    };
    error = '';
    sure = false;
  }

  async function save() {
    if (busy) return;
    busy = true;
    error = '';
    const data = {
      title: form.title,
      place: form.place,
      note: form.note,
      date: form.date,
      minute: form.minute === null ? undefined : form.minute,
      length: form.minute === null ? undefined : form.length,
      colour: form.colour,
      remind: form.remind === null ? undefined : form.remind,
    };
    if (mode === 'edit') data.id = editing;
    const r = await post('calSave', data);
    busy = false;
    if (!r?.ok) {
      error = scopedError(r?.reason, 'calendar');
      return;
    }
    selected = r.event.date;
    mode = 'day';
    const p = parse(selected);
    if (p && (p.y !== view.y || p.m !== view.m)) view = { y: p.y, m: p.m };
    else await load();
  }

  async function remove() {
    if (mode !== 'edit') return;
    if (!sure) {
      sure = true;
      setTimeout(() => (sure = false), 3000);
      return;
    }
    const r = await post('calRemove', { id: editing });
    sure = false;
    if (r?.ok) {
      mode = 'day';
      load();
    } else error = scopedError(r?.reason, 'calendar');
  }

  function remindLabel(n) {
    if (n === 0) return t('calendar.remind.0');
    if (n >= 1440) return t('calendar.remind.days', { n: n / 1440 });
    if (n >= 60) return t('calendar.remind.hours', { n: n / 60 });
    return t('calendar.remind.minutes', { n });
  }

  function whenText(e) {
    if (e.minute === null || e.minute === undefined) return t('calendar.allDay');
    const end = e.length ? ` – ${timeText((e.minute + e.length) % 1440, time24)}` : '';
    return `${timeText(e.minute, time24)}${end}`;
  }

  const detailOpen = $derived(showDay || mode !== 'day');
</script>

{#snippet month()}
  <div class="ap-head">
    <h2>{monthText(view.y, view.m)}</h2>
    <div class="ap-tools">
      <button class="ap-round" onclick={() => move(-1)} aria-label={t('date.prev')}><Glyph name="chev-left" size={18} stroke={2.4} /></button>
      <button class="ap-round" onclick={goToday} aria-label={t('date.today')}><Glyph name="calendar" size={18} stroke={2} /></button>
      <button class="ap-round" onclick={() => move(1)} aria-label={t('date.next')}><Glyph name="chev-right" size={18} stroke={2.4} /></button>
    </div>
  </div>
  <div class="week" class:tight={phone.fold === 'flex'}>{#each [1, 2, 3, 4, 5, 6, 0] as d (d)}<span>{t(`day.${d}`).slice(0, 3)}</span>{/each}</div>
  {#each rows as row, i (i)}
    <div class="weekrow" class:tight={phone.fold === 'flex'}>
      {#each row as cell (cell.date)}
        {@const list = byDate[cell.date] ?? []}
        <button class="cell" class:dim={!cell.inMonth} class:sel={cell.date === selected} class:now={cell.date === today} onclick={() => choose(cell.date)}>
          <span class="num">{cell.day}</span>
          <span class="dots">
            {#each list.slice(0, 3) as e (e.id)}<i style:background={COLOURS[e.colour] ?? COLOURS[0]}></i>{/each}
          </span>
        </button>
      {/each}
    </div>
  {/each}
{/snippet}

{#snippet side()}
  {#if mode === 'new' || mode === 'edit'}
    <div class="ap-form">
      <h2>{mode === 'new' ? t('calendar.new') : t('calendar.edit')}</h2>
      <label>
        <span>{t('calendar.title')}</span>
        <input type="text" bind:value={form.title} maxlength="120" placeholder={t('calendar.titlePlaceholder')} />
      </label>
      <label>
        <span>{t('calendar.place')}</span>
        <input type="text" bind:value={form.place} maxlength="120" placeholder={t('calendar.placePlaceholder')} />
      </label>
      <div class="field">
        <span class="lbl">{t('calendar.date')}</span>
        <DatePicker value={form.date} {today} onchange={(d) => (form.date = d)} label={t('calendar.date')} />
      </div>
      <div class="field">
        <span class="lbl">{t('calendar.time')}</span>
        <TimePicker value={form.minute} allowNone noneLabel={t('calendar.allDay')} onchange={(m) => (form.minute = m)} />
      </div>
      {#if form.minute !== null}
        <div class="field">
          <span class="lbl">{t('calendar.length')}</span>
          <div class="ap-chips">
            {#each [30, 60, 120, 240] as n (n)}
              <button type="button" class="ap-chip" class:on={form.length === n} onclick={() => (form.length = n)}>{n >= 60 ? `${n / 60} h` : `${n} min`}</button>
            {/each}
          </div>
        </div>
      {/if}
      <div class="field">
        <span class="lbl">{t('calendar.alert')}</span>
        <div class="ap-chips">
          <button type="button" class="ap-chip" class:on={form.remind === null} onclick={() => (form.remind = null)}>{t('calendar.noAlert')}</button>
          {#each remindChoices as n (n)}
            <button type="button" class="ap-chip" class:on={form.remind === n} onclick={() => (form.remind = n)}>{remindLabel(n)}</button>
          {/each}
        </div>
      </div>
      <div class="field">
        <span class="lbl">{t('calendar.colour')}</span>
        <div class="swatches">
          {#each COLOURS as c, i (c)}
            <button type="button" class="sw" class:on={form.colour === i} style:background={c} onclick={() => (form.colour = i)} aria-label={`${t('calendar.colour')} ${i + 1}`}></button>
          {/each}
        </div>
      </div>
      <label>
        <span>{t('calendar.note')}</span>
        <textarea bind:value={form.note} maxlength="500" rows="3" placeholder={t('calendar.notePlaceholder')}></textarea>
      </label>
      {#if error}<p class="ap-err">{error}</p>{/if}
      <div class="ap-btns">
        <button class="ap-btn" onclick={() => (mode = 'day')}>{t('common.cancel')}</button>
        {#if mode === 'edit'}<button class="ap-btn red" onclick={remove}>{sure ? t('calendar.deleteSure') : t('calendar.delete')}</button>{/if}
        <button class="ap-btn main" onclick={save} disabled={busy || !form.title.trim()}>{t('calendar.save')}</button>
      </div>
    </div>
  {:else}
    <div class="ap-head">
      <h2 class="day">{dayText(selected, true)}</h2>
      <button class="ap-plus" onclick={startNew} aria-label={t('calendar.new')}><Glyph name="plus" size={22} stroke={2.4} /></button>
    </div>
    {#if selected === today}<p class="ap-ghost today">{t('calendar.todayTag')}</p>{/if}
    {#if dayEvents.length === 0}
      <p class="ap-empty">{t('calendar.noEvents')}</p>
    {:else}
      <ul class="ap-list">
        {#each dayEvents as e (e.id)}
          <li>
            <button class="ap-row ev" onclick={() => startEdit(e)}>
              <span class="bar" style:background={COLOURS[e.colour] ?? COLOURS[0]}></span>
              <span class="txt">
                <span class="ttl">{e.title}</span>
                <span class="sub">{whenText(e)}{#if e.place} · {e.place}{/if}</span>
              </span>
              {#if e.remind !== null && e.remind !== undefined}<Glyph name="bell" size={15} />{/if}
            </button>
          </li>
        {/each}
      </ul>
    {/if}
  {/if}
{/snippet}

<TwoPane list={month} detail={side} cover="switch" showDetail={detailOpen} />

<style>
  .week,
  .weekrow {
    display: grid;
    grid-template-columns: repeat(7, 1fr);
    gap: 3px;
  }
  .week span {
    padding: 4px 0;
    text-align: center;
    font-size: 11px;
    font-weight: 700;
    color: var(--ink-3);
  }
  .weekrow {
    margin-bottom: 3px;
  }
  .cell {
    min-height: 46px;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 3px;
    border-radius: 12px;
    color: var(--ink);
  }
  .weekrow.tight .cell {
    min-height: 34px;
    gap: 1px;
  }
  .weekrow.tight .num {
    font-size: 14px;
  }
  .cell:hover {
    background: var(--surface-2);
  }
  .cell.dim {
    opacity: 0.45;
  }
  .cell.now .num {
    color: var(--accent);
    font-weight: 800;
  }
  .cell.sel {
    background: var(--accent);
    color: var(--on-accent);
    opacity: 1;
  }
  .cell.sel .num {
    color: var(--on-accent);
  }
  .num {
    font-size: 15px;
    font-weight: 600;
  }
  .dots {
    display: flex;
    gap: 3px;
    height: 6px;
  }
  .dots i {
    width: 6px;
    height: 6px;
    border-radius: 50%;
  }
  .cell.sel .dots i {
    box-shadow: 0 0 0 1px rgba(255, 255, 255, 0.85);
  }
  .day {
    font-size: 20px;
  }
  .today {
    margin: -4px 0 8px;
  }
  .ev {
    align-items: stretch;
  }
  .bar {
    flex: none;
    width: 5px;
    border-radius: 3px;
  }
  .txt {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .ttl {
    font-size: 15.5px;
    font-weight: 700;
  }
  .sub {
    font-size: 13px;
    color: var(--ink-3);
  }
  .field {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .lbl {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .swatches {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
  }
  .sw {
    width: 30px;
    height: 30px;
    border-radius: 50%;
  }
  .sw.on {
    box-shadow: 0 0 0 3px var(--bg), 0 0 0 5px var(--ink);
  }
</style>
