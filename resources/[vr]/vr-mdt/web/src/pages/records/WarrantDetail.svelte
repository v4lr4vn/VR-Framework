<script>
  import './records.css';
  import Badge from '../../components/Badge.svelte';
  import Button from '../../components/Button.svelte';
  import Icon from '../../components/Icon.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import { session, can, go, request, clock } from '../../lib/state.svelte.js';
  import { confirm } from '../../lib/confirm.svelte.js';
  import { dateTime, agoWords } from '../../lib/format.js';
  import { warrantTone, warrantLabel, chargeText } from './shared.js';

  let { warrant: w, canDecide = false, fallback = false, onchanged } = $props();

  let note = $state('');
  let busy = $state('');

  $effect(() => {
    w.id;
    note = '';
  });

  const mine = $derived(session.me?.cid);
  const canRevoke = $derived(
    (w.status === 'pending' || w.status === 'active') &&
      (can('warrants.approve') || (session.dept?.id === 'police' && session.me?.isboss) || w.approved_by_cid === mine || (w.status === 'pending' && w.created_by_cid === mine)),
  );

  function until(ts, now = clock.now) {
    const s = Math.max(0, ts - now);
    const d = Math.floor(s / 86400);
    const h = Math.floor((s % 86400) / 3600);
    const m = Math.floor((s % 3600) / 60);
    if (d > 0) return `${d} d ${h} h`;
    if (h > 0) return `${h} h ${m} min`;
    return `${m} min`;
  }

  async function act(name, action, data, success) {
    busy = name;
    const res = await request(action, { id: w.id, ...data }, { success });
    busy = '';
    if (res.ok) onchanged?.(res.data);
    return res;
  }

  async function revoke() {
    const pending = w.status === 'pending';
    const ok = await confirm({
      title: pending ? 'Withdraw this request?' : 'Revoke this warrant?',
      text: pending ? `The request for ${w.name} will be closed without a decision.` : `Officers will no longer be able to arrest ${w.name} on warrant #${w.id}.`,
      yes: pending ? 'Withdraw' : 'Revoke',
      danger: true,
    });
    if (ok) act('revoke', 'warrants.revoke', {}, pending ? 'Request withdrawn' : 'Warrant revoked');
  }

  async function serve() {
    const ok = await confirm({ title: 'Mark as served?', text: `Confirm ${w.name} was arrested on warrant #${w.id}.`, yes: 'Mark served' });
    if (ok) act('serve', 'warrants.serve', {}, 'Warrant served');
  }
</script>

<article class="detail" aria-label="Warrant #{w.id}">
  <header class="top">
    <div class="meta mono">
      <span>WARRANT #{w.id}</span><span>·</span><span>{dateTime(w.created_at)}</span>
      <span class="grow"></span>
      <Badge tone={warrantTone(w.status)} solid={w.status === 'active' || w.status === 'pending'}>{warrantLabel(w.status).toUpperCase()}</Badge>
    </div>
    <button type="button" class="who" onclick={() => go('citizens', { cid: w.cid })}>
      <h2>{w.name}</h2>
      <span class="mono faint">{w.cid}</span>
      <Icon name="chevron" size={16} />
    </button>
    {#if w.status === 'active'}
      <p class="expiry"><Icon name="hourglass" size={14} /> Expires in {until(w.expires_at)}{' · '}{dateTime(w.expires_at)}</p>
    {/if}
  </header>

  <div class="body scroll">
    {#if canDecide && fallback && w.status === 'pending'}
      <div class="fallback"><Icon name="alert" size={15} /><span>No judge is available. As a senior officer you may decide on this request. Your decision is logged.</span></div>
    {/if}

    <section class="rec-section">
      <h3 class="eyebrow">Probable cause</h3>
      <p class="reason">{w.reason}</p>
    </section>

    <section class="rec-section">
      <h3 class="eyebrow">Charges</h3>
      {#if w.charges?.length}
        <ul class="charges">
          {#each w.charges as c}<li><Icon name="scale" size={14} />{chargeText(c)}</li>{/each}
        </ul>
      {:else}
        <p class="faint">No charges listed.</p>
      {/if}
    </section>

    {#if w.report_id}
      <section class="rec-section">
        <h3 class="eyebrow">Linked report</h3>
        <div class="link"><Button size="sm" icon="report" onclick={() => go('reports', { id: w.report_id })}>Report #{w.report_id}</Button></div>
      </section>
    {/if}

    <section class="rec-section">
      <h3 class="eyebrow">History</h3>
      <ol class="timeline">
        <li><span class="dot"></span><span><b>Requested</b> by {w.created_by_name || 'Unknown'}{' · '}<span class="faint">{agoWords(w.created_at)}</span></span></li>
        {#if w.decided_at && w.approved_by_name}
          <li class:bad={w.status === 'denied'}><span class="dot"></span><span><b>{w.status === 'denied' ? 'Denied' : 'Approved'}</b> by {w.approved_by_name}{' · '}<span class="faint">{agoWords(w.decided_at)}</span>{#if w.decision_note}<span class="quote">"{w.decision_note}"</span>{/if}</span></li>
        {/if}
        {#if w.status === 'served'}
          <li class="good"><span class="dot"></span><span><b>Served</b> by {w.closed_by_name}{' · '}<span class="faint">{agoWords(w.served_at)}</span></span></li>
        {:else if w.status === 'revoked'}
          <li class="bad"><span class="dot"></span><span><b>Revoked</b> by {w.closed_by_name}</span></li>
        {:else if w.status === 'expired'}
          <li><span class="dot"></span><span><b>Expired</b>{' · '}<span class="faint">{dateTime(w.expires_at)}</span></span></li>
        {/if}
      </ol>
    </section>
  </div>

  {#if w.status === 'pending' && canDecide}
    <footer class="decide">
      <label class="sr-only" for="decision-note">Decision note</label>
      <Textarea id="decision-note" bind:value={note} rows={2} maxlength={500} placeholder="Note for the requesting officer (required to deny)" />
      <div class="row">
        <Button variant="danger" icon="x" busy={busy === 'deny'} disabled={!note.trim() || !!busy} onclick={() => act('deny', 'warrants.decide', { approve: false, note: note.trim() }, 'Warrant denied')}>Deny</Button>
        <Button variant="primary" icon="check" busy={busy === 'approve'} disabled={!!busy} onclick={() => act('approve', 'warrants.decide', { approve: true, note: note.trim() }, 'Warrant approved')}>Approve warrant</Button>
      </div>
    </footer>
  {:else if (w.status === 'active' && can('warrants.create')) || canRevoke}
    <footer class="decide">
      <div class="row">
        {#if canRevoke}<Button variant="ghost" icon="ban" busy={busy === 'revoke'} onclick={revoke}>{w.status === 'pending' ? 'Withdraw request' : 'Revoke'}</Button>{/if}
        {#if w.status === 'active' && can('warrants.create')}<Button variant="primary" icon="lock" busy={busy === 'serve'} onclick={serve}>Mark served</Button>{/if}
      </div>
    </footer>
  {/if}
</article>

<style>
  .detail { flex: 1; min-width: 0; display: flex; flex-direction: column; background: var(--panel); border: 1px solid var(--line-2); border-radius: var(--radius-lg); min-height: 0; }
  .top { padding: 14px 18px; border-bottom: 1px solid var(--line); display: flex; flex-direction: column; gap: 8px; }
  .meta { display: flex; align-items: center; gap: 6px; font-size: 12px; color: var(--muted); }
  .grow { flex: 1; }
  .who { display: flex; align-items: baseline; gap: 10px; border: 0; background: transparent; padding: 0; color: var(--faint); text-align: left; align-self: flex-start; }
  .who:hover h2 { color: var(--accent); }
  .who :global(svg) { align-self: center; }
  h2 { font-size: 24px; font-weight: 700; color: var(--text); }
  .expiry { display: flex; align-items: center; gap: 6px; color: var(--danger-text); font-size: 13px; }
  .body { flex: 1; min-height: 0; padding: 16px 18px; display: flex; flex-direction: column; }
  .fallback { display: flex; gap: 10px; align-items: flex-start; padding: 10px 12px; border-radius: var(--radius); background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--p2-text); margin-bottom: 16px; line-height: 1.45; }
  .fallback :global(svg) { margin-top: 2px; color: var(--accent); }
  .reason { color: var(--text); line-height: 1.55; white-space: pre-wrap; overflow-wrap: anywhere; }
  .charges { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; }
  .charges li { display: flex; align-items: center; gap: 8px; color: var(--text); font-weight: 500; }
  .charges :global(svg) { color: var(--faint); }
  .timeline { list-style: none; margin: 0; padding: 0 0 0 4px; display: flex; flex-direction: column; gap: 12px; }
  .timeline li { display: flex; gap: 12px; color: var(--text-2); line-height: 1.4; }
  .timeline b { color: var(--text); font-weight: 600; }
  .dot { width: 9px; height: 9px; border-radius: 50%; background: var(--line-3); margin-top: 5px; flex: none; }
  .timeline li:not(.bad):not(.good):nth-child(2) .dot { background: var(--accent); }
  .good .dot { background: var(--ok); }
  .bad .dot { background: var(--danger); }
  .quote { display: block; color: var(--muted); font-style: italic; margin-top: 2px; }
  .decide { padding: 12px 18px 14px; border-top: 1px solid var(--line); display: flex; flex-direction: column; gap: 10px; }
  .row { display: flex; justify-content: flex-end; gap: 8px; }
  .link { align-self: flex-start; }
</style>
