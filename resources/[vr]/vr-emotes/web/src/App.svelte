<script>
  import { onMount, tick } from 'svelte';
  import Grid from './ui/Grid.svelte';
  import Detail from './ui/Detail.svelte';
  import Slots from './ui/Slots.svelte';
  import StyleList from './ui/StyleList.svelte';
  import Capture from './ui/Capture.svelte';
  import Request from './ui/Request.svelte';
  import { em, itemById, toast } from './lib/state.svelte.js';
  import { post, isGame } from './lib/nui.js';

  let grid = $state(null);
  let searchEl = $state(null);
  let hoverTimer = 0;
  let lastPreview = '';

  const tabs = $derived.by(() => {
    const out = [
      { id: 'favs', label: 'Favourites', icon: 'star', count: em.state.favs.length },
      { id: 'slots', label: 'Quick slots', icon: 'bolt' },
    ];
    for (const t of em.tabs) {
      if (t.id === 'animals' && !em.animals) continue;
      if (t.id === 'shared' && !em.sharedOn) continue;
      out.push({ id: t.id, label: t.label, icon: t.icon });
    }
    if (em.walksOn) out.push({ id: 'walks', label: 'Walks', icon: 'person-walking' });
    if (em.moodsOn) out.push({ id: 'moods', label: 'Moods', icon: 'face-smile' });
    return out;
  });

  const emoteTab = $derived(!['slots', 'walks', 'moods'].includes(em.tab));
  const styleTab = $derived(em.tab === 'walks' || em.tab === 'moods');
  const globalSearch = $derived(!!em.search && !styleTab);

  const list = $derived.by(() => {
    const q = em.search.trim().toLowerCase();
    if (q) {
      return em.items.filter((i) => i.l.toLowerCase().includes(q) || i.k.toLowerCase().includes(q)).slice(0, 600);
    }
    if (em.tab === 'favs') return em.items.filter((i) => em.state.favs.includes(i.id));
    return em.items.filter((i) => i.c === em.tab);
  });

  const styleList = $derived.by(() => {
    const src = em.tab === 'walks' ? em.walks : em.moods;
    const q = em.search.trim().toLowerCase();
    return q ? src.filter((s) => s.l.toLowerCase().includes(q) || s.k.toLowerCase().includes(q)) : src;
  });

  const preview = (data) => {
    const key = JSON.stringify(data);
    if (key === lastPreview) return;
    lastPreview = key;
    post('preview', data);
  };

  const previewSelected = () => {
    clearTimeout(hoverTimer);
    hoverTimer = setTimeout(() => {
      if (em.tab === 'moods') preview({ kind: 'mood', key: em.state.mood || null });
      else if (em.selected) preview({ kind: 'emote', id: em.selected });
      else preview({ kind: 'idle' });
    }, 120);
  };

  const hoverItem = (item) => {
    clearTimeout(hoverTimer);
    hoverTimer = setTimeout(() => preview({ kind: 'emote', id: item.id }), em.delay);
  };

  const hoverStyle = (s) => {
    clearTimeout(hoverTimer);
    const kind = em.tab === 'walks' ? 'walk' : 'mood';
    hoverTimer = setTimeout(() => preview({ kind, key: s ? s.k : null }), em.delay);
  };

  const pick = (item) => {
    em.selected = item.id;
    em.variation = 0;
    em.picker = false;
    preview({ kind: 'emote', id: item.id });
  };

  const play = (item) => {
    if (!item) return;
    if (item.f.includes('W')) post('shared', { id: item.id });
    else post('play', { id: item.id, variation: item.v ? em.variation + 1 : null });
  };

  const pickStyle = async (s) => {
    const res = await post(em.tab === 'walks' ? 'walk' : 'mood', { key: s ? s.k : null });
    if (res && res.state) em.state = res.state;
    if (em.tab === 'walks') toast(s ? `You now walk ${s.l.toLowerCase()}` : 'Walking style reset', 'ok');
    else toast(s ? `Mood set to ${s.l.toLowerCase()}` : 'Mood cleared', 'ok');
  };

  const setTab = async (id) => {
    em.tab = id;
    em.search = '';
    em.picker = false;
    lastPreview = '';
    await tick();
    if (grid) grid.reset();
    if (id === 'moods') preview({ kind: 'mood', key: em.state.mood || null });
    else previewSelected();
  };

  const stop = async () => {
    const res = await post('cancel');
    if (res && res.state) em.state = res.state;
  };

  const close = () => {
    em.picker = false;
    post('close');
    if (!isGame) em.open = false;
  };

  const move = (dx, dy) => {
    if (!(emoteTab || globalSearch) || !list.length) return;
    let i = list.findIndex((x) => x.id === em.selected);
    if (i < 0) i = 0;
    else i = Math.max(0, Math.min(list.length - 1, i + dx + dy * 2));
    pick(list[i]);
    if (grid) grid.reveal(i);
  };

  const onKey = (e) => {
    if (!em.open || em.capture) return;
    const typing = document.activeElement === searchEl;
    if (e.key === 'Escape') {
      e.preventDefault();
      if (em.picker) em.picker = false;
      else if (em.search) em.search = '';
      else close();
      return;
    }
    if (e.key === '/' && !typing) {
      e.preventDefault();
      searchEl && searchEl.focus();
      return;
    }
    if (e.key === 'Enter') {
      e.preventDefault();
      if ((emoteTab || globalSearch) && em.selected) play(itemById(em.selected));
      else if ((emoteTab || globalSearch) && list.length) play(list[0]);
      return;
    }
    if (typing && !['ArrowDown', 'ArrowUp'].includes(e.key)) return;
    if (e.key === 'ArrowRight') { e.preventDefault(); move(1, 0); }
    else if (e.key === 'ArrowLeft') { e.preventDefault(); move(-1, 0); }
    else if (e.key === 'ArrowDown') { e.preventDefault(); if (typing) searchEl.blur(); move(0, 1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); move(0, -1); }
  };

  const handlers = {
    open(d) {
      em.open = true;
      em.preview = !!d.preview;
      em.previewWhy = d.previewWhy || null;
      em.animals = !!d.animals;
      em.state = d.state || em.state;
      em.search = '';
      em.picker = false;
      em.capture = null;
      lastPreview = '';
      if (d.tab) em.tab = d.tab;
      if (em.tab === 'animals' && !em.animals) em.tab = 'emotes';
      if (!em.keyData) post('keyinfo').then((r) => { if (r && r.ok) em.keyData = r.data; });
      setTimeout(() => (em.tab === 'moods' ? preview({ kind: 'mood', key: em.state.mood || null }) : previewSelected()), 200);
    },
    close() {
      em.open = false;
      em.capture = null;
      em.picker = false;
    },
    request(d) {
      em.request = d ? { ...d, at: Date.now() } : null;
    },
  };

  onMount(() => {
    const onMessage = (event) => {
      const msg = event.data;
      if (!msg || typeof msg !== 'object' || typeof msg.action !== 'string') return;
      const fn = handlers[msg.action];
      if (fn) fn(msg.data);
    };
    window.addEventListener('message', onMessage);
    window.addEventListener('keydown', onKey);
    post('ready').then((d) => {
      if (!d) return;
      em.items = d.items || [];
      em.walks = d.walks || [];
      em.moods = d.moods || [];
      em.tabs = d.tabs || [];
      em.slots = d.slots || 10;
      em.sharedOn = d.shared !== false;
      em.walksOn = d.walksOn !== false;
      em.moodsOn = d.moodsOn !== false;
      em.delay = d.delay || 160;
      em.ready = true;
    });
    return () => {
      window.removeEventListener('message', onMessage);
      window.removeEventListener('keydown', onKey);
    };
  });

  const currentTab = $derived(tabs.find((t) => t.id === em.tab));
  const selectedItem = $derived(em.selected ? itemById(em.selected) : null);
  const hint = $derived(em.previewWhy === 'vehicle' ? 'Preview isn’t available in a vehicle' : em.previewWhy ? 'Preview isn’t available right now' : '');
</script>

{#if em.open}
  <div class="stagecap" class:off={!em.preview}>
    {#if em.preview}
      <div class="eyebrow mono"><i class="fa-solid fa-eye"></i>PREVIEW · ONLY YOU CAN SEE THIS</div>
      {#if em.tab !== 'walks' && em.tab !== 'moods' && selectedItem}<div class="big">{selectedItem.l}</div>{/if}
    {:else}
      <div class="eyebrow mono"><i class="fa-solid fa-eye-slash"></i>{hint}</div>
    {/if}
  </div>

  <div class="panel card" role="application">
    <header>
      <div class="mark"><i class="fa-solid fa-face-smile"></i></div>
      <h1>Emotes</h1>
      <div class="search">
        <i class="fa-solid fa-magnifying-glass"></i>
        <input bind:this={searchEl} bind:value={em.search} placeholder={styleTab ? `Search ${em.tab === 'walks' ? 'walking styles' : 'moods'}` : `Search ${em.items.length} emotes`} spellcheck="false" />
        {#if em.search}<button class="clr" onclick={() => (em.search = '')} aria-label="Clear search"><i class="fa-solid fa-xmark"></i></button>{:else}<kbd class="key">/</kbd>{/if}
      </div>
      <button class="x" onclick={close} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
    </header>

    <nav class="tabs">
      {#each tabs as t (t.id)}
        <button class="tab" class:on={!globalSearch && em.tab === t.id} onclick={() => setTab(t.id)}>
          <i class="fa-solid fa-{t.icon}"></i>{t.label}{#if t.count}<span class="mono n">{t.count}</span>{/if}
        </button>
      {/each}
    </nav>

    <section class="content">
      {#if globalSearch}
        <div class="head"><span class="mono">{list.length}{list.length === 600 ? '+' : ''} RESULTS</span></div>
      {:else if currentTab}
        <div class="head"><span class="mono">{currentTab.label.toUpperCase()}</span>
          {#if emoteTab}<span class="hint">Hover to preview · click to select · double-click or Enter to play</span>{/if}
        </div>
      {/if}

      {#if !globalSearch && em.tab === 'slots'}
        <Slots onhover={hoverItem} onleave={previewSelected} />
      {:else if styleTab}
        <StyleList list={styleList} current={em.tab === 'walks' ? em.state.walk : em.state.mood} kind={em.tab === 'walks' ? 'walk' : 'mood'}
          resetLabel={em.tab === 'walks' ? 'Default walk' : 'No mood'} onhover={hoverStyle} onleave={previewSelected} onpick={pickStyle} />
      {:else}
        <Grid bind:this={grid} {list} onhover={hoverItem} onleave={previewSelected} onpick={pick} onplay={play}
          empty={em.tab === 'favs' && !em.search ? 'No favourites yet. Select an emote and press the star.' : 'No emotes match that search.'} />
      {/if}
    </section>

    {#if (emoteTab || globalSearch) && em.selected}
      <Detail onplay={play} />
    {/if}

    <footer>
      <button class="stop" onclick={stop} disabled={!em.state.playing}>
        <i class="fa-solid fa-hand"></i>Stop emote
        {#if em.state.cancelKey}<kbd class="key">{em.state.cancelKey}</kbd>{:else}<span class="mono dim">/e c</span>{/if}
      </button>
      <span class="tip">{em.state.menuKey ? `Open this menu with ${em.state.menuKey}` : 'Bind a key to open this menu in /keybinds'}</span>
      {#if em.toast}{#key em.toast.id}<span class="toast" class:ok={em.toast.kind === 'ok'}>{em.toast.text}</span>{/key}{/if}
    </footer>
  </div>
  <Capture />
{/if}

<Request />

<style>
  .panel {
    position: fixed; top: 3.5vh; bottom: 3.5vh; right: 2vw; width: min(640px, 44vw); display: flex; flex-direction: column; overflow: hidden;
    animation: slide 0.18s var(--ease);
  }
  @keyframes slide { from { transform: translateX(24px); opacity: 0; } to { transform: none; opacity: 1; } }
  header { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); }
  .mark { width: 38px; height: 38px; border-radius: var(--radius-lg); display: flex; align-items: center; justify-content: center; background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--accent); font-size: 18px; flex-shrink: 0; }
  h1 { font-size: 20px; font-weight: 700; }
  .search { flex: 1; display: flex; align-items: center; gap: 8px; height: 38px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--bg-2); color: var(--muted); margin-left: 6px; }
  .search:focus-within { border-color: var(--accent-line); }
  .search input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); font-size: 14px; }
  .search input::placeholder { color: var(--faint); }
  .clr { border: 0; background: transparent; color: var(--muted); }
  .x { width: 36px; height: 36px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel-2); color: var(--muted); flex-shrink: 0; }
  .x:hover { color: var(--text); }
  .tabs { display: flex; flex-wrap: wrap; gap: 6px; padding: 10px 16px; border-bottom: 1px solid var(--line-2); background: rgba(0, 0, 0, 0.12); }
  .tab { display: inline-flex; align-items: center; gap: 7px; height: 32px; padding: 0 11px; border-radius: 16px; border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 13px; font-weight: 600; }
  .tab i { font-size: 12px; color: var(--muted); }
  .tab:hover { border-color: var(--line-3); background: var(--panel-2); }
  .tab.on { border-color: var(--accent-line); background: var(--accent-soft); color: var(--text); }
  .tab.on i { color: var(--accent); }
  .tab .n { font-size: 11px; color: var(--accent-2); }
  .content { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 8px; padding: 10px 12px 10px 16px; }
  .head { display: flex; align-items: baseline; gap: 12px; padding: 0 2px; }
  .head .mono { font-size: 11px; letter-spacing: 0.14em; color: var(--p2-text); font-weight: 600; }
  .head .hint { font-size: 11px; color: var(--faint); }
  footer { display: flex; align-items: center; gap: 12px; padding: 10px 14px; border-top: 1px solid var(--line-2); background: rgba(0, 0, 0, 0.25); position: relative; }
  .stop { height: 34px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); font-weight: 600; display: inline-flex; align-items: center; gap: 8px; }
  .stop:hover:not(:disabled) { border-color: var(--danger-line); color: var(--danger-text); background: var(--danger-bg); }
  .stop:disabled { opacity: 0.45; }
  .dim { color: var(--faint); font-size: 11px; }
  .tip { color: var(--faint); font-size: 12px; }
  .toast { position: absolute; right: 14px; padding: 6px 10px; border-radius: var(--radius); background: var(--info-bg); border: 1px solid var(--info-line); color: var(--info-text); font-size: 12px; font-weight: 600; animation: pop 0.15s ease; }
  .toast.ok { background: var(--ok-bg); border-color: var(--ok-line); color: var(--ok-text); }
  @keyframes pop { from { opacity: 0; transform: translateY(4px); } to { opacity: 1; transform: none; } }
  .stagecap { position: fixed; left: 4vw; bottom: 6vh; display: flex; flex-direction: column; gap: 8px; pointer-events: none; text-shadow: 0 2px 12px rgba(0, 0, 0, 0.8); }
  .eyebrow { display: inline-flex; align-items: center; gap: 8px; font-size: 11px; letter-spacing: 0.16em; color: var(--accent-2); font-weight: 600; padding: 6px 10px; border-radius: var(--radius); background: rgba(10, 14, 20, 0.7); border: 1px solid var(--accent-line); width: fit-content; text-shadow: none; }
  .stagecap.off .eyebrow { color: var(--muted); border-color: var(--line-3); }
  .big { font-size: 38px; font-weight: 700; color: var(--text); letter-spacing: 0.01em; }
</style>
