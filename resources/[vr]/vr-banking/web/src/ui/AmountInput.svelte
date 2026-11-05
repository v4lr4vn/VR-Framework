<script>
  let { value = $bindable(''), quick = [100, 500, 1000, 5000], max = null, autofocus = false, label = 'Amount' } = $props();
  let el;
  $effect(() => {
    if (autofocus && el) el.focus();
  });
  const clean = (e) => {
    const v = e.currentTarget.value.replace(/[^\d]/g, '');
    value = v;
    e.currentTarget.value = v ? Number(v).toLocaleString('en-US') : '';
  };
</script>

<label class="field">
  <span>{label}</span>
  <div class="wrap">
    <span class="cur">$</span>
    <input bind:this={el} class="input num big" inputmode="numeric" placeholder="0" value={value ? Number(value).toLocaleString('en-US') : ''} oninput={clean} />
  </div>
  <div class="quick">
    {#each quick as q}
      <button type="button" class="btn small ghost" onclick={() => (value = String(q))}>${q.toLocaleString('en-US')}</button>
    {/each}
    {#if max != null && max > 0}
      <button type="button" class="btn small ghost" onclick={() => (value = String(Math.floor(max)))}>All</button>
    {/if}
  </div>
</label>

<style>
  .wrap { position: relative; }
  .cur { position: absolute; left: 12px; top: 50%; transform: translateY(-50%); color: var(--muted); font-family: var(--mono); font-size: 16px; }
  .big { height: 44px; font-size: 20px; padding-left: 28px; }
  .quick { display: flex; gap: 6px; flex-wrap: wrap; }
</style>
