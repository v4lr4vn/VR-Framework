<script>
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Icon from '../../components/Icon.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import { callback } from '../../lib/nui.js';
  import { request, toast } from '../../lib/state.svelte.js';
  import { errorText } from '../../lib/lang.js';
  import { confirm } from '../../lib/confirm.svelte.js';

  let { cameras = null, error = '', canManage = false, filter = '', onchanged, onretry } = $props();

  let opening = $state(null);

  const shown = $derived.by(() => {
    if (!cameras) return [];
    const term = filter.trim().toLowerCase();
    return term ? cameras.filter((c) => `${c.label} ${c.location}`.toLowerCase().includes(term)) : cameras;
  });

  const groups = $derived.by(() => {
    const map = new Map();
    for (const c of shown) {
      if (!map.has(c.location)) map.set(c.location, []);
      map.get(c.location).push(c);
    }
    return [...map.entries()].map(([name, list]) => ({ name, list }));
  });

  async function view(cam) {
    if (opening) return;
    opening = cam.id;
    const res = await callback('viewCamera', { id: cam.id, list: shown.map((c) => c.id) });
    opening = null;
    if (!res || !res.ok) toast(errorText(res?.error || 'no_camera'), 'error');
  }

  async function remove(cam) {
    const ok = await confirm({ title: 'Remove this camera?', text: `"${cam.label}" in ${cam.location} will be taken offline for everyone.`, yes: 'Remove camera', danger: true });
    if (!ok) return;
    const res = await request('cameras.remove', { id: cam.id }, { success: 'Camera removed' });
    if (res.ok) onchanged?.();
  }

  const pad = (n) => String(n).padStart(3, '0');
</script>

{#if error}
  <Empty icon="alert" title="Couldn't load cameras" text="Try again in a moment.">
    <Button icon="refresh" onclick={onretry}>Retry</Button>
  </Empty>
{:else if !cameras}
  <Spinner label="Loading cameras" />
{:else if !shown.length}
  <Empty icon="cctv" title={filter ? 'No matching cameras' : 'No cameras yet'} text={filter ? `Nothing matches "${filter}".` : canManage ? 'Add one from where you stand with "Add camera".' : 'Ask a lieutenant or above to add security cameras.'} />
{:else}
  {#each groups as g (g.name)}
    <section class="group" aria-label={g.name}>
      <h2 class="eyebrow">{g.name} · {g.list.length}</h2>
      <div class="grid">
        {#each g.list as c (c.id)}
          <article class="card">
            <button type="button" class="feed" aria-label="View {c.label}" disabled={opening != null} onclick={() => view(c)}>
              <span class="tag mono">CAM {pad(c.id)}</span>
              <span class="rec mono"><i></i>LIVE</span>
              <span class="play">{#if opening === c.id}<span class="spin" aria-hidden="true"></span>{:else}<Icon name="play" size={18} />{/if}</span>
              <span class="hdg mono">{Math.round(c.heading)}° · FOV {Math.round(c.fov)}°</span>
            </button>
            <div class="info">
              <div class="txt">
                <span class="label">{c.label}</span>
                <span class="pos mono">{Math.round(c.x)}, {Math.round(c.y)}, {Math.round(c.z)}</span>
              </div>
              {#if canManage}
                <IconButton icon="trash" label="Remove {c.label}" size={30} variant="danger" onclick={() => remove(c)} />
              {/if}
            </div>
          </article>
        {/each}
      </div>
    </section>
  {/each}
{/if}

<style>
  .group { display: flex; flex-direction: column; gap: 8px; }
  .grid { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 12px; }
  .card { display: flex; flex-direction: column; border-radius: var(--radius-lg); border: 1px solid var(--line-2); background: var(--panel); overflow: hidden; min-width: 0; }
  .card:hover { border-color: var(--line-3); }
  .feed { position: relative; height: 112px; border: 0; padding: 0; color: var(--text); background:
    repeating-linear-gradient(to bottom, rgba(255, 255, 255, 0.025) 0 1px, transparent 1px 3px),
    radial-gradient(ellipse at 50% 60%, #1B2738 0%, #0D141F 70%, #090D14 100%); }
  .feed:hover .play { background: var(--accent); color: var(--accent-ink); border-color: var(--accent); }
  .feed:focus-visible { outline-offset: -2px; }
  .tag { position: absolute; left: 8px; top: 8px; font-size: 11px; padding: 1px 6px; border-radius: 3px; background: rgba(10, 14, 20, 0.75); color: var(--text-2); }
  .rec { position: absolute; right: 8px; top: 8px; display: inline-flex; align-items: center; gap: 5px; font-size: 11px; color: var(--p1-text); }
  .rec i { width: 7px; height: 7px; border-radius: 50%; background: var(--p1); }
  .play { position: absolute; left: 50%; top: 50%; transform: translate(-50%, -50%); width: 40px; height: 40px; border-radius: 50%; display: flex; align-items: center; justify-content: center; background: rgba(10, 14, 20, 0.7); border: 1px solid var(--line-3); color: var(--text); transition: background 0.12s, color 0.12s; }
  .hdg { position: absolute; left: 8px; bottom: 7px; font-size: 11px; color: var(--muted); }
  .spin { width: 16px; height: 16px; border-radius: 50%; border: 2px solid currentColor; border-right-color: transparent; animation: r 0.7s linear infinite; }
  @keyframes r { to { transform: rotate(360deg); } }
  .info { display: flex; align-items: center; gap: 8px; padding: 9px 8px 10px 12px; }
  .txt { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 1px; }
  .label { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pos { color: var(--faint); font-size: 11px; }
</style>
