<script>
  import { glyphPath } from '../lib/glyphs.js';

  let { name, size = 24, stroke = 1.8, class: klass = '' } = $props();
</script>

<svg
  class="glyph {klass}"
  width={size}
  height={size}
  viewBox="0 0 24 24"
  fill="none"
  stroke="currentColor"
  stroke-width={stroke}
  stroke-linecap="round"
  stroke-linejoin="round"
  aria-hidden="true"
>{@html glyphPath(name)}</svg>

<style>
  .glyph {
    display: block;
    flex: none;
  }
</style>
