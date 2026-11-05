<script>
  import { onMount, untrack } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import Segmented from '../../ui/kit/Segmented.svelte';
  import { phone, onBack } from '../../lib/store.svelte.js';
  import { comms } from '../../lib/comms.svelte.js';
  import { post } from '../../lib/nui.js';
  import { scopedError } from '../../lib/errors.js';
  import { stampDay, stampTime } from '../../lib/time.js';
  import { t } from '../../lib/i18n.js';

  // Mail on ravenmail.io. Not signed in: create an account, sign in, or reset the password.
  // Signed in: folders and the message list on one side, the open message (or the writing form) on the other.
  let ready = $state(false);
  let account = $state(null); // { id, address, name }
  let counts = $state({ inbox: 0, unread: 0, sent: 0, trash: 0 });

  // signed out
  let gate = $state('login'); // 'login' | 'create' | 'reset' | 'recovery'
  let g = $state({ address: '', password: '', password2: '', name: '', code: '' });
  let recoveryCode = $state('');
  let gateError = $state('');
  let gateBusy = $state(false);

  // signed in
  let folder = $state('inbox');
  let messages = $state([]);
  let more = $state(false);
  let loading = $state(false);
  let current = $state(null); // the open message, in full
  let mode = $state('read'); // 'read' | 'compose' | 'account'
  let draft = $state({ to: '', subject: '', body: '' });
  let error = $state('');
  let busy = $state(false);
  let sure = $state(false);
  let sentFlash = $state(false);
  let pw = $state({ old: '', next: '', done: false });

  const limits = $derived(phone.features?.mail ?? { domain: 'ravenmail.io', subjectLength: 100, bodyLength: 4000, keepTrashDays: 30 });
  const domain = $derived(limits.domain);
  const time24 = $derived(phone.settings.general.time24);
  const detailOpen = $derived(mode !== 'read' || current !== null);

  const folders = $derived([
    { value: 'inbox', label: counts.unread ? `${t('mail.inbox')} · ${counts.unread}` : t('mail.inbox') },
    { value: 'starred', label: t('mail.starred') },
    { value: 'sent', label: t('mail.sent') },
    { value: 'trash', label: t('mail.trash') },
  ]);

  function setCounts(c) {
    if (!c) return;
    counts = c;
    comms.badges.mail = c.unread ?? 0;
  }

  async function start() {
    const r = await post('mailState');
    ready = true;
    if (r?.ok && r.account) {
      account = r.account;
      setCounts(r.counts);
      await loadList(true);
    } else {
      account = null;
    }
  }
  onMount(start);

  // A message arrived while this is open.
  let seenRev = comms.rev.mail;
  $effect(() => {
    const rev = comms.rev.mail;
    untrack(() => {
      if (rev === seenRev) return;
      seenRev = rev;
      if (account && ready) loadList(true);
    });
  });

  $effect(() => {
    return onBack(() => {
      if (phone.fold === 'cover' && account && detailOpen) {
        current = null;
        mode = 'read';
        error = '';
        return true;
      }
      return false;
    });
  });

  // ---- signed out

  const errFor = (r) => {
    if (r?.reason === 'locked') return t('mail.err.locked', { seconds: r.seconds ?? 60 });
    return scopedError(r?.reason, 'mail');
  };

  function switchGate(to) {
    gate = to;
    gateError = '';
    g.password = '';
    g.password2 = '';
    g.code = '';
  }

  async function signIn() {
    if (gateBusy) return;
    gateBusy = true;
    gateError = '';
    const r = await post('mailLogin', { address: g.address, password: g.password });
    gateBusy = false;
    if (!r?.ok) {
      gateError = errFor(r);
      return;
    }
    enter(r);
  }

  async function createAccount() {
    if (gateBusy) return;
    if (g.password !== g.password2) {
      gateError = t('mail.err.mismatch');
      return;
    }
    gateBusy = true;
    gateError = '';
    const r = await post('mailCreate', { address: g.address, password: g.password, name: g.name });
    gateBusy = false;
    if (!r?.ok) {
      gateError = errFor(r);
      return;
    }
    recoveryCode = r.recovery;
    gate = 'recovery';
    account = null;
    pendingAccount = r;
  }

  async function resetPassword() {
    if (gateBusy) return;
    if (g.password !== g.password2) {
      gateError = t('mail.err.mismatch');
      return;
    }
    gateBusy = true;
    gateError = '';
    const r = await post('mailReset', { address: g.address, code: g.code, password: g.password });
    gateBusy = false;
    if (!r?.ok) {
      gateError = errFor(r);
      return;
    }
    recoveryCode = r.recovery;
    gate = 'recovery';
    pendingAccount = r;
  }

  // The recovery code is shown once. The mailbox opens when the player says they have it.
  let pendingAccount = null;
  function finishRecovery() {
    if (pendingAccount) enter(pendingAccount);
    pendingAccount = null;
    recoveryCode = '';
  }

  async function enter(r) {
    account = r.account;
    setCounts(r.counts);
    g = { address: '', password: '', password2: '', name: '', code: '' };
    folder = 'inbox';
    current = null;
    mode = 'read';
    await loadList(true);
  }

  // ---- signed in

  async function loadList(reset = true) {
    if (!account || loading) return;
    loading = true;
    const before = reset ? undefined : messages[messages.length - 1]?.id;
    const wanted = folder;
    const r = await post('mailList', { folder: wanted, before });
    loading = false;
    if (wanted !== folder) return;
    if (!r?.ok) {
      if (r?.reason === 'no_account') account = null;
      return;
    }
    messages = reset ? r.messages : [...messages, ...r.messages];
    more = r.more === true;
    setCounts(r.counts);
  }

  function pickFolder(f) {
    folder = f;
    messages = [];
    more = false;
    current = null;
    mode = 'read';
    loadList(true);
  }

  async function openMessage(m) {
    error = '';
    sure = false;
    const r = await post('mailGet', { id: m.id });
    if (!r?.ok) {
      error = scopedError(r?.reason, 'mail');
      loadList(true);
      return;
    }
    current = r.message;
    mode = 'read';
    m.read = true;
    setCounts(r.counts);
  }

  function compose(prefill = {}) {
    mode = 'compose';
    current = null;
    draft = { to: prefill.to ?? '', subject: prefill.subject ?? '', body: prefill.body ?? '' };
    error = '';
  }

  function reply() {
    if (!current) return;
    const to = current.folder === 'sent' ? current.to : current.from;
    const subject = /^re:/i.test(current.subject) ? current.subject : `Re: ${current.subject}`;
    const quote = current.body.split('\n').map((l) => `> ${l}`).join('\n');
    compose({ to, subject, body: `\n\n${quote}` });
  }

  async function send() {
    if (busy) return;
    busy = true;
    error = '';
    const r = await post('mailSend', { to: draft.to, subject: draft.subject, body: draft.body });
    busy = false;
    if (!r?.ok) {
      error = scopedError(r?.reason, 'mail');
      return;
    }
    setCounts(r.counts);
    mode = 'read';
    sentFlash = true;
    setTimeout(() => (sentFlash = false), 2200);
    if (folder === 'sent') loadList(true);
  }

  async function edit(action, extra = {}) {
    if (!current) return;
    const r = await post('mailEdit', { action, ids: [current.id], ...extra });
    if (!r?.ok) {
      error = scopedError(r?.reason, 'mail');
      return;
    }
    setCounts(r.counts);
    if (action === 'star') current = { ...current, starred: extra.on === true };
    else current = null;
    await loadList(true);
  }

  async function eraseNow() {
    if (!sure) {
      sure = true;
      setTimeout(() => (sure = false), 3000);
      return;
    }
    sure = false;
    await edit('erase');
  }

  async function emptyTrash() {
    const r = await post('mailEdit', { action: 'empty', ids: [] });
    if (r?.ok) {
      setCounts(r.counts);
      loadList(true);
    }
  }

  async function signOut() {
    await post('mailLogout');
    account = null;
    messages = [];
    current = null;
    mode = 'read';
    comms.badges.mail = 0;
    gate = 'login';
  }

  async function changePassword() {
    if (busy) return;
    busy = true;
    error = '';
    pw.done = false;
    const r = await post('mailPassword', { old: pw.old, new: pw.next });
    busy = false;
    if (!r?.ok) {
      error = errFor(r);
      return;
    }
    pw = { old: '', next: '', done: true };
  }

  function whenText(at) {
    const day = stampDay(at, Date.now());
    return `${day}, ${stampTime(at, time24)}`;
  }
  const shortWhen = (at) => stampDay(at, Date.now());
  const who = (m) => (folder === 'sent' ? m.to : m.fromName || m.from);
</script>

{#if !ready}
  <div class="wait"><p class="ap-empty">{t('common.loading')}</p></div>
{:else if !account}
  <div class="gate">
    <div class="card">
      <div class="logo"><Glyph name="mail" size={34} stroke={1.8} /></div>
      <h2>{t('mail.welcome')}</h2>
      <p class="ap-note">{t('mail.tagline', { domain })}</p>

      {#if gate === 'recovery'}
        <div class="ap-form">
          <h3>{t('mail.recoveryTitle')}</h3>
          <p class="ap-note">{t('mail.recoveryText')}</p>
          <div class="code">{recoveryCode}</div>
          <button class="ap-btn main" onclick={finishRecovery}>{t('mail.recoveryDone')}</button>
        </div>
      {:else}
        <Segmented
          options={[
            { value: 'login', label: t('mail.signIn') },
            { value: 'create', label: t('mail.create') },
          ]}
          value={gate === 'create' ? 'create' : 'login'}
          onchange={switchGate}
          label={t('app.mail')}
        />
        <form class="ap-form" onsubmit={(e) => e.preventDefault()}>
          <label>
            <span>{t('mail.address')}</span>
            <span class="addr">
              <input type="text" bind:value={g.address} maxlength="30" placeholder={t('mail.addressPlaceholder')} autocapitalize="off" spellcheck="false" />
              <em>@{domain}</em>
            </span>
          </label>
          {#if gate === 'create'}
            <label>
              <span>{t('mail.name')}</span>
              <input type="text" bind:value={g.name} maxlength="60" placeholder={t('mail.namePlaceholder')} />
            </label>
          {/if}
          {#if gate === 'reset'}
            <label>
              <span>{t('mail.code')}</span>
              <input type="text" bind:value={g.code} maxlength="16" placeholder="XXXX-XXXX-XXXX" autocapitalize="characters" spellcheck="false" />
            </label>
          {/if}
          <label>
            <span>{gate === 'reset' ? t('mail.newPassword') : t('mail.password')}</span>
            <input type="password" bind:value={g.password} maxlength="40" />
          </label>
          {#if gate === 'create' || gate === 'reset'}
            <label>
              <span>{t('mail.passwordAgain')}</span>
              <input type="password" bind:value={g.password2} maxlength="40" />
            </label>
          {/if}
          {#if gateError}<p class="ap-err">{gateError}</p>{/if}
          {#if gate === 'login'}
            <button class="ap-btn main" onclick={signIn} disabled={gateBusy || !g.address.trim() || !g.password}>{t('mail.signIn')}</button>
            <button class="link" onclick={() => switchGate('reset')}>{t('mail.forgot')}</button>
          {:else if gate === 'create'}
            <button class="ap-btn main" onclick={createAccount} disabled={gateBusy || !g.address.trim() || !g.password}>{t('mail.create')}</button>
          {:else}
            <button class="ap-btn main" onclick={resetPassword} disabled={gateBusy || !g.address.trim() || !g.code.trim() || !g.password}>{t('mail.reset')}</button>
            <button class="link" onclick={() => switchGate('login')}>{t('mail.backToSignIn')}</button>
          {/if}
        </form>
      {/if}
    </div>
  </div>
{:else}
  {#snippet listing()}
    <div class="ap-head">
      <h2>{t('app.mail')}</h2>
      <div class="ap-tools">
        <button class="ap-round" onclick={() => (mode = 'account', (current = null), (error = ''))} aria-label={t('mail.account')}><Glyph name="user" size={18} stroke={2} /></button>
        <button class="ap-plus" onclick={() => compose()} aria-label={t('mail.compose')}><Glyph name="edit" size={19} stroke={2.2} /></button>
      </div>
    </div>
    <Segmented options={folders} value={folder} onchange={pickFolder} label={t('app.mail')} />

    {#if loading && messages.length === 0}
      <p class="ap-empty">{t('common.loading')}</p>
    {:else if messages.length === 0}
      <p class="ap-empty">{t(`mail.empty.${folder}`)}</p>
    {:else}
      <ul class="ap-list mails">
        {#each messages as m (m.id)}
          <li>
            <button class="ap-row mrow" class:on={current?.id === m.id} onclick={() => openMessage(m)}>
              <span class="dot" class:unread={!m.read && folder !== 'sent'}></span>
              <span class="txt">
                <span class="l1"><b class:bold={!m.read && folder !== 'sent'}>{who(m)}</b><i>{shortWhen(m.at)}</i></span>
                <span class="subj">{#if m.starred}<Glyph name="star-fill" size={12} />{/if}{m.subject}</span>
                <span class="prev">{m.preview}</span>
              </span>
            </button>
          </li>
        {/each}
      </ul>
      {#if more}<button class="ap-btn more" onclick={() => loadList(false)} disabled={loading}>{t('common.loadMore')}</button>{/if}
    {/if}
    {#if folder === 'trash' && messages.length}
      <p class="ap-note trashnote">{t('mail.trashNote', { days: limits.keepTrashDays })}</p>
      <button class="ap-btn red more" onclick={emptyTrash}>{t('mail.emptyTrash')}</button>
    {/if}
  {/snippet}

  {#snippet side()}
    {#if mode === 'compose'}
      <div class="ap-form">
        <h2>{t('mail.compose')}</h2>
        <label>
          <span>{t('mail.to')}</span>
          <input type="text" bind:value={draft.to} maxlength="60" placeholder={`name@${domain}`} autocapitalize="off" spellcheck="false" />
        </label>
        <label>
          <span>{t('mail.subject')}</span>
          <input type="text" bind:value={draft.subject} maxlength={limits.subjectLength} placeholder={t('mail.subjectPlaceholder')} />
        </label>
        <label>
          <span>{t('mail.message')}</span>
          <textarea bind:value={draft.body} maxlength={limits.bodyLength} rows="8" placeholder={t('mail.messagePlaceholder')}></textarea>
        </label>
        {#if error}<p class="ap-err">{error}</p>{/if}
        <div class="ap-btns">
          <button class="ap-btn" onclick={() => (mode = 'read')}>{t('common.cancel')}</button>
          <button class="ap-btn main" onclick={send} disabled={busy || !draft.to.trim() || (!draft.subject.trim() && !draft.body.trim())}>{t('mail.send')}</button>
        </div>
      </div>
    {:else if mode === 'account'}
      <div class="ap-form">
        <h2>{t('mail.account')}</h2>
        <div class="me"><b>{account.address}</b>{#if account.name}<span>{account.name}</span>{/if}</div>
        <h3>{t('mail.changePassword')}</h3>
        <label><span>{t('mail.oldPassword')}</span><input type="password" bind:value={pw.old} maxlength="40" /></label>
        <label><span>{t('mail.newPassword')}</span><input type="password" bind:value={pw.next} maxlength="40" /></label>
        {#if error}<p class="ap-err">{error}</p>{/if}
        {#if pw.done}<p class="ap-note ok">{t('mail.passwordChanged')}</p>{/if}
        <div class="ap-btns">
          <button class="ap-btn red" onclick={signOut}>{t('mail.signOut')}</button>
          <button class="ap-btn main" onclick={changePassword} disabled={busy || !pw.old || !pw.next}>{t('mail.changePassword')}</button>
        </div>
        <p class="ap-note">{t('mail.recoveryReminder')}</p>
      </div>
    {:else if current}
      <div class="read">
        <h2 class="subject">{current.subject}</h2>
        <div class="meta">
          <div><span>{t('mail.from')}</span><b>{current.fromName ? `${current.fromName} <${current.from}>` : current.from}</b></div>
          <div><span>{t('mail.to')}</span><b>{current.to}</b></div>
          <div><span>{t('mail.date')}</span><b>{whenText(current.at)}</b></div>
        </div>
        <div class="body">{current.body}</div>
        {#if error}<p class="ap-err">{error}</p>{/if}
        <div class="ap-btns acts">
          {#if current.folder === 'trash'}
            <button class="ap-btn" onclick={() => edit('restore')}>{t('mail.restore')}</button>
            <button class="ap-btn red" onclick={eraseNow}>{sure ? t('mail.deleteSure') : t('mail.deleteForever')}</button>
          {:else}
            <button class="ap-btn" onclick={() => edit('star', { on: !current.starred })}>{current.starred ? t('mail.unstar') : t('mail.star')}</button>
            {#if current.folder === 'inbox'}<button class="ap-btn" onclick={() => edit('read', { on: false })}>{t('mail.markUnread')}</button>{/if}
            <button class="ap-btn" onclick={reply}>{t('mail.reply')}</button>
            <button class="ap-btn red" onclick={() => edit('trash')}>{t('mail.delete')}</button>
          {/if}
        </div>
      </div>
    {:else}
      <div class="ap-none">
        <Glyph name="mail" size={44} stroke={1.6} />
        {#if sentFlash}<p class="ok">{t('mail.sentOk')}</p>{:else}<p>{t('mail.pick')}</p>{/if}
        <button class="ap-btn main" onclick={() => compose()}>{t('mail.compose')}</button>
      </div>
    {/if}
  {/snippet}

  <TwoPane list={listing} detail={side} cover="switch" showDetail={detailOpen} />
{/if}

<style>
  .wait,
  .gate {
    position: absolute;
    inset: 0;
    overflow-y: auto;
  }
  .wait {
    display: grid;
    place-items: center;
  }
  .gate {
    display: flex;
    justify-content: center;
    padding: 56px 22px 44px;
  }
  .card {
    width: 100%;
    max-width: 380px;
    display: flex;
    flex-direction: column;
    gap: 12px;
    align-self: flex-start;
  }
  .logo {
    width: 58px;
    height: 58px;
    display: grid;
    place-items: center;
    border-radius: 18px;
    background: #4f7df0;
    color: #fff;
  }
  .card h2 {
    margin: 4px 0 0;
    font-size: 26px;
  }
  .card h3 {
    margin: 0;
    font-size: 17px;
  }
  .addr {
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .addr input {
    flex: 1;
    min-width: 0;
  }
  .addr em {
    font-style: normal;
    font-size: 15px;
    color: var(--ink-3);
    white-space: nowrap;
  }
  .link {
    padding: 8px;
    font-size: 14px;
    font-weight: 700;
    color: var(--accent);
  }
  .code {
    padding: 16px;
    border-radius: 16px;
    background: var(--surface);
    border: 2px dashed var(--accent);
    font-family: var(--mono);
    font-size: 24px;
    font-weight: 700;
    letter-spacing: 0.08em;
    text-align: center;
    user-select: all;
  }
  .mrow {
    align-items: flex-start;
  }
  .dot {
    flex: none;
    width: 9px;
    height: 9px;
    margin-top: 6px;
    border-radius: 50%;
  }
  .dot.unread {
    background: var(--accent);
  }
  .txt {
    flex: 1;
    min-width: 0;
    display: flex;
    flex-direction: column;
    gap: 1px;
  }
  .l1 {
    display: flex;
    justify-content: space-between;
    gap: 8px;
    font-size: 14.5px;
  }
  .l1 b {
    font-weight: 600;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .l1 b.bold {
    font-weight: 800;
  }
  .l1 i {
    flex: none;
    font-style: normal;
    font-size: 12px;
    color: var(--ink-3);
  }
  .subj {
    display: flex;
    align-items: center;
    gap: 4px;
    font-size: 14px;
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .subj :global(svg) {
    color: #e0a21e;
    flex: none;
  }
  .prev {
    font-size: 13px;
    color: var(--ink-3);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .more {
    width: 100%;
    margin-top: 10px;
  }
  .trashnote {
    margin-top: 12px;
  }
  .read {
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .subject {
    margin: 0;
    font-size: 21px;
    font-weight: 700;
    word-break: break-word;
  }
  .meta {
    display: flex;
    flex-direction: column;
    gap: 4px;
    padding: 10px 12px;
    border-radius: 14px;
    background: var(--surface-2);
    font-size: 13.5px;
  }
  .meta span {
    display: inline-block;
    min-width: 44px;
    margin-right: 6px;
    color: var(--ink-3);
  }
  .meta b {
    font-weight: 600;
    word-break: break-all;
  }
  .body {
    white-space: pre-wrap;
    word-break: break-word;
    font-size: 15px;
    line-height: 1.5;
  }
  .acts {
    justify-content: flex-start;
  }
  .me {
    display: flex;
    flex-direction: column;
    gap: 2px;
    padding: 12px 14px;
    border-radius: 14px;
    background: var(--surface-2);
  }
  .me span {
    font-size: 13px;
    color: var(--ink-3);
  }
  .ok {
    color: #1b8f6c;
    font-weight: 600;
  }
</style>
