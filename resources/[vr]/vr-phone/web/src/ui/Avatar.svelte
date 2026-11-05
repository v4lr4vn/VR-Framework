<script>
  import Glyph from './Glyph.svelte';

  // A round picture for a contact: their initials on a colour picked from the name. Without a name it shows a person.
  let { name = '', number = '', size = 44 } = $props();

  const COLORS = ['#e5484d', '#e08a1e', '#2fa84f', '#1fa596', '#3b82f6', '#7a5cff', '#d6409f', '#8b7f72'];
  const key = $derived(name || number || '?');
  const color = $derived(COLORS[[...key].reduce((a, c) => (a * 31 + c.charCodeAt(0)) >>> 0, 7) % COLORS.length]);
  const initials = $derived(
    name
      .trim()
      .split(/\s+/)
      .slice(0, 2)
      .map((w) => [...w][0] ?? '')
      .join('')
      .toUpperCase(),
  );
</script>

<span class="avatar" style:width="{size}px" style:height="{size}px" style:background={color} style:font-size="{size * 0.38}px">
  {#if initials}{initials}{:else}<Glyph name="user" size={Math.round(size * 0.52)} stroke={2} />{/if}
</span>

<style>
  .avatar {
    flex: none;
    display: grid;
    place-items: center;
    border-radius: 50%;
    color: #fff;
    font-weight: 700;
    letter-spacing: 0.02em;
    user-select: none;
  }
</style>
