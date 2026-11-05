<script>
  import { onMount } from 'svelte';
  import { on } from '../lib/bus.js';
  import { md } from '../lib/md.js';
  import { colorOf } from '../lib/icon.js';
  import { cssOf } from '../lib/style.js';
  import { settings } from '../lib/settings.svelte.js';
  import Icon from './Icon.svelte';

  let visible = $state(false);
  let data = $state({ text: '', options: {} });
  const POS = ['right-center', 'left-center', 'top-center', 'bottom-center'];
  const pos = $derived(POS.includes(data.options?.position) ? data.options.position : settings.textui.position || 'left-center');

  onMount(() => {
    const a = on('textui:show', (d) => {
      data = { text: d?.text ?? '', options: d?.options || {} };
      visible = true;
    });
    const b = on('textui:hide', () => (visible = false));
    return () => (a(), b());
  });
</script>

{#if visible}
  <div class="wrap {pos}">
    <div class="tui" class:top={data.options.alignIcon === 'top'} style={cssOf(data.options.style)}>
      <span class="edge"></span>
      {#if data.options.icon}
        <span class="ico" style:color={colorOf(data.options.iconColor, null)}><Icon icon={data.options.icon} animation={data.options.iconAnimation} size={14} /></span>
      {/if}
      <div class="text md">{@html md(data.text)}</div>
    </div>
  </div>
{/if}

<style>
  .wrap { position: fixed; z-index: 30; pointer-events: none; display: flex; }
  .right-center { right: 24px; top: 50%; transform: translateY(-50%); }
  .left-center { left: 24px; top: 50%; transform: translateY(-50%); }
  .top-center { top: 24px; left: 50%; transform: translateX(-50%); }
  .bottom-center { bottom: 64px; left: 50%; transform: translateX(-50%); }

  .tui {
    position: relative; display: flex; align-items: center; gap: 10px; max-width: 420px;
    padding: 10px 14px 10px 16px; border-radius: var(--radius-lg); background: var(--card);
    border: 1px solid var(--line-2); box-shadow: 0 10px 28px rgba(0, 0, 0, 0.5); overflow: hidden;
    animation: pop 0.18s var(--ease);
  }
  .tui.top { align-items: flex-start; }
  .edge { position: absolute; left: 0; top: 0; bottom: 0; width: 3px; background: var(--accent); }
  .ico {
    flex: none; display: inline-flex; align-items: center; justify-content: center; width: 26px; height: 26px;
    border-radius: 6px; background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--accent-2);
  }
  .text { color: var(--text); font-size: 15px; font-weight: 500; line-height: 1.45; overflow-wrap: anywhere; }
  @keyframes pop { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
</style>
