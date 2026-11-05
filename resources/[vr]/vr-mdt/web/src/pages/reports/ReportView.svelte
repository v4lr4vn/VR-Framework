<script>
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import Icon from '../../components/Icon.svelte';
  import Mugshot from '../../components/Mugshot.svelte';
  import Photo from './Photo.svelte';
  import PhotoViewer from './PhotoViewer.svelte';
  import SentencePanel from './SentencePanel.svelte';
  import { go, can, request, session } from '../../lib/state.svelte.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { dateTime, agoWords, money } from '../../lib/format.js';
  import { typeLabel, typeTone, classShort, classTone, classLabel, roleLabel, officerLabel, jail } from './util.js';

  let { report, onedit, onchanged, ondeleted } = $props();

  let busy = $state('');
  let viewer = $state(false);
  let viewIndex = $state(0);

  const suspects = $derived(report.people.filter((p) => p.role === 'suspect'));
  const others = $derived(report.people.filter((p) => p.role !== 'suspect' && p.role !== 'officer'));
  const photos = $derived(report.images.map((i) => ({ id: i.id, imageId: i.id, title: i.caption || 'Report photo', caption: i.caption })));
  const canProfile = $derived(can('records.view'));
  const responder = $derived(session.dept?.id === 'police' || session.dept?.id === 'ems');

  async function setLock(locked) {
    busy = 'lock';
    const res = await request('reports.lock', { id: report.id, locked }, { success: locked ? 'Report locked' : 'Report unlocked' });
    busy = '';
    if (res.ok) onchanged?.(res.data);
  }

  async function remove() {
    const ok = await confirm({ title: `Delete report #${report.id}?`, text: 'The report, its people, vehicles and photos are removed. Sentences already applied stay on the citizen record.', yes: 'Delete report', danger: true });
    if (!ok) return;
    busy = 'delete';
    const res = await request('reports.delete', { id: report.id }, { success: 'Report deleted' });
    busy = '';
    if (res.ok) ondeleted?.(report.id);
  }

  async function reload() {
    const res = await request('reports.get', { id: report.id });
    if (res.ok) onchanged?.(res.data);
  }

  function openPhoto(i) {
    viewIndex = i;
    viewer = true;
  }
</script>

<article class="view">
  <header class="top">
    <div class="meta mono">
      <span>REPORT #{report.id}</span><span>·</span><span>{dateTime(report.createdAt)}</span>
      {#if report.updatedAt && report.updatedAt - report.createdAt > 60}<span>·</span><span>edited {agoWords(report.updatedAt)}</span>{/if}
      <span class="grow"></span>
      <Badge tone={typeTone(report.type)}>{typeLabel(report.type)}</Badge>
      {#if report.locked}<Badge tone="danger"><Icon name="lock" size={12} /> Locked</Badge>{/if}
    </div>
    <h1>{report.title}</h1>
    <div class="facts">
      <span class="fact"><Icon name="shield" size={14} /> <span class="mono strong">{report.author.callsign || ''}</span> {report.author.name}</span>
      {#if report.location}<span class="fact"><Icon name="pin" size={14} /> {report.location}</span>{/if}
      {#if report.callId && responder}
        <button type="button" class="fact link" onclick={() => go('dispatch', { id: report.callId })}><Icon name="radio" size={14} /> Call <span class="mono">#{report.callId}</span></button>
      {:else if report.callId}
        <span class="fact"><Icon name="radio" size={14} /> Call <span class="mono">#{report.callId}</span></span>
      {/if}
      {#if report.case}
        <button type="button" class="fact link" onclick={() => go('cases', { id: report.case.id })}><Icon name="folder" size={14} /> Case <span class="mono">#{report.case.id}</span> {report.case.title}</button>
      {/if}
      {#if report.evidenceCount}<span class="fact"><Icon name="evidence" size={14} /> {report.evidenceCount} evidence {report.evidenceCount === 1 ? 'item' : 'items'}</span>{/if}
    </div>
    <div class="actions">
      {#if report.can?.edit}
        <Button variant="primary" icon="edit" onclick={onedit}>Edit report</Button>
      {/if}
      {#if report.can?.lock}
        <Button icon={report.locked ? 'unlock' : 'lock'} busy={busy === 'lock'} onclick={() => setLock(!report.locked)}>{report.locked ? 'Unlock' : 'Lock'}</Button>
      {/if}
      {#if report.can?.delete}
        <Button variant="ghost" icon="trash" busy={busy === 'delete'} onclick={remove}>Delete</Button>
      {/if}
      {#if report.locked && !report.can?.edit}
        <span class="lockednote">Locked reports can only be changed by a boss.</span>
      {/if}
    </div>
  </header>

  <div class="cols">
    <div class="main">
      <section class="block">
        <h2 class="eyebrow">Narrative</h2>
        {#if report.body}
          <p class="body">{report.body}</p>
        {:else}
          <p class="none">No narrative written.</p>
        {/if}
        {#if report.tags?.length}
          <div class="tags">{#each report.tags as t}<span class="tag"><Icon name="tag" size={12} />{t}</span>{/each}</div>
        {/if}
      </section>

      <section class="block">
        <h2 class="eyebrow">Suspects · {suspects.length}</h2>
        {#each suspects as s (s.id)}
          <div class="suspect">
            <div class="shead">
              <Mugshot name={s.name} size={40} />
              <div class="who">
                {#if s.cid && canProfile}
                  <button type="button" class="name link" onclick={() => go('citizens', { cid: s.cid })}>{s.name}</button>
                {:else}
                  <span class="name">{s.name}</span>
                {/if}
                <span class="sub mono">{s.cid || 'No citizen record'}</span>
              </div>
              {#if s.totals.class}<Badge tone={classTone(s.totals.class)}>{classLabel(s.totals.class)}</Badge>{/if}
              {#if s.sentenced}<Badge tone="ok" solid><Icon name="check" size={12} stroke={3} /> Sentenced</Badge>{:else if s.charges.length}<Badge tone="muted">Not sentenced</Badge>{/if}
            </div>
            {#if s.notes}<p class="notes">{s.notes}</p>{/if}
            {#if s.charges.length}
              <table class="charges">
                <thead><tr><th>Charge</th><th class="c">Class</th><th class="r">Count</th><th class="r">Fine</th><th class="r">Jail</th></tr></thead>
                <tbody>
                  {#each s.charges as c (c.id ?? c.title)}
                    <tr>
                      <td class="ct">{c.title}{#if c.active === false}<span class="retired">Retired</span>{/if}</td>
                      <td class="c"><Badge tone={classTone(c.class)} mono>{classShort(c.class)}</Badge></td>
                      <td class="r mono">{c.count > 1 ? `×${c.count}` : '1'}</td>
                      <td class="r mono">{money(c.fine * c.count)}</td>
                      <td class="r mono">{c.months ? `${c.months * c.count} mo` : '—'}</td>
                    </tr>
                  {/each}
                </tbody>
                <tfoot>
                  <tr><td colspan="3">{s.sentenced ? 'Charged at sentencing' : 'Maximum'}{s.totals.points ? ` · ${s.totals.points} ${s.totals.points === 1 ? 'point' : 'points'}` : ''}</td><td class="r mono">{money(s.totals.fine)}</td><td class="r mono">{s.totals.months ? `${s.totals.months} mo` : '—'}</td></tr>
                </tfoot>
              </table>
            {:else}
              <p class="none">No charges.</p>
            {/if}
            {#if s.sentenced && s.sentence}
              <div class="sentence">
                <Icon name="gavel" size={16} />
                <div class="stext">
                  <span><b class="mono">{money(s.sentence.fine)}</b> fine{#if s.sentence.paid < s.sentence.fine}{' '}<span class="unpaid">({money(s.sentence.fine - s.sentence.paid)} unpaid)</span>{/if}{' · '}{#if s.sentence.months}<b>{jail(s.sentence.months)}</b>{:else}no jail time{/if}{#if s.sentence.plea}{' · '}guilty plea{/if}</span>
                  <span class="sub">{s.sentence.officer} · {dateTime(s.sentence.at)}{#if s.sentence.months > 0 && !s.sentence.jailed}{' · '}<span class="unpaid">not jailed by the prison system</span>{/if}</span>
                </div>
              </div>
            {:else if !s.sentenced && report.can?.sentence && s.cid && s.charges.length}
              <SentencePanel reportId={report.id} person={s} onapplied={reload} />
            {/if}
          </div>
        {:else}
          <p class="none">No suspects on this report.</p>
        {/each}
      </section>
    </div>

    <aside class="side">
      <section class="block">
        <h2 class="eyebrow">People · {others.length}</h2>
        {#each others as p (p.id)}
          <div class="person">
            <span class="role">{roleLabel(p.role)}</span>
            <div class="pw">
              {#if p.cid && canProfile}
                <button type="button" class="pn link" onclick={() => go('citizens', { cid: p.cid })}>{p.name}</button>
              {:else}
                <span class="pn">{p.name}</span>
              {/if}
              {#if p.notes}<span class="sub">{p.notes}</span>{/if}
            </div>
          </div>
        {:else}
          <p class="none">No victims or witnesses.</p>
        {/each}
      </section>

      <section class="block">
        <h2 class="eyebrow">Officers · {report.officers.length}</h2>
        {#each report.officers as o (o.cid)}
          <div class="officer">
            <span class="cs mono">{o.callsign || '—'}</span>
            <span class="on">{o.name}</span>
            {#if o.author}<Badge tone="accent">Author</Badge>{/if}
          </div>
        {/each}
      </section>

      <section class="block">
        <h2 class="eyebrow">Vehicles · {report.vehicles.length}</h2>
        {#each report.vehicles as v (v.plate)}
          <div class="vehicle">
            <span class="plate mono">{v.plate}</span>
            <div class="pw"><span class="pn">{v.label || 'Unknown model'}</span>{#if v.note}<span class="sub">{v.note}</span>{/if}</div>
          </div>
        {:else}
          <p class="none">No vehicles.</p>
        {/each}
      </section>

      <section class="block">
        <h2 class="eyebrow">Photos · {report.images.length}</h2>
        {#if report.images.length}
          <div class="gallery">
            {#each photos as p, i (p.id)}
              <figure>
                <Photo id={p.imageId} alt={p.title} height={84} onclick={() => openPhoto(i)} />
                {#if p.caption}<figcaption>{p.caption}</figcaption>{/if}
              </figure>
            {/each}
          </div>
        {:else}
          <p class="none">No photos attached.</p>
        {/if}
      </section>
    </aside>
  </div>
</article>

<PhotoViewer bind:open={viewer} items={photos} bind:index={viewIndex} />

<style>
  .view { display: flex; flex-direction: column; min-height: 100%; }
  .top { padding: 16px 24px 16px; display: flex; flex-direction: column; gap: 10px; border-bottom: 1px solid var(--line); background: var(--bg-2); }
  .meta { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--muted); }
  .grow { flex: 1; }
  h1 { font-size: 24px; font-weight: 700; line-height: 1.15; }
  .facts { display: flex; flex-wrap: wrap; gap: 6px 18px; }
  .fact { display: inline-flex; align-items: center; gap: 6px; color: var(--text-2); }
  .strong { font-weight: 600; color: var(--text); }
  .link { border: 0; background: transparent; padding: 0; cursor: pointer; text-align: left; }
  .fact.link:hover, .name.link:hover, .pn.link:hover { color: var(--accent); }
  .actions { display: flex; align-items: center; gap: 8px; flex-wrap: wrap; }
  .lockednote { color: var(--muted); font-size: 13px; }
  .cols { display: grid; grid-template-columns: minmax(0, 1fr) 320px; gap: 20px; padding: 18px 24px 24px; align-items: start; }
  .main, .side { display: flex; flex-direction: column; gap: 18px; min-width: 0; }
  .block { display: flex; flex-direction: column; gap: 10px; }
  .side .block { padding: 12px 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .body { color: var(--text-2); line-height: 1.55; white-space: pre-wrap; overflow-wrap: anywhere; user-select: text; padding: 14px 16px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .tags { display: flex; flex-wrap: wrap; gap: 6px; }
  .tag { display: inline-flex; align-items: center; gap: 5px; height: 22px; padding: 0 8px; border-radius: 4px; background: var(--panel-2); color: var(--text-2); font-size: 12px; }
  .none { color: var(--faint); font-size: 13px; }
  .suspect { display: flex; flex-direction: column; gap: 10px; padding: 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .shead { display: flex; align-items: center; gap: 12px; }
  .who { flex: 1; display: flex; flex-direction: column; min-width: 0; }
  .name { font-size: 16px; font-weight: 700; color: var(--text); }
  .sub { color: var(--muted); font-size: 12px; }
  .notes { color: var(--text-2); font-size: 13px; line-height: 1.45; white-space: pre-wrap; }
  table { width: 100%; border-collapse: collapse; }
  th { text-align: left; font-size: 11px; letter-spacing: 0.1em; text-transform: uppercase; color: var(--faint); font-weight: 600; padding: 6px 8px; border-bottom: 1px solid var(--line-2); }
  td { padding: 7px 8px; border-bottom: 1px solid var(--line); color: var(--text-2); }
  .ct { color: var(--text); font-weight: 500; }
  .c { width: 64px; }
  .r { text-align: right; width: 88px; }
  tfoot td { border-bottom: 0; color: var(--muted); font-size: 13px; }
  tfoot td.r { color: var(--text); font-weight: 600; }
  .retired { margin-left: 8px; font-size: 11px; font-weight: 600; color: var(--muted); text-transform: uppercase; letter-spacing: 0.08em; }
  .sentence { display: flex; gap: 12px; align-items: flex-start; padding: 10px 12px; border-radius: var(--radius); background: var(--ok-bg); border: 1px solid var(--ok-line); color: var(--ok); }
  .stext { display: flex; flex-direction: column; gap: 2px; color: var(--text); }
  .stext b { font-weight: 700; }
  .unpaid { color: var(--p1-text); }
  .person, .vehicle { display: flex; gap: 10px; align-items: flex-start; }
  .role { width: 64px; flex: none; color: var(--faint); font-size: 12px; text-transform: uppercase; letter-spacing: 0.06em; padding-top: 2px; }
  .pw { display: flex; flex-direction: column; min-width: 0; }
  .pn { color: var(--text); font-weight: 600; text-align: left; }
  .officer { display: flex; align-items: center; gap: 10px; min-height: 24px; }
  .cs { width: 96px; flex: none; color: var(--p3-text); font-size: 13px; }
  .on { flex: 1; min-width: 0; color: var(--text-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .plate { flex: none; padding: 1px 6px; border-radius: 4px; border: 1px solid var(--accent-line); color: var(--accent); font-weight: 600; font-size: 13px; }
  .gallery { display: grid; grid-template-columns: repeat(3, minmax(0, 1fr)); gap: 8px; }
  figure { margin: 0; display: flex; flex-direction: column; gap: 4px; min-width: 0; }
  figcaption { color: var(--muted); font-size: 11px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
</style>
