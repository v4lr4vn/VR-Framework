<script>
  // The dial pad. onkey gets '0'..'9', '*' or '#'.
  let { onkey, compact = false } = $props();

  const KEYS = [
    ['1', ''], ['2', 'ABC'], ['3', 'DEF'],
    ['4', 'GHI'], ['5', 'JKL'], ['6', 'MNO'],
    ['7', 'PQRS'], ['8', 'TUV'], ['9', 'WXYZ'],
    ['*', ''], ['0', '+'], ['#', ''],
  ];
</script>

<div class="pad" class:compact>
  {#each KEYS as [d, letters] (d)}
    <button class="key" onclick={() => onkey?.(d)} aria-label={d}>
      <span class="d">{d}</span>
      <span class="l">{letters}</span>
    </button>
  {/each}
</div>

<style>
  .pad {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 10px;
    width: 100%;
    max-width: 300px;
    margin: 0 auto;
  }
  .key {
    height: 58px;
    border-radius: 29px;
    background: var(--surface-2);
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    transition: background 0.12s var(--ease-soft), transform 0.12s var(--ease);
  }
  .key:hover {
    background: var(--surface-3);
  }
  .key:active {
    transform: scale(0.95);
  }
  .compact {
    gap: 6px;
  }
  .compact .key {
    height: 38px;
    border-radius: 19px;
  }
  .d {
    font-size: 24px;
    font-weight: 600;
    line-height: 1;
    color: var(--ink);
  }
  .l {
    min-height: 10px;
    margin-top: 2px;
    font-size: 9px;
    font-weight: 700;
    letter-spacing: 0.14em;
    color: var(--ink-3);
  }
  .compact .d {
    font-size: 19px;
  }
  .compact .l {
    display: none;
  }
</style>
