<script>
  // A settings row: text on the left, a control (snippet) on the right.
  // stack: put the control under the text (for wide controls on a narrow screen).
  let { title, hint = '', stack = false, children } = $props();
</script>

<div class="row" class:stack>
  <div class="text">
    <div class="title">{title}</div>
    {#if hint}<div class="hint">{hint}</div>{/if}
  </div>
  <div class="control">{@render children?.()}</div>
</div>

<style>
  .row {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 14px 4px;
    border-bottom: 1px solid var(--line);
    min-height: 56px;
  }
  .row.stack {
    flex-direction: column;
    align-items: stretch;
    gap: 10px;
  }
  .row.stack .control {
    justify-content: flex-start;
  }
  .row:last-child {
    border-bottom: 0;
  }
  .text {
    flex: 1;
    min-width: 0;
  }
  .title {
    font-size: 15px;
    font-weight: 600;
    color: var(--ink);
  }
  .hint {
    margin-top: 2px;
    font-size: 12.5px;
    color: var(--ink-3);
    line-height: 1.35;
  }
  .control {
    flex: none;
    display: flex;
    align-items: center;
    justify-content: flex-end;
    min-width: 0;
  }
</style>
