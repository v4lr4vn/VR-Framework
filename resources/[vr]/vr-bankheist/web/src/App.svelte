<script>
  import { isGame, post } from './lib/nui.js';
  import { mockOpen, mockCreator, mockTerminal, mockHack } from './lib/mock.js';
  import Creator from './ui/Creator.svelte';
  import Terminal from './ui/Terminal.svelte';
  import Drill from './ui/Drill.svelte';
  import Progress from './ui/Progress.svelte';
  import { bus } from './lib/bus.js';

  const view = new URLSearchParams(location.search).get('view') || '';

  let creator = $state(!isGame && view === 'creator' ? mockOpen() : null);
  let locked = $state(true);
  let hidden = $state(false);
  let term = $state(!isGame && view === 'terminal' ? mockTerminal() : null);
  let drill = $state(!isGame && view === 'drill' ? { depth: 42, heat: 58, jam: false } : null);
  let prog = $state(!isGame && view === 'progress' ? { id: 1, label: 'Grabbing cash', ms: 9000 } : null);
  let seq = 0;

  const creatorCall = async (action, data = {}) => {
    if (!isGame) return mockCreator(action, data);
    const r = await post('creator', { action, data });
    return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
  };

  const termCall = async (name, data = {}) => {
    if (!isGame) return name === 'hackCmd' ? mockHack(data.cmd) : { ok: true };
    const r = await post(name, data);
    return r && typeof r === 'object' ? r : { ok: false, error: 'failed' };
  };

  const closeCreator = () => {
    if (isGame) post('creatorClose');
    creator = null;
  };

  const closeTerm = () => {
    if (!term) return;
    if (isGame) post('hackClose');
    term = null;
  };

  $effect(() => {
    const onMsg = (e) => {
      const d = e.data || {};
      switch (d.action) {
        case 'creatorOpen':
          creator = d.data;
          locked = true;
          break;
        case 'creatorMode':
          locked = d.locked !== false;
          if (!locked && document.activeElement && document.activeElement !== document.body) document.activeElement.blur();
          break;
        case 'creatorClose':
          creator = null;
          hidden = false;
          break;
        case 'creatorHide':
          hidden = true;
          break;
        case 'creatorShow':
          hidden = false;
          break;
        case 'creatorPlaced':
          bus.emit(d);
          break;
        case 'terminal':
          term = d.data;
          break;
        case 'terminalClose':
          term = null;
          break;
        case 'drill':
          drill = { depth: d.depth || 0, heat: d.heat || 0, jam: d.jam === true };
          break;
        case 'drillEnd':
          drill = null;
          break;
        case 'progress':
          prog = { id: ++seq, label: d.label, ms: d.ms };
          break;
        case 'progressEnd':
          prog = null;
          break;
      }
    };
    const swallow = (e) => {
      if (!creator || locked || e.key === 'Alt') return;
      e.preventDefault();
      e.stopImmediatePropagation();
    };
    const onKey = (e) => {
      if (e.key === 'Alt') {
        if (creator) {
          e.preventDefault();
          if (locked && isGame && !e.repeat) post('creatorWalk');
        }
        return;
      }
      if (e.key !== 'Escape') return;
      if (term) closeTerm();
      else if (creator) closeCreator();
    };
    const onUp = (e) => {
      if (e.key === 'Alt' && creator) e.preventDefault();
    };
    window.addEventListener('message', onMsg);
    window.addEventListener('keydown', swallow, true);
    window.addEventListener('keypress', swallow, true);
    window.addEventListener('keyup', swallow, true);
    window.addEventListener('keydown', onKey);
    window.addEventListener('keyup', onUp);
    return () => {
      window.removeEventListener('message', onMsg);
      window.removeEventListener('keydown', swallow, true);
      window.removeEventListener('keypress', swallow, true);
      window.removeEventListener('keyup', swallow, true);
      window.removeEventListener('keydown', onKey);
      window.removeEventListener('keyup', onUp);
    };
  });
</script>

{#if drill}<Drill depth={drill.depth} heat={drill.heat} jam={drill.jam} />{/if}
{#if prog}{#key prog.id}<Progress label={prog.label} ms={prog.ms} />{/key}{/if}
{#if creator}<Creator data={creator} call={creatorCall} {post} {locked} {hidden} onclose={closeCreator} />{/if}
{#if term}<Terminal data={term} call={termCall} onclose={closeTerm} />{/if}
