<script>
  import { onMount } from 'svelte';
  import KeyChip from './KeyChip.svelte';
  import { kb, keyLabel, blockedWhy, gtaUse, conflictFor, actionById, bindText } from '../lib/state.svelte.js';
  import { vkFromCode, modFamily, modFromEvent } from '../lib/keys.js';
  import { post } from '../lib/nui.js';

  let held = $state(null);
  let error = $state(null);

  const cap = $derived(kb.capture);
  const current = $derived(cap ? kb.binds[cap.id] : null);
  const live = $derived(held ? [kb.modLabels[modFamily(held)] ?? keyLabel(held), '…'] : null);

  const commit = async (bind, mode) => {
    const id = cap.id;
    const res = await post('set', { id, bind, mode });
    if (res && res.ok) {
      kb.binds = res.binds || kb.binds;
      kb.flash = id;
      setTimeout(() => { if (kb.flash === id) kb.flash = null; }, 900);
      kb.capture = null;
    } else if (res && res.reason === 'conflict') {
      kb.capture = { ...cap, stage: 'conflict', bind, other: res.other };
    } else if (res) {
      error = 'That key can’t be used.';
      kb.capture = { ...cap, stage: 'listen' };
    } else {
      kb.binds = { ...kb.binds, [id]: bind };
      kb.capture = null;
    }
  };

  const evaluate = (bind) => {
    held = null;
    const why = blockedWhy(bind.k);
    if (why) {
      error = `${keyLabel(bind.k)} is reserved: ${why}.`;
      return;
    }
    error = null;
    const other = conflictFor(cap.id, bind);
    if (other) {
      kb.capture = { ...cap, stage: 'conflict', bind, other };
      return;
    }
    const gta = gtaUse(bind.k);
    if (gta) {
      kb.capture = { ...cap, stage: 'gta', bind, gta };
      return;
    }
    commit(bind);
  };

  const cancel = () => {
    held = null;
    error = null;
    kb.capture = null;
  };

  const clear = () => {
    held = null;
    commit(null);
  };

  const retry = () => {
    error = null;
    kb.capture = { ...cap, stage: 'listen', bind: null };
  };

  const onDown = (e) => {
    if (!kb.capture) return;
    e.preventDefault();
    e.stopPropagation();
    if (e.repeat) return;
    if (kb.capture.stage !== 'listen') {
      if (e.code === 'Escape') retry();
      return;
    }
    if (e.code === 'Escape') return cancel();
    if (e.code === 'Backspace' || e.code === 'Delete') return current ? clear() : null;
    const vk = vkFromCode(e.code);
    if (!vk) {
      error = 'That key isn’t supported.';
      return;
    }
    if (modFamily(vk)) {
      held = vk;
      return;
    }
    let m = modFromEvent(e);
    evaluate({ k: vk, m });
  };

  const onUp = (e) => {
    if (!kb.capture || kb.capture.stage !== 'listen') return;
    e.preventDefault();
    const vk = vkFromCode(e.code);
    if (held && vk && modFamily(vk) === modFamily(held)) {
      const k = held;
      held = null;
      evaluate({ k, m: null });
    }
  };

  onMount(() => {
    window.addEventListener('keydown', onDown, true);
    window.addEventListener('keyup', onUp, true);
    return () => {
      window.removeEventListener('keydown', onDown, true);
      window.removeEventListener('keyup', onUp, true);
    };
  });
</script>

{#if cap}
  <div class="veil" role="presentation" onpointerdown={(e) => { if (e.target === e.currentTarget && cap.stage === 'listen') cancel(); }}>
    <div class="box card" role="dialog" aria-modal="true" aria-label="Set a key">
      <div class="for mono">SET KEY</div>
      <h2>{cap.label}</h2>

      {#if cap.stage === 'listen'}
        <div class="stage">
          <KeyChip size="lg" live={live} bind={live ? null : current} empty="Press a key" />
        </div>
        <p class="hint">
          {#if live}Now press the other key, or let go to use {keyLabel(held)} on its own.
          {:else}Press the key you want. Hold <b>Shift</b>, <b>Ctrl</b> or <b>Alt</b> first for a combination.{/if}
        </p>
        {#if error}<p class="err"><i class="fa-solid fa-ban"></i>{error}</p>{/if}
        <div class="foot">
          <span><kbd class="key">Esc</kbd> cancel</span>
          {#if current}<span><kbd class="key">Backspace</kbd> clear</span>{/if}
        </div>
      {:else if cap.stage === 'conflict'}
        <div class="stage"><KeyChip size="lg" bind={cap.bind} /></div>
        <p class="warn"><i class="fa-solid fa-link"></i><span><b>{bindText(cap.bind)}</b> is already used for <b>{actionById(cap.other)?.label ?? 'another action'}</b>.</span></p>
        <div class="actions">
          <button class="primary" onclick={() => commit(cap.bind, 'replace')}>Use it here</button>
          {#if current}<button onclick={() => commit(cap.bind, 'swap')}>Swap keys</button>{/if}
          <button class="ghost" onclick={retry}>Pick another</button>
        </div>
        <p class="small">{current ? `Swap gives ${actionById(cap.other)?.label ?? 'it'} your old key (${bindText(current)}).` : `${actionById(cap.other)?.label ?? 'The other action'} will be left without a key.`}</p>
      {:else if cap.stage === 'gta'}
        <div class="stage"><KeyChip size="lg" bind={cap.bind} /></div>
        <p class="warn"><i class="fa-solid fa-gamepad"></i><span>GTA also uses <b>{bindText(cap.bind)}</b> for <b>{cap.gta}</b>. Both will happen when you press it.</span></p>
        <div class="actions">
          <button class="primary" onclick={() => commit(cap.bind)}>Use it anyway</button>
          <button class="ghost" onclick={retry}>Pick another</button>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .veil { position: fixed; inset: 0; z-index: 50; display: flex; align-items: center; justify-content: center; background: rgba(4, 6, 10, 0.6); animation: fade 0.12s ease; }
  @keyframes fade { from { opacity: 0; } to { opacity: 1; } }
  .box { width: 460px; padding: 22px 24px 18px; display: flex; flex-direction: column; align-items: center; text-align: center; gap: 10px; border-color: var(--line-3); animation: pop 0.14s var(--ease); }
  @keyframes pop { from { transform: scale(0.97); opacity: 0; } to { transform: none; opacity: 1; } }
  .for { font-size: 10px; letter-spacing: 0.16em; color: var(--accent); font-weight: 600; }
  h2 { font-size: 20px; font-weight: 700; }
  .stage { min-height: 84px; display: flex; align-items: center; justify-content: center; width: 100%; margin: 6px 0 2px; border-radius: var(--radius-lg); background: var(--bg-2); border: 1px dashed var(--line-3); }
  .hint { color: var(--muted); font-size: 13px; max-width: 360px; }
  .hint b { color: var(--text-2); font-weight: 600; }
  .err, .warn { display: flex; gap: 8px; align-items: flex-start; text-align: left; font-size: 13px; padding: 8px 10px; border-radius: var(--radius); width: 100%; }
  .err { background: var(--danger-bg); border: 1px solid var(--danger-line); color: var(--danger-text); }
  .warn { background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--p2-text); }
  .warn b { color: var(--accent-2); }
  .err i, .warn i { margin-top: 2px; }
  .foot { display: flex; gap: 16px; color: var(--faint); font-size: 12px; margin-top: 2px; }
  .actions { display: flex; gap: 8px; margin-top: 4px; }
  .small { font-size: 12px; color: var(--faint); }
  button { height: 34px; padding: 0 14px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); font-weight: 600; }
  button:hover { background: var(--panel-3); color: var(--text); }
  .primary { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }
  .primary:hover { background: var(--accent-2); color: var(--accent-ink); }
  .ghost { background: transparent; }
</style>
