<script>
  import Icon from '../../components/Icon.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import { radio, loadRadio, joinChannel, leaveChannel, ptt, session } from '../../lib/state.svelte.js';

  let busy = $state(false);

  $effect(() => {
    if (!radio.loaded) loadRadio();
  });

  const deptLabel = { police: 'LSPD', ems: 'EMS', all: 'ALL' };
  const current = $derived(radio.channels.find((c) => c.id === radio.transmit));
  const live = $derived(radio.talking[String(radio.transmit)] || {});

  async function join(c) {
    if (busy || radio.transmit === c.id) return;
    busy = true;
    await joinChannel(c.id);
    busy = false;
  }

  async function leave() {
    busy = true;
    await leaveChannel();
    busy = false;
  }

  function down(e) {
    if (e.button !== 0) return;
    e.preventDefault();
    ptt(true);
  }
</script>

<svelte:window onpointerup={() => ptt(false)} onblur={() => ptt(false)} />

<div class="radio">
  <header>
    <div class="t">
      <h2>RADIO</h2>
      <p>Your MDT doubles as a radio. Dispatch can move you between channels.</p>
    </div>
  </header>

  {#if !radio.loaded}
    <Spinner />
  {:else if !radio.voice}
    <Empty icon="headphones" title="Voice isn't running" text="vr-voice needs to be started for the radio." />
  {:else}
    <div class="body scroll">
      <section class="now" class:on={!!current} class:hot={radio.self || radio.ptt}>
        <div class="row">
          <span class="eyebrow">You are on</span>
          <span class="grow"></span>
          {#if current}<button class="leave" disabled={busy} onclick={leave}><Icon name="x" size={14} />Leave</button>{/if}
        </div>
        {#if current}
          <div class="big">
            <span class="num mono">CH {current.id}</span>
            <span class="lbl">{current.label}</span>
          </div>
        {:else if radio.transmit}
          <div class="big"><span class="num mono">CH {radio.transmit}</span><span class="lbl muted">Not a department channel</span></div>
        {:else}
          <div class="big"><span class="lbl muted">Off the radio</span></div>
        {/if}
        <button class="ptt" class:hot={radio.self || radio.ptt} disabled={!radio.transmit} onpointerdown={down} onpointerup={() => ptt(false)} onpointerleave={() => ptt(false)}>
          <Icon name="mic" size={20} />
          <span>{radio.ptt || radio.self ? 'Talking…' : 'Hold to talk'}</span>
        </button>
      </section>

      {#if current}
        <section class="people">
          <span class="eyebrow">On this channel · {radio.members.length}</span>
          <div class="list">
            {#each radio.members as m (m.src)}
              <span class="who" class:talk={!!live[m.src]} class:ems={m.dept === 'ems'} class:disp={m.dept === 'dispatch'}>
                {#if live[m.src]}<span class="dot"></span>{/if}{m.name}
              </span>
            {:else}
              <span class="muted">Nobody else yet.</span>
            {/each}
          </div>
        </section>
      {/if}

      <section>
        <span class="eyebrow">Channels</span>
        <div class="grid">
          {#each radio.channels as c (c.id)}
            <button class="ch" class:sel={radio.transmit === c.id} disabled={busy} onclick={() => join(c)} aria-pressed={radio.transmit === c.id}>
              <span class="r1"><span class="mono n">CH {c.id}</span><span class="dept mono {c.dept}">{deptLabel[c.dept] || c.dept}</span></span>
              <span class="l">{c.label}</span>
              <span class="act">{radio.transmit === c.id ? 'Connected' : 'Join'}</span>
            </button>
          {/each}
        </div>
      </section>
      <p class="hint">Your <b>Talk on the radio</b> key works too. The <b>{session.dept?.id === 'ems' ? 'EMS' : 'Police'}</b> page of your radial menu has the same channels.</p>
    </div>
  {/if}
</div>

<style>
  .radio { flex: 1; min-height: 0; display: flex; flex-direction: column; }
  header { display: flex; align-items: center; gap: 12px; padding: 16px 20px 12px; border-bottom: 1px solid var(--line); }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; }
  .t p { color: var(--muted); font-size: 13px; margin-top: 2px; }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 18px; padding: 16px 20px; }
  section { display: flex; flex-direction: column; gap: 10px; }
  .grow { flex: 1; }
  .now { padding: 16px; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: var(--panel); gap: 12px; }
  .now.on { border-color: var(--accent-line); }
  .now.hot { border-color: var(--ok); box-shadow: 0 0 24px rgba(61, 214, 140, 0.15); }
  .row { display: flex; align-items: center; }
  .big { display: flex; align-items: baseline; gap: 12px; }
  .big .num { font-size: 28px; font-weight: 700; color: var(--accent-2); }
  .big .lbl { font-size: 20px; font-weight: 700; }
  .muted { color: var(--faint); }
  .leave { display: inline-flex; align-items: center; gap: 6px; height: 30px; padding: 0 10px; border-radius: var(--radius); border: 1px solid var(--line-3); background: transparent; color: var(--text-2); font-weight: 600; font-size: 12px; }
  .leave:hover:not(:disabled) { color: var(--text); background: var(--panel-3); }
  .ptt { align-self: flex-start; height: 48px; min-width: 220px; display: inline-flex; align-items: center; justify-content: center; gap: 10px; border-radius: 24px; border: 2px solid var(--accent-line); background: var(--panel-2); color: var(--text); font-size: 15px; font-weight: 700; user-select: none; }
  .ptt:hover:not(:disabled) { border-color: var(--accent); }
  .ptt.hot { background: var(--ok-bg); border-color: var(--ok); color: var(--ok-text); }
  .ptt:disabled { opacity: 0.5; }
  .list { display: flex; flex-wrap: wrap; gap: 6px; }
  .who { display: inline-flex; align-items: center; gap: 6px; height: 28px; padding: 0 10px; border-radius: 14px; background: var(--info-bg); color: var(--info-text); font-family: var(--mono); font-size: 12px; font-weight: 600; }
  .who.ems { background: var(--ems-bg); color: var(--ems-text); }
  .who.disp { background: var(--ok-bg); color: var(--ok-text); }
  .who.talk { box-shadow: 0 0 0 1px var(--ok); }
  .dot { width: 7px; height: 7px; border-radius: 50%; background: var(--ok); animation: pulse 0.9s infinite; }
  @keyframes pulse { 50% { opacity: 0.3; } }
  .grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(200px, 1fr)); gap: 10px; }
  .ch { display: flex; flex-direction: column; align-items: flex-start; gap: 6px; padding: 12px; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: var(--panel); color: var(--text); text-align: left; }
  .ch:hover:not(:disabled) { border-color: var(--line-3); background: var(--panel-2); }
  .ch.sel { border-color: var(--accent); background: var(--accent-soft); }
  .r1 { display: flex; gap: 8px; align-items: center; }
  .n { font-size: 12px; color: var(--muted); font-weight: 600; }
  .dept { font-size: 10px; letter-spacing: 0.1em; padding: 2px 6px; border-radius: 4px; background: var(--panel-3); color: var(--text-2); }
  .dept.police { background: var(--info-bg); color: var(--info-text); }
  .dept.ems { background: var(--ems-bg); color: var(--ems-text); }
  .l { font-size: 16px; font-weight: 700; }
  .act { font-size: 12px; color: var(--accent-2); font-weight: 600; }
  .ch:not(.sel) .act { color: var(--muted); }
  .hint { color: var(--faint); font-size: 12px; }
  .hint b { color: var(--text-2); }
</style>
