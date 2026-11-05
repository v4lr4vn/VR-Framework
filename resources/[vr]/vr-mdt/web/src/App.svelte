<script>
  import Tablet from './shell/Tablet.svelte';
  import AlertStack from './hud/AlertStack.svelte';
  import { ui } from './lib/state.svelte.js';
  import { inGame } from './lib/nui.js';
  import { hudComponents } from './hud/index.js';

  let scale = $state(1);

  function measure() {
    scale = Math.min((window.innerWidth - 48) / 1600, (window.innerHeight - 48) / 900, 1.35);
  }

  $effect(() => {
    measure();
    window.addEventListener('resize', measure);
    return () => window.removeEventListener('resize', measure);
  });

  $effect(() => {
    if (!inGame) document.body.classList.add('browser');
  });
</script>

{#if ui.open}
  <div class="stage" class:hidden={ui.hidden} class:console={ui.console}>
    {#if ui.console}
      <div class="full"><Tablet /></div>
    {:else}
      <div class="frame" style:transform="translate(-50%, -50%) scale({scale})">
        <Tablet />
      </div>
    {/if}
  </div>
{:else}
  <AlertStack />
{/if}

{#each hudComponents as Hud}
  <Hud />
{/each}

<style>
  .stage { position: fixed; inset: 0; background: rgba(2, 4, 8, 0.35); }
  .hidden { visibility: hidden; opacity: 0; pointer-events: none; }
  .frame { position: absolute; left: 50%; top: 50%; width: 1600px; height: 900px; transform-origin: center; }
  .stage.console { background: var(--bg); }
  .full { position: absolute; inset: 0; }
</style>
