<script>
  import Glyph from './Glyph.svelte';
  import { phone } from '../lib/store.svelte.js';
  import { metaFor } from '../lib/apps.js';
  import { inkOn } from '../lib/color.js';

  // Just the coloured square with the app's glyph. No button, so it can sit inside other controls.
  let { id, size = 60, children } = $props();

  const meta = $derived(metaFor(id, phone.appDefs[id]));
</script>

<span class="tile" style:width="{size}px" style:height="{size}px" style:background={meta.color} style:color={inkOn(meta.color)}>
  <Glyph name={meta.glyph} size={Math.round(size * 0.52)} />
  {@render children?.()}
</span>

<style>
  .tile {
    position: relative;
    display: grid;
    place-items: center;
    flex: none;
    border-radius: 29%;
    box-shadow: inset 0 1px 0 rgba(255, 255, 255, 0.24), inset 0 -2px 0 rgba(0, 0, 0, 0.12), 0 2px 6px rgba(0, 0, 0, 0.2);
  }
</style>
