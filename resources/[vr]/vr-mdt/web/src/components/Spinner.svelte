<script>
  let { label = 'Loading' } = $props();
</script>

<div class="wrap" role="status"><span class="spin" aria-hidden="true"></span><span class="sr-only">{label}</span></div>

<style>
  .wrap { flex: 1; display: flex; align-items: center; justify-content: center; padding: 32px; }
  .spin { width: 22px; height: 22px; border-radius: 50%; border: 2px solid var(--line-3); border-top-color: var(--accent); animation: r 0.8s linear infinite; }
  @keyframes r { to { transform: rotate(360deg); } }
</style>
