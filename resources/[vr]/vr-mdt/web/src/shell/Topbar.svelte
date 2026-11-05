<script>
  import Icon from '../components/Icon.svelte';
  import IconButton from '../components/IconButton.svelte';
  import StatusMenu from './StatusMenu.svelte';
  import GlobalSearch from './GlobalSearch.svelte';
  import { session, close, clock, radio, ui, go, can } from '../lib/state.svelte.js';
  import { initials, time } from '../lib/format.js';

  const responder = $derived(['police', 'ems'].includes(session.dept?.id));
  const deptTone = $derived(session.dept?.id === 'ems' ? 'var(--ems)' : session.dept?.id === 'doj' ? 'var(--doj)' : session.dept?.id === 'dispatch' ? 'var(--ok)' : 'var(--accent)');
  const dispatcher = $derived(session.dept?.id === 'dispatch');
  const txChannel = $derived(radio.channels.find((c) => c.id === radio.transmit));
  const anyTalk = $derived(Object.values(radio.talking).some((l) => Object.keys(l || {}).length > 0));
</script>

<header class="top">
  <div class="brand">
    <span class="logo" style:color={deptTone}><Icon name="shield" size={22} /></span>
    <div class="names">
      <span class="title">VALRAVN MDT</span>
      <span class="dept">{session.dept?.label}</span>
    </div>
  </div>

  <GlobalSearch />

  <div class="spacer"></div>

  {#if responder}
    <button type="button" class="radiochip" class:live={anyTalk} class:me={radio.self || radio.ptt} onclick={() => go('radio')}>
      <Icon name={radio.self || radio.ptt ? 'mic' : 'headphones'} size={15} />
      <span class="mono">{radio.transmit ? `CH ${radio.transmit}` : 'RADIO OFF'}</span>
      {#if txChannel}<span class="n">{txChannel.label}</span>{/if}
    </button>
    <StatusMenu />
  {/if}
  {#if dispatcher}
    {#if ui.console}<span class="console mono"><Icon name="desk" size={14} />CONSOLE</span>{/if}
    {#if can('radio.multi')}
      <button type="button" class="radiochip" class:live={anyTalk} class:me={radio.self || radio.ptt} onclick={() => go('radio')}>
        <Icon name={radio.self || radio.ptt ? 'mic' : 'headphones'} size={15} />
        <span class="mono">{txChannel ? `TX CH ${txChannel.id}` : 'NO TX'}</span>
        <span class="n mono">{radio.listen.length} listening</span>
      </button>
    {/if}
  {/if}

  <div class="me">
    <div class="avatar" style:color={deptTone}>{initials(session.me?.name)}</div>
    <div class="who">
      <span class="callsign mono">{session.me?.callsign || session.me?.jobLabel}</span>
      <span class="sub">{session.me?.name} · {session.me?.gradeName}</span>
    </div>
  </div>

  <span class="clock mono">{time(clock.now)}</span>
  <IconButton icon="x" label="Close the MDT" size={34} onclick={close} />
</header>

<style>
  .top { height: 56px; flex: none; display: flex; align-items: center; gap: 20px; padding: 0 12px 0 18px; border-bottom: 1px solid var(--line); background: var(--bg-2); }
  .brand { display: flex; align-items: center; gap: 10px; width: 206px; flex: none; }
  .names { display: flex; flex-direction: column; line-height: 1.1; min-width: 0; }
  .title { font-weight: 700; letter-spacing: 0.08em; font-size: 15px; }
  .dept { color: var(--muted); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .spacer { flex: 1; }
  .me { display: flex; align-items: center; gap: 10px; padding-left: 16px; border-left: 1px solid var(--line); }
  .avatar { width: 34px; height: 34px; border-radius: var(--radius); background: var(--panel-2); display: flex; align-items: center; justify-content: center; font-weight: 700; }
  .who { display: flex; flex-direction: column; line-height: 1.15; }
  .callsign { font-weight: 600; }
  .sub { color: var(--muted); font-size: 12px; }
  .clock { font-size: 15px; font-weight: 500; padding: 0 4px; }
  .console { display: inline-flex; align-items: center; gap: 6px; height: 28px; padding: 0 10px; border-radius: 14px; border: 1px solid var(--ok-line); background: var(--ok-bg); color: var(--ok-text); font-size: 11px; letter-spacing: 0.12em; font-weight: 600; }
  .radiochip { display: inline-flex; align-items: center; gap: 8px; height: 34px; padding: 0 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: var(--text-2); font-size: 12px; font-weight: 600; }
  .radiochip:hover { border-color: var(--line-3); color: var(--text); }
  .radiochip .n { color: var(--faint); font-weight: 500; }
  .radiochip.live { border-color: var(--ok); box-shadow: 0 0 12px rgba(61, 214, 140, 0.2); }
  .radiochip.me { border-color: var(--ok); background: var(--ok-bg); color: var(--ok-text); }
</style>
