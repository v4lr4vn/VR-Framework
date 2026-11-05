<script>
  import AppTile from './AppTile.svelte';

  // A folder on the home screen: a glass square with up to four small app tiles inside.
  let { folder, apps, size = 60, onopen } = $props();
</script>

<button class="folder" onclick={() => onopen?.()} aria-label={folder} title={folder}>
  <span class="box" style:width="{size}px" style:height="{size}px">
    {#each apps.slice(0, 4) as id (id)}
      <AppTile {id} size={Math.round(size * 0.37)} />
    {/each}
  </span>
  <span class="name">{folder}</span>
</button>

<style>
  .folder {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 7px;
    min-width: 0;
  }
  .box {
    display: grid;
    grid-template-columns: 1fr 1fr;
    place-items: center;
    padding: 7%;
    border-radius: 29%;
    background: rgba(255, 255, 255, 0.24);
    border: 1px solid rgba(255, 255, 255, 0.3);
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
