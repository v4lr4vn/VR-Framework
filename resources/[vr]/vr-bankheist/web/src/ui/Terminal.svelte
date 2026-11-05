<script>
  import { tick } from 'svelte';
  import { clock } from '../lib/format.js';

  let { data, call, onclose } = $props();

  const COMMANDS = ['help', 'man', 'ls', 'cd', 'pwd', 'cat', 'whoami', 'clear', 'exit', 'logout', 'heimdall', 'fenrir', 'gungnir', 'mjolnir', 'hel', 'sudo'];

  let lines = $state([]);
  let input = $state('');
  let prompt = $state(data.prompt || 'guest@host:~$');
  let trace = $state(0);
  let left = $state(data.seconds || 0);
  let busy = $state(true);
  let end = $state(null);
  let done = $state(false);
  let history = [];
  let hist = -1;
  let words = new Set();
  let box;
  let field;
  let alive = true;
  let seq = 0;

  const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

  async function scroll() {
    await tick();
    if (box) box.scrollTop = box.scrollHeight;
  }

  async function push(k, t, d) {
    if (!alive) return;
    if (d && d > 0) await sleep(Math.min(d, 2500));
    if (!alive) return;
    lines.push({ k, t: String(t ?? ''), id: ++seq });
    for (const w of String(t ?? '').split(/[\s,:;()\[\]]+/)) if (w && w.length < 40) words.add(w);
    if (lines.length > 600) lines.splice(0, lines.length - 600);
    scroll();
  }

  async function boot() {
    const rows = [
      ['dim', "ODIN'S EYE  intrusion shell  build 9.0.1"],
      ['dim', 'tunnel .......... up'],
      ['dim', `target ........... ${data.hostname}  [${data.ip}]`],
      ['dim', `perimeter ........ ${data.ward}  (tier ${data.tier})`],
      ['out', ''],
      ['out', "You are in. Type 'help' to see what you can do."],
    ];
    for (const [k, t] of rows) await push(k, t, 120);
    busy = false;
    focus();
  }

  const focus = async () => {
    await tick();
    if (field) field.focus();
  };

  async function submit() {
    if (busy || end) return;
    const cmd = input.trim();
    const shown = `${prompt} ${input}`;
    input = '';
    hist = -1;
    if (!cmd) {
      push('cmd', shown);
      return;
    }
    if (history[history.length - 1] !== cmd) history.push(cmd);
    if (history.length > 80) history.shift();
    push('cmd', shown);
    busy = true;
    const r = await call('hackCmd', { cmd });
    if (!alive) return;
    if (!r || !r.ok || !r.data) {
      await push('err', r && r.error === 'slow_down' ? 'too fast, wait a moment' : 'connection lost');
      if (r && r.error === 'no_session') finish('closed');
      busy = false;
      focus();
      return;
    }
    const d = r.data;
    if (d.clear) lines.splice(0, lines.length);
    for (const l of d.lines || []) await push(l.k || 'out', l.t, l.d);
    if (typeof d.trace === 'number') trace = d.trace;
    if (d.prompt) prompt = d.prompt;
    if (d.done) done = true;
    if (d.closed) {
      finish(d.failed ? 'failed' : 'closed');
      return;
    }
    busy = false;
    focus();
  }

  function finish(kind) {
    end = kind;
    busy = true;
    setTimeout(() => alive && onclose(), kind === 'failed' ? 3200 : 1500);
  }

  function complete() {
    const parts = input.split(/\s+/);
    const last = parts[parts.length - 1];
    if (!last) return;
    const pool = parts.length === 1 ? COMMANDS : [...words];
    const hits = pool.filter((w) => w.startsWith(last) && w !== last);
    if (hits.length === 1) {
      parts[parts.length - 1] = hits[0];
      input = parts.join(' ') + (parts.length === 1 ? ' ' : '');
    } else if (hits.length > 1) {
      push('dim', hits.slice(0, 14).join('   '));
    }
  }

  function onkey(e) {
    if (e.key === 'Enter') {
      e.preventDefault();
      submit();
    } else if (e.key === 'ArrowUp') {
      e.preventDefault();
      if (!history.length) return;
      hist = hist < 0 ? history.length - 1 : Math.max(0, hist - 1);
      input = history[hist];
    } else if (e.key === 'ArrowDown') {
      e.preventDefault();
      if (hist < 0) return;
      hist++;
      if (hist >= history.length) {
        hist = -1;
        input = '';
      } else input = history[hist];
    } else if (e.key === 'Tab') {
      e.preventDefault();
      complete();
    } else if (e.ctrlKey && (e.key === 'l' || e.key === 'L')) {
      e.preventDefault();
      lines.splice(0, lines.length);
    } else if (e.ctrlKey && (e.key === 'c' || e.key === 'C') && !window.getSelection().toString()) {
      e.preventDefault();
      if (input) push('cmd', `${prompt} ${input}^C`);
      input = '';
    }
  }

  $effect(() => {
    boot();
    const t = setInterval(() => {
      if (left > 0 && !end) left--;
    }, 1000);
    return () => {
      alive = false;
      clearInterval(t);
    };
  });

  const level = $derived(trace >= 80 ? 'crit' : trace >= 50 ? 'high' : 'low');
  const ward = $derived(data.tier || 1);
</script>

<!-- svelte-ignore a11y_click_events_have_key_events, a11y_no_static_element_interactions -->
<div class="stage" onclick={focus}>
  <div class="term card" class:crit={level === 'crit'} class:ended={!!end}>
    <header>
      <svg class="eye" viewBox="0 0 64 40" aria-hidden="true">
        <path d="M2 20 C14 4 50 4 62 20 C50 36 14 36 2 20 Z" fill="none" stroke="currentColor" stroke-width="2.4" />
        <circle class="iris" cx="32" cy="20" r="9" fill="none" stroke="currentColor" stroke-width="2.4" />
        <circle class="pupil" cx="32" cy="20" r="3.6" fill="currentColor" />
      </svg>
      <div class="id">
        <h1>Odin's Eye</h1>
        <p class="num">{data.hostname} · {data.ip}</p>
      </div>
      <div class="ward">
        <span class="label">{data.ward}</span>
        <span class="pips">{#each [1, 2, 3, 4, 5] as n}<i class:on={n <= ward}></i>{/each}</span>
      </div>
      <div class="timer" class:low={left < 30}>
        <span class="label">Session</span>
        <span class="num big">{clock(left)}</span>
      </div>
      <button class="x" onclick={onclose} aria-label="Disconnect" title="Disconnect (Esc)"><i class="fa-solid fa-power-off"></i></button>
    </header>

    <div class="trace" class:crit={level === 'crit'}>
      <span class="label">Trace</span>
      <div class="meter {level}"><span style="width:{Math.min(100, trace)}%"></span></div>
      <span class="num pct">{trace}%</span>
      {#if done}<span class="chip ok"><i class="fa-solid fa-check"></i>Objective done</span>{/if}
    </div>

    <div class="screen scroll" bind:this={box} role="log" aria-live="polite">
      {#each lines as l (l.id)}
        <div class="ln {l.k}">{l.t || ' '}</div>
      {/each}
      {#if !end}
        <label class="in" class:wait={busy}>
          <span class="pr">{prompt}</span>
          <input bind:this={field} bind:value={input} onkeydown={onkey} disabled={busy} spellcheck="false" autocomplete="off" autocapitalize="off" aria-label="Command" />
        </label>
      {/if}
    </div>

    {#if end}
      <div class="over {end}">
        <i class="fa-solid {end === 'failed' ? 'fa-triangle-exclamation' : 'fa-plug-circle-xmark'}"></i>
        <strong>{end === 'failed' ? 'Traced. Connection burned' : 'Disconnected'}</strong>
        <span>{end === 'failed' ? 'Your rig is cold for a while' : 'Session closed'}</span>
      </div>
    {/if}

    <footer>
      <span><kbd class="key">Tab</kbd> complete</span>
      <span><kbd class="key">↑</kbd><kbd class="key">↓</kbd> history</span>
      <span><kbd class="key">Esc</kbd> disconnect</span>
    </footer>
  </div>
</div>

<style>
  .stage { position: fixed; inset: 0; display: grid; place-items: center; background: radial-gradient(ellipse at center, rgba(5, 8, 12, 0.55), rgba(5, 8, 12, 0.88)); }
  .term { position: relative; width: min(960px, 92vw); height: min(640px, 84vh); display: flex; flex-direction: column; overflow: hidden; background: rgba(8, 12, 18, 0.97); border-color: var(--line-3); }
  .term.crit { border-color: var(--danger-line); animation: alarm 0.9s ease-in-out infinite; }
  @keyframes alarm { 50% { box-shadow: 0 10px 40px rgba(255, 90, 82, 0.35); } }
  header { display: flex; align-items: center; gap: 18px; padding: 10px 14px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(245, 165, 36, 0.08), transparent); }
  .eye { width: 54px; height: 34px; color: var(--accent); flex: none; filter: drop-shadow(0 0 6px rgba(245, 165, 36, 0.5)); }
  .pupil { animation: look 6s ease-in-out infinite; }
  .iris { transform-origin: 32px 20px; animation: breathe 3s ease-in-out infinite; }
  @keyframes look { 0%, 100% { transform: translateX(0); } 30% { transform: translateX(5px); } 60% { transform: translateX(-5px); } }
  @keyframes breathe { 50% { transform: scale(1.08); } }
  .id { flex: 1; min-width: 0; }
  h1 { font-size: 15px; font-weight: 700; letter-spacing: 0.1em; text-transform: uppercase; color: var(--accent-2); }
  .id p { font-size: 11.5px; color: var(--muted); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .ward, .timer { display: flex; flex-direction: column; gap: 4px; align-items: flex-end; }
  .pips { display: flex; gap: 3px; }
  .pips i { width: 14px; height: 5px; border-radius: 2px; background: var(--line-3); }
  .pips i.on { background: var(--accent); }
  .big { font-size: 18px; font-weight: 600; line-height: 1; }
  .timer.low .big { color: var(--danger-text); }
  .x { width: 32px; height: 32px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--danger-text); border-color: var(--danger-line); background: var(--danger-bg); }
  .trace { display: flex; align-items: center; gap: 12px; padding: 8px 14px; border-bottom: 1px solid var(--line); }
  .meter { flex: 1; height: 8px; border-radius: 4px; background: var(--line-2); overflow: hidden; }
  .meter span { display: block; height: 100%; border-radius: 4px; transition: width 0.4s var(--ease); }
  .meter.low span { background: var(--info); }
  .meter.high span { background: var(--accent); }
  .meter.crit span { background: var(--danger); }
  .pct { width: 40px; text-align: right; font-size: 12px; }
  .screen { flex: 1; min-height: 0; padding: 12px 16px; font-family: var(--mono); font-size: 13px; line-height: 1.5; background: repeating-linear-gradient(0deg, rgba(255, 255, 255, 0.012) 0 1px, transparent 1px 3px); }
  .ln { white-space: pre-wrap; word-break: break-word; color: var(--text-2); user-select: text; }
  .ln.cmd { color: var(--text); }
  .ln.dim { color: var(--faint); }
  .ln.err { color: var(--danger-text); }
  .ln.ok { color: var(--ok-text); }
  .ln.warn { color: var(--warn-text); }
  .in { display: flex; gap: 8px; align-items: baseline; }
  .pr { color: var(--accent-2); white-space: nowrap; }
  .in input { flex: 1; min-width: 0; background: none; border: 0; padding: 0; outline: none; color: var(--text); font-family: var(--mono); font-size: 13px; caret-color: var(--accent); }
  .in.wait .pr { color: var(--faint); }
  .over { position: absolute; inset: 0; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 8px; background: rgba(6, 9, 14, 0.82); color: var(--text-2); animation: fade 0.25s var(--ease); }
  .over i { font-size: 30px; color: var(--muted); }
  .over strong { font-size: 17px; text-transform: uppercase; letter-spacing: 0.06em; color: var(--text); }
  .over.failed i, .over.failed strong { color: var(--danger-text); }
  @keyframes fade { from { opacity: 0; } }
  footer { display: flex; gap: 18px; padding: 7px 14px; border-top: 1px solid var(--line); font-size: 11px; color: var(--muted); }
</style>
