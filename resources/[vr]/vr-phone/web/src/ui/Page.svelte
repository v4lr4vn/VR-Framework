<script>
  import AppTile from './AppTile.svelte';

  // A simple one-column app page with a title. Use TwoPane instead when the app has a list and a detail view.
  let { title, appId = '', children } = $props();
</script>

<div class="page">
  <header>
    {#if appId}<AppTile id={appId} size={34} />{/if}
    <h1>{title}</h1>
  </header>
  <div class="body">{@render children?.()}</div>
</div>

<style>
  .page {
    position: absolute;
    inset: 0;
    display: flex;
    flex-direction: column;
    padding: 50px 40px 40px;
  }
  header {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 18px;
  }
  h1 {
    margin: 0;
    font-size: 26px;
    font-weight: 700;
    letter-spacing: -0.01em;
  }
  .body {
    flex: 1;
    min-height: 0;
    overflow-y: auto;
  }
</style>
