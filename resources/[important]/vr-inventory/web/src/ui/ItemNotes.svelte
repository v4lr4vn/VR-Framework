<script>
  import { ui, t, labelOf, imageOf } from '../lib/state.svelte.js';

  const KINDS = {
    ui_added: { tone: 'ok', icon: 'plus', code: 'ADDED' },
    ui_removed: { tone: 'danger', icon: 'minus', code: 'REMOVED' },
    ui_equipped: { tone: 'accent', icon: 'hand-fist', code: 'EQUIPPED' },
    ui_holstered: { tone: 'muted', icon: 'hand', code: 'HOLSTERED' },
    used: { tone: 'info', icon: 'check', code: 'USED' },
  };

  const kindOf = (key) => KINDS[key] || { tone: 'info', icon: 'circle-info', code: String(t(key) || key).toUpperCase() };
</script>

{#if ui.notes.length}
  <div class="notes" class:raised={!ui.open} class:top={ui.open}>
    {#each ui.notes as n (n.id)}
      {@const k = kindOf(n.key)}
      <article class="note tone-{k.tone}" class:leaving={n.leaving}>
        <span class="pill"><i class="fa-solid fa-{k.icon}"></i></span>
        <img src={imageOf(n.item)} alt="" onerror={(e) => (e.currentTarget.style.visibility = 'hidden')} />
        <div class="txt">
          <span class="code mono">{k.code}</span>
          <span class="name">{n.count && n.count > 0 ? `${n.count}× ` : ''}{labelOf(n.item)}</span>
        </div>
        <span class="bar"></span>
      </article>
    {/each}
  </div>
{/if}

<style>
  .notes { position: fixed; left: 50%; bottom: 28px; transform: translateX(-50%); z-index: 35; display: flex; flex-direction: row-reverse; gap: 8px; pointer-events: none; }
  .notes.raised { bottom: 134px; }
  .notes.top { bottom: auto; top: 6px; }
  .note {
    position: relative; overflow: hidden; display: flex; align-items: center; gap: 10px; min-width: 190px; max-width: 260px;
    padding: 9px 12px 11px 10px; border-radius: var(--radius-lg); background: var(--card); border: 1px solid var(--tone);
    box-shadow: 0 10px 28px rgba(0, 0, 0, 0.5); animation: enter 0.2s var(--ease); transition: opacity 0.2s, transform 0.2s;
  }
  .note.leaving { opacity: 0; transform: translateY(10px); }
  @keyframes enter { from { opacity: 0; transform: translateY(12px); } to { opacity: 1; transform: none; } }
  .pill { flex: none; width: 22px; height: 20px; border-radius: 4px; background: var(--tone); color: var(--bg); display: inline-flex; align-items: center; justify-content: center; font-size: 10px; }
  img { flex: none; width: 36px; height: 36px; object-fit: contain; filter: drop-shadow(0 3px 4px rgba(0, 0, 0, 0.5)); }
  .txt { min-width: 0; display: flex; flex-direction: column; }
  .code { font-size: 11px; font-weight: 600; letter-spacing: 0.04em; color: var(--tone-text); }
  .name { font-size: 14px; font-weight: 700; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .bar { position: absolute; left: 0; bottom: 0; height: 2px; width: 100%; background: var(--tone); transform-origin: left; animation: shrink 3s linear forwards; }
  @keyframes shrink { from { transform: scaleX(1); } to { transform: scaleX(0); } }
  .tone-ok { --tone: var(--ok); --tone-text: var(--ok-text); }
  .tone-danger { --tone: var(--danger); --tone-text: var(--danger-text); }
  .tone-accent { --tone: var(--accent); --tone-text: var(--p2-text); }
  .tone-muted { --tone: var(--muted); --tone-text: var(--text-2); }
  .tone-info { --tone: var(--info); --tone-text: var(--info-text); }
</style>
