<script>
  import ConsoleRadio from './radio/ConsoleRadio.svelte';
  import UnitRadio from './radio/UnitRadio.svelte';
  import { session } from '../lib/state.svelte.js';
</script>

{#if session.dept?.id === 'dispatch'}
  <ConsoleRadio />
{:else}
  <UnitRadio />
{/if}
