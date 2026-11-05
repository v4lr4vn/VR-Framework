<script>
  import AppTile from './AppTile.svelte';
  import { unreadFor } from '../lib/store.svelte.js';
  import { appLabel } from '../lib/apps.js';

  // An app on the home screen: tile, optional name and an unread badge. `onopen` gets the app id.
  let { id, size = 60, label = true, onopen } = $props();

  const badge = $derived(unreadFor(id));
</script>

<button class="app" onclick={() => onopen?.(id)} aria-label={appLabel(id)} title={appLabel(id)}>
  <AppTile {id} {size}>
    {#if badge > 0}<span class="badge">{badge > 9 ? '9+' : badge}</span>{/if}
  </AppTile>
  {#if label}<span class="name">{appLabel(id)}</span>{/if}
</button>

<style>
  .app {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 7px;
    min-width: 0;
    transition: transform 0.16s var(--ease);
  }
  .app:active {
    transform: scale(0.94);
  }
  .badge {
    position: absolute;
    top: -5px;
    right: -5px;
    min-width: 20px;
    height: 20px;
    padding: 0 5px;
    border-radius: 10px;
    background: #ff4d5e;
    color: #fff;
    font-size: 11.5px;
    font-weight: 700;
    display: grid;
    place-items: center;
    box-shadow: 0 0 0 2px rgba(0, 0, 0, 0.25);
  }
  .name {
    max-width: 100%;
    font-size: 12px;
    font-weight: 600;
    color: var(--wp-ink, var(--ink));
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
    text-shadow: var(--wp-text-shadow, none);
  }
</style>
