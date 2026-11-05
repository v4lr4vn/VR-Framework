<script>
  import { onMount } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import Segmented from '../../ui/kit/Segmented.svelte';
  import DatePicker from '../../ui/DatePicker.svelte';
  import TimePicker from '../../ui/TimePicker.svelte';
  import { phone, onBack } from '../../lib/store.svelte.js';
  import { post } from '../../lib/nui.js';
  import { scopedError } from '../../lib/errors.js';
  import { todayOf, nowStamp, stamp, dayText, timeText } from '../../lib/gamedate.js';
  import { t } from '../../lib/i18n.js';

  // Things to do, some with a date and a time. A reminder with a date alerts at that moment on the game clock.
  let items = $state([]);
  let loaded = $state(false);
  let tab = $state('today'); // 'today' | 'scheduled' | 'all' | 'done'
  let pick = $state(null); // an id, or 'new'
  let form = $state({ title: '', note: '', date: '', minute: null });
  let error = $state('');
  let busy = $state(false);

  const today = $derived(todayOf(phone.clock));
  const time24 = $derived(phone.settings.general.time24);
  const now = $derived(nowStamp(phone.clock));
  const open = $derived(pick !== null);

  const isLate = (r) => !r.done && r.date && stamp(r.date, r.minute ?? 0) < now;

  const shown = $derived.by(() => {
    if (tab === 'done') return items.filter((r) => r.done);
    const live = items.filter((r) => !r.done);
    if (tab === 'today') return live.filter((r) => r.date && r.date <= today);
    if (tab === 'scheduled') return live.filter((r) => r.date && r.date > today);
    return live;
  });
  const counts = $derived({
    today: items.filter((r) => !r.done && r.date && r.date <= today).length,
    scheduled: items.filter((r) => !r.done && r.date && r.date > today).length,
  });

  const tabs = $derived([
    { value: 'today', label: counts.today ? `${t('reminders.today')} · ${counts.today}` : t('reminders.today') },
    { value: 'scheduled', label: t('reminders.scheduled') },
    { value: 'all', label: t('reminders.all') },
    { value: 'done', label: t('reminders.done') },
  ]);

  async function load() {
    const r = await post('remList');
    if (r?.ok) items = r.reminders;
    loaded = true;
  }
  onMount(load);

  $effect(() => {
    return onBack(() => {
      if (phone.fold === 'cover' && open) {
        pick = null;
        error = '';
        return true;
      }
      return false;
    });
  });

  function startNew() {
    pick = 'new';
    form = { title: '', note: '', date: '', minute: null };
    error = '';
  }

  function edit(r) {
    pick = r.id;
    form = { title: r.title, note: r.note ?? '', date: r.date ?? '', minute: r.minute ?? null };
    error = '';
  }

  async function save() {
    if (busy) return;
    busy = true;
    error = '';
    const data = { title: form.title, note: form.note, date: form.date || undefined, minute: form.date && form.minute !== null ? form.minute : undefined };
    if (typeof pick === 'number') data.id = pick;
    const r = await post('remSave', data);
    busy = false;
    if (!r?.ok) {
      error = scopedError(r?.reason, 'reminders');
      return;
    }
    pick = null;
    await load();
  }

  async function toggle(r) {
    const res = await post('remDone', { id: r.id, done: !r.done });
    if (res?.ok) {
      r.done = !r.done;
      items = items;
      if (pick === r.id) pick = null;
    } else load();
  }

  async function remove() {
    if (typeof pick !== 'number') {
      pick = null;
      return;
    }
    const r = await post('remRemove', { id: pick });
    if (r?.ok) {
      pick = null;
      load();
    } else error = scopedError(r?.reason, 'reminders');
  }

  async function clearDone() {
    const r = await post('remRemove', { clearDone: true });
    if (r?.ok) load();
  }

  function whenText(r) {
    if (!r.date) return '';
    const day = r.date === today ? t('reminders.todayWord') : dayText(r.date);
    return r.minute !== null && r.minute !== undefined ? `${day}, ${timeText(r.minute, time24)}` : day;
  }
</script>

{#snippet listing()}
  <div class="ap-head">
    <h2>{t('app.reminders')}</h2>
    <button class="ap-plus" onclick={startNew} aria-label={t('reminders.new')}><Glyph name="plus" size={22} stroke={2.4} /></button>
  </div>
  <Segmented options={tabs} value={tab} onchange={(v) => (tab = v)} label={t('app.reminders')} />

  {#if !loaded}
    <p class="ap-empty">{t('common.loading')}</p>
  {:else if shown.length === 0}
    <p class="ap-empty">{t(`reminders.empty.${tab}`)}</p>
  {:else}
    <ul class="ap-list">
      {#each shown as r (r.id)}
        <li class="item">
          <button class="tick" class:on={r.done} onclick={() => toggle(r)} aria-label={r.done ? t('reminders.undo') : t('reminders.complete')}>
            {#if r.done}<Glyph name="check" size={15} stroke={3} />{/if}
          </button>
          <button class="ap-row" class:on={pick === r.id} onclick={() => edit(r)}>
            <span class="txt">
              <span class="ttl" class:struck={r.done}>{r.title}</span>
              {#if r.date}<span class="sub" class:late={isLate(r)}>{whenText(r)}</span>{/if}
            </span>
          </button>
        </li>
      {/each}
    </ul>
    {#if tab === 'done'}
      <div class="ap-btns clear"><button class="ap-btn red" onclick={clearDone}>{t('reminders.clear')}</button></div>
    {/if}
  {/if}
{/snippet}

{#snippet editor()}
  {#if open}
    <div class="ap-form">
      <h2>{typeof pick === 'number' ? t('reminders.edit') : t('reminders.new')}</h2>
      <label>
        <span>{t('reminders.title')}</span>
        <input type="text" bind:value={form.title} maxlength="120" placeholder={t('reminders.titlePlaceholder')} />
      </label>
      <label>
        <span>{t('reminders.note')}</span>
        <input type="text" bind:value={form.note} maxlength="300" placeholder={t('reminders.notePlaceholder')} />
      </label>
      <div class="field">
        <span class="lbl">{t('reminders.date')}</span>
        <DatePicker value={form.date} {today} allowNone onchange={(d) => (form.date = d)} label={t('reminders.date')} />
      </div>
      {#if form.date}
        <div class="field">
          <span class="lbl">{t('reminders.time')}</span>
          <TimePicker value={form.minute} allowNone noneLabel={t('reminders.noTime')} onchange={(m) => (form.minute = m)} />
        </div>
        <p class="ap-note">{form.minute === null ? t('reminders.alertDefault') : t('reminders.alertAt')}</p>
      {/if}
      {#if error}<p class="ap-err">{error}</p>{/if}
      <div class="ap-btns">
        <button class="ap-btn" onclick={() => (pick = null)}>{t('common.cancel')}</button>
        {#if typeof pick === 'number'}<button class="ap-btn red" onclick={remove}>{t('reminders.delete')}</button>{/if}
        <button class="ap-btn main" onclick={save} disabled={busy || !form.title.trim()}>{t('reminders.save')}</button>
      </div>
    </div>
  {:else}
    <div class="ap-none">
      <Glyph name="reminders" size={44} stroke={1.6} />
      <p>{t('reminders.pick')}</p>
      <button class="ap-btn main" onclick={startNew}>{t('reminders.new')}</button>
    </div>
  {/if}
{/snippet}

<TwoPane list={listing} detail={editor} cover="switch" showDetail={open} />

<style>
  .item {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .tick {
    flex: none;
    width: 26px;
    height: 26px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    border: 2px solid var(--ink-3);
    color: var(--on-accent);
  }
  .tick.on {
    background: var(--accent);
    border-color: var(--accent);
  }
  .txt {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .ttl {
    font-size: 15.5px;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .ttl.struck {
    text-decoration: line-through;
    color: var(--ink-3);
  }
  .sub {
    font-size: 13px;
    color: var(--ink-3);
  }
  .sub.late {
    color: #e5484d;
    font-weight: 600;
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
  .clear {
    margin-top: 12px;
  }
</style>
