<script>
  import LockScreen from './LockScreen.svelte';
  import Home from './Home.svelte';
  import AppHost from './AppHost.svelte';
  import StatusBar from './StatusBar.svelte';
  import NavBar from './NavBar.svelte';
  import ToastLayer from './ToastLayer.svelte';
  import QuickPanel from './QuickPanel.svelte';
  import PoweredOff from './PoweredOff.svelte';
  import ShareSheet from './ShareSheet.svelte';
  import ShareRequest from './ShareRequest.svelte';
  import CallScreen from './CallScreen.svelte';
  import { comms } from '../lib/comms.svelte.js';
  import { phone } from '../lib/store.svelte.js';
  import { lightWallpapers } from '../lib/wallpapers.js';

  // Chooses what the screen shows: the lock screen, then an app or the home screen.
  // The closed phone (cover) and the open one use the same screens. Each one lays itself out for the fold state.
  // An empty battery turns all of it off. The quick panel sits on top of whatever is showing.
  const dead = $derived(!phone.status.powered || phone.booting);
  const onWallpaper = $derived(phone.locked || !phone.app);
  const wp = $derived(phone.locked ? phone.settings.wallpaper.lock : phone.settings.wallpaper.home);
  // The call screen is dark, so the bar is white on top of it.
  const onCall = $derived(comms.call !== null && !comms.call.minimized);
  const barInk = $derived(
    phone.panel ? 'var(--ink)' : onCall ? '#ffffff' : onWallpaper ? (lightWallpapers[wp] ? '#17142a' : '#ffffff') : 'var(--ink)',
  );
</script>

<div class="layer" style:--bar-ink={barInk}>
  {#if dead}
    <PoweredOff />
  {:else}
    {#if phone.locked}
      <LockScreen />
    {:else if phone.app}
      <AppHost id={phone.app} />
    {:else}
      <Home />
    {/if}
    <CallScreen />
    {#if !phone.locked}<ShareSheet />{/if}
    <ShareRequest />
    <QuickPanel />
    <StatusBar />
    {#if !phone.locked}<NavBar />{/if}
    <ToastLayer />
  {/if}
</div>

<style>
  .layer {
    position: absolute;
    inset: 0;
  }
</style>
