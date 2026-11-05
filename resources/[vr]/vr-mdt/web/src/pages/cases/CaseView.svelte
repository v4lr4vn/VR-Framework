<script>
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import Icon from '../../components/Icon.svelte';
  import Photo from '../reports/Photo.svelte';
  import PhotoViewer from '../reports/PhotoViewer.svelte';
  import EvidenceModal from './EvidenceModal.svelte';
  import LinkReportModal from './LinkReportModal.svelte';
  import CaseEditor from './CaseEditor.svelte';
  import { callback } from '../../lib/nui.js';
  import { go, can, request, toast } from '../../lib/state.svelte.js';
  import { errorText } from '../../lib/lang.js';
  import { rememberImage } from '../../lib/images.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { date, dateTime, agoWords } from '../../lib/format.js';
  import { statusLabel, statusTone, caseRoleLabel } from './util.js';
  import { typeLabel, typeTone } from '../reports/util.js';

  let { item, onchanged } = $props();

  let busy = $state('');
  let viewer = $state(false);
  let viewIndex = $state(0);
  let evModal = $state(false);
  let evKind = $state('note');
  let evImage = $state(null);
  let evItem = $state(null);
  let linkModal = $state(false);
  let editModal = $state(false);

  const photos = $derived(item.evidence.filter((e) => e.kind === 'photo'));
  const records = $derived(item.evidence.filter((e) => e.kind !== 'photo'));
  const manage = $derived(item.can?.manage);
  const evidence = $derived(item.can?.evidence);

  async function reload() {
    const res = await request('cases.get', { id: item.id });
    if (res.ok) onchanged?.(res.data);
  }

  async function setStatus(status) {
    const verb = status === 'closed' ? 'Close' : status === 'cold' ? 'Mark as cold' : 'Reopen';
    if (status !== 'open') {
      const ok = await confirm({ title: `${verb} case #${item.id}?`, text: status === 'closed' ? 'Closed cases stay searchable and can be reopened.' : 'Cold cases stay searchable and can be reopened when new leads come in.', yes: verb });
      if (!ok) return;
    }
    busy = status;
    const res = await request('cases.close', { id: item.id, status }, { success: `Case ${statusLabel(status).toLowerCase()}` });
    busy = '';
    if (res.ok) onchanged?.(res.data);
  }

  async function locker() {
    busy = 'locker';
    const res = await request('evidence.locker', { caseId: item.id });
    if (res.ok) {
      const opened = await callback('openStash', { id: res.data.id });
      if (!opened?.ok) toast(errorText(opened?.error), 'error');
      else toast(`Opening ${res.data.label.toLowerCase()}`, 'ok');
    }
    busy = '';
  }

  function addEvidence(kind) {
    evKind = kind;
    evImage = null;
    evItem = null;
    evModal = true;
  }

  async function takePhoto() {
    busy = 'photo';
    const res = await callback('capture', { kind: 'evidence' });
    busy = '';
    if (!res || !res.ok) {
      toast(errorText(res?.error), res?.error === 'cancelled' ? 'info' : 'error');
      return;
    }
    rememberImage(res.data.id, res.data.url);
    evKind = 'photo';
    evImage = res.data.id;
    evItem = null;
    evModal = true;
  }

  function editEvidence(e) {
    evItem = e;
    evModal = true;
  }

  async function removeEvidence(e) {
    const ok = await confirm({ title: `Remove "${e.title}"?`, text: e.kind === 'photo' ? 'The photo is deleted for good.' : 'This removes it from the case file.', yes: 'Remove', danger: true });
    if (!ok) return;
    const res = await request('evidence.remove', { id: e.id }, { success: 'Evidence removed' });
    if (res.ok) {
      viewer = false;
      reload();
    }
  }

  async function unlink(r) {
    const ok = await confirm({ title: `Unlink report #${r.id}?`, text: 'The report stays on file, it just leaves this case.', yes: 'Unlink' });
    if (!ok) return;
    const res = await request('cases.unlink', { caseId: item.id, reportId: r.id }, { success: 'Report unlinked' });
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
      <span>CASE #{item.id}</span><span>·</span><span>opened {date(item.createdAt)}{item.createdBy?.name ? ` by ${item.createdBy.name}` : ''}</span><span>·</span><span>updated {agoWords(item.updatedAt)}</span>
      <span class="grow"></span>
      <Badge tone={statusTone(item.status)} solid={item.status === 'open'}>{statusLabel(item.status)}</Badge>
    </div>
    <h1>{item.title}</h1>
    <div class="facts">
      <span class="fact"><Icon name="shield" size={14} /> Lead: {#if item.lead}<span class="strong">{item.lead.name}</span>{:else}<span class="faint">none</span>{/if}</span>
      <span class="fact"><Icon name="report" size={14} /> {item.reports.length} {item.reports.length === 1 ? 'report' : 'reports'}</span>
      <span class="fact"><Icon name="evidence" size={14} /> {item.evidence.length} evidence</span>
    </div>
    {#if manage || evidence}
      <div class="actions">
        {#if manage}
          <Button variant="primary" icon="edit" onclick={() => (editModal = true)}>Edit case</Button>
          {#if item.status === 'open'}
            <Button icon="check" busy={busy === 'closed'} onclick={() => setStatus('closed')}>Close case</Button>
            <Button variant="ghost" icon="clock" busy={busy === 'cold'} onclick={() => setStatus('cold')}>Mark cold</Button>
          {:else}
            <Button icon="refresh" busy={busy === 'open'} onclick={() => setStatus('open')}>Reopen</Button>
          {/if}
        {/if}
        {#if evidence}
          <span class="grow"></span>
          <Button icon="stash" busy={busy === 'locker'} onclick={locker}>Evidence locker</Button>
        {/if}
      </div>
    {/if}
  </header>

  <div class="cols">
    <div class="main">
      <section class="block">
        <h2 class="eyebrow">Summary</h2>
        {#if item.summary}<p class="body">{item.summary}</p>{:else}<p class="none">No summary yet.</p>{/if}
      </section>

      <section class="block">
        <div class="sh">
          <h2 class="eyebrow">Evidence · {item.evidence.length}</h2>
          <span class="grow"></span>
          {#if evidence}
            <Button size="sm" icon="photo" busy={busy === 'photo'} onclick={takePhoto}>Take photo</Button>
            <Button size="sm" icon="note" onclick={() => addEvidence('note')}>Add note</Button>
            <Button size="sm" icon="box" onclick={() => addEvidence('item')}>Add item</Button>
          {/if}
        </div>
        {#if photos.length}
          <div class="gallery">
            {#each photos as p, i (p.id)}
              <figure>
                <Photo id={p.imageId} alt={p.title} height={118} onclick={() => openPhoto(i)} />
                <figcaption><span class="ft">{p.title}</span><span class="fs">{p.location || date(p.createdAt)}</span></figcaption>
              </figure>
            {/each}
          </div>
        {/if}
        {#each records as e (e.id)}
          <div class="ev">
            <span class="kind {e.kind}"><Icon name={e.kind === 'item' ? 'box' : 'note'} size={15} /></span>
            <div class="et">
              <div class="eh"><span class="title">{e.title}</span>{#if e.reportId}<button type="button" class="rl mono" onclick={() => go('reports', { id: e.reportId })}>#{e.reportId}</button>{/if}</div>
              {#if e.description}<p class="desc">{e.description}</p>{/if}
              <span class="sub">{[e.kind === 'item' ? 'Item' : 'Note', e.location, e.collectedBy?.name, dateTime(e.createdAt)].filter(Boolean).join(' · ')}</span>
            </div>
            {#if evidence}
              <div class="eact">
                <IconButton icon="edit" label="Edit {e.title}" size={28} onclick={() => editEvidence(e)} />
                <IconButton icon="trash" label="Remove {e.title}" size={28} variant="danger" onclick={() => removeEvidence(e)} />
              </div>
            {/if}
          </div>
        {/each}
        {#if !item.evidence.length}
          <p class="none">No evidence logged. {evidence ? 'Take photos, add notes or log items as you collect them.' : ''}</p>
        {/if}
      </section>
    </div>

    <aside class="side">
      <section class="block card">
        <h2 class="eyebrow">People · {item.people.length}</h2>
        {#each item.people as p (p.id ?? p.name)}
          <div class="person">
            <span class="role">{caseRoleLabel(p.role)}</span>
            {#if p.cid && can('records.view')}
              <button type="button" class="pn link" onclick={() => go('citizens', { cid: p.cid })}>{p.name}</button>
            {:else}
              <span class="pn">{p.name}</span>
            {/if}
          </div>
        {:else}
          <p class="none">Nobody linked.</p>
        {/each}
      </section>

      <section class="block card">
        <h2 class="eyebrow">Officers · {item.officers.length}</h2>
        {#each item.officers as o (o.cid)}
          <div class="officer"><span class="cs mono">{o.callsign || '—'}</span><span class="on">{o.name}</span>{#if item.lead?.cid === o.cid}<Badge tone="accent">Lead</Badge>{/if}</div>
        {:else}
          <p class="none">No officers assigned.</p>
        {/each}
      </section>

      <section class="block card">
        <div class="sh">
          <h2 class="eyebrow">Reports · {item.reports.length}</h2>
          <span class="grow"></span>
          {#if manage}<Button size="sm" icon="link" onclick={() => (linkModal = true)}>Link</Button>{/if}
        </div>
        {#each item.reports as r (r.id)}
          <div class="rep">
            <button type="button" class="rb" onclick={() => go('reports', { id: r.id })} disabled={!item.can?.reports}>
              <span class="rh"><span class="mono faint">#{r.id}</span><Badge tone={typeTone(r.type)}>{typeLabel(r.type)}</Badge>{#if r.locked}<Icon name="lock" size={12} />{/if}</span>
              <span class="rt">{r.title}</span>
              <span class="sub">{r.author.callsign || r.author.name} · {date(r.createdAt)}</span>
            </button>
            {#if manage}<IconButton icon="unlink" label="Unlink report #{r.id}" size={28} onclick={() => unlink(r)} />{/if}
          </div>
        {:else}
          <p class="none">No reports linked.</p>
        {/each}
      </section>
    </aside>
  </div>
</article>

<PhotoViewer bind:open={viewer} items={photos} bind:index={viewIndex} ondelete={evidence ? removeEvidence : null} />
<EvidenceModal bind:open={evModal} caseId={item.id} kind={evKind} imageId={evImage} item={evItem} onsaved={reload} />
<LinkReportModal bind:open={linkModal} caseId={item.id} linked={item.reports.map((r) => r.id)} onlinked={(c) => onchanged?.(c)} />
<CaseEditor bind:open={editModal} {item} onsaved={(c) => onchanged?.(c)} />

<style>
  .view { display: flex; flex-direction: column; min-height: 100%; }
  .top { padding: 16px 24px; display: flex; flex-direction: column; gap: 10px; border-bottom: 1px solid var(--line); background: var(--bg-2); }
  .meta { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--muted); }
  .grow { flex: 1; }
  h1 { font-size: 24px; font-weight: 700; line-height: 1.15; }
  .facts { display: flex; flex-wrap: wrap; gap: 6px 18px; }
  .fact { display: inline-flex; align-items: center; gap: 6px; color: var(--text-2); }
  .strong { color: var(--text); font-weight: 600; }
  .actions { display: flex; align-items: center; gap: 8px; }
  .cols { display: grid; grid-template-columns: minmax(0, 1fr) 330px; gap: 20px; padding: 18px 24px 24px; align-items: start; }
  .main, .side { display: flex; flex-direction: column; gap: 18px; min-width: 0; }
  .block { display: flex; flex-direction: column; gap: 10px; }
  .card { padding: 12px 14px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .sh { display: flex; align-items: center; gap: 6px; min-height: 28px; }
  .body { color: var(--text-2); line-height: 1.55; white-space: pre-wrap; overflow-wrap: anywhere; user-select: text; padding: 14px 16px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .none { color: var(--faint); font-size: 13px; }
  .gallery { display: grid; grid-template-columns: repeat(4, minmax(0, 1fr)); gap: 10px; }
  figure { margin: 0; display: flex; flex-direction: column; gap: 4px; min-width: 0; }
  figcaption { display: flex; flex-direction: column; min-width: 0; }
  .ft { color: var(--text); font-size: 13px; font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .fs { color: var(--muted); font-size: 12px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .ev { display: flex; gap: 12px; padding: 12px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); }
  .kind { width: 30px; height: 30px; border-radius: var(--radius); display: flex; align-items: center; justify-content: center; flex: none; background: var(--info-bg); color: var(--info-text); }
  .kind.item { background: var(--accent-soft); color: var(--accent); }
  .et { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 3px; }
  .eh { display: flex; align-items: center; gap: 8px; }
  .title { color: var(--text); font-weight: 600; }
  .rl { border: 1px solid var(--line-3); background: transparent; color: var(--p3-text); border-radius: 4px; padding: 0 5px; font-size: 11px; height: 18px; }
  .rl:hover { border-color: var(--accent); color: var(--accent); }
  .desc { color: var(--text-2); font-size: 13px; line-height: 1.45; white-space: pre-wrap; }
  .sub { color: var(--muted); font-size: 12px; }
  .eact { display: flex; gap: 2px; align-self: flex-start; }
  .person { display: flex; align-items: baseline; gap: 10px; }
  .role { width: 92px; flex: none; color: var(--faint); font-size: 11px; text-transform: uppercase; letter-spacing: 0.06em; }
  .pn { color: var(--text); font-weight: 600; text-align: left; min-width: 0; }
  .link { border: 0; background: transparent; padding: 0; }
  .link:hover { color: var(--accent); }
  .officer { display: flex; align-items: center; gap: 10px; min-height: 24px; }
  .cs { width: 96px; flex: none; color: var(--p3-text); font-size: 13px; }
  .on { flex: 1; min-width: 0; color: var(--text-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .rep { display: flex; align-items: center; gap: 4px; }
  .rb { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 2px; padding: 8px 10px; border-radius: var(--radius); border: 1px solid var(--line); background: var(--bg-2); text-align: left; color: var(--text); }
  .rb:hover:not(:disabled) { border-color: var(--line-3); }
  .rb:disabled { opacity: 1; cursor: default; }
  .rh { display: flex; align-items: center; gap: 8px; color: var(--muted); }
  .rt { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
</style>
