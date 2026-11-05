<script>
  import './records.css';
  import { onMount, untrack } from 'svelte';
  import SearchBox from '../../components/SearchBox.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Icon from '../../components/Icon.svelte';
  import { api } from '../../lib/nui.js';
  import { errorText } from '../../lib/lang.js';
  import { remembered } from './shared.js';

  let {
    title, subtitle = '', placeholder = 'Search', action, recentAction, recentLabel = 'Recent', memory, icon = 'search',
    startTitle, startText, emptyTitle, columns, head, row, key, onpick, actions, reloadKey = 0,
  } = $props();

  let q = $state(untrack(() => remembered[memory] || ''));
  let results = $state(null);
  let recent = $state(null);
  let loading = $state(false);
  let error = $state('');
  let seq = 0;

  function loadRecent() {
    api(recentAction, {}).then((res) => (recent = res.ok ? res.data : []));
  }

  onMount(() => {
    loadRecent();
    if (q.trim().length >= 2) search(q.trim());
  });

  $effect(() => {
    if (reloadKey) {
      loadRecent();
      if (q.trim().length >= 2) search(q.trim());
    }
  });

  async function search(term) {
    remembered[memory] = term;
    if (term.length < 2) {
      results = null;
      error = '';
      return;
    }
    const mine = ++seq;
    loading = true;
    const res = await api(action, { q: term });
    if (mine !== seq) return;
    loading = false;
    error = res.ok ? '' : errorText(res.error);
    results = res.ok ? res.data : [];
  }

  const list = $derived(results ?? recent ?? []);
</script>

<div class="page">
  <header class="ph">
    <div>
      <h1>{title}</h1>
      {#if subtitle}<p class="muted">{subtitle}</p>{/if}
    </div>
    {#if actions}<div class="acts">{@render actions()}</div>{/if}
  </header>

  <div class="tools">
    <SearchBox bind:value={q} {placeholder} onsearch={search} autofocus id="{memory}-search" />
  </div>

  <div class="body scroll">
    <h2 class="eyebrow">{results === null ? recentLabel : `${results.length} ${results.length === 1 ? 'match' : 'matches'}`}</h2>
    {#if loading || (results === null && recent === null)}
      <Spinner />
    {:else if error}
      <Empty icon="alert" title="Search failed" text={error} />
    {:else if !list.length}
      {#if results === null}
        <Empty {icon} title={startTitle} text={startText} />
      {:else}
        <Empty icon="search" title={emptyTitle} text={`Nothing matches "${q.trim()}".`} />
      {/if}
    {:else}
      <div class="rec-rows">
        <div class="rec-head" style:grid-template-columns="{columns} 20px" aria-hidden="true">{@render head()}<span></span></div>
        {#each list as item (key(item))}
          <button type="button" class="rec-row line" style:grid-template-columns="{columns} 20px" onclick={() => onpick(item)}>
            {@render row(item)}
            <Icon name="chevron" size={16} class="go" />
          </button>
        {/each}
      </div>
    {/if}
  </div>
</div>

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 0; gap: 16px; }
  .ph { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
  h1 { font-size: 24px; font-weight: 700; }
  .acts { display: flex; gap: 8px; }
  .tools { max-width: 520px; }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px; padding-bottom: 24px; }
  .line { min-height: 58px; gap: 16px; }
  .line :global(.go) { color: var(--faint); }
  .line:hover :global(.go) { color: var(--accent); }
</style>
