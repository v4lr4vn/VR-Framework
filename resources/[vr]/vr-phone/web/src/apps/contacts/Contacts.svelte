<script>
  import { onMount } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Avatar from '../../ui/Avatar.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { phone, onBack } from '../../lib/store.svelte.js';
  import { comms, saveContact, removeContact, reloadContacts, dial, errorText } from '../../lib/comms.svelte.js';
  import { messageTo } from '../../lib/actions.js';
  import { startShare } from '../../lib/media.svelte.js';
  import { t } from '../../lib/i18n.js';

  // The contact list on one side, the chosen contact (or the form) on the other.
  //   cover (closed): the list, and the contact opens over it. Back returns to the list
  //   flex (half open): the contact on top, the list below
  //   open: the list on the left, the contact on the right
  let query = $state('');
  let pick = $state(null); // the id of the contact being looked at
  let mode = $state('view'); // 'view' | 'new' | 'edit'
  let form = $state({ name: '', number: '' });
  let error = $state('');
  let saving = $state(false);
  let sure = $state(false);

  const list = $derived(
    comms.contacts
      .filter((c) => {
        const q = query.trim().toLowerCase();
        return !q || c.name.toLowerCase().includes(q) || c.number.replace(/\D/g, '').includes(q.replace(/\D/g, '') || '\u0000');
      })
      .sort((a, b) => a.name.localeCompare(b.name, undefined, { sensitivity: 'base' })),
  );
  const current = $derived(comms.contacts.find((c) => c.id === pick) ?? null);
  const detailOpen = $derived(mode !== 'view' || current !== null);

  // Names grouped by their first letter.
  const groups = $derived.by(() => {
    const out = [];
    for (const c of list) {
      const letter = (c.name[0] ?? '#').toUpperCase();
      const last = out[out.length - 1];
      if (last && last.letter === letter) last.items.push(c);
      else out.push({ letter, items: [c] });
    }
    return out;
  });

  onMount(() => {
    reloadContacts();
  });

  // Another app asked to add a number (this also runs once when the app opens).
  $effect(() => {
    const d = comms.draft;
    if (d) {
      startNew(d.number);
      comms.draft = null;
    }
  });

  // On the closed phone the Back button goes from the contact to the list.
  $effect(() => {
    return onBack(() => {
      if (phone.fold === 'cover' && detailOpen) {
        mode = 'view';
        pick = null;
        error = '';
        return true;
      }
      return false;
    });
  });

  function startNew(number = '') {
    mode = 'new';
    pick = null;
    form = { name: '', number };
    error = '';
    sure = false;
  }

  function startEdit() {
    if (!current) return;
    mode = 'edit';
    form = { name: current.name, number: current.number };
    error = '';
  }

  function show(c) {
    pick = c.id;
    mode = 'view';
    error = '';
    sure = false;
  }

  function cancel() {
    mode = 'view';
    error = '';
    if (!current) pick = null;
  }

  async function save() {
    if (saving) return;
    saving = true;
    error = '';
    const data = { name: form.name, number: form.number };
    if (mode === 'edit' && current) {
      data.id = current.id;
      data.favourite = current.favourite;
      data.blocked = current.blocked;
    }
    const r = await saveContact(data);
    saving = false;
    if (!r.ok) {
      error = errorText(r.reason);
      return;
    }
    pick = r.contact.id;
    mode = 'view';
  }

  async function flag(key) {
    if (!current) return;
    error = '';
    const r = await saveContact({ id: current.id, name: current.name, number: current.number, favourite: current.favourite, blocked: current.blocked, [key]: !current[key] });
    if (!r.ok) error = errorText(r.reason);
  }

  async function remove() {
    if (!current) return;
    if (!sure) {
      sure = true;
      setTimeout(() => (sure = false), 3000);
      return;
    }
    const r = await removeContact(current.id);
    sure = false;
    if (r.ok) pick = null;
    else error = errorText(r.reason);
  }

  async function call() {
    if (!current) return;
    error = '';
    const r = await dial(current.number);
    if (!r.ok) error = errorText(r.reason);
  }

  function onformkey(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      save();
    }
  }
</script>

{#snippet people()}
  <div class="head">
    <h2>{t('app.contacts')}</h2>
    <button class="plus" onclick={() => startNew()} aria-label={t('contacts.new')}><Glyph name="plus" size={22} stroke={2.4} /></button>
  </div>
  <label class="search">
    <Glyph name="search" size={18} />
    <input type="text" bind:value={query} placeholder={t('contacts.search')} maxlength="40" />
  </label>

  {#if comms.contacts.length === 0}
    <p class="empty">{t('contacts.empty')}</p>
  {:else if list.length === 0}
    <p class="empty">{t('contacts.noMatch')}</p>
  {:else}
    {#each groups as g (g.letter)}
      <div class="letter">{g.letter}</div>
      <ul>
        {#each g.items as c (c.id)}
          <li>
            <button class="row" class:on={pick === c.id && mode !== 'new'} onclick={() => show(c)}>
              <Avatar name={c.name} number={c.number} size={38} />
              <span class="text">
                <span class="name">{c.name}</span>
                <span class="sub">{c.number}</span>
              </span>
              {#if c.favourite}<Glyph name="star-fill" size={15} />{/if}
              {#if c.blocked}<Glyph name="block" size={15} stroke={2} />{/if}
            </button>
          </li>
        {/each}
      </ul>
    {/each}
  {/if}
{/snippet}

{#snippet card()}
  {#if mode === 'new' || mode === 'edit'}
    <div class="form">
      <h2>{mode === 'new' ? t('contacts.new') : t('contacts.edit')}</h2>
      <label>
        <span>{t('contacts.name')}</span>
        <input type="text" bind:value={form.name} maxlength="40" placeholder={t('contacts.namePlaceholder')} onkeydown={onformkey} />
      </label>
      <label>
        <span>{t('contacts.number')}</span>
        <input type="text" inputmode="tel" bind:value={form.number} maxlength="20" placeholder="555-0123" onkeydown={onformkey} />
      </label>
      {#if error}<p class="err">{error}</p>{/if}
      <div class="btns">
        <button class="btn" onclick={cancel}>{t('common.cancel')}</button>
        <button class="btn main" onclick={save} disabled={saving || !form.name.trim() || !form.number.trim()}>{t('contacts.save')}</button>
      </div>
    </div>
  {:else if current}
    <div class="view">
      <Avatar name={current.name} number={current.number} size={84} />
      <h2 class="big">{current.name}</h2>
      <div class="num">{current.number}</div>
      {#if current.blocked}<div class="tag">{t('contacts.blockedTag')}</div>{/if}

      <div class="acts">
        <button class="act" onclick={call} disabled={comms.call !== null || current.blocked}>
          <span class="ico green"><Glyph name="phone" size={22} stroke={2} /></span>{t('contacts.call')}
        </button>
        <button class="act" onclick={() => messageTo(current.number)}>
          <span class="ico blue"><Glyph name="message" size={22} stroke={2} /></span>{t('contacts.message')}
        </button>
        <button class="act" onclick={() => startShare('contact', [current.id], current.name)}>
          <span class="ico violet"><Glyph name="share" size={22} stroke={2} /></span>{t('contacts.share')}
        </button>
        <button class="act" onclick={() => flag('favourite')}>
          <span class="ico gold"><Glyph name={current.favourite ? 'star-fill' : 'star'} size={22} stroke={2} /></span>{current.favourite ? t('contacts.unfavourite') : t('contacts.favourite')}
        </button>
      </div>

      {#if error}<p class="err">{error}</p>{/if}

      <div class="list">
        <button class="line" onclick={startEdit}><Glyph name="edit" size={19} stroke={2} />{t('contacts.edit')}</button>
        <button class="line" onclick={() => flag('blocked')}>
          <Glyph name="block" size={19} stroke={2} />{current.blocked ? t('contacts.unblock') : t('contacts.block')}
        </button>
        <button class="line red" onclick={remove}><Glyph name="trash" size={19} stroke={2} />{sure ? t('contacts.deleteSure') : t('contacts.delete')}</button>
      </div>
      {#if !current.blocked}<p class="note">{t('contacts.blockHint')}</p>{/if}
    </div>
  {:else}
    <div class="none">
      <Glyph name="contacts" size={44} stroke={1.6} />
      <p>{t('contacts.pick')}</p>
      <button class="btn main" onclick={() => startNew()}>{t('contacts.new')}</button>
    </div>
  {/if}
{/snippet}

<TwoPane list={people} detail={card} cover="switch" showDetail={detailOpen} />

<style>
  .head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 10px;
  }
  h2 {
    margin: 0;
    font-size: 24px;
    font-weight: 700;
  }
  .plus {
    width: 38px;
    height: 38px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: var(--accent);
    color: var(--on-accent);
  }
  .search {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 0 12px;
    height: 40px;
    margin-bottom: 8px;
    border-radius: 14px;
    background: var(--surface-2);
    color: var(--ink-3);
  }
  .search input {
    flex: 1;
    min-width: 0;
    border: 0;
    background: none;
    font-size: 15px;
    color: var(--ink);
  }
  .search input:focus-visible {
    outline: none;
  }
  .letter {
    margin: 12px 4px 2px;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.08em;
    color: var(--ink-3);
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .row {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 11px;
    padding: 7px 8px;
    border-radius: 14px;
    color: var(--ink-3);
  }
  .row:hover {
    background: var(--surface-2);
  }
  .row.on {
    background: var(--accent-soft);
  }
  .text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    color: var(--ink);
  }
  .name {
    font-size: 15.5px;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sub {
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .empty {
    margin: 18px 4px;
    font-size: 14px;
    color: var(--ink-3);
  }

  .view {
    display: flex;
    flex-direction: column;
    align-items: center;
    text-align: center;
  }
  .big {
    margin-top: 12px;
    max-width: 100%;
    font-size: 26px;
    overflow-wrap: anywhere;
  }
  .num {
    margin-top: 2px;
    font-size: 15px;
    color: var(--ink-3);
  }
  .tag {
    margin-top: 8px;
    padding: 3px 10px;
    border-radius: 10px;
    background: rgba(229, 72, 77, 0.14);
    color: #e5484d;
    font-size: 12px;
    font-weight: 700;
  }
  .acts {
    display: flex;
    gap: 10px;
    margin: 18px 0 8px;
  }
  .act {
    width: 74px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 6px;
    font-size: 12px;
    font-weight: 700;
    color: var(--ink-2);
  }
  .act:disabled {
    opacity: 0.4;
  }
  .ico {
    width: 50px;
    height: 50px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    color: #fff;
  }
  .green {
    background: #2fa84f;
  }
  .blue {
    background: #3b82f6;
  }
  .gold {
    background: #e0a21e;
  }
  .violet {
    background: #7a5cff;
  }
  .list {
    width: 100%;
    margin-top: 12px;
    border-radius: var(--r-l);
    background: var(--surface);
    padding: 2px 16px;
  }
  .line {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 13px 0;
    border-bottom: 1px solid var(--line);
    font-size: 15px;
    font-weight: 600;
    color: var(--ink);
  }
  .line:last-child {
    border-bottom: 0;
  }
  .line.red {
    color: #e5484d;
  }
  .note {
    margin: 10px 6px 0;
    font-size: 12.5px;
    line-height: 1.4;
    color: var(--ink-3);
  }
  .err {
    margin: 8px 0 0;
    font-size: 13.5px;
    font-weight: 600;
    color: #e5484d;
  }

  .form {
    display: flex;
    flex-direction: column;
    gap: 14px;
  }
  .form label {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .form label span {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .form input {
    height: 46px;
    padding: 0 14px;
    border-radius: 14px;
    border: 1px solid var(--line);
    background: var(--surface);
    font-size: 16px;
    color: var(--ink);
  }
  .btns {
    display: flex;
    gap: 10px;
    justify-content: flex-end;
  }
  .btn {
    padding: 11px 18px;
    border-radius: 14px;
    background: var(--surface-2);
    font-size: 14px;
    font-weight: 700;
    color: var(--ink);
  }
  .btn.main {
    background: var(--accent);
    color: var(--on-accent);
  }
  .btn:disabled {
    opacity: 0.45;
  }
  .none {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    margin-top: 40px;
    color: var(--ink-3);
    text-align: center;
  }
  .none p {
    margin: 0;
    font-size: 14.5px;
  }
</style>
