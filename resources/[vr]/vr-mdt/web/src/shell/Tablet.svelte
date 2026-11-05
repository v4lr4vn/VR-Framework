<script>
  import Topbar from './Topbar.svelte';
  import Sidebar from './Sidebar.svelte';
  import Toasts from '../components/Toasts.svelte';
  import Confirm from '../components/Confirm.svelte';
  import Spinner from '../components/Spinner.svelte';
  import Empty from '../components/Empty.svelte';
  import Button from '../components/Button.svelte';
  import { pages } from '../pages/index.js';
  import { routes } from '../routes.js';
  import { ui, session, can, close, go, loadSession, loadDispatch, loadRadio } from '../lib/state.svelte.js';
  import { errorText } from '../lib/lang.js';

  const allowed = $derived(routes.filter((r) => session.dept && r.depts.includes(session.dept.id) && can(r.perm)));
  const Page = $derived.by(() => {
    if (!session.ready) return null;
    const ok = allowed.find((r) => r.id === ui.route.page);
    return ok ? pages[ok.id] : null;
  });

  $effect(() => {
    if (session.ready && !allowed.some((r) => r.id === ui.route.page) && allowed.length) {
      go(allowed[0].id);
    }
  });

  async function retry() {
    const res = await loadSession();
    if (res.ok && ['police', 'ems', 'dispatch'].includes(session.dept?.id)) loadDispatch();
    if (res.ok && session.dept?.id === 'dispatch' && can('radio.multi')) loadRadio();
  }

  function key(e) {
    if (e.key !== 'Escape') return;
    if (document.querySelector('[aria-modal="true"]')) return;
    close();
  }
</script>

<svelte:window onkeydown={key} />

<div class="bezel" class:console={ui.console}>
  <div class="screen">
    {#if !session.ready && session.error}
      <div class="center">
        <Empty icon="lock" title="The MDT can't open" text={errorText(session.error)}>
          <div class="acts">
            <Button variant="ghost" onclick={close}>Close</Button>
            <Button icon="refresh" onclick={retry}>Try again</Button>
          </div>
        </Empty>
      </div>
    {:else if !session.ready}
      <div class="center"><Spinner label="Starting the MDT" /></div>
    {:else}
      <Topbar />
      <div class="main">
        <Sidebar routes={allowed} />
        <div class="content">
          {#key ui.route.page}
            {#if Page}
              <Page params={ui.route.params} />
            {:else}
              <Empty icon="lock" title="Nothing here" text="You don't have access to this section.">
                <Button onclick={() => go(allowed[0]?.id || 'bulletin')}>Go back</Button>
              </Empty>
            {/if}
          {/key}
        </div>
      </div>
    {/if}
    <Toasts />
    <Confirm />
  </div>
</div>

<style>
  .bezel { width: 100%; height: 100%; padding: 10px; border-radius: 22px; background: #05070A; box-shadow: 0 30px 80px rgba(0, 0, 0, 0.6), inset 0 0 0 1px #1A212C; }
  .screen { position: relative; width: 100%; height: 100%; border-radius: 14px; overflow: hidden; background: var(--bg); display: flex; flex-direction: column; }
  .bezel.console { padding: 0; border-radius: 0; box-shadow: none; background: var(--bg); }
  .bezel.console .screen { border-radius: 0; }
  .main { flex: 1; display: flex; min-height: 0; }
  .content { flex: 1; min-width: 0; display: flex; flex-direction: column; position: relative; }
  .center { flex: 1; display: flex; }
  .acts { display: flex; gap: 8px; justify-content: center; }
</style>
