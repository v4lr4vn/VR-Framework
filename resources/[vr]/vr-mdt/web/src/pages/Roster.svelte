<script>
  import { untrack } from 'svelte';
  import Tabs from '../components/Tabs.svelte';
  import Members from './department/Members.svelte';
  import PermissionMatrix from './department/PermissionMatrix.svelte';
  import AuditLog from './department/AuditLog.svelte';
  import { can, session } from '../lib/state.svelte.js';

  let { params = {} } = $props();

  const tabs = $derived([
    { id: 'members', label: 'Members' },
    ...(can('permissions.manage') ? [{ id: 'permissions', label: 'Permissions' }, { id: 'audit', label: 'Audit log' }] : []),
  ]);

  let tab = $state(untrack(() => params.tab || 'members'));
  const current = $derived(tabs.some((t) => t.id === tab) ? tab : 'members');
</script>

<div class="page">
  <header class="ph">
    <div class="titles">
      <h1>Roster</h1>
      <p class="muted">{session.dept?.label}</p>
    </div>
    {#if tabs.length > 1}
      <div class="tabs"><Tabs {tabs} bind:value={tab} /></div>
    {/if}
  </header>

  {#if current === 'permissions'}
    <PermissionMatrix />
  {:else if current === 'audit'}
    <AuditLog />
  {:else}
    <Members initial={params.cid || null} />
  {/if}
</div>

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; }
  .ph { display: flex; align-items: flex-end; gap: 32px; padding: 20px 24px 0; border-bottom: 1px solid var(--line); }
  .titles { padding-bottom: 12px; }
  h1 { font-size: 24px; font-weight: 700; }
  .tabs :global(.tabs) { border-bottom: 0; }
  .tabs :global(.tab) { height: 40px; }
</style>
