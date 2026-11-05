<script>
  import { isGame, post } from './lib/nui.js';
  import { mockOpen, mockCall, mockHud, mockSetup, mockSetupCall } from './lib/mock.js';
  import Board from './ui/Board.svelte';
  import Hud from './ui/Hud.svelte';
  import Progress from './ui/Progress.svelte';
  import Skill from './ui/Skill.svelte';
  import Invite from './ui/Invite.svelte';
  import SetupPanel from './ui/SetupPanel.svelte';

  const q = new URLSearchParams(location.search);
  const view = q.get('view') || 'board';

  let visible = $state(!isGame && view !== 'hud' && view !== 'setup' && view !== 'progress' && view !== 'skill' && view !== 'invite');
  let p = $state(!isGame ? mockOpen() : null);
  let hud = $state(!isGame && view === 'hud' ? mockHud() : null);
  let prog = $state(!isGame && view === 'progress' ? { id: 1, label: 'Chopping', ms: 9000 } : null);
  let skill = $state(!isGame && view === 'skill' ? { id: 1, label: 'Reel it in', zone: 0.24, speed: 1, rounds: 2 } : null);
  let invite = $state(!isGame && view === 'invite' ? { id: 1, from: 'Rae Hale', label: 'Sanitation', seconds: 30 } : null);
  let setup = $state(!isGame && view === 'setup' ? mockSetup() : null);
  let mouse = $state(true);
  let seq = 0;

  const setupCall = async (action, data = {}) => {
    if (!isGame) return mockSetupCall(action, data);
    const r = await post('setup', { action, data });
    return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
  };

  const closeSetup = () => {
    if (isGame) post('setupClose');
    setup = null;
  };

  const call = async (action, data = {}) => {
    if (!isGame) return mockCall(action, data);
    const r = await post('api', { action, data });
    return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
  };

  const closeBoard = (silent) => {
    if (isGame) post('close');
    visible = false;
  };

  const skillDone = (ok) => {
    skill = null;
    if (isGame) post('skill', { success: ok });
  };

  $effect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      switch (d.action) {
        case 'open':
          p = d.data;
          visible = true;
          break;
        case 'update':
          if (visible) p = d.data;
          break;
        case 'close':
          visible = false;
          break;
        case 'hud':
          hud = { title: d.title, lines: d.lines || [], pct: d.pct };
          break;
        case 'hudClear':
          hud = null;
          break;
        case 'progress':
          prog = { id: ++seq, label: d.label, ms: d.ms };
          break;
        case 'progressEnd':
          prog = null;
          break;
        case 'skill':
          skill = { id: ++seq, label: d.label, zone: d.zone, speed: d.speed, rounds: d.rounds };
          break;
        case 'invite':
          invite = { id: ++seq, from: d.from, label: d.label, seconds: d.seconds };
          break;
        case 'inviteEnd':
          invite = null;
          break;
        case 'setupOpen':
          setup = d.data;
          mouse = true;
          break;
        case 'setupMode':
          mouse = d.mouse === true;
          if (!mouse && document.activeElement && document.activeElement !== document.body) document.activeElement.blur();
          break;
        case 'setupClose':
          setup = null;
          break;
      }
    };
    const swallow = (e) => {
      if (!setup || mouse || e.key === 'Alt') return;
      e.preventDefault();
      e.stopImmediatePropagation();
    };
    const onKey = (e) => {
      if (e.key === 'Alt') {
        if (setup) {
          e.preventDefault();
          if (mouse && isGame && !e.repeat) post('setupWalk');
        }
        return;
      }
      if (e.key !== 'Escape') return;
      if (setup) closeSetup();
      else if (visible) closeBoard();
    };
    window.addEventListener('message', onMsg);
    const onUp = (e) => {
      if (e.key === 'Alt' && setup) e.preventDefault();
    };
    window.addEventListener('keydown', swallow, true);
    window.addEventListener('keypress', swallow, true);
    window.addEventListener('keyup', swallow, true);
    window.addEventListener('keydown', onKey);
    window.addEventListener('keyup', onUp);
    return () => {
      window.removeEventListener('keydown', swallow, true);
      window.removeEventListener('keypress', swallow, true);
      window.removeEventListener('keyup', swallow, true);
      window.removeEventListener('keyup', onUp);
      window.removeEventListener('message', onMsg);
      window.removeEventListener('keydown', onKey);
    };
  });
</script>

{#if hud}<Hud {hud} />{/if}
{#if prog}{#key prog.id}<Progress label={prog.label} ms={prog.ms} />{/key}{/if}
{#if skill}{#key skill.id}<Skill label={skill.label} zone={skill.zone} speed={skill.speed} rounds={skill.rounds} ondone={skillDone} />{/key}{/if}
{#if invite}{#key invite.id}<Invite from={invite.from} label={invite.label} seconds={invite.seconds} />{/key}{/if}

{#if setup}<SetupPanel data={setup} call={setupCall} {post} {mouse} onclose={closeSetup} />{/if}

{#if visible && p}
  <div class="stage">
    <Board {p} {call} onclose={closeBoard} />
  </div>
{/if}

<style>
  .stage { position: fixed; inset: 0; display: grid; place-items: center; background: radial-gradient(ellipse at center, rgba(10, 14, 20, 0.35), rgba(10, 14, 20, 0.65)); }
</style>
