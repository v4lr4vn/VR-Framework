<script>
  import Card from './Card.svelte';

  let { list = [], cols = 2, rowH = 70, gap = 6, onhover, onleave, onpick, onplay, empty = 'Nothing here.' } = $props();

  let el = $state(null);
  let top = $state(0);
  let height = $state(600);

  const rows = $derived(Math.ceil(list.length / cols));
  const step = $derived(rowH + gap);
  const first = $derived(Math.max(0, Math.floor(top / step) - 3));
  const last = $derived(Math.min(rows, Math.ceil((top + height) / step) + 3));
  const visible = $derived.by(() => {
    const out = [];
    for (let r = first; r < last; r++) {
      for (let c = 0; c < cols; c++) {
        const i = r * cols + c;
        if (i < list.length) out.push({ item: list[i], r, c, i });
      }
    }
    return out;
  });

  export const reset = () => {
    if (el) el.scrollTop = 0;
    top = 0;
  };

  export const reveal = (index) => {
    if (!el || index < 0) return;
    const r = Math.floor(index / cols);
    const y = r * step;
    if (y < el.scrollTop) el.scrollTop = y;
    else if (y + rowH > el.scrollTop + height) el.scrollTop = y + rowH - height;
  };
</script>

<div class="grid scroll" bind:this={el} bind:clientHeight={height} onscroll={(e) => (top = e.currentTarget.scrollTop)} onmouseleave={() => onleave && onleave()} role="list">
  {#if list.length}
    <div class="space" style:height="{rows * step - gap}px">
      {#each visible as v (v.item.id)}
        <div class="cell" style:top="{v.r * step}px" style:left="calc({(100 / cols) * v.c}% + {v.c ? gap / 2 : 0}px)" style:width="calc({100 / cols}% - {gap / 2}px)" style:height="{rowH}px" role="listitem">
          <Card item={v.item} {onhover} {onpick} {onplay} />
        </div>
      {/each}
    </div>
  {:else}
    <div class="empty">{empty}</div>
  {/if}
</div>

<style>
  .grid { flex: 1; min-height: 0; position: relative; padding-right: 4px; }
  .space { position: relative; }
  .cell { position: absolute; }
  .empty { color: var(--faint); text-align: center; padding: 40px 0; font-size: 14px; }
</style>
