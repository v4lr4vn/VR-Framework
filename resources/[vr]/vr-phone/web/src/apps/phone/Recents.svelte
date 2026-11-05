<script>
  import Avatar from '../../ui/Avatar.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { phone, tick } from '../../lib/store.svelte.js';
  import { comms, labelFor, nameFor, dial, errorText, clearRecents } from '../../lib/comms.svelte.js';
  import { messageTo } from '../../lib/actions.js';
  import { durationText, stampTime, stampDay } from '../../lib/time.js';
  import { t } from '../../lib/i18n.js';

  // Calls, newest first. Tap one to call that number again.
  let sure = $state(false);
  let error = $state('');

  const calls = $derived(comms.recents);

  // missed | in | out | declined | none (nobody answered a call I made)
  function kind(c) {
    if (c.outgoing) return c.result === 'answered' ? 'out' : c.result === 'declined' ? 'declined' : 'none';
    return c.result === 'missed' ? 'missed' : c.result === 'declined' ? 'declined' : 'in';
  }

  const glyph = { missed: 'phone-miss', in: 'phone-in', out: 'phone-out', declined: 'phone-miss', none: 'phone-out' };

  function detail(c) {
    const k = kind(c);
    const word = t(`phone.kind.${k}`);
    return c.result === 'answered' && c.duration > 0 ? `${word} · ${durationText(c.duration)}` : word;
  }

  async function again(c) {
    error = '';
    const r = await dial(c.number);
    if (!r.ok) error = errorText(r.reason);
  }

  async function clear() {
    if (!sure) {
      sure = true;
      setTimeout(() => (sure = false), 3000);
      return;
    }
    sure = false;
    await clearRecents();
  }
</script>

<div class="head">
  <h2>{t('phone.recents')}</h2>
  {#if calls.length > 0}
    <button class="clear" class:sure onclick={clear}>{sure ? t('phone.clearSure') : t('phone.clear')}</button>
  {/if}
</div>

{#if error}<p class="err">{error}</p>{/if}

{#if !comms.recentsLoaded}
  <p class="empty">{t('common.loading')}</p>
{:else if calls.length === 0}
  <p class="empty">{t('phone.recentsEmpty')}</p>
{:else}
  <ul>
    {#each calls as c (c.id)}
      {@const k = kind(c)}
      <li>
        <button class="row" onclick={() => again(c)} disabled={comms.call !== null}>
          <Avatar name={nameFor(c.number)} number={c.number} size={40} />
          <span class="text">
            <span class="name" class:red={k === 'missed'}>{labelFor(c.number)}</span>
            <span class="sub"><Glyph name={glyph[k]} size={14} stroke={2.2} />{detail(c)}</span>
          </span>
          <span class="when">{stampDay(c.at, tick.now)}<br />{stampTime(c.at, phone.settings.general.time24)}</span>
        </button>
        <button class="msg" onclick={() => messageTo(c.number)} aria-label={t('phone.message')}><Glyph name="message" size={20} /></button>
      </li>
    {/each}
  </ul>
{/if}

<style>
  .head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 8px;
  }
  h2 {
    margin: 0;
    font-size: 22px;
    font-weight: 700;
  }
  .clear {
    padding: 5px 11px;
    border-radius: 12px;
    background: var(--surface-2);
    font-size: 12.5px;
    font-weight: 700;
    color: var(--ink-2);
  }
  .clear.sure {
    background: #e5484d;
    color: #fff;
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  li {
    display: flex;
    align-items: center;
    border-bottom: 1px solid var(--line);
  }
  li:last-child {
    border-bottom: 0;
  }
  .row {
    flex: 1;
    min-width: 0;
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 10px 2px;
  }
  .row:disabled {
    opacity: 0.6;
  }
  .text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .name {
    font-size: 15.5px;
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .name.red {
    color: #e5484d;
  }
  .sub {
    display: flex;
    align-items: center;
    gap: 5px;
    font-size: 12.5px;
    color: var(--ink-3);
  }
  .when {
    flex: none;
    font-size: 11.5px;
    line-height: 1.35;
    text-align: right;
    color: var(--ink-3);
  }
  .msg {
    flex: none;
    width: 38px;
    height: 38px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    color: var(--accent);
  }
  .msg:hover {
    background: var(--surface-2);
  }
  .empty,
  .err {
    margin: 14px 2px;
    font-size: 14px;
    color: var(--ink-3);
  }
  .err {
    color: #e5484d;
    font-weight: 600;
  }
</style>
