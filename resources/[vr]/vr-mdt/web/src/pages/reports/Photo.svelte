<script>
  import Icon from '../../components/Icon.svelte';
  import { imageUrl } from '../../lib/images.js';

  let { id, alt = 'Photo', height = 120, onclick = null, fit = 'cover' } = $props();
  let src = $state(null);
  let failed = $state(false);

  $effect(() => {
    const want = id;
    src = null;
    failed = false;
    if (!want) return;
    imageUrl(want).then((url) => {
      if (id !== want) return;
      src = url;
      failed = !url;
    });
  });
</script>

{#if onclick}
  <button type="button" class="photo" style:height="{height}px" {onclick} aria-label="Open {alt}">
    {#if src}<img {src} {alt} style:object-fit={fit} />{:else}<span class="ph" class:failed><Icon name={failed ? 'image' : 'photo'} size={20} /></span>{/if}
  </button>
{:else}
  <div class="photo" style:height="{height}px">
    {#if src}<img {src} {alt} style:object-fit={fit} />{:else}<span class="ph" class:failed><Icon name={failed ? 'image' : 'photo'} size={20} /></span>{/if}
  </div>
{/if}

<style>
  .photo { width: 100%; display: block; padding: 0; border: 1px solid var(--line-2); border-radius: var(--radius); background: var(--bg-2); overflow: hidden; position: relative; }
  button.photo:hover { border-color: var(--accent); }
  img { width: 100%; height: 100%; display: block; }
  .ph { position: absolute; inset: 0; display: flex; align-items: center; justify-content: center; color: var(--faint); }
  .failed { color: var(--danger-text); }
</style>
