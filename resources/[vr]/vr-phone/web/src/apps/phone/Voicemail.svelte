<script>
  import Avatar from '../../ui/Avatar.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { phone, tick } from '../../lib/store.svelte.js';
  import { comms, labelFor, nameFor, dial, errorText, heardVoicemail, removeVoicemail } from '../../lib/comms.svelte.js';
  import { stampTime, stampDay } from '../../lib/time.js';
  import { t } from '../../lib/i18n.js';

  // Messages people left when nobody picked up. They are typed, not recorded.
  let open = $state(null);
  let error = $state('');

  function toggle(v) {
    open = open === v.id ? null : v.id;
    if (open === v.id) heardVoicemail(v.id);
  }

  async function call(v) {
    error = '';
    const r = await dial(v.from);
    if (!r.ok) error = errorText(r.reason);
  }
</script>

<h2>{t('phone.voicemail')}</h2>

{#if error}<p class="err">{error}</p>{/if}

{#if !comms.voicemailLoaded}
  <p class="empty">{t('common.loading')}</p>
{:else if comms.voicemail.length === 0}
  <p class="empty">{t('phone.voicemailEmpty')}</p>
{:else}
  <ul>
    {#each comms.voicemail as v (v.id)}
      <li class:new={!v.heard}>
        <button class="row" onclick={() => toggle(v)} aria-expanded={open === v.id}>
          <Avatar name={nameFor(v.from)} number={v.from} size={40} />
          <span class="text">
            <span class="name">{#if !v.heard}<i class="dot"></i>{/if}{labelFor(v.from)}</span>
            <span class="sub" class:clip={open !== v.id}>{v.body}</span>
          </span>
          <span class="when">{stampDay(v.at, tick.now)}<br />{stampTime(v.at, phone.settings.general.time24)}</span>
        </button>
        {#if open === v.id}
          <div class="acts">
            <button class="act" onclick={() => call(v)} disabled={comms.call !== null}><Glyph name="phone" size={18} stroke={2} />{t('phone.callBack')}</button>
            <button class="act red" onclick={() => removeVoicemail(v.id)}><Glyph name="trash" size={18} stroke={2} />{t('phone.delete')}</button>
          </div>
        {/if}
      </li>
    {/each}
  </ul>
{/if}

<style>
  h2 {
    margin: 0 0 8px;
    font-size: 22px;
    font-weight: 700;
  }
  ul {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  li {
    border-bottom: 1px solid var(--line);
  }
  li:last-child {
    border-bottom: 0;
  }
  .row {
    width: 100%;
    display: flex;
    align-items: flex-start;
    gap: 12px;
    padding: 10px 2px;
  }
  .text {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .name {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 15.5px;
    font-weight: 600;
  }
  .new .name {
    font-weight: 700;
  }
  .dot {
    flex: none;
    width: 9px;
    height: 9px;
    border-radius: 50%;
    background: var(--accent);
  }
  .sub {
    font-size: 13.5px;
    line-height: 1.35;
    color: var(--ink-2);
    white-space: pre-wrap;
    overflow-wrap: anywhere;
  }
  .sub.clip {
    display: -webkit-box;
    -webkit-line-clamp: 1;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }
  .when {
    flex: none;
    font-size: 11.5px;
    line-height: 1.35;
    text-align: right;
    color: var(--ink-3);
  }
  .acts {
    display: flex;
    gap: 8px;
    padding: 0 2px 12px 54px;
  }
  .act {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    padding: 8px 13px;
    border-radius: 14px;
    background: var(--surface-2);
    font-size: 13px;
    font-weight: 700;
    color: var(--ink);
  }
  .act:disabled {
    opacity: 0.45;
  }
  .act.red {
    color: #e5484d;
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
