<script>
  import { phone, shownClock } from '../lib/store.svelte.js';
  import { clockText, hoursText, pad, ampm } from '../lib/time.js';

  // The big clock. variant: 'stack' (hours over minutes), 'row' (HH:MM) or 'mono'. `size` is the main font size in px.
  let { variant = 'stack', size = 100 } = $props();

  const c = $derived(shownClock());
  const time24 = $derived(phone.settings.general.time24);
</script>

{#if variant === 'stack'}
  <div class="stack" style:font-size="{size}px">
    <span>{hoursText(c, time24)}</span>
    <span class="min">{pad(c.m)}</span>
  </div>
{:else if variant === 'mono'}
  <div class="mono" style:font-size="{size * 0.68}px">
    {clockText(c, time24)}{#if !time24}<small>{ampm(c)}</small>{/if}
  </div>
{:else}
  <div class="row" style:font-size="{size * 0.8}px">
    {clockText(c, time24)}{#if !time24}<small>{ampm(c)}</small>{/if}
  </div>
{/if}

<style>
  .stack {
    display: flex;
    flex-direction: column;
    font-weight: 300;
    line-height: 0.88;
    letter-spacing: -0.03em;
    font-variant-numeric: tabular-nums;
  }
  .min {
    color: var(--accent-light);
    font-weight: 600;
  }
  .row {
    font-weight: 300;
    line-height: 1;
    letter-spacing: -0.03em;
    font-variant-numeric: tabular-nums;
  }
  .mono {
    font-family: var(--mono);
    font-weight: 500;
    line-height: 1;
    letter-spacing: -0.04em;
  }
  small {
    font-size: 0.26em;
    font-weight: 700;
    letter-spacing: 0.04em;
    margin-left: 0.4em;
    opacity: 0.7;
  }
</style>
