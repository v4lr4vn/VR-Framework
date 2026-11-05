<script>
  import { onMount, tick as nextTick, untrack } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Avatar from '../../ui/Avatar.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { phone, onBack, setTyping } from '../../lib/store.svelte.js';
  import {
    comms,
    labelFor,
    nameFor,
    contactFor,
    loadThreads,
    openConversation,
    closeConversation,
    loadOlder,
    sendText,
    removeThread,
    dial,
    errorText,
  } from '../../lib/comms.svelte.js';
  import { addContact } from '../../lib/actions.js';
  import { ago, stampTime, stampDay } from '../../lib/time.js';
  import { tick } from '../../lib/store.svelte.js';
  import { t } from '../../lib/i18n.js';

  // Conversations on one side, the open conversation on the other.
  //   cover (closed): the list, and the conversation opens over it. Back returns to the list
  //   flex (half open): the conversation on top, the list below
  //   open: the list on the left, the conversation on the right
  let to = $state(null); // the number of the open conversation, or 'new' while choosing who to write to
  let who = $state(''); // the number typed in the "To" box of a new message
  let draft = $state('');
  let error = $state('');
  let sending = $state(false);
  let sure = $state(false);
  let scroller = $state(null);

  const limit = $derived(phone.features.calls?.maxLength || 500);
  const convo = $derived(to && to !== 'new' ? comms.convos[to] : null);
  const detailOpen = $derived(to !== null);

  // New message: contacts that match what is typed.
  const matches = $derived.by(() => {
    const q = who.trim().toLowerCase();
    const digits = q.replace(/\D/g, '');
    return comms.contacts
      .filter((c) => !c.blocked && (!q || c.name.toLowerCase().includes(q) || (digits && c.number.replace(/\D/g, '').includes(digits))))
      .slice(0, 6);
  });

  // Messages with a day heading above the first one of each day.
  const rows = $derived.by(() => {
    const out = [];
    let last = '';
    for (const m of convo?.messages ?? []) {
      const day = stampDay(m.at, tick.now);
      if (day !== last) out.push({ kind: 'day', key: `d${m.id}`, text: day });
      last = day;
      out.push({ kind: 'msg', key: `m${m.id}`, m });
    }
    return out;
  });

  onMount(() => {
    loadThreads(true);
  });

  // New texts, new names: fetch the list again.
  $effect(() => {
    comms.rev.threads;
    untrack(() => loadThreads(true));
  });

  // Another app asked to open a conversation.
  $effect(() => {
    const target = comms.target;
    if (target) {
      comms.target = null;
      untrack(() => open(target));
    }
  });

  // On the closed phone the Back button goes from the conversation to the list.
  $effect(() => {
    return onBack(() => {
      if (phone.fold === 'cover' && detailOpen) {
        leave();
        return true;
      }
      return false;
    });
  });

  // The conversation is at its newest message whenever it opens or a message arrives.
  $effect(() => {
    convo?.messages.length;
    nextTick().then(() => {
      if (scroller) scroller.scrollTop = scroller.scrollHeight;
    });
  });

  // The game must not read keys as movement while the To box is on screen. (The composer and the box have their own focus.)
  $effect(() => {
    if (to === 'new') setTyping(true);
    return () => {
      if (to === 'new') setTyping(false);
    };
  });

  function leave() {
    to = null;
    draft = '';
    error = '';
    sure = false;
    closeConversation();
  }

  function open(number) {
    to = number;
    draft = '';
    error = '';
    sure = false;
    openConversation(number);
  }

  function startNew() {
    to = 'new';
    who = '';
    error = '';
    closeConversation();
  }

  function startTo(number) {
    if (!number.trim()) return;
    open(number.trim());
  }

  async function send() {
    const body = draft.trim();
    if (!body || sending || !to || to === 'new') return;
    sending = true;
    error = '';
    const r = await sendText(to, body);
    sending = false;
    if (r.ok) draft = '';
    else error = errorText(r.reason);
  }

  function onbox(e) {
    // Enter sends. Shift+Enter makes a new line.
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault();
      send();
    }
  }

  async function call() {
    if (!to || to === 'new') return;
    error = '';
    const r = await dial(to);
    if (!r.ok) error = errorText(r.reason);
  }

  async function remove() {
    if (!sure) {
      sure = true;
      setTimeout(() => (sure = false), 3000);
      return;
    }
    const number = to;
    sure = false;
    const r = await removeThread(number);
    if (r.ok) leave();
    else error = errorText(r.reason);
  }
</script>

{#snippet threads()}
  <div class="head">
    <h2>{t('app.messages')}</h2>
    <button class="plus" onclick={startNew} aria-label={t('messages.new')}><Glyph name="edit" size={20} stroke={2.2} /></button>
  </div>
  {#if comms.threads.length === 0}
    <p class="empty">{t('messages.empty')}</p>
  {:else}
    <ul>
      {#each comms.threads as th (th.number)}
        <li>
          <button class="row" class:on={to === th.number} onclick={() => open(th.number)}>
            <Avatar name={nameFor(th.number)} number={th.number} size={44} />
            <span class="text">
              <span class="top">
                <span class="name" class:bold={th.unread > 0}>{labelFor(th.number)}</span>
                <span class="when">{ago(th.at * 1000, tick.now)}</span>
              </span>
              <span class="prev" class:bold={th.unread > 0}>
                <span class="line">{th.mine ? `${t('messages.you')}: ` : ''}{th.body}</span>
                {#if th.unread > 0}<i class="count">{th.unread > 9 ? '9+' : th.unread}</i>{/if}
              </span>
            </span>
          </button>
        </li>
      {/each}
    </ul>
  {/if}
{/snippet}

{#snippet chat()}
  {#if to === 'new'}
    <div class="newmsg">
      <h2>{t('messages.new')}</h2>
      <label class="to">
        <span>{t('messages.to')}</span>
        <input
          type="text"
          bind:value={who}
          maxlength="20"
          placeholder={t('messages.toPlaceholder')}
          onkeydown={(e) => e.key === 'Enter' && (e.preventDefault(), startTo(who))}
        />
      </label>
      <ul>
        {#each matches as c (c.id)}
          <li>
            <button class="row" onclick={() => open(c.number)}>
              <Avatar name={c.name} number={c.number} size={38} />
              <span class="text">
                <span class="name">{c.name}</span>
                <span class="sub">{c.number}</span>
              </span>
            </button>
          </li>
        {/each}
      </ul>
      {#if who.trim() && !matches.some((c) => c.number === who.trim())}
        <button class="use" onclick={() => startTo(who)}>{t('messages.writeTo', { who: who.trim() })}</button>
      {/if}
    </div>
  {:else if to}
    <div class="chat">
      <header>
        <Avatar name={nameFor(to)} number={to} size={38} />
        <div class="who">
          <div class="name">{labelFor(to)}</div>
          {#if nameFor(to)}<div class="sub">{to}</div>{/if}
        </div>
        {#if !contactFor(to)}
          <button class="tool" onclick={() => addContact(to)} aria-label={t('phone.addContact')} title={t('phone.addContact')}><Glyph name="user-plus" size={20} stroke={2} /></button>
        {/if}
        <button class="tool" onclick={call} disabled={comms.call !== null} aria-label={t('phone.call')} title={t('phone.call')}><Glyph name="phone" size={20} stroke={2} /></button>
        <button class="tool" class:red={sure} onclick={remove} aria-label={t('messages.delete')} title={sure ? t('messages.deleteSure') : t('messages.delete')}>
          <Glyph name="trash" size={20} stroke={2} />
        </button>
      </header>

      <div class="msgs" bind:this={scroller}>
        {#if convo?.more}
          <button class="older" onclick={() => loadOlder(to)}>{t('messages.older')}</button>
        {/if}
        {#if convo && !convo.loaded}
          <p class="faint">{t('common.loading')}</p>
        {:else if rows.length === 0}
          <p class="faint">{t('messages.sayHi')}</p>
        {/if}
        {#each rows as r (r.key)}
          {#if r.kind === 'day'}
            <div class="day">{r.text}</div>
          {:else}
            <div class="bubble" class:mine={r.m.mine}>
              <span class="body">{r.m.body}</span>
              <span class="time">{stampTime(r.m.at, phone.settings.general.time24)}</span>
            </div>
          {/if}
        {/each}
      </div>

      {#if error}<div class="err">{error}</div>{/if}
      <div class="composer">
        <textarea
          rows="1"
          bind:value={draft}
          onkeydown={onbox}
          maxlength={limit}
          placeholder={t('messages.placeholder')}
        ></textarea>
        <button class="send" onclick={send} disabled={!draft.trim() || sending} aria-label={t('messages.send')}>
          <Glyph name="send" size={20} stroke={2} />
        </button>
      </div>
      {#if draft.length > limit - 80}<div class="left">{limit - draft.length}</div>{/if}
    </div>
  {:else}
    <div class="none">
      <Glyph name="message" size={44} stroke={1.6} />
      <p>{t('messages.pick')}</p>
      <button class="btn" onclick={startNew}>{t('messages.new')}</button>
    </div>
  {/if}
{/snippet}

<TwoPane list={threads} detail={chat} cover="switch" showDetail={detailOpen} />

<style>
  .head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
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
  ul {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .row {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 9px 8px;
    border-radius: 14px;
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
    gap: 2px;
  }
  .top,
  .prev {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .name {
    flex: 1;
    min-width: 0;
    font-size: 15.5px;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .name.bold {
    font-weight: 700;
  }
  .when {
    flex: none;
    font-size: 11.5px;
    color: var(--ink-3);
  }
  .prev {
    font-size: 13.5px;
    color: var(--ink-3);
  }
  .prev.bold {
    color: var(--ink);
    font-weight: 600;
  }
  .line {
    flex: 1;
    min-width: 0;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .sub {
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .count {
    flex: none;
    min-width: 19px;
    height: 19px;
    padding: 0 5px;
    border-radius: 10px;
    background: var(--accent);
    color: var(--on-accent);
    font-size: 11px;
    font-style: normal;
    font-weight: 700;
    line-height: 19px;
    text-align: center;
  }
  .empty,
  .faint {
    margin: 18px 4px;
    font-size: 14px;
    color: var(--ink-3);
    text-align: center;
  }

  /* the open conversation fills its half of the screen */
  .chat {
    display: flex;
    flex-direction: column;
    height: 100%;
    min-height: 0;
    position: relative;
  }
  header {
    flex: none;
    display: flex;
    align-items: center;
    gap: 10px;
    padding-bottom: 10px;
    border-bottom: 1px solid var(--line);
  }
  .who {
    flex: 1;
    min-width: 0;
  }
  .who .name {
    font-size: 16px;
    font-weight: 700;
  }
  .tool {
    flex: none;
    width: 36px;
    height: 36px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    color: var(--ink-2);
  }
  .tool:hover {
    background: var(--surface-2);
  }
  .tool:disabled {
    opacity: 0.4;
  }
  .tool.red {
    background: #e5484d;
    color: #fff;
  }
  .msgs {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
    display: flex;
    flex-direction: column;
    gap: 5px;
    padding: 10px 2px;
  }
  .older {
    align-self: center;
    padding: 5px 12px;
    border-radius: 12px;
    background: var(--surface-2);
    font-size: 12.5px;
    font-weight: 700;
    color: var(--ink-2);
  }
  .day {
    align-self: center;
    margin: 8px 0 3px;
    font-size: 11.5px;
    font-weight: 700;
    color: var(--ink-3);
  }
  .bubble {
    align-self: flex-start;
    max-width: 82%;
    padding: 8px 12px 6px;
    border-radius: 18px 18px 18px 6px;
    background: var(--surface-2);
    color: var(--ink);
  }
  .bubble.mine {
    align-self: flex-end;
    border-radius: 18px 18px 6px 18px;
    background: var(--accent);
    color: var(--on-accent);
  }
  .body {
    display: block;
    font-size: 15px;
    line-height: 1.35;
    white-space: pre-wrap;
    overflow-wrap: anywhere;
  }
  .time {
    display: block;
    margin-top: 2px;
    font-size: 10.5px;
    text-align: right;
    opacity: 0.65;
  }
  .err {
    flex: none;
    padding: 4px 4px 0;
    font-size: 13px;
    font-weight: 600;
    color: #e5484d;
  }
  .composer {
    flex: none;
    display: flex;
    align-items: flex-end;
    gap: 8px;
    padding-top: 8px;
  }
  textarea {
    flex: 1;
    min-width: 0;
    max-height: 90px;
    resize: none;
    padding: 10px 14px;
    border-radius: 20px;
    border: 1px solid var(--line);
    background: var(--surface);
    font: inherit;
    font-size: 15px;
    line-height: 1.3;
    color: var(--ink);
  }
  .send {
    flex: none;
    width: 42px;
    height: 42px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: var(--accent);
    color: var(--on-accent);
  }
  .send:disabled {
    opacity: 0.4;
  }
  .left {
    position: absolute;
    right: 56px;
    bottom: 50px;
    font-size: 11px;
    font-weight: 700;
    color: var(--ink-3);
  }

  .newmsg {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .to {
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .to span {
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.06em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .to input {
    height: 46px;
    padding: 0 14px;
    border-radius: 14px;
    border: 1px solid var(--line);
    background: var(--surface);
    font-size: 16px;
    color: var(--ink);
  }
  .use {
    padding: 11px 14px;
    border-radius: 14px;
    background: var(--accent-soft);
    font-size: 14px;
    font-weight: 700;
    color: var(--accent);
    text-align: left;
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
  .btn {
    padding: 11px 18px;
    border-radius: 14px;
    background: var(--accent);
    font-size: 14px;
    font-weight: 700;
    color: var(--on-accent);
  }
</style>
