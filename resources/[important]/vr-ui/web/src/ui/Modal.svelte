<script>
  import { md } from '../lib/md.js';
  import Glyph from './Glyph.svelte';
  let { title = '', size = 'sm', closable = true, onclose, centered = true, children, footer } = $props();
  const W = { xs: 300, sm: 400, md: 480, lg: 640, xl: 800 };
</script>

<div class="backdrop" class:top={!centered}>
  <div class="modal" style:width="{W[size] || W.sm}px">
    <header>
      <h2>{@html md(title || ' ').replace(/^<p>|<\/p>$/g, '')}</h2>
      {#if closable}<button class="x" type="button" onclick={onclose} aria-label="Close"><Glyph name="close" size={14} /></button>{/if}
    </header>
    <div class="content scroll">{@render children()}</div>
    {#if footer}<footer>{@render footer()}</footer>{/if}
  </div>
</div>

<style>
  .backdrop { position: fixed; inset: 0; z-index: 60; display: flex; align-items: center; justify-content: center; background: rgba(4, 6, 10, 0.5); pointer-events: auto; animation: fade 0.15s; }
  .backdrop.top { align-items: flex-start; padding-top: 14vh; }
  .modal { max-width: calc(100vw - 48px); max-height: 82vh; display: flex; flex-direction: column; background: var(--bg-2); border: 1px solid var(--line-3); border-radius: var(--radius-lg); box-shadow: var(--shadow); animation: up 0.18s var(--ease); }
  header { position: relative; display: flex; align-items: center; justify-content: space-between; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line); }
  header::before { content: ''; position: absolute; left: -1px; top: 12px; bottom: 12px; width: 3px; border-radius: 0 2px 2px 0; background: var(--accent); }
  h2 { font-size: 17px; font-weight: 700; line-height: 1.3; }
  .x { flex: none; width: 28px; height: 28px; display: inline-flex; align-items: center; justify-content: center; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); }
  .x:hover { background: var(--panel-2); color: var(--text); border-color: var(--line-3); }
  .content { padding: 16px; display: flex; flex-direction: column; gap: 14px; min-height: 0; }
  footer { display: flex; justify-content: flex-end; gap: 8px; padding: 12px 16px; border-top: 1px solid var(--line); }
  @keyframes fade { from { opacity: 0; } to { opacity: 1; } }
  @keyframes up { from { opacity: 0; translate: 0 8px; } to { opacity: 1; translate: 0 0; } }
</style>
