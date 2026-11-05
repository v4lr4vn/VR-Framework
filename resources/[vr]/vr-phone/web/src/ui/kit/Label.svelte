<script>
  // A small heading above a group.
  let { children } = $props();
</script>

<h3>{@render children?.()}</h3>

<style>
  h3 {
    margin: 22px 0 10px;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-transform: uppercase;
    color: var(--ink-3);
  }
</style>
