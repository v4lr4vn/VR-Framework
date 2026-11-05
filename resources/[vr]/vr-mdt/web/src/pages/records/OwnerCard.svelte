<script>
  import Mugshot from '../../components/Mugshot.svelte';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import { go } from '../../lib/state.svelte.js';
  import { age } from '../../lib/format.js';
  import { flagTone, dobText } from './shared.js';

  let { person, children } = $props();
  const years = $derived(person ? age(person.dob) : null);
</script>

<div class="owner">
  <Mugshot id={person.mugshot} name={person.name} size={64} />
  <div class="info">
    <div class="line">
      <span class="nm">{person.name}</span>
      {#if person.online}<Badge tone="ok">In the city</Badge>{/if}
    </div>
    <span class="mono faint">{person.cid}{#if person.dob}{' · '}{dobText(person.dob)}{#if years != null}{' · '}{years} yrs{/if}{/if}</span>
    {#if person.phone || person.jobLabel}
      <span class="muted sub">{[person.phone, person.jobLabel].filter(Boolean).join(' · ')}</span>
    {/if}
    {#if person.flags?.length}
      <div class="chips">{#each person.flags as f}<Badge tone={flagTone(f)}>{f}</Badge>{/each}</div>
    {/if}
    {#if children}{@render children()}{/if}
  </div>
  <Button size="sm" iconRight="chevron" onclick={() => go('citizens', { cid: person.cid })}>Profile</Button>
</div>

<style>
  .owner { display: flex; gap: 14px; align-items: flex-start; }
  .info { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
  .line { display: flex; align-items: center; gap: 8px; }
  .nm { font-size: 17px; font-weight: 700; color: var(--text); }
  .mono { font-size: 12px; }
  .sub { font-size: 13px; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; margin-top: 4px; }
</style>
