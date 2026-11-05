<script>
  import { onMount } from 'svelte';
  import Device from './ui/Device.svelte';
  import ToastLayer from './ui/ToastLayer.svelte';
  import { on } from './lib/nui.js';
  import { inkOn, shade, hexToRgb } from './lib/color.js';
  import { reduced } from './lib/motion.js';
  import {
    phone,
    tick,
    pcTick,
    openPhone,
    hidePhone,
    closePhone,
    openApp,
    goHome,
    goBack,
    closePanel,
    setStatus,
    applySettingsPatch,
    syncSound,
    setClock,
    setTyping,
    pushNotification,
    receiveMessage,
  } from './lib/store.svelte.js';
  import { onCall, backFromCall } from './lib/comms.svelte.js';
  import CallPill from './ui/CallPill.svelte';
  import AppHost from './ui/AppHost.svelte';
  import { fullscreenApps } from './lib/apps.js';
  import { comms } from './lib/comms.svelte.js';
  import { onShareIncoming, onShareResult, onShareClosed } from './lib/media.svelte.js';

  // Messages from the game.
  on('open', openPhone);
  on('close', hidePhone);
  on('clock', setClock);
  on('notify', pushNotification);
  on('status', setStatus);
  on('settings', applySettingsPatch);
  on('call', onCall);
  on('message', receiveMessage);
  on('share', onShareIncoming);
  on('shareClosed', onShareClosed);
  on('shareResult', (r) => {
    onShareResult(r);
    if (!r || typeof r.state !== 'string') return;
    pushNotification({
      id: `share-${r.id}`,
      app: 'system',
      titleKey: `share.result.${r.state}`,
      messageKey: `share.resultText.${r.state}`,
      data: { name: String(r.name ?? ''), n: Number(r.count) || 0 },
    });
  });
  on('openApp', (id) => {
    if (typeof id === 'string') openApp(id);
  });

  // The accent colour comes from the settings, so every shade of it is worked out here.
  const accent = $derived(phone.settings.theme.accent || '#7a5cff');
  const style = $derived(
    [
      `--accent:${accent}`,
      `--accent-rgb:${hexToRgb(accent).join(', ')}`,
      `--accent-light:${shade(accent, 0.22)}`,
      `--accent-dark:${shade(accent, -0.22)}`,
      `--on-accent:${inkOn(accent)}`,
    ].join(';'),
  );
  const dark = $derived(phone.settings.theme.dark);
  const still = $derived(reduced());
  // An app like the Camera fills the game view, so the phone body steps aside while it is open.
  const full = $derived(
    phone.visible && !phone.locked && phone.status.powered && !phone.booting && phone.app !== null && fullscreenApps.has(phone.app),
  );

  // A call coming in ends the full screen app, so the call screen is not hidden behind it.
  $effect(() => {
    if (full && comms.call !== null) goHome();
  });

  // The sound player follows the sound settings and silent mode.
  $effect(() => {
    syncSound();
  });

  function onkey(e) {
    if (!phone.visible || e.key !== 'Escape') return;
    e.preventDefault();
    if (phone.panel) closePanel();
    else if (backFromCall()) return;
    else if (phone.app && !phone.locked) goBack();
    else closePhone();
  }

  // While a text box has focus, the game must not read keys as movement.
  function focusin(e) {
    const el = e.target;
    if (el && (el.tagName === 'TEXTAREA' || (el.tagName === 'INPUT' && el.type !== 'range'))) setTyping(true);
  }
  function focusout(e) {
    const el = e.target;
    if (el && (el.tagName === 'TEXTAREA' || (el.tagName === 'INPUT' && el.type !== 'range'))) setTyping(false);
  }

  onMount(() => {
    const id = setInterval(() => (tick.now = Date.now()), 5000);
    const second = setInterval(() => (pcTick.now = Date.now()), 1000);
    return () => {
      clearInterval(id);
      clearInterval(second);
    };
  });
</script>

<svelte:window onkeydown={onkey} onfocusin={focusin} onfocusout={focusout} />

<div class="root {dark ? 'theme-dark' : 'theme-light'}" class:reduce={still} {style}>
  {#if full}
    <AppHost id={phone.app} bare />
  {:else if phone.visible}
    <Device />
  {:else}
    <CallPill />
    <ToastLayer floating />
  {/if}
</div>

<style>
  .root {
    position: fixed;
    inset: 0;
    pointer-events: none;
    font-family: var(--font);
    color: var(--ink);
  }
</style>
