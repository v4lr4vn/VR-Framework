<script>
  import Icon from '../../components/Icon.svelte';
  import Button from '../../components/Button.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import { radio, loadRadio, setListen, setTransmit, ptt, clock, dispatch } from '../../lib/state.svelte.js';

  let busy = $state(false);

  $effect(() => {
    if (!radio.loaded) loadRadio();
  });

  const deptLabel = { police: 'LSPD', ems: 'EMS', all: 'ALL' };
  const tx = $derived(radio.channels.find((c) => c.id === radio.transmit));

  const listening = (id) => radio.listen.includes(id) || radio.transmit === id;
  const talkers = (id) => Object.values(radio.talking[String(id)] || {});
  const unitsOn = (id) => dispatch.units.filter((u) => u.radio === id);

  async function toggle(c) {
    if (busy) return;
    busy = true;
    const next = radio.listen.includes(c.id) ? radio.listen.filter((x) => x !== c.id) : [...radio.listen, c.id];
    await setListen(next);
    busy = false;
  }

  async function transmit(c) {
    if (radio.transmit === c.id) return;
    await setTransmit(c.id);
    if (!radio.listen.includes(c.id)) await setListen([...radio.listen, c.id]);
  }

  async function defaults() {
    busy = true;
    await setListen(radio.defaults.listen || []);
    if (radio.defaults.transmit) await setTransmit(radio.defaults.transmit);
    busy = false;
  }

  function ago(at) {
    const s = Math.max(0, Math.round((clock.now * 1000 - at) / 1000));
    return s < 60 ? `${s}s ago` : `${Math.floor(s / 60)}m ago`;
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
      <h2>DISPATCH RADIO</h2>
      <p>Listen to as many channels as you need. You only talk on the one marked <b>TX</b>.</p>
    </div>
    <span class="grow"></span>
    <Button icon="refresh" variant="ghost" busy={busy} onclick={defaults}>Default channels</Button>
  </header>

  {#if !radio.loaded}
    <Spinner />
  {:else if !radio.voice}
    <Empty icon="headphones" title="Voice isn't running" text="vr-voice needs to be started for the dispatch radio." />
  {:else}
    <div class="grid scroll">
      {#each radio.channels as c (c.id)}
        {@const on = listening(c.id)}
        {@const live = talkers(c.id)}
        <article class="ch" class:on class:tx={radio.transmit === c.id} class:live={live.length > 0}>
          <div class="row">
            <span class="num mono">CH {c.id}</span>
            <span class="dept mono {c.dept}">{deptLabel[c.dept] || c.dept}</span>
            <span class="grow"></span>
            {#if radio.transmit === c.id}<span class="txb mono">TX</span>{/if}
          </div>
          <h3>{c.label}</h3>
          <div class="now">
            {#if live.length}
              <span class="talk"><span class="dot"></span>{live.join(', ')}</span>
            {:else if radio.last[String(c.id)]}
              <span class="last">Last: {radio.last[String(c.id)].name} · {ago(radio.last[String(c.id)].at)}</span>
            {:else}
              <span class="last">{on ? 'Quiet' : 'Not listening'}</span>
            {/if}
          </div>
          {#if unitsOn(c.id).length}
            <div class="units">
              {#each unitsOn(c.id) as u (u.cid)}<span class="u mono" class:ems={u.dept === 'ems'}>{u.callsign || u.name}</span>{/each}
            </div>
          {/if}
          <div class="acts">
            <button class="b" class:sel={on} disabled={busy || radio.transmit === c.id} onclick={() => toggle(c)} aria-pressed={on}>
              <Icon name="headphones" size={15} />{on ? 'Listening' : 'Listen'}
            </button>
            <button class="b" class:sel={radio.transmit === c.id} onclick={() => transmit(c)} aria-pressed={radio.transmit === c.id}>
              <Icon name="broadcast" size={15} />{radio.transmit === c.id ? 'Transmitting' : 'Talk here'}
            </button>
          </div>
        </article>
      {/each}
    </div>

    <footer class:hot={radio.ptt || radio.self}>
      <div class="txinfo">
        <span class="eyebrow">Transmit channel</span>
        <span class="tx mono">{tx ? `CH ${tx.id} · ${tx.label}` : 'None selected'}</span>
      </div>
      <button class="ptt" class:hot={radio.ptt || radio.self} disabled={!tx} onpointerdown={down} onpointerup={() => ptt(false)} onpointerleave={() => ptt(false)}>
        <Icon name="mic" size={22} />
        <span>{radio.ptt || radio.self ? 'Talking…' : 'Hold to talk'}</span>
      </button>
      <p class="hint">Your <b>Talk on the radio</b> key works here too, if it's on a key like Caps Lock, Alt or an F-key.</p>
    </footer>
  {/if}
</div>

<style>
  .radio { flex: 1; min-height: 0; display: flex; flex-direction: column; }
  header { display: flex; align-items: center; gap: 12px; padding: 16px 20px 12px; border-bottom: 1px solid var(--line); }
  h2 { font-size: 15px; font-weight: 700; letter-spacing: 0.06em; }
  .t p { color: var(--muted); font-size: 13px; margin-top: 2px; }
  .t b { color: var(--accent-2); font-family: var(--mono); }
  .grow { flex: 1; }
  .grid { flex: 1; min-height: 0; display: grid; grid-template-columns: repeat(auto-fill, minmax(260px, 1fr)); align-content: start; gap: 12px; padding: 16px 20px; }
  .ch { display: flex; flex-direction: column; gap: 8px; padding: 14px; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: var(--panel); transition: border-color 0.15s, box-shadow 0.15s; }
  .ch.on { border-color: var(--line-3); background: var(--panel-2); }
  .ch.tx { border-color: var(--accent); }
  .ch.live { box-shadow: 0 0 0 1px var(--ok), 0 0 24px rgba(61, 214, 140, 0.18); }
  .row { display: flex; align-items: center; gap: 8px; }
  .num { font-size: 12px; color: var(--muted); font-weight: 600; }
  .dept { font-size: 10px; letter-spacing: 0.1em; padding: 2px 6px; border-radius: 4px; background: var(--panel-3); color: var(--text-2); }
  .dept.police { background: var(--info-bg); color: var(--info-text); }
  .dept.ems { background: var(--ems-bg); color: var(--ems-text); }
  .txb { font-size: 10px; letter-spacing: 0.12em; font-weight: 700; padding: 2px 6px; border-radius: 4px; background: var(--accent); color: var(--accent-ink); }
  h3 { font-size: 18px; font-weight: 700; }
  .now { min-height: 20px; font-size: 13px; }
  .talk { display: inline-flex; align-items: center; gap: 8px; color: var(--ok); font-weight: 600; }
  .dot { width: 8px; height: 8px; border-radius: 50%; background: var(--ok); animation: pulse 0.9s infinite; }
  @keyframes pulse { 50% { opacity: 0.3; } }
  .last { color: var(--faint); }
  .acts { display: flex; gap: 8px; }
  .units { display: flex; flex-wrap: wrap; gap: 4px; }
  .u { font-size: 11px; padding: 2px 6px; border-radius: 4px; background: var(--info-bg); color: var(--info-text); }
  .u.ems { background: var(--ems-bg); color: var(--ems-text); }
  .b { flex: 1; height: 34px; display: inline-flex; align-items: center; justify-content: center; gap: 6px; border-radius: var(--radius); border: 1px solid var(--line-3); background: transparent; color: var(--text-2); font-weight: 600; font-size: 13px; }
  .b:hover:not(:disabled) { background: var(--panel-3); color: var(--text); }
  .b.sel { background: var(--accent-soft); border-color: var(--accent-line); color: var(--text); }
  .b:disabled { opacity: 0.6; }
  footer { display: flex; align-items: center; gap: 20px; padding: 14px 20px; border-top: 1px solid var(--line); background: var(--bg-2); transition: background 0.15s; }
  footer.hot { background: linear-gradient(90deg, rgba(61, 214, 140, 0.12), transparent 60%), var(--bg-2); }
  .txinfo { display: flex; flex-direction: column; gap: 2px; min-width: 220px; }
  .tx { font-size: 15px; font-weight: 600; color: var(--accent-2); }
  .ptt { height: 54px; min-width: 240px; display: inline-flex; align-items: center; justify-content: center; gap: 10px; border-radius: 27px; border: 2px solid var(--accent-line); background: var(--panel-2); color: var(--text); font-size: 16px; font-weight: 700; letter-spacing: 0.04em; user-select: none; }
  .ptt:hover:not(:disabled) { border-color: var(--accent); }
  .ptt.hot { background: var(--ok-bg); border-color: var(--ok); color: var(--ok-text); }
  .ptt:disabled { opacity: 0.5; }
  .hint { color: var(--faint); font-size: 12px; max-width: 360px; }
  .hint b { color: var(--text-2); }
</style>
