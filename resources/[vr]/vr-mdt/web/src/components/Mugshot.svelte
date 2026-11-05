<script>
  import { imageUrl } from '../lib/images.js';
  import { initials } from '../lib/format.js';
  let { id = null, name = '', size = 48, radius = 6 } = $props();
  let src = $state(null);

  $effect(() => {
    const want = id;
    src = null;
    if (!want) return;
    imageUrl(want).then((url) => { if (id === want) src = url; });
  });
</script>

<div class="mug" style:width="{size}px" style:height="{size}px" style:border-radius="{radius}px" style:font-size="{Math.round(size * 0.36)}px">
  {#if src}
    <img {src} alt={name ? `Photo of ${name}` : 'Photo'} />
  {:else}
    <span aria-hidden="true">{initials(name)}</span>
  {/if}
</div>

<style>
  .mug { flex: none; overflow: hidden; background: var(--panel-2); border: 1px solid var(--line-2); display: flex; align-items: center; justify-content: center; color: var(--accent); font-weight: 700; }
  img { width: 100%; height: 100%; object-fit: cover; display: block; }
</style>
