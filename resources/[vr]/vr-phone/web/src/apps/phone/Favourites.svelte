<script>
  import Avatar from '../../ui/Avatar.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { comms, dial, errorText } from '../../lib/comms.svelte.js';
  import { messageTo } from '../../lib/actions.js';
  import { t } from '../../lib/i18n.js';

  // Contacts marked with a star.
  let error = $state('');
  const list = $derived(comms.contacts.filter((c) => c.favourite && !c.blocked));

  async function call(c) {
    error = '';
    const r = await dial(c.number);
    if (!r.ok) error = errorText(r.reason);
  }
</script>

<h2>{t('phone.favourites')}</h2>

{#if error}<p class="err">{error}</p>{/if}

{#if list.length === 0}
  <p class="empty">{t('phone.favouritesEmpty')}</p>
{:else}
  <ul>
    {#each list as c (c.id)}
      <li>
        <button class="row" onclick={() => call(c)} disabled={comms.call !== null}>
          <Avatar name={c.name} number={c.number} size={40} />
          <span class="text">
            <span class="name">{c.name}</span>
            <span class="sub">{c.number}</span>
          </span>
          <Glyph name="phone" size={20} />
        </button>
        <button class="msg" onclick={() => messageTo(c.number)} aria-label={t('phone.message')}><Glyph name="message" size={20} /></button>
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
    color: #2fa84f;
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
