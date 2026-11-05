<script>
  import { onMount } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { phone, onBack } from '../../lib/store.svelte.js';
  import { post } from '../../lib/nui.js';
  import { scopedError } from '../../lib/errors.js';
  import { stampDay } from '../../lib/time.js';
  import { t } from '../../lib/i18n.js';

  // The list of notes on one side, the open note on the other (same layout rules as Contacts).
  let notes = $state([]);
  let loaded = $state(false);
  let query = $state('');
  let pick = $state(null); // the id of the open note, or 'new'
  let draft = $state({ title: '', body: '' });
  let saved = $state({ title: '', body: '' }); // what the server has, to tell if anything changed
  let error = $state('');
  let busy = $state(false);
  let sure = $state(false);
  let justSaved = $state(false);
  let flashTimer = 0;

  const limits = $derived(phone.features?.notes ?? { max: 100, titleLength: 80, bodyLength: 4000 });
  const dirty = $derived(draft.title !== saved.title || draft.body !== saved.body);
  const open = $derived(pick !== null);
  const current = $derived(typeof pick === 'number' ? notes.find((n) => n.id === pick) ?? null : null);

  const shown = $derived.by(() => {
    const q = query.trim().toLowerCase();
    if (!q) return notes;
    return notes.filter((n) => n.title.toLowerCase().includes(q) || (n.preview ?? '').toLowerCase().includes(q));
  });

  async function load() {
    const r = await post('noteList');
    if (r?.ok) notes = r.notes;
    loaded = true;
  }

  onMount(() => {
    load();
    return () => {
      clearTimeout(flashTimer);
    };
  });

  // Leaving a note with changes saves it first, so nothing typed is lost.
  async function leave() {
    if (open && dirty && (draft.title.trim() || draft.body.trim())) await save(true);
  }

  $effect(() => {
    return onBack(() => {
      if (phone.fold === 'cover' && open) {
        close();
        return true;
      }
      return false;
    });
  });

  async function close() {
    await leave();
    pick = null;
    error = '';
    sure = false;
  }

  async function startNew() {
    await leave();
    pick = 'new';
    draft = { title: '', body: '' };
    saved = { title: '', body: '' };
    error = '';
    sure = false;
  }

  async function show(n) {
    if (pick === n.id) return;
    await leave();
    const r = await post('noteGet', { id: n.id });
    if (!r?.ok) {
      error = scopedError(r?.reason, 'notes');
      load();
      return;
    }
    pick = n.id;
    draft = { title: r.note.title, body: r.note.body };
    saved = { ...draft };
    error = '';
    sure = false;
  }

  async function save(quiet = false) {
    if (busy) return;
    busy = true;
    error = '';
    const data = { title: draft.title, body: draft.body };
    if (typeof pick === 'number') data.id = pick;
    const r = await post('noteSave', data);
    busy = false;
    if (!r?.ok) {
      if (!quiet) error = scopedError(r?.reason, 'notes');
      return;
    }
    pick = r.note.id;
    draft = { title: r.note.title, body: r.note.body };
    saved = { ...draft };
    await load();
    if (!quiet) {
      justSaved = true;
      clearTimeout(flashTimer);
      flashTimer = setTimeout(() => (justSaved = false), 1600);
    }
  }

  async function togglePin() {
    if (!current) return;
    const r = await post('notePin', { id: current.id, on: !current.pinned });
    if (r?.ok) load();
  }

  async function remove() {
    if (typeof pick !== 'number') {
      pick = null;
      return;
    }
    if (!sure) {
      sure = true;
      setTimeout(() => (sure = false), 3000);
      return;
    }
    const r = await post('noteRemove', { id: pick });
    sure = false;
    if (r?.ok) {
      pick = null;
      saved = { title: '', body: '' };
      draft = { title: '', body: '' };
      load();
    } else error = scopedError(r?.reason, 'notes');
  }
</script>

{#snippet listing()}
  <div class="ap-head">
    <h2>{t('app.notes')}</h2>
    <button class="ap-plus" onclick={startNew} aria-label={t('notes.new')}><Glyph name="plus" size={22} stroke={2.4} /></button>
  </div>
  <label class="ap-search">
    <Glyph name="search" size={18} />
    <input type="text" bind:value={query} placeholder={t('notes.search')} maxlength="40" />
  </label>

  {#if !loaded}
    <p class="ap-empty">{t('common.loading')}</p>
  {:else if notes.length === 0}
    <p class="ap-empty">{t('notes.empty')}</p>
  {:else if shown.length === 0}
    <p class="ap-empty">{t('notes.noMatch')}</p>
  {:else}
    <ul class="ap-list">
      {#each shown as n (n.id)}
        <li>
          <button class="ap-row note" class:on={pick === n.id} onclick={() => show(n)}>
            <span class="txt">
              <span class="ttl">{#if n.pinned}<Glyph name="star-fill" size={13} />{/if}{n.title}</span>
              <span class="sub">{stampDay(n.at, Date.now())} · {n.preview || t('notes.noText')}</span>
            </span>
          </button>
        </li>
      {/each}
    </ul>
  {/if}
{/snippet}

{#snippet editor()}
  {#if open}
    <div class="ap-form">
      <div class="top">
        <h2>{typeof pick === 'number' ? t('notes.edit') : t('notes.new')}</h2>
        {#if current}
          <button class="ap-round" onclick={togglePin} aria-label={current.pinned ? t('notes.unpin') : t('notes.pin')} title={current.pinned ? t('notes.unpin') : t('notes.pin')}>
            <Glyph name={current.pinned ? 'star-fill' : 'star'} size={18} stroke={2} />
          </button>
        {/if}
      </div>
      <label>
        <span>{t('notes.title')}</span>
        <input type="text" bind:value={draft.title} maxlength={limits.titleLength} placeholder={t('notes.titlePlaceholder')} />
      </label>
      <label>
        <span>{t('notes.body')}</span>
        <textarea bind:value={draft.body} maxlength={limits.bodyLength} rows="9" placeholder={t('notes.bodyPlaceholder')}></textarea>
      </label>
      <p class="ap-note count">{draft.body.length} / {limits.bodyLength}</p>
      {#if error}<p class="ap-err">{error}</p>{/if}
      <div class="ap-btns">
        {#if phone.fold === 'cover'}<button class="ap-btn" onclick={close}>{t('notes.done')}</button>{/if}
        <button class="ap-btn red" onclick={remove}>{sure ? t('notes.deleteSure') : t('notes.delete')}</button>
        <button class="ap-btn main" onclick={() => save()} disabled={busy || !dirty || (!draft.title.trim() && !draft.body.trim())}>
          {justSaved ? t('notes.saved') : t('notes.save')}
        </button>
      </div>
    </div>
  {:else}
    <div class="ap-none">
      <Glyph name="notes" size={44} stroke={1.6} />
      <p>{t('notes.pick')}</p>
      <button class="ap-btn main" onclick={startNew}>{t('notes.new')}</button>
    </div>
  {/if}
{/snippet}

<TwoPane list={listing} detail={editor} cover="switch" showDetail={open} />

<style>
  .note {
    align-items: flex-start;
  }
  .txt {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .ttl {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 15.5px;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .ttl :global(svg) {
    color: #e0a21e;
    flex: none;
  }
  .sub {
    font-size: 13px;
    color: var(--ink-3);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .top {
    display: flex;
    align-items: center;
    justify-content: space-between;
  }
  .count {
    margin-top: -8px;
    text-align: right;
  }
</style>
