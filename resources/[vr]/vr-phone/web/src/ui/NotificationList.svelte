<script>
  import AppTile from './AppTile.svelte';
  import Glyph from './Glyph.svelte';
  import { phone, tick, noteTitle, noteText, lockVisible, dismissNotification } from '../lib/store.svelte.js';
  import { appLabel } from '../lib/apps.js';
  import { ago } from '../lib/time.js';
  import { t } from '../lib/i18n.js';

  // Notifications as cards, in the style the player picked in Settings:
  //   list  - one card each, newest first
  //   stack - one pile for each app. Tap a pile to spread it out
  //   count - a single line that says how many there are. Tap it to see them
  // locked: this is the lock screen, so apps the player hid from it stay hidden, and so does the text if previews are off.
  // dismissable: each card gets a small close button.
  let { limit = 3, hideText = false, locked = false, dismissable = false, onopen, variant = '' } = $props();

  const mode = $derived(variant || phone.settings.notify.style || 'list');
  const items = $derived(locked ? lockVisible(phone.notifications) : phone.notifications);
  const hide = $derived(hideText || (locked && !phone.settings.lock.showPreviews));

  // One group for each app. The group with the newest notification comes first.
  const groups = $derived.by(() => {
    const order = [];
    const byApp = {};
    for (const n of items) {
      if (!byApp[n.app]) {
        byApp[n.app] = [];
        order.push(n.app);
      }
      byApp[n.app].push(n);
    }
    return order.map((app) => ({ app, list: byApp[app] }));
  });

  const apps = $derived(groups.map((g) => g.app));

  let spread = $state({}); // stack: which piles are spread out
  let all = $state(false); // count: the list is showing
</script>

{#snippet inner(n)}
  <AppTile id={n.app} size={34} />
  <span class="body">
    <span class="top">
      <span class="app">{appLabel(n.app)}</span>
      <span class="when">{ago(n.at, tick.now)}</span>
    </span>
    {#if hide}
      <span class="title">{t('notify.hidden')}</span>
    {:else}
      {#if noteTitle(n)}<span class="title">{noteTitle(n)}</span>{/if}
      {#if noteText(n)}<span class="msg">{noteText(n)}</span>{/if}
    {/if}
  </span>
{/snippet}

{#snippet card(n)}
  <div class="card">
    <button class="main" onclick={() => onopen?.(n)} disabled={!onopen}>{@render inner(n)}</button>
    {#if dismissable}
      <button class="x" onclick={() => dismissNotification(n.id)} aria-label={t('notify.dismiss')}>
        <Glyph name="close" size={13} stroke={2.6} />
      </button>
    {/if}
  </div>
{/snippet}

{#if mode === 'stack'}
  {#each groups.slice(0, limit) as g (g.app)}
    {#if g.list.length === 1 || spread[g.app]}
      {#each g.list as n (n.id)}{@render card(n)}{/each}
      {#if g.list.length > 1}
        <button class="less" onclick={() => (spread[g.app] = false)}>{t('notify.showLess')}</button>
      {/if}
    {:else}
      <div class="pile">
        <button class="card main" onclick={() => (spread[g.app] = true)} aria-label={t('notify.showAll', { n: g.list.length })}>
          {@render inner(g.list[0])}
          <span class="more">+{g.list.length - 1}</span>
        </button>
      </div>
    {/if}
  {/each}
{:else if mode === 'count'}
  {#if items.length > 0}
    <button class="count" onclick={() => (all = !all)} aria-expanded={all}>
      <span class="icons">
        {#each apps.slice(0, 4) as app (app)}<AppTile id={app} size={26} />{/each}
      </span>
      <span class="num">{t(items.length === 1 ? 'notify.countOne' : 'notify.count', { n: items.length })}</span>
      <Glyph name={all ? 'chev-up' : 'chev-down'} size={18} />
    </button>
    {#if all}
      {#each items.slice(0, limit) as n (n.id)}{@render card(n)}{/each}
    {/if}
  {/if}
{:else}
  {#each items.slice(0, limit) as n (n.id)}{@render card(n)}{/each}
{/if}

<style>
  .card {
    position: relative;
    display: flex;
    align-items: flex-start;
    width: 100%;
    margin-bottom: 8px;
    border-radius: 18px;
    background: var(--glass);
    border: 1px solid var(--glass-line);
    color: var(--ink);
  }
  .main {
    display: flex;
    gap: 11px;
    align-items: flex-start;
    flex: 1;
    min-width: 0;
    padding: 11px 13px;
    text-align: left;
    color: inherit;
  }
  .main:disabled {
    cursor: default;
  }
  .x {
    flex: none;
    margin: 8px 8px 0 0;
    width: 24px;
    height: 24px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    color: var(--ink-3);
    background: var(--surface-2);
  }
  .x:hover {
    color: var(--ink);
    background: var(--surface-3);
  }
  .body {
    display: flex;
    flex-direction: column;
    min-width: 0;
    flex: 1;
    gap: 1px;
  }
  .top {
    display: flex;
    justify-content: space-between;
    gap: 8px;
    font-size: 11px;
    font-weight: 700;
    letter-spacing: 0.04em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
  .title {
    font-size: 14px;
    font-weight: 700;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .msg {
    font-size: 13px;
    line-height: 1.3;
    color: var(--ink-2);
    display: -webkit-box;
    -webkit-line-clamp: 2;
    -webkit-box-orient: vertical;
    overflow: hidden;
  }

  /* a pile: the top card with two edges peeking out underneath */
  .pile {
    position: relative;
    margin-bottom: 18px;
  }
  .pile::before,
  .pile::after {
    content: '';
    position: absolute;
    height: 8px;
    border-radius: 0 0 14px 14px;
    background: var(--glass);
    border: 1px solid var(--glass-line);
    border-top: 0;
  }
  .pile::before {
    left: 10px;
    right: 10px;
    bottom: -8px;
    opacity: 0.8;
  }
  .pile::after {
    left: 20px;
    right: 20px;
    bottom: -14px;
    opacity: 0.55;
  }
  .pile .card {
    position: relative;
    z-index: 1;
    color: var(--ink);
    margin-bottom: 0;
    padding: 11px 13px;
  }
  .more {
    flex: none;
    align-self: center;
    min-width: 26px;
    height: 22px;
    padding: 0 7px;
    border-radius: 11px;
    display: grid;
    place-items: center;
    font-size: 12px;
    font-weight: 700;
    background: var(--accent);
    color: var(--on-accent);
  }
  .less {
    display: block;
    margin: 0 0 10px auto;
    padding: 4px 12px;
    border-radius: 12px;
    font-size: 12px;
    font-weight: 700;
    background: var(--glass);
    border: 1px solid var(--glass-line);
    color: var(--ink);
  }

  /* count: one line */
  .count {
    display: flex;
    align-items: center;
    gap: 10px;
    width: 100%;
    margin-bottom: 8px;
    padding: 9px 14px;
    border-radius: 20px;
    background: var(--glass);
    border: 1px solid var(--glass-line);
    color: var(--ink);
  }
  .icons {
    display: flex;
  }
  .icons :global(.tile) {
    margin-right: -8px;
    border-radius: 9px;
    box-shadow: 0 0 0 2px var(--bg);
  }
  .num {
    flex: 1;
    margin-left: 8px;
    font-size: 14px;
    font-weight: 700;
  }
</style>
