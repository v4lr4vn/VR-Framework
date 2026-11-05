<script>
  // A rounded box that holds a few settings rows.
  let { children } = $props();
</script>

<div class="group">{@render children?.()}</div>

<style>
  .group {
    background: var(--surface);
    border-radius: var(--r-l);
    padding: 4px 18px;
  }
</style>
