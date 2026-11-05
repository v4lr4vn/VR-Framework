<script>
  let { tone = 'muted', solid = false, mono = false, children } = $props();
</script>

<span class="badge {tone}" class:solid class:mono>{@render children()}</span>

<style>
  .badge { display: inline-flex; align-items: center; gap: 4px; height: 20px; padding: 0 7px; border-radius: 4px; font-size: 12px; font-weight: 600; white-space: nowrap; border: 1px solid transparent; }
  .mono { font-family: var(--mono); }
  .muted { background: var(--panel-2); color: var(--text-2); }
  .accent { background: var(--accent-soft); color: var(--accent); border-color: var(--accent-line); }
  .p1 { background: var(--p1-soft); color: var(--p1-text); }
  .p2 { background: var(--accent-soft); color: var(--p2-text); }
  .p3 { background: var(--info-bg); color: var(--p3-text); }
  .info { background: var(--info-bg); color: var(--info-text); }
  .ok { background: var(--ok-bg); color: var(--ok); }
  .danger { background: var(--danger-bg); color: var(--danger-text); }
  .ems { background: var(--ems-bg); color: var(--ems-text); }
  .doj { background: var(--doj-bg); color: var(--doj-text); }
  .solid.p1 { background: var(--p1); color: var(--accent-ink); }
  .solid.p2 { background: var(--p2); color: var(--accent-ink); }
  .solid.p3 { background: var(--p3); color: var(--accent-ink); }
  .solid.accent { background: var(--accent); color: var(--accent-ink); }
  .solid.ok { background: var(--ok); color: var(--accent-ink); }
  .solid.danger { background: var(--danger); color: var(--accent-ink); }
</style>
