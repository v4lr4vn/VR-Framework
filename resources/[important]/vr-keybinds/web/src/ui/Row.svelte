<script>
  import KeyChip from './KeyChip.svelte';
  import { kb, suggestionFree, bindText, gtaUse } from '../lib/state.svelte.js';
  import { post } from '../lib/nui.js';

  let { action } = $props();

  const bind = $derived(kb.binds[action.id]);
  const flash = $derived(kb.flash === action.id);
  const canSuggest = $derived(!bind && suggestionFree(action));
  const warn = $derived(bind ? gtaUse(bind.k) : null);

  const capture = () => {
    kb.capture = { id: action.id, label: action.label, stage: 'listen' };
  };

  const clear = async () => {
    const res = await post('set', { id: action.id, bind: null });
    if (res && res.ok) kb.binds = res.binds || kb.binds;
    else if (!res) {
      const next = { ...kb.binds };
      delete next[action.id];
      kb.binds = next;
    }
  };

  const useSuggested = async () => {
    const res = await post('set', { id: action.id, bind: action.suggested });
    if (res && res.ok) kb.binds = res.binds || kb.binds;
    else if (!res) kb.binds = { ...kb.binds, [action.id]: action.suggested };
  };
</script>

<div class="row" class:flash class:need={action.essential && !bind}>
  <div class="text">
    <div class="label">
      {action.label}
      {#if action.essential}<span class="badge" class:ok={!!bind}>{bind ? 'Essential' : 'Required'}</span>{/if}
    </div>
    {#if action.description}<div class="desc">{action.description}</div>{/if}
    {#if warn}<div class="gta"><i class="fa-solid fa-gamepad"></i>Also {warn.toLowerCase()} in GTA</div>{/if}
  </div>
  <div class="side">
    {#if canSuggest}
      <button class="suggest" onclick={useSuggested} title="Use the suggested key">
        <i class="fa-solid fa-wand-magic-sparkles"></i>Use <span class="mono">{bindText(action.suggested)}</span>
      </button>
    {/if}
    <button class="key" class:set={!!bind} onclick={capture} aria-label="Set key for {action.label}">
      <KeyChip {bind} empty="Not set" />
    </button>
    <button class="clear" onclick={clear} disabled={!bind} aria-label="Clear key" title="Clear"><i class="fa-solid fa-xmark"></i></button>
  </div>
</div>

<style>
  .row {
    display: flex; align-items: center; gap: 16px; padding: 12px 14px; border-radius: var(--radius-lg);
    background: var(--panel); border: 1px solid var(--line); transition: border-color 0.2s, background 0.2s;
  }
  .row:hover { border-color: var(--line-3); }
  .row.need { border-color: var(--accent-line); background: linear-gradient(90deg, var(--accent-soft), transparent 60%), var(--panel); }
  .row.flash { border-color: var(--ok-line); background: linear-gradient(90deg, rgba(61, 214, 140, 0.12), transparent 60%), var(--panel); }
  .text { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 3px; }
  .label { display: flex; align-items: center; gap: 8px; font-weight: 600; font-size: 15px; color: var(--text); }
  .desc { color: var(--muted); font-size: 13px; }
  .gta { color: var(--faint); font-size: 12px; display: flex; align-items: center; gap: 6px; }
  .badge {
    font-family: var(--mono); font-size: 10px; letter-spacing: 0.1em; text-transform: uppercase; font-weight: 600;
    padding: 2px 6px; border-radius: 4px; background: var(--accent-soft); color: var(--accent-2); border: 1px solid var(--accent-line);
  }
  .badge.ok { background: var(--ok-bg); color: var(--ok-text); border-color: var(--ok-line); }
  .side { display: flex; align-items: center; gap: 8px; }
  button { border: 1px solid var(--line-3); background: var(--panel-2); color: var(--text-2); border-radius: var(--radius); }
  .key { min-width: 120px; height: 40px; padding: 0 10px; display: inline-flex; align-items: center; justify-content: center; background: var(--bg-2); border-style: dashed; }
  .key.set { border-style: solid; }
  .key:hover { border-color: var(--accent); background: var(--panel-2); }
  .clear { width: 32px; height: 32px; display: inline-flex; align-items: center; justify-content: center; color: var(--muted); background: transparent; }
  .clear:hover:not(:disabled) { color: var(--danger-text); border-color: var(--danger-line); background: var(--danger-bg); }
  .clear:disabled { opacity: 0.3; }
  .suggest { height: 32px; padding: 0 10px; display: inline-flex; align-items: center; gap: 6px; font-size: 13px; color: var(--muted); background: transparent; border-style: dashed; }
  .suggest .mono { color: var(--accent-2); font-weight: 600; }
  .suggest i { font-size: 11px; }
  .suggest:hover { color: var(--text); border-color: var(--accent-line); background: var(--accent-soft); }
</style>
