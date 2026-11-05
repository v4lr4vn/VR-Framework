<script>
  import { untrack } from 'svelte';
  import Badge from '../components/Badge.svelte';
  import Button from '../components/Button.svelte';
  import IconButton from '../components/IconButton.svelte';
  import Empty from '../components/Empty.svelte';
  import Spinner from '../components/Spinner.svelte';
  import SearchBox from '../components/SearchBox.svelte';
  import PenalChargeModal from './reports/PenalChargeModal.svelte';
  import PenalCategoryModal from './reports/PenalCategoryModal.svelte';
  import { penal, loadPenal } from './reports/penal.svelte.js';
  import { classes, classLabel, classTone } from './reports/util.js';
  import { can, request, toast } from '../lib/state.svelte.js';
  import { errorText } from '../lib/lang.js';
  import { confirm } from '../lib/confirm.svelte.js';
  import { money } from '../lib/format.js';

  let { params = {} } = $props();

  let q = $state('');
  let cls = $state('');
  let editing = $state(false);
  let chargeModal = $state(false);
  let categoryModal = $state(false);
  let editCharge = $state(null);
  let editCategory = $state(null);
  let newIn = $state(null);
  let activeCat = $state(null);
  let body;

  const manager = $derived(can('penal.manage'));
  const plural = { infraction: 'Infractions', misdemeanor: 'Misdemeanors', felony: 'Felonies' };

  $effect(() => {
    const all = editing && manager;
    untrack(() => loadPenal(all, penal.loaded && penal.all !== all));
  });

  const sections = $derived.by(() => {
    const term = q.trim().toLowerCase();
    return penal.categories
      .map((cat) => ({
        ...cat,
        list: cat.charges.filter((c) => (!cls || c.class === cls) && (!term || c.title.toLowerCase().includes(term) || (c.description || '').toLowerCase().includes(term))),
      }))
      .filter((cat) => cat.list.length || (editing && !term && !cls));
  });

  const counts = $derived.by(() => {
    const out = { all: 0, infraction: 0, misdemeanor: 0, felony: 0, inactive: 0 };
    for (const cat of penal.categories)
      for (const c of cat.charges) {
        if (c.active === false) {
          out.inactive += 1;
          continue;
        }
        out.all += 1;
        out[c.class] = (out[c.class] || 0) + 1;
      }
    return out;
  });

  function jump(id) {
    activeCat = id;
    body?.querySelector(`[data-cat="${id}"]`)?.scrollIntoView({ block: 'start', behavior: 'smooth' });
  }

  function openCharge(charge, categoryId = null) {
    editCharge = charge;
    newIn = categoryId;
    chargeModal = true;
  }

  function openCategory(cat) {
    editCategory = cat;
    categoryModal = true;
  }

  function refresh() {
    loadPenal(editing && manager, true);
  }

  async function removeCharge(c) {
    const ok = await confirm({ title: `Remove "${c.title}"?`, text: 'If any report or sentence already uses this charge it is retired instead: it stays on those records but can no longer be added.', yes: 'Remove charge', danger: true });
    if (!ok) return;
    const res = await request('penal.chargeDelete', { id: c.id });
    if (!res.ok) return;
    refresh();
    if (res.data.deactivated) toast(`"${c.title}" is used on existing records, so it was retired.`, 'ok', 5000);
    else toast('Charge removed', 'ok');
  }

  async function removeCategory(cat) {
    const ok = await confirm({ title: `Delete "${cat.name}"?`, text: 'Only empty categories can be deleted.', yes: 'Delete category', danger: true });
    if (!ok) return;
    const res = await request('penal.categoryDelete', { id: cat.id }, { success: 'Category deleted' });
    if (res.ok) refresh();
  }

  async function moveCategory(index, d) {
    const ids = penal.categories.map((c) => c.id);
    const j = index + d;
    if (j < 0 || j >= ids.length) return;
    [ids[index], ids[j]] = [ids[j], ids[index]];
    const res = await request('penal.reorder', { categories: ids });
    if (res.ok) refresh();
  }

  async function moveCharge(cat, index, d) {
    const ids = cat.charges.map((c) => c.id);
    const j = index + d;
    if (j < 0 || j >= ids.length) return;
    [ids[index], ids[j]] = [ids[j], ids[index]];
    const res = await request('penal.reorder', { charges: ids });
    if (res.ok) refresh();
  }
</script>

<div class="page">
  <header class="ph">
    <div>
      <h1>Penal code</h1>
      <p class="muted">{counts.all} charges in {penal.categories.length} categories{#if editing && counts.inactive}{' · '}{counts.inactive} retired{/if}</p>
    </div>
    <div class="stats">
      {#each classes as c}
        <button type="button" class="stat {classTone(c.value)}" class:on={cls === c.value} aria-pressed={cls === c.value} onclick={() => (cls = cls === c.value ? '' : c.value)}>
          <span class="n mono">{counts[c.value] || 0}</span><span class="l">{plural[c.value]}</span>
        </button>
      {/each}
    </div>
  </header>

  <div class="tools">
    <div class="search"><SearchBox bind:value={q} placeholder="Search charges and descriptions" delay={120} /></div>
    {#if cls}<Button size="sm" variant="ghost" icon="x" onclick={() => (cls = '')}>{classLabel(cls)} only</Button>{/if}
    <span class="grow"></span>
    {#if manager}
      {#if editing}
        <Button icon="plus" onclick={() => openCategory(null)}>New category</Button>
        <Button icon="plus" onclick={() => openCharge(null, activeCat)}>New charge</Button>
        <Button variant="primary" icon="check" onclick={() => (editing = false)}>Done editing</Button>
      {:else}
        <Button icon="edit" onclick={() => (editing = true)}>Edit penal code</Button>
      {/if}
    {/if}
  </div>

  {#if editing}
    <div class="banner"><span class="dot"></span>Edit mode. Changes apply to every officer at once. Sentences already applied keep the fines and jail times they were given.</div>
  {/if}

  <div class="body">
    <nav class="cats scroll" aria-label="Categories">
      <span class="eyebrow navh">Categories</span>
      {#each penal.categories as cat}
        {@const n = cat.charges.filter((c) => c.active !== false).length}
        {@const hit = sections.some((x) => x.id === cat.id)}
        <button type="button" class="cat" class:on={activeCat === cat.id} class:miss={!hit} disabled={!hit} onclick={() => jump(cat.id)}>
          <span class="cn">{cat.name}</span><span class="cc mono">{n}</span>
        </button>
      {/each}
    </nav>

    <div class="sections scroll" bind:this={body}>
      {#if !penal.loaded && penal.loading}
        <Spinner label="Loading the penal code" />
      {:else if !penal.loaded && penal.error}
        <Empty icon="alert" title="Couldn't load the penal code" text={errorText(penal.error)}>
          <Button size="sm" icon="refresh" onclick={refresh}>Try again</Button>
        </Empty>
      {:else if !sections.length}
        <Empty icon="scale" title={q || cls ? 'No charges match' : 'The penal code is empty'} text={q || cls ? 'Try another word or clear the class filter.' : manager ? 'Use Edit penal code to add categories and charges.' : 'Ask command staff to add charges.'} />
      {:else}
        {#each sections as cat, ci (cat.id)}
          <section data-cat={cat.id}>
            <div class="sh">
              <h2>{cat.name}</h2>
              <span class="mono faint">{cat.list.length}</span>
              <span class="grow"></span>
              {#if editing}
                <IconButton icon="chevronup" label="Move {cat.name} up" size={28} disabled={ci === 0 || q || cls} onclick={() => moveCategory(penal.categories.findIndex((c) => c.id === cat.id), -1)} />
                <IconButton icon="chevrondown" label="Move {cat.name} down" size={28} disabled={ci === sections.length - 1 || q || cls} onclick={() => moveCategory(penal.categories.findIndex((c) => c.id === cat.id), 1)} />
                <IconButton icon="edit" label="Rename {cat.name}" size={28} onclick={() => openCategory(cat)} />
                <IconButton icon="trash" label="Delete {cat.name}" size={28} variant="danger" disabled={cat.charges.length > 0} onclick={() => removeCategory(cat)} />
                <Button size="sm" icon="plus" onclick={() => openCharge(null, cat.id)}>Charge</Button>
              {/if}
            </div>
            {#if cat.list.length}
              <table>
                <thead>
                  <tr><th>Charge</th><th class="c">Class</th><th class="r">Fine</th><th class="r">Jail</th><th class="r pts">Points</th>{#if editing}<th class="act"><span class="sr-only">Actions</span></th>{/if}</tr>
                </thead>
                <tbody>
                  {#each cat.list as c, i (c.id)}
                    <tr class:inactive={c.active === false}>
                      <td>
                        <div class="t">{c.title}{#if c.active === false}<Badge tone="muted">Retired</Badge>{/if}</div>
                        {#if c.description}<div class="d">{c.description}</div>{/if}
                      </td>
                      <td class="c"><Badge tone={classTone(c.class)}>{classLabel(c.class)}</Badge></td>
                      <td class="r mono">{money(c.fine)}</td>
                      <td class="r mono">{c.months ? `${c.months} mo` : '—'}</td>
                      <td class="r mono pts">{c.points || '—'}</td>
                      {#if editing}
                        <td class="act">
                          <div class="acts">
                            <IconButton icon="chevronup" label="Move {c.title} up" size={26} disabled={i === 0 || q || cls} onclick={() => moveCharge(cat, cat.charges.findIndex((x) => x.id === c.id), -1)} />
                            <IconButton icon="chevrondown" label="Move {c.title} down" size={26} disabled={i === cat.list.length - 1 || q || cls} onclick={() => moveCharge(cat, cat.charges.findIndex((x) => x.id === c.id), 1)} />
                            <IconButton icon="edit" label="Edit {c.title}" size={26} onclick={() => openCharge(c)} />
                            <IconButton icon="trash" label="Remove {c.title}" size={26} variant="danger" onclick={() => removeCharge(c)} />
                          </div>
                        </td>
                      {/if}
                    </tr>
                  {/each}
                </tbody>
              </table>
            {:else}
              <p class="none">No charges in this category yet.</p>
            {/if}
          </section>
        {/each}
      {/if}
    </div>
  </div>
</div>

<PenalChargeModal bind:open={chargeModal} charge={editCharge} categories={penal.categories} categoryId={newIn} onsaved={refresh} />
<PenalCategoryModal bind:open={categoryModal} category={editCategory} onsaved={refresh} />

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 0; gap: 14px; }
  .ph { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
  h1 { font-size: 24px; font-weight: 700; }
  .stats { display: flex; gap: 8px; }
  .stat { display: flex; flex-direction: column; align-items: flex-start; padding: 8px 12px; border-radius: var(--radius); background: var(--panel); border: 1px solid var(--line-2); min-width: 112px; color: var(--text); text-align: left; }
  .stat:hover { border-color: var(--line-3); }
  .stat.on { border-color: var(--accent); background: var(--panel-2); }
  .stat .n { font-size: 20px; font-weight: 600; }
  .stat .l { color: var(--muted); font-size: 12px; }
  .stat.p1 .n { color: var(--p1-text); }
  .stat.accent .n { color: var(--accent); }
  .stat.muted .n { color: var(--text-2); }
  .tools { display: flex; align-items: center; gap: 8px; }
  .search { width: 360px; }
  .grow { flex: 1; }
  .banner { display: flex; align-items: center; gap: 10px; padding: 8px 12px; border-radius: var(--radius); background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--p2-text); font-size: 13px; }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--accent); flex: none; }
  .body { flex: 1; min-height: 0; display: flex; gap: 20px; }
  .cats { width: 200px; flex: none; display: flex; flex-direction: column; gap: 2px; padding-bottom: 20px; }
  .cat { display: flex; align-items: center; gap: 8px; height: 34px; padding: 0 10px; border-radius: var(--radius); border: 0; background: transparent; color: var(--text-2); text-align: left; flex: none; }
  .cat:hover:not(:disabled) { background: var(--panel); color: var(--text); }
  .cat.miss { opacity: 0.4; }
  .navh { padding: 8px 10px 6px; }
  .cat.on { background: var(--panel-2); color: var(--accent); }
  .cn { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .cc { font-size: 12px; color: var(--faint); }
  .sections { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 22px; padding-bottom: 24px; padding-right: 4px; }
  section { display: flex; flex-direction: column; gap: 6px; scroll-margin-top: 4px; }
  .sh { display: flex; align-items: center; gap: 8px; min-height: 30px; }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.04em; text-transform: uppercase; }
  table { width: 100%; border-collapse: collapse; }
  th { text-align: left; font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; padding: 6px 12px; border-bottom: 1px solid var(--line-2); }
  td { padding: 8px 12px; border-bottom: 1px solid var(--line); vertical-align: top; color: var(--text-2); }
  tr:hover td { background: rgba(255, 255, 255, 0.015); }
  .t { color: var(--text); font-weight: 600; display: flex; align-items: center; gap: 8px; }
  .d { color: var(--muted); font-size: 13px; margin-top: 2px; line-height: 1.4; }
  .inactive .t, .inactive .d, .inactive .r { opacity: 0.55; }
  .c { width: 128px; }
  .r { text-align: right; width: 104px; color: var(--text); }
  .pts { width: 72px; }
  .act { width: 128px; }
  .acts { display: flex; justify-content: flex-end; gap: 2px; }
  .none { color: var(--faint); font-size: 13px; padding: 4px 12px; }
</style>
