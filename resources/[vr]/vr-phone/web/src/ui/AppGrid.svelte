<script>
  import AppIcon from './AppIcon.svelte';
  import FolderTile from './FolderTile.svelte';
  import { t } from '../lib/i18n.js';

  // Icons in pages. `items` are app ids or { folder, apps } objects.
  // Scroll sideways, click a dot, use the mouse wheel or drag to change page.
  let { items, cols = 4, rows = 4, cellHeight = 100, iconSize = 60, onopen, onfolder } = $props();

  const perPage = $derived(cols * rows);
  const pages = $derived.by(() => {
    const out = [];
    for (let i = 0; i < items.length; i += perPage) out.push(items.slice(i, i + perPage));
    return out.length ? out : [[]];
  });

  let page = $state(0);
  let scroller = $state();
  let drag = null;

  function go(i) {
    if (!scroller) return;
    const next = Math.max(0, Math.min(pages.length - 1, i));
    scroller.scrollTo({ left: next * scroller.clientWidth, behavior: 'smooth' });
  }

  function onscroll() {
    if (scroller) page = Math.round(scroller.scrollLeft / Math.max(1, scroller.clientWidth));
  }

  function onwheel(e) {
    if (pages.length > 1 && Math.abs(e.deltaY) > 4) go(page + Math.sign(e.deltaY));
  }

  function down(e) {
    drag = { x: e.clientX, page };
  }

  function up(e) {
    if (!drag) return;
    const dx = e.clientX - drag.x;
    if (Math.abs(dx) > 50) go(drag.page + (dx < 0 ? 1 : -1));
    drag = null;
  }
</script>

<div class="grid">
  <div
    class="pages"
    style:height="{rows * cellHeight}px"
    bind:this={scroller}
    {onscroll}
    {onwheel}
    onpointerdown={down}
    onpointerup={up}
    onpointercancel={() => (drag = null)}
    role="group"
  >
    {#each pages as pageItems, p (p)}
      <div class="page" style:grid-template-columns="repeat({cols}, 1fr)" style:grid-template-rows="repeat({rows}, {cellHeight}px)">
        {#each pageItems as item (typeof item === 'string' ? item : `f:${item.folder}`)}
          <div class="cell">
            {#if typeof item === 'string'}
              <AppIcon id={item} size={iconSize} {onopen} />
            {:else}
              <FolderTile folder={item.folder} apps={item.apps} size={iconSize} onopen={() => onfolder?.(item)} />
            {/if}
          </div>
        {/each}
      </div>
    {/each}
  </div>

  {#if pages.length > 1}
    <div class="dots">
      {#each pages as _, i}
        <button class="dot" class:on={i === page} onclick={() => go(i)} aria-label={t('home.page', { n: i + 1 })}></button>
      {/each}
    </div>
  {/if}
</div>

<style>
  .grid {
    display: flex;
    flex-direction: column;
    align-items: center;
    width: 100%;
  }
  .pages {
    display: flex;
    width: 100%;
    overflow-x: auto;
    overflow-y: hidden;
    scroll-snap-type: x mandatory;
    scrollbar-width: none;
  }
  .pages::-webkit-scrollbar {
    display: none;
  }
  .page {
    flex: 0 0 100%;
    scroll-snap-align: start;
    display: grid;
    align-content: start;
  }
  .cell {
    display: flex;
    justify-content: center;
    align-items: flex-start;
    min-width: 0;
  }
  .dots {
    display: flex;
    gap: 6px;
    margin-top: 8px;
  }
  .dot {
    width: 7px;
    height: 7px;
    border-radius: 50%;
    background: var(--wp-ink, #fff);
    opacity: 0.4;
    transition: opacity 0.2s, transform 0.2s var(--ease);
  }
  .dot.on {
    opacity: 1;
    transform: scale(1.25);
  }
</style>
