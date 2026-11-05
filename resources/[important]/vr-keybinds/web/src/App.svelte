<script>
  import { onMount } from 'svelte';
  import Row from './ui/Row.svelte';
  import Capture from './ui/Capture.svelte';
  import { kb, essentials, missing } from './lib/state.svelte.js';
  import { post } from './lib/nui.js';

  let nag = $state(false);
  let confirmReset = $state(false);
  let searchEl = $state(null);

  const sections = $derived.by(() => {
    const out = [];
    const ess = essentials();
    if (ess.length) out.push({ id: 'essentials', label: 'Essentials', icon: 'star', items: ess });
    for (const c of kb.categories) {
      const items = kb.actions.filter((a) => a.category === c.id);
      if (items.length) out.push({ ...c, items });
    }
    return out;
  });

  const current = $derived(sections.find((s) => s.id === kb.section) ?? sections[0]);

  const shown = $derived.by(() => {
    const q = kb.search.trim().toLowerCase();
    if (!q) return current ? current.items : [];
    return kb.actions.filter((a) => a.label.toLowerCase().includes(q) || (a.description || '').toLowerCase().includes(q));
  });

  const need = $derived(missing());
  const essTotal = $derived(essentials().length);
  const setup = $derived(kb.mode === 'setup');
  const boundCount = (items) => items.filter((a) => kb.binds[a.id]).length;

  const close = async () => {
    if (setup && need.length) {
      nag = true;
      kb.section = 'essentials';
      setTimeout(() => (nag = false), 1600);
      return;
    }
    const res = await post('close');
    if (res && res.ok === false) {
      nag = true;
      setTimeout(() => (nag = false), 1600);
      return;
    }
    if (!res) kb.open = false;
  };

  const reset = async () => {
    confirmReset = false;
    const res = await post('reset');
    kb.binds = (res && res.binds) || {};
  };

  const handlers = {
    open(d) {
      kb.mode = d.mode || 'menu';
      kb.actions = d.actions || [];
      kb.binds = d.binds || {};
      kb.categories = d.categories || [];
      kb.labels = d.labels || {};
      kb.modLabels = d.modLabels || kb.modLabels;
      kb.blocked = d.blocked || {};
      kb.gta = d.gta || {};
      kb.command = d.command || 'keybinds';
      kb.search = '';
      kb.capture = null;
      kb.section = kb.mode === 'setup' || !kb.section ? 'essentials' : kb.section;
      confirmReset = false;
      kb.open = true;
    },
    close() {
      kb.open = false;
      kb.capture = null;
    },
    actions(d) {
      kb.actions = d.actions || kb.actions;
      kb.binds = d.binds || kb.binds;
    },
    mode(d) {
      kb.mode = d.mode || kb.mode;
    },
  };

  const onKey = (e) => {
    if (!kb.open || kb.capture) return;
    if (e.key === 'Escape') {
      e.preventDefault();
      if (confirmReset) confirmReset = false;
      else if (kb.search) kb.search = '';
      else close();
    } else if (e.key === 'f' && (e.ctrlKey || e.metaKey) && searchEl) {
      e.preventDefault();
      searchEl.focus();
    }
  };

  onMount(() => {
    const onMessage = (event) => {
      const msg = event.data;
      if (!msg || typeof msg !== 'object' || typeof msg.action !== 'string') return;
      const fn = handlers[msg.action];
      if (fn) fn(msg.data || {});
    };
    window.addEventListener('message', onMessage);
    window.addEventListener('keydown', onKey);
    post('ready');
    return () => {
      window.removeEventListener('message', onMessage);
      window.removeEventListener('keydown', onKey);
    };
  });
</script>

{#if kb.open}
  <div class="screen" role="application">
    <div class="panel card">
      <header>
        <div class="mark"><i class="fa-solid fa-keyboard"></i></div>
        <div class="title">
          <h1>{setup ? 'Set up your keys' : 'Key bindings'}</h1>
          <p>
            {#if setup}Nothing is bound until you choose. Set the essentials to start playing — everything else is optional.
            {:else}Pick any key for any action. Combinations with Shift, Ctrl or Alt work too.{/if}
          </p>
        </div>
        {#if essTotal}
          <div class="progress" class:done={!need.length} class:nag>
            <span class="mono">{essTotal - need.length}/{essTotal}</span>
            <span>essentials</span>
            <div class="bar"><div style:width="{((essTotal - need.length) / essTotal) * 100}%"></div></div>
          </div>
        {/if}
        {#if !setup}
          <button class="x" onclick={close} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
        {/if}
      </header>

      <div class="body">
        <nav class="scroll">
          {#each sections as s (s.id)}
            <button class="sec" class:on={!kb.search && current && current.id === s.id} onclick={() => { kb.search = ''; kb.section = s.id; }}>
              <i class="fa-solid fa-{s.icon || 'circle'}"></i>
              <span class="name">{s.label}</span>
              <span class="count mono" class:full={boundCount(s.items) === s.items.length}>{boundCount(s.items)}/{s.items.length}</span>
            </button>
          {/each}
        </nav>

        <section>
          <div class="search">
            <i class="fa-solid fa-magnifying-glass"></i>
            <input bind:this={searchEl} bind:value={kb.search} placeholder="Search actions" spellcheck="false" />
            {#if kb.search}<button class="clr" onclick={() => (kb.search = '')} aria-label="Clear search"><i class="fa-solid fa-xmark"></i></button>{/if}
          </div>
          {#if !kb.search && current}
            <div class="sechead">
              <h2>{current.label}</h2>
              {#if current.id === 'essentials'}<span>You need these to play.</span>{/if}
            </div>
          {/if}
          <div class="list scroll">
            {#each shown as a (a.id)}
              <Row action={a} />
            {:else}
              <div class="empty">{kb.search ? 'No actions match that search.' : 'Nothing here yet.'}</div>
            {/each}
          </div>
        </section>
      </div>

      <footer>
        <div class="tip">
          <i class="fa-solid fa-circle-info"></i>
          Change these anytime with <span class="mono">/{kb.command}</span>
        </div>
        {#if !setup}
          {#if confirmReset}
            <span class="sure">Clear every key?</span>
            <button class="danger" onclick={reset}>Yes, clear all</button>
            <button onclick={() => (confirmReset = false)}>Keep</button>
          {:else}
            <button class="ghost" onclick={() => (confirmReset = true)}>Clear all</button>
          {/if}
        {/if}
        <button class="primary" class:locked={setup && need.length} onclick={close}>
          {#if setup && need.length}Set {need.length} more essential{need.length === 1 ? '' : 's'}{:else if setup}Continue<i class="fa-solid fa-arrow-right"></i>{:else}Done{/if}
        </button>
      </footer>
    </div>
  </div>
  <Capture />
{/if}

<style>
  .screen {
    position: fixed; inset: 0; display: flex; align-items: center; justify-content: center;
    background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.55) 0%, rgba(4, 6, 10, 0.88) 100%);
    animation: fade 0.16s ease;
  }
  @keyframes fade { from { opacity: 0; } to { opacity: 1; } }
  .panel { width: min(1080px, 92vw); height: min(780px, 86vh); display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 16px; padding: 18px 22px; border-bottom: 1px solid var(--line-2); }
  .mark { width: 44px; height: 44px; border-radius: var(--radius-lg); display: flex; align-items: center; justify-content: center; background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--accent); font-size: 20px; }
  .title { flex: 1; min-width: 0; }
  h1 { font-size: 22px; font-weight: 700; letter-spacing: 0.01em; }
  .title p { color: var(--muted); font-size: 14px; margin-top: 2px; }
  .progress { display: grid; grid-template-columns: auto auto; column-gap: 6px; row-gap: 6px; align-items: baseline; padding: 8px 12px; border-radius: var(--radius-lg); border: 1px solid var(--accent-line); background: var(--accent-soft); color: var(--p2-text); font-size: 12px; text-transform: uppercase; letter-spacing: 0.08em; transition: transform 0.2s; }
  .progress .mono { font-size: 18px; font-weight: 600; color: var(--accent-2); letter-spacing: 0; text-transform: none; }
  .progress .bar { grid-column: 1 / -1; height: 4px; border-radius: 4px; background: rgba(0, 0, 0, 0.35); overflow: hidden; }
  .progress .bar div { height: 100%; background: var(--accent); transition: width 0.25s var(--ease); }
  .progress.done { border-color: var(--ok-line); background: var(--ok-bg); color: var(--ok-text); }
  .progress.done .mono { color: var(--ok-text); }
  .progress.done .bar div { background: var(--ok); }
  .progress.nag { animation: shake 0.4s; border-color: var(--danger-line); }
  @keyframes shake { 20%, 60% { transform: translateX(-4px); } 40%, 80% { transform: translateX(4px); } }
  .x { width: 36px; height: 36px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel-2); color: var(--muted); }
  .x:hover { color: var(--text); }
  .body { flex: 1; min-height: 0; display: flex; }
  nav { width: 230px; flex-shrink: 0; padding: 12px; border-right: 1px solid var(--line-2); display: flex; flex-direction: column; gap: 2px; background: rgba(0, 0, 0, 0.12); }
  .sec { display: flex; align-items: center; gap: 10px; height: 38px; padding: 0 10px; border-radius: var(--radius); border: 1px solid transparent; background: transparent; color: var(--text-2); text-align: left; font-size: 14px; font-weight: 500; }
  .sec i { width: 16px; text-align: center; color: var(--muted); font-size: 13px; }
  .sec .name { flex: 1; }
  .sec .count { font-size: 11px; color: var(--faint); }
  .sec .count.full { color: var(--ok-text); }
  .sec:hover { background: var(--panel-2); }
  .sec.on { background: var(--accent-soft); border-color: var(--accent-line); color: var(--text); }
  .sec.on i { color: var(--accent); }
  section { flex: 1; min-width: 0; display: flex; flex-direction: column; padding: 14px 18px 0; gap: 10px; }
  .search { display: flex; align-items: center; gap: 8px; height: 38px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--bg-2); color: var(--muted); }
  .search:focus-within { border-color: var(--accent-line); }
  .search input { flex: 1; border: 0; outline: none; background: transparent; font-size: 14px; color: var(--text); }
  .search input::placeholder { color: var(--faint); }
  .clr { border: 0; background: transparent; color: var(--muted); }
  .sechead { display: flex; align-items: baseline; gap: 12px; padding: 2px 2px 0; }
  .sechead h2 { font-size: 13px; font-family: var(--mono); letter-spacing: 0.12em; text-transform: uppercase; color: var(--p2-text); font-weight: 600; }
  .sechead span { font-size: 12px; color: var(--faint); }
  .list { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 6px; padding: 0 4px 14px 0; }
  .empty { color: var(--faint); padding: 30px 0; text-align: center; }
  footer { display: flex; align-items: center; gap: 8px; padding: 12px 18px; border-top: 1px solid var(--line-2); background: rgba(0, 0, 0, 0.18); }
  .tip { flex: 1; display: flex; align-items: center; gap: 8px; color: var(--faint); font-size: 13px; }
  .tip .mono { color: var(--accent-2); }
  .sure { color: var(--danger-text); font-size: 13px; }
  footer button { height: 38px; padding: 0 16px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); font-weight: 600; display: inline-flex; align-items: center; gap: 8px; }
  footer button:hover { background: var(--panel-3); color: var(--text); }
  .ghost { background: transparent; }
  .danger { background: var(--danger-bg); border-color: var(--danger-line); color: var(--danger-text); }
  .primary { min-width: 150px; justify-content: center; background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }
  .primary:hover { background: var(--accent-2); color: var(--accent-ink); }
  .primary.locked { background: var(--panel-2); border-color: var(--accent-line); color: var(--p2-text); }
</style>
