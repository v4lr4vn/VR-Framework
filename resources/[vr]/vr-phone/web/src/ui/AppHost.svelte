<script>
  import { fly, fade } from 'svelte/transition';
  import ComingSoon from '../apps/shared/ComingSoon.svelte';
  import { loaders } from '../lib/apps.js';
  import { dur } from '../lib/motion.js';

  // Opens one app. The app's code is fetched the first time it is needed (see src/lib/apps.js).
  // bare: draw the app straight over the game (no phone body, no background). The Camera app uses this.
  let { id, bare = false } = $props();

  let Comp = $state(null);
  let failed = $state(false);

  $effect(() => {
    const load = loaders[id];
    Comp = null;
    failed = false;
    if (!load) return;
    let live = true;
    load()
      .then((module) => {
        if (live) Comp = module.default;
      })
      .catch(() => {
        if (live) failed = true;
      });
    return () => {
      live = false;
    };
  });
</script>

<div class="host" class:bare in:fly={{ y: bare ? 0 : 26, duration: dur(260) }} out:fade={{ duration: dur(120) }}>
  {#if Comp}
    <Comp />
  {:else if !loaders[id] || failed}
    <ComingSoon {id} {failed} />
  {:else}
    <div class="loading"><span class="spinner"></span></div>
  {/if}
</div>

<style>
  .host {
    position: absolute;
    inset: 0;
    background: var(--bg);
    color: var(--ink);
    z-index: 5;
  }
  .host.bare {
    position: fixed;
    background: transparent;
    pointer-events: none;
  }
  .loading {
    position: absolute;
    inset: 0;
    display: grid;
    place-items: center;
  }
  .spinner {
    width: 30px;
    height: 30px;
    border-radius: 50%;
    border: 3px solid var(--line);
    border-top-color: var(--accent);
    animation: spin 0.8s linear infinite;
  }
  @keyframes spin {
    to { transform: rotate(360deg); }
  }
</style>
