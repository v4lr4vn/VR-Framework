<script>
  import { iconOf } from '../lib/icon.js';
  let { icon, animation = null, color = null, size = 14 } = $props();
  const parsed = $derived(iconOf(icon, animation));
</script>

{#if parsed?.img}
  <img class="img" src={parsed.img} alt="" style:width="{size + 4}px" style:height="{size + 4}px" />
{:else if parsed}
  <i class={parsed.cls} style:color={color} style:font-size="{size}px" aria-hidden="true"></i>
{/if}

<style>
  .img { object-fit: contain; display: block; }
  i { width: 1.25em; text-align: center; line-height: 1; }
</style>
