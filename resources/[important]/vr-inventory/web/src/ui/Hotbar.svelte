<script>
  import Slot from './Slot.svelte';
  import { ui } from '../lib/state.svelte.js';

  let visible = $state(false);
  let timer = 0;

  $effect(() => {
    const stamp = ui.hotbar;
    if (!stamp) return;
    visible = true;
    clearTimeout(timer);
    timer = setTimeout(() => (visible = false), 3200);
    return () => clearTimeout(timer);
  });
</script>

{#if visible && ui.player && !ui.open}
  <div class="hotbar">
    {#each [0, 1, 2, 3, 4] as i (i)}
      <Slot inv={ui.player} index={i} item={ui.player.items[i]} hotkey={i + 1} />
    {/each}
  </div>
{/if}

<style>
  .hotbar {
    position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%); z-index: 30;
    display: flex; gap: 6px; padding: 8px; border-radius: var(--radius-lg);
    background: var(--card); border: 1px solid var(--line-2); box-shadow: 0 14px 34px rgba(0, 0, 0, 0.55);
    --slot: min(84px, 7.8vh); animation: up 0.18s var(--ease);
  }
  .hotbar :global(.slot) { cursor: default; }
  @keyframes up { from { opacity: 0; transform: translate(-50%, 14px); } to { opacity: 1; transform: translate(-50%, 0); } }
</style>
