<script>
  import { onMount } from 'svelte';
  import { em, toast } from '../lib/state.svelte.js';
  import { vkFromCode, modFamily, modFromEvent } from '../lib/keys.js';
  import { post } from '../lib/nui.js';

  let held = $state(null);
  let error = $state(null);
  let stage = $state('listen');
  let pendingBind = $state(null);
  let info = $state(null);

  const cap = $derived(em.capture);
  const kd = $derived(em.keyData || { labels: {}, modLabels: { shift: 'Shift', ctrl: 'Ctrl', alt: 'Alt' }, blocked: {}, gta: {} });
  const label = (vk) => kd.labels[String(vk)] ?? `Key ${vk}`;
  const text = (b) => (b ? [(b.m ? kd.modLabels[b.m] : null), label(b.k)].filter(Boolean).join(' + ') : '');

  const reset = () => {
    held = null;
    error = null;
    stage = 'listen';
    pendingBind = null;
    info = null;
  };

  const done = (res) => {
    if (res && res.state) em.state = res.state;
    em.capture = null;
    reset();
  };

  const commit = async (bind, mode) => {
    const res = await post('key', { slot: cap.slot, bind, mode });
    if (res && res.ok) {
      toast(bind ? `Quick slot ${cap.slot} is on ${text(bind)}` : `Key cleared from quick slot ${cap.slot}`, 'ok');
      done(res);
    } else if (res && res.reason === 'conflict') {
      stage = 'conflict';
      pendingBind = bind;
      info = { otherLabel: res.otherLabel };
    } else {
      error = 'That key can’t be used.';
      stage = 'listen';
    }
  };

  const evaluate = async (bind) => {
    held = null;
    const res = await post('keycheck', { slot: cap.slot, bind });
    if (!res) return commit(bind);
    if (res.reason === 'blocked') {
      error = `${label(bind.k)} is reserved: ${res.why}.`;
      return;
    }
    error = null;
    pendingBind = bind;
    info = res;
    if (res.reason === 'conflict') stage = 'conflict';
    else if (res.gta) stage = 'gta';
    else commit(bind);
  };

  const onDown = (e) => {
    if (!em.capture) return;
    e.preventDefault();
    e.stopPropagation();
    if (e.repeat) return;
    if (stage !== 'listen') {
      if (e.code === 'Escape') reset();
      return;
    }
    if (e.code === 'Escape') { em.capture = null; reset(); return; }
    if (e.code === 'Backspace' || e.code === 'Delete') { if (cap.current) commit(null); return; }
    const vk = vkFromCode(e.code);
    if (!vk) { error = 'That key isn’t supported.'; return; }
    if (modFamily(vk)) { held = vk; return; }
    evaluate({ k: vk, m: modFromEvent(e) });
  };

  const onUp = (e) => {
    if (!em.capture || stage !== 'listen') return;
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
  <div class="veil" role="presentation" onpointerdown={(e) => { if (e.target === e.currentTarget && stage === 'listen') { em.capture = null; reset(); } }}>
    <div class="box card" role="dialog" aria-modal="true" aria-label="Set a key">
      <div class="for mono">QUICK SLOT {cap.slot}</div>
      <h2>{cap.label || 'Empty slot'}</h2>
      {#if stage === 'listen'}
        <div class="stage">
          {#if held}<kbd class="mono big">{kd.modLabels[modFamily(held)]}</kbd><span class="plus">+</span><kbd class="mono big">…</kbd>
          {:else if cap.current}<kbd class="mono big">{cap.current}</kbd>
          {:else}<span class="none mono">Press a key</span>{/if}
        </div>
        <p class="hint">Press the key you want for this slot. Hold <b>Shift</b>, <b>Ctrl</b> or <b>Alt</b> first for a combination.</p>
        {#if error}<p class="err"><i class="fa-solid fa-ban"></i>{error}</p>{/if}
        <div class="foot"><span><kbd class="key">Esc</kbd> cancel</span>{#if cap.current}<span><kbd class="key">Backspace</kbd> clear</span>{/if}</div>
      {:else if stage === 'conflict'}
        <div class="stage"><kbd class="mono big">{text(pendingBind)}</kbd></div>
        <p class="warn"><i class="fa-solid fa-link"></i><span><b>{text(pendingBind)}</b> is already used for <b>{info?.otherLabel || 'another action'}</b>.</span></p>
        <div class="actions">
          <button class="primary" onclick={() => commit(pendingBind, 'replace')}>Use it here</button>
          {#if cap.current}<button onclick={() => commit(pendingBind, 'swap')}>Swap keys</button>{/if}
          <button class="ghost" onclick={reset}>Pick another</button>
        </div>
      {:else if stage === 'gta'}
        <div class="stage"><kbd class="mono big">{text(pendingBind)}</kbd></div>
        <p class="warn"><i class="fa-solid fa-gamepad"></i><span>GTA also uses <b>{text(pendingBind)}</b> for <b>{info?.gta}</b>. Both will happen when you press it.</span></p>
        <div class="actions">
          <button class="primary" onclick={() => commit(pendingBind)}>Use it anyway</button>
          <button class="ghost" onclick={reset}>Pick another</button>
        </div>
      {/if}
    </div>
  </div>
{/if}

<style>
  .veil { position: fixed; inset: 0; z-index: 60; display: flex; align-items: center; justify-content: center; background: rgba(4, 6, 10, 0.55); }
  .box { width: 440px; padding: 20px 22px 16px; display: flex; flex-direction: column; align-items: center; text-align: center; gap: 10px; border-color: var(--line-3); }
  .for { font-size: 10px; letter-spacing: 0.16em; color: var(--accent); font-weight: 600; }
  h2 { font-size: 19px; font-weight: 700; }
  .stage { min-height: 80px; width: 100%; display: flex; align-items: center; justify-content: center; gap: 8px; border-radius: var(--radius-lg); background: var(--bg-2); border: 1px dashed var(--line-3); }
  kbd.big { display: inline-flex; align-items: center; justify-content: center; min-width: 52px; height: 50px; padding: 0 14px; border-radius: 8px; border: 1px solid var(--line-3); border-bottom-width: 4px; background: var(--panel-2); color: var(--accent-2); font-size: 20px; font-weight: 600; }
  .plus { color: var(--faint); font-size: 18px; }
  .none { color: var(--faint); font-size: 15px; }
  .hint { color: var(--muted); font-size: 13px; }
  .hint b { color: var(--text-2); }
  .err, .warn { display: flex; gap: 8px; align-items: flex-start; text-align: left; font-size: 13px; padding: 8px 10px; border-radius: var(--radius); width: 100%; }
  .err { background: var(--danger-bg); border: 1px solid var(--danger-line); color: var(--danger-text); }
  .warn { background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--p2-text); }
  .warn b { color: var(--accent-2); }
  .foot { display: flex; gap: 16px; color: var(--faint); font-size: 12px; }
  .actions { display: flex; gap: 8px; }
  button { height: 34px; padding: 0 14px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); font-weight: 600; }
  button:hover { background: var(--panel-3); color: var(--text); }
  .primary { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); }
  .primary:hover { background: var(--accent-2); color: var(--accent-ink); }
  .ghost { background: transparent; }
</style>
