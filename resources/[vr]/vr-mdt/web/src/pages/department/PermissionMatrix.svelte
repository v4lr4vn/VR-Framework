<script>
  import { untrack } from 'svelte';
  import Button from '../../components/Button.svelte';
  import Icon from '../../components/Icon.svelte';
  import Empty from '../../components/Empty.svelte';
  import Spinner from '../../components/Spinner.svelte';
  import Segmented from './Segmented.svelte';
  import { request, session } from '../../lib/state.svelte.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { on } from '../../lib/nui.js';

  let data = $state(null);
  let job = $state('');
  let loading = $state(true);
  let failed = $state(false);
  let busy = $state('');

  async function load(quiet = false) {
    if (!quiet) loading = true;
    const res = await request('permissions.get', job ? { job } : {}, { quiet: true });
    loading = false;
    failed = !res.ok;
    if (res.ok) {
      data = res.data;
      job = res.data.job;
    }
  }

  $effect(() => {
    untrack(() => load());
    return on('permissions:changed', (p) => {
      if (p?.job === job) load(true);
    });
  });

  const jobOptions = $derived((data?.jobs || []).map((j) => ({ value: j.name, label: j.label })));

  function lowerFirst(s) {
    return s ? s[0].toLowerCase() + s.slice(1) : s;
  }

  function selfLock(perm, g) {
    return perm.key === 'permissions.manage' && g.mine && !session.me?.isboss;
  }

  async function toggle(perm, i) {
    const g = data.grades[i];
    const cell = perm.cells[i];
    if (cell.locked || busy || selfLock(perm, g)) return;
    const allowed = !cell.allowed;
    busy = `${perm.key}:${g.level}`;
    const res = await request('permissions.set', { job: data.job, grade: g.level, perm: perm.key, allowed }, { success: `${g.name} ${allowed ? 'can now' : 'can no longer'} ${lowerFirst(perm.label)}` });
    busy = '';
    if (res.ok) data = res.data;
  }

  async function reset(g) {
    const ok = await confirm({ title: `Reset ${g.name}?`, text: `${g.changes} change${g.changes === 1 ? '' : 's'} for ${g.name} will go back to the defaults. Members of this rank get the new permissions right away.`, yes: 'Reset', danger: true });
    if (!ok) return;
    busy = `reset:${g.level}`;
    const res = await request('permissions.reset', { job: data.job, grade: g.level }, { success: `${g.name} reset to defaults` });
    busy = '';
    if (res.ok) data = res.data;
  }

  function pickJob(name) {
    job = name;
    load();
  }
</script>

<div class="wrap">
  <div class="toolbar">
    {#if jobOptions.length > 1}
      <Segmented options={jobOptions} value={job} label="Job" onchange={pickJob} />
    {:else if data}
      <span class="job">{data.jobLabel}</span>
    {/if}
    <div class="legend" aria-hidden="true">
      <span><i class="sw on"><Icon name="check" size={10} stroke={3} /></i>Allowed</span>
      <span><i class="sw"></i>Not allowed</span>
      <span><i class="sw ch"></i>Changed from default</span>
      <span><i class="sw lk"><Icon name="lock" size={10} /></i>Command rank, always allowed</span>
    </div>
    <span class="grow"></span>
    <p class="note">Changes apply to everyone of that rank on their next action.</p>
  </div>

  <div class="scroller scroll">
    {#if loading && !data}
      <Spinner label="Loading permissions" />
    {:else if failed && !data}
      <Empty icon="alert" title="Couldn't load permissions">
        <Button icon="refresh" onclick={() => load()}>Try again</Button>
      </Empty>
    {:else if data}
      <table style:--cols={data.grades.length}>
        <thead>
          <tr>
            <th class="perm">Permission</th>
            {#each data.grades as g}
              <th class="g" class:boss={g.isboss}>
                <span class="gn">{g.name}</span>
                <span class="gl mono">
                  {#if g.isboss}<Icon name="lock" size={10} />Command{:else}Grade {g.level}{/if}
                  {#if g.mine}<span class="you">You</span>{/if}
                </span>
              </th>
            {/each}
          </tr>
        </thead>
        <tbody>
          {#each data.groups as group}
            <tr class="grp"><td colspan={data.grades.length + 1}><span class="eyebrow">{group.name}</span></td></tr>
            {#each group.perms as perm (perm.key)}
              <tr class="row">
                <td class="perm">
                  <span class="pl">{perm.label}</span>
                  <span class="pk mono">{perm.key}</span>
                </td>
                {#each perm.cells as cell, i}
                  {@const g = data.grades[i]}
                  {@const locked = cell.locked || selfLock(perm, g)}
                  <td class="cellwrap" class:bosscol={g.isboss}>
                    <button
                      type="button"
                      class="cell"
                      class:on={cell.allowed}
                      class:ch={cell.overridden}
                      class:lk={cell.locked}
                      class:busy={busy === `${perm.key}:${g.level}`}
                      aria-pressed={cell.allowed}
                      aria-label="{perm.label} for {g.name}"
                      title={cell.locked ? 'Command ranks always have every permission' : selfLock(perm, g) ? "You can't remove this from your own rank" : cell.overridden ? `Changed. Default: ${cell.default ? 'allowed' : 'not allowed'}` : ''}
                      disabled={locked}
                      onclick={() => toggle(perm, i)}
                    >
                      {#if cell.locked}<Icon name="lock" size={11} />{:else if cell.allowed}<Icon name="check" size={13} stroke={3} />{/if}
                    </button>
                  </td>
                {/each}
              </tr>
            {/each}
          {/each}
        </tbody>
        <tfoot>
          <tr>
            <td class="perm"><span class="faint">Reset a rank to the default permissions</span></td>
            {#each data.grades as g}
              <td class="cellwrap">
                {#if !g.isboss}
                  <Button size="sm" variant="ghost" icon="rotate" busy={busy === `reset:${g.level}`} disabled={!g.changes || (g.mine && !session.me?.isboss)} onclick={() => reset(g)}>
                    {g.changes ? `Reset ${g.changes}` : 'Default'}
                  </Button>
                {/if}
              </td>
            {/each}
          </tr>
        </tfoot>
      </table>
    {/if}
  </div>
</div>

<style>
  .wrap { flex: 1; min-height: 0; display: flex; flex-direction: column; }
  .toolbar { display: flex; align-items: center; gap: 18px; padding: 14px 24px 12px; }
  .job { font-weight: 600; color: var(--text); }
  .legend { display: flex; align-items: center; gap: 14px; color: var(--muted); font-size: 12px; }
  .legend span { display: inline-flex; align-items: center; gap: 6px; }
  .sw { width: 16px; height: 16px; border-radius: 4px; border: 1px solid var(--line-3); background: var(--bg-2); display: inline-flex; align-items: center; justify-content: center; position: relative; color: var(--accent-ink); }
  .sw.on { background: var(--accent); border-color: var(--accent); }
  .sw.ch { border-color: var(--accent); box-shadow: inset 0 0 0 1px var(--accent-line); }
  .sw.lk { background: var(--panel-2); color: var(--muted); border-color: var(--line-2); }
  .grow { flex: 1; }
  .note { color: var(--faint); font-size: 12px; }
  .scroller { flex: 1; min-height: 0; padding: 0 24px 20px; }
  table { width: 100%; border-collapse: separate; border-spacing: 0; table-layout: fixed; }
  thead th { position: sticky; top: 0; z-index: 2; background: var(--bg); border-bottom: 1px solid var(--line-2); padding: 8px 6px 10px; text-align: center; vertical-align: bottom; }
  th.perm, td.perm { text-align: left; width: 44%; padding-left: 10px; }
  thead th.perm { font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; }
  .g { display: table-cell; }
  .gn { display: block; font-weight: 700; color: var(--text); font-size: 14px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .gl { display: inline-flex; align-items: center; gap: 5px; color: var(--faint); font-size: 11px; font-weight: 500; margin-top: 2px; }
  th.boss .gn { color: var(--accent); }
  .you { font-family: var(--font); background: var(--accent-soft); color: var(--accent); border-radius: 3px; padding: 0 5px; font-size: 11px; font-weight: 700; }
  .grp td { padding: 16px 10px 6px; border-bottom: 1px solid var(--line-2); }
  .grp .eyebrow { color: var(--muted); }
  .row td { border-bottom: 1px solid var(--line); height: 40px; }
  .row:hover td { background: var(--bg-2); }
  .pl { color: var(--text); display: block; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .pk { color: var(--faint); font-size: 11px; }
  .row .perm { padding-top: 4px; padding-bottom: 4px; line-height: 1.25; }
  .cellwrap { text-align: center; }
  .bosscol { background: rgba(245, 165, 36, 0.025); }
  .cell { width: 26px; height: 26px; border-radius: 5px; border: 1px solid var(--line-3); background: var(--bg-2); color: var(--accent-ink); display: inline-flex; align-items: center; justify-content: center; position: relative; padding: 0; transition: background 0.1s, border-color 0.1s; }
  .cell:hover:not(:disabled) { border-color: var(--accent); }
  .cell.on { background: var(--accent); border-color: var(--accent); }
  .cell.ch::after { content: ''; position: absolute; top: -4px; right: -4px; width: 8px; height: 8px; border-radius: 50%; background: var(--accent); border: 2px solid var(--bg); }
  .cell.on.ch::after { background: var(--accent-2); }
  .cell.ch:not(.on) { border-color: var(--accent); }
  .cell.lk { background: var(--panel-2); border-color: var(--line-2); color: var(--muted); }
  .cell:disabled { opacity: 1; cursor: default; }
  .cell:disabled:not(.lk) { opacity: 0.6; }
  .cell.busy { opacity: 0.4; }
  tfoot td { padding: 12px 0 4px; border-top: 1px solid var(--line-2); }
  tfoot .perm { padding-left: 10px; font-size: 12px; }
</style>
