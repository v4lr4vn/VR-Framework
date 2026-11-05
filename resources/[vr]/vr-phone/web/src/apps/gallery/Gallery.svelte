<script>
  import { onMount } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import Segmented from '../../ui/kit/Segmented.svelte';
  import { phone, onBack, openApp } from '../../lib/store.svelte.js';
  import {
    media,
    loadPhotos,
    loadStats,
    showView,
    fetchPhoto,
    editPhotos,
    albumAction,
    startShare,
    mediaError,
  } from '../../lib/media.svelte.js';
  import { t } from '../../lib/i18n.js';

  // The photos on one side, the chosen photo on the other (the same split as Contacts).
  //   cover (closed): the grid, and the photo opens over it. Back returns to the grid
  //   flex (half open): the photo on top, the grid below
  //   open: the grid on the left, the photo on the right
  let pick = $state(null); // the id of the photo being looked at
  let picture = $state(null); // its full picture
  let loadingPicture = $state(false);
  let info = $state(false);
  let select = $state(false);
  let chosen = $state([]);
  let error = $state('');
  let sure = $state(false);
  let albumMenu = $state(false);
  let naming = $state(null); // 'new' or the id of the album being renamed
  let nameText = $state('');

  const tabs = $derived([
    { value: 'all', label: t('gallery.photos') },
    { value: 'favourites', label: t('gallery.favourites') },
    { value: 'albums', label: t('gallery.albums') },
    { value: 'deleted', label: t('gallery.deleted') },
  ]);
  const tab = $derived(media.view === 'album' ? 'albums' : media.view);
  const current = $derived(media.items.find((p) => p.id === pick) ?? null);
  const index = $derived(media.items.findIndex((p) => p.id === pick));
  const inTrash = $derived(media.view === 'deleted');
  const albumName = $derived(media.albums.find((a) => a.id === media.album)?.name ?? '');
  const detailOpen = $derived(pick !== null);

  onMount(() => {
    if (!media.loaded) showView('all');
    loadStats();
  });

  // A new photo (camera, nearby share) arrived while the app is open.
  let seenRev = media.rev;
  $effect(() => {
    if (media.rev !== seenRev) {
      seenRev = media.rev;
      loadPhotos(true);
      loadStats();
    }
  });

  // Back leaves a photo, then a selection, then an album.
  $effect(() =>
    onBack(() => {
      if (naming !== null) {
        naming = null;
        return true;
      }
      if (select) {
        stopSelect();
        return true;
      }
      if (pick !== null && phone.fold === 'cover') {
        close();
        return true;
      }
      if (media.view === 'album') {
        showView('albums');
        close();
        return true;
      }
      return false;
    }),
  );

  async function show(photo) {
    if (select) {
      toggle(photo.id);
      return;
    }
    pick = photo.id;
    info = false;
    error = '';
    sure = false;
    albumMenu = false;
    picture = null;
    loadingPicture = true;
    const p = await fetchPhoto(photo.id);
    if (pick === photo.id) {
      picture = p;
      loadingPicture = false;
      if (!p) error = mediaError('not_found');
    }
  }

  function close() {
    pick = null;
    picture = null;
    info = false;
    error = '';
    sure = false;
    albumMenu = false;
  }

  function step(delta) {
    const next = media.items[index + delta];
    if (next) show(next);
  }

  function chooseTab(value) {
    close();
    stopSelect();
    showView(value);
  }

  function startSelect() {
    select = true;
    chosen = [];
    close();
  }
  function stopSelect() {
    select = false;
    chosen = [];
  }
  function toggle(id) {
    chosen = chosen.includes(id) ? chosen.filter((x) => x !== id) : [...chosen, id];
  }

  // After a change the grid reloads, so a photo that left the list closes.
  async function run(action, ids, extra) {
    error = '';
    const r = await editPhotos(action, ids, extra);
    if (!r.ok) {
      error = mediaError(r.reason);
      return false;
    }
    if (pick !== null && !media.items.some((p) => p.id === pick)) close();
    return true;
  }

  const favourite = () => current && run('favourite', [current.id], { on: !current.favourite });
  const trash = () => current && run('trash', [current.id]);
  const restore = () => current && run('restore', [current.id]);

  async function erase() {
    if (!current) return;
    if (!sure) {
      sure = true;
      setTimeout(() => (sure = false), 3000);
      return;
    }
    sure = false;
    run('erase', [current.id]);
  }

  async function emptyTrash() {
    if (!sure) {
      sure = true;
      setTimeout(() => (sure = false), 3000);
      return;
    }
    sure = false;
    run('empty');
  }

  async function batch(action) {
    if (!chosen.length) return;
    const ok = await run(action, chosen);
    if (ok) stopSelect();
  }

  async function intoAlbum(id) {
    albumMenu = false;
    if (current) run('album', [current.id], { album: id });
  }

  function shareOne() {
    if (current) startShare('photo', [current.id], t('gallery.onePhoto'));
  }
  function shareMany() {
    if (chosen.length) startShare('photo', chosen, t('gallery.nPhotos', { n: chosen.length }));
  }

  async function saveName() {
    const text = nameText.trim();
    if (!text) return;
    const r = naming === 'new' ? await albumAction({ action: 'create', name: text }) : await albumAction({ action: 'rename', id: naming, name: text });
    if (!r.ok) {
      error = mediaError(r.reason);
      return;
    }
    naming = null;
    error = '';
  }

  function newAlbum() {
    naming = 'new';
    nameText = '';
    error = '';
  }
  function renameAlbum(a) {
    naming = a.id;
    nameText = a.name;
    error = '';
  }
  async function dropAlbum(a) {
    if (!sure) {
      sure = true;
      setTimeout(() => (sure = false), 3000);
      return;
    }
    sure = false;
    await albumAction({ action: 'remove', id: a.id });
  }

  function when(at) {
    const d = new Date(at * 1000);
    return d.toLocaleString(undefined, { day: 'numeric', month: 'short', year: 'numeric', hour: '2-digit', minute: '2-digit' });
  }
  function size(bytes) {
    const n = Number(bytes) || 0;
    return n > 1048576 ? `${(n / 1048576).toFixed(1)} MB` : `${Math.max(1, Math.round(n / 1024))} KB`;
  }
  const daysLeft = (photo) => Math.max(0, media.limits.keepDeletedDays - Math.floor((Date.now() / 1000 - photo.deletedAt) / 86400));
</script>

{#snippet roll()}
  <div class="head">
    <h2>{media.view === 'album' ? albumName : t('app.gallery')}</h2>
    <div class="tools">
      {#if media.view !== 'albums' && media.items.length}
        <button class="pill" class:on={select} onclick={() => (select ? stopSelect() : startSelect())}>{select ? t('common.cancel') : t('gallery.select')}</button>
      {/if}
      <button class="pill cam" onclick={() => openApp('camera')} aria-label={t('app.camera')}><Glyph name="camera" size={18} stroke={2} /></button>
    </div>
  </div>

  {#if media.view === 'album'}
    <button class="crumb" onclick={() => showView('albums')}><Glyph name="chev-left" size={16} stroke={2.2} />{t('gallery.albums')}</button>
  {:else}
    <Segmented options={tabs} value={tab} onchange={chooseTab} label={t('app.gallery')} />
  {/if}

  {#if media.view === 'albums'}
    <div class="albums">
      <button class="album new" onclick={newAlbum}><span class="cover"><Glyph name="plus" size={24} stroke={2.2} /></span><span class="aname">{t('gallery.newAlbum')}</span></button>
      {#each media.albums as a (a.id)}
        <div class="album">
          <button class="cover open" onclick={() => showView('album', a.id)} aria-label={a.name}><Glyph name="folder" size={26} stroke={1.8} /></button>
          <span class="aname">{a.name}</span>
          <span class="acount">{a.count}</span>
          <span class="aacts">
            <button onclick={() => renameAlbum(a)} aria-label={t('contacts.edit')}><Glyph name="edit" size={16} stroke={2} /></button>
            <button class="red" onclick={() => dropAlbum(a)} aria-label={t('gallery.delete')}>
              {#if sure}<b>{t('contacts.deleteSure')}</b>{:else}<Glyph name="trash" size={16} stroke={2} />{/if}
            </button>
          </span>
        </div>
      {/each}
    </div>
    {#if naming !== null}
      <div class="naming">
        <input type="text" bind:value={nameText} maxlength="24" placeholder={t('gallery.albumName')} onkeydown={(e) => e.key === 'Enter' && saveName()} />
        <button class="go" onclick={saveName} disabled={!nameText.trim()}>{t('contacts.save')}</button>
      </div>
    {/if}
    {#if error}<p class="err">{error}</p>{/if}
  {:else if !media.loaded}
    <div class="center"><span class="spin"></span></div>
  {:else if media.items.length === 0}
    <p class="empty">{t(`gallery.empty.${media.view}`)}</p>
  {:else}
    {#if inTrash}
      <p class="hint">{t('gallery.trashHint', { days: media.limits.keepDeletedDays })}</p>
    {/if}
    <ul class="thumbs">
      {#each media.items as p (p.id)}
        <li>
          <button class="th" class:on={pick === p.id} class:sel={chosen.includes(p.id)} onclick={() => show(p)} aria-label={t('gallery.open')}>
            <img src={p.thumb} alt="" loading="lazy" />
            {#if p.favourite}<span class="fav"><Glyph name="star-fill" size={13} /></span>{/if}
            {#if select}<span class="tick" class:on={chosen.includes(p.id)}>{#if chosen.includes(p.id)}<Glyph name="check" size={14} stroke={3} />{/if}</span>{/if}
          </button>
        </li>
      {/each}
    </ul>
    {#if media.more}
      <button class="more" onclick={() => loadPhotos(false)} disabled={media.loading}>{t('common.loadMore')}</button>
    {/if}
    {#if inTrash}
      <button class="more red" onclick={emptyTrash}>{sure ? t('gallery.emptySure') : t('gallery.emptyTrash')}</button>
    {/if}
  {/if}

  {#if select}
    <div class="selbar">
      <span>{t('gallery.chosen', { n: chosen.length })}</span>
      <span class="selacts">
        {#if inTrash}
          <button disabled={!chosen.length} onclick={() => batch('restore')}><Glyph name="restore" size={18} stroke={2} />{t('gallery.restore')}</button>
          <button class="red" disabled={!chosen.length} onclick={() => batch('erase')}><Glyph name="trash" size={18} stroke={2} />{t('gallery.erase')}</button>
        {:else}
          <button disabled={!chosen.length} onclick={shareMany}><Glyph name="share" size={18} stroke={2} />{t('gallery.share')}</button>
          <button class="red" disabled={!chosen.length} onclick={() => batch('trash')}><Glyph name="trash" size={18} stroke={2} />{t('gallery.delete')}</button>
        {/if}
      </span>
    </div>
  {/if}
{/snippet}

{#snippet viewer()}
  {#if current}
    <div class="view" class:half={phone.fold === 'flex'}>
      <div class="frame">
        {#if picture}
          <img class="big" src={picture.image} alt="" />
        {:else}
          <img class="big blur" src={current.thumb} alt="" />
          {#if loadingPicture}<span class="spin over"></span>{/if}
        {/if}
        {#if index > 0}<button class="nav l" onclick={() => step(-1)} aria-label={t('gallery.previous')}><Glyph name="chev-left" size={22} stroke={2.4} /></button>{/if}
        {#if index >= 0 && index < media.items.length - 1}<button class="nav r" onclick={() => step(1)} aria-label={t('gallery.next')}><Glyph name="chev-right" size={22} stroke={2.4} /></button>{/if}
      </div>

      <div class="acts">
        {#if inTrash}
          <button onclick={restore}><Glyph name="restore" size={20} stroke={2} /><span>{t('gallery.restore')}</span></button>
          <button class="red" onclick={erase}><Glyph name="trash" size={20} stroke={2} /><span>{sure ? t('contacts.deleteSure') : t('gallery.erase')}</span></button>
          <p class="left">{t('gallery.daysLeft', { n: daysLeft(current) })}</p>
        {:else}
          <button class:gold={current.favourite} onclick={favourite}><Glyph name={current.favourite ? 'star-fill' : 'star'} size={20} stroke={2} /><span>{current.favourite ? t('contacts.unfavourite') : t('contacts.favourite')}</span></button>
          <button onclick={shareOne}><Glyph name="share" size={20} stroke={2} /><span>{t('gallery.share')}</span></button>
          <button onclick={() => (albumMenu = !albumMenu)}><Glyph name="folder" size={20} stroke={2} /><span>{t('gallery.addToAlbum')}</span></button>
          <button onclick={() => (info = !info)}><Glyph name="info" size={20} stroke={2} /><span>{t('gallery.info')}</span></button>
          <button class="red" onclick={trash}><Glyph name="trash" size={20} stroke={2} /><span>{t('gallery.delete')}</span></button>
        {/if}
      </div>

      {#if albumMenu}
        <div class="menu">
          {#each media.albums as a (a.id)}
            <button class:on={current.album === a.id} onclick={() => intoAlbum(a.id)}>{a.name}{#if current.album === a.id}<Glyph name="check" size={16} stroke={2.6} />{/if}</button>
          {/each}
          {#if current.album}<button class="red" onclick={() => intoAlbum(null)}>{t('gallery.removeFromAlbum')}</button>{/if}
          {#if !media.albums.length}<p class="hint">{t('gallery.noAlbums')}</p>{/if}
        </div>
      {/if}

      {#if info && picture}
        <dl class="info">
          <div><dt>{t('gallery.taken')}</dt><dd>{when(picture.at)}</dd></div>
          <div><dt>{t('gallery.size')}</dt><dd>{picture.width} × {picture.height} · {size(picture.bytes)}</dd></div>
          <div><dt>{t('gallery.from')}</dt><dd>{t(`gallery.source.${picture.source}`)}</dd></div>
        </dl>
      {/if}
      {#if error}<p class="err">{error}</p>{/if}
    </div>
  {:else}
    <div class="none">
      <Glyph name="gallery" size={44} stroke={1.6} />
      <p>{t('gallery.pick')}</p>
    </div>
  {/if}
{/snippet}

<TwoPane list={roll} detail={viewer} cover="switch" showDetail={detailOpen} />

<style>
  .head {
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    margin-bottom: 10px;
  }
  h2 {
    margin: 0;
    min-width: 0;
    font-size: 24px;
    font-weight: 700;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .tools {
    display: flex;
    gap: 6px;
  }
  .pill {
    height: 36px;
    padding: 0 14px;
    border-radius: 18px;
    background: var(--surface-2);
    font-size: 13.5px;
    font-weight: 700;
    color: var(--ink);
  }
  .pill.on,
  .pill.cam {
    background: var(--accent);
    color: var(--on-accent);
  }
  .pill.cam {
    width: 38px;
    padding: 0;
    display: grid;
    place-items: center;
  }
  .crumb {
    display: inline-flex;
    align-items: center;
    gap: 4px;
    margin-bottom: 4px;
    font-size: 14px;
    font-weight: 700;
    color: var(--accent);
  }

  .thumbs {
    list-style: none;
    margin: 12px 0 0;
    padding: 0;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(84px, 1fr));
    gap: 4px;
  }
  .th {
    position: relative;
    display: block;
    width: 100%;
    aspect-ratio: 1;
    overflow: hidden;
    border-radius: 10px;
    background: var(--surface-2);
  }
  .th img {
    width: 100%;
    height: 100%;
    object-fit: cover;
    display: block;
  }
  .th.on {
    outline: 3px solid var(--accent);
    outline-offset: -3px;
  }
  .th.sel img {
    opacity: 0.7;
  }
  .fav {
    position: absolute;
    left: 5px;
    bottom: 5px;
    color: #ffd24d;
    filter: drop-shadow(0 1px 2px rgba(0, 0, 0, 0.6));
  }
  .tick {
    position: absolute;
    right: 5px;
    top: 5px;
    width: 22px;
    height: 22px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    border: 2px solid #fff;
    background: rgba(0, 0, 0, 0.3);
    color: #fff;
  }
  .tick.on {
    background: var(--accent);
    border-color: var(--accent);
  }
  .more {
    width: 100%;
    margin-top: 12px;
    padding: 11px;
    border-radius: 14px;
    background: var(--surface-2);
    font-size: 14px;
    font-weight: 700;
    color: var(--ink);
  }
  .more.red,
  .red {
    color: #e5484d;
  }
  .more:disabled {
    opacity: 0.5;
  }
  .empty,
  .hint {
    margin: 16px 4px 4px;
    font-size: 14px;
    line-height: 1.45;
    color: var(--ink-3);
  }
  .center {
    display: grid;
    place-items: center;
    padding: 40px 0;
  }
  .spin {
    width: 28px;
    height: 28px;
    border-radius: 50%;
    border: 3px solid var(--line);
    border-top-color: var(--accent);
    animation: spin 0.8s linear infinite;
  }
  .spin.over {
    position: absolute;
    inset: 0;
    margin: auto;
  }
  @keyframes spin {
    to {
      transform: rotate(360deg);
    }
  }

  .selbar {
    position: sticky;
    bottom: 0;
    margin-top: 12px;
    padding: 10px 12px;
    display: flex;
    align-items: center;
    justify-content: space-between;
    gap: 8px;
    border-radius: 16px;
    background: var(--surface);
    box-shadow: 0 -2px 14px rgba(0, 0, 0, 0.14);
    font-size: 13.5px;
    font-weight: 700;
  }
  .selacts {
    display: flex;
    gap: 6px;
  }
  .selacts button {
    display: inline-flex;
    align-items: center;
    gap: 5px;
    padding: 7px 11px;
    border-radius: 12px;
    background: var(--surface-2);
    font-size: 13px;
    font-weight: 700;
    color: var(--ink);
  }
  .selacts button.red {
    color: #e5484d;
  }
  .selacts button:disabled {
    opacity: 0.4;
  }

  .albums {
    margin-top: 12px;
    display: flex;
    flex-direction: column;
    gap: 6px;
  }
  .album {
    display: flex;
    align-items: center;
    gap: 12px;
    padding: 8px;
    border-radius: 14px;
    background: var(--surface);
  }
  .cover {
    width: 48px;
    height: 48px;
    flex: none;
    display: grid;
    place-items: center;
    border-radius: 12px;
    background: var(--surface-2);
    color: var(--accent);
  }
  .album.new {
    width: 100%;
    background: none;
    color: var(--accent);
    font-weight: 700;
  }
  .aname {
    flex: 1;
    min-width: 0;
    font-size: 15.5px;
    font-weight: 600;
    text-align: left;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .acount {
    font-size: 13px;
    color: var(--ink-3);
  }
  .aacts {
    display: flex;
    gap: 2px;
  }
  .aacts button {
    height: 32px;
    min-width: 32px;
    padding: 0 6px;
    display: grid;
    place-items: center;
    border-radius: 10px;
    color: var(--ink-2);
    font-size: 12px;
  }
  .naming {
    display: flex;
    gap: 8px;
    margin-top: 10px;
  }
  .naming input {
    flex: 1;
    min-width: 0;
    height: 44px;
    padding: 0 14px;
    border-radius: 14px;
    border: 1px solid var(--line);
    background: var(--surface);
    font-size: 15px;
    color: var(--ink);
  }
  .go {
    padding: 0 16px;
    border-radius: 14px;
    background: var(--accent);
    color: var(--on-accent);
    font-weight: 700;
  }
  .go:disabled {
    opacity: 0.45;
  }

  .view {
    display: flex;
    flex-direction: column;
    gap: 10px;
  }
  .frame {
    position: relative;
    min-height: 120px;
    border-radius: 18px;
    overflow: hidden;
    background: #000;
    display: grid;
    place-items: center;
  }
  .big {
    display: block;
    width: 100%;
    max-height: 56vh;
    object-fit: contain;
  }
  /* The small copy shows while the full picture comes; it is only a little soft because it is small. */
  /* Half open: the photo has only the top half of the screen. */
  .half .big {
    max-height: 30vh;
  }
  .big.blur {
    opacity: 0.8;
  }
  .nav {
    position: absolute;
    top: 50%;
    width: 36px;
    height: 36px;
    margin-top: -18px;
    display: grid;
    place-items: center;
    border-radius: 50%;
    background: rgba(0, 0, 0, 0.45);
    color: #fff;
  }
  .nav.l {
    left: 8px;
  }
  .nav.r {
    right: 8px;
  }
  .acts {
    display: flex;
    flex-wrap: wrap;
    justify-content: space-between;
    gap: 4px;
  }
  .acts button {
    flex: 1;
    min-width: 58px;
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 4px;
    padding: 8px 2px;
    border-radius: 12px;
    font-size: 11.5px;
    font-weight: 700;
    color: var(--ink-2);
  }
  .acts button:hover {
    background: var(--surface-2);
  }
  .acts button.gold {
    color: #e0a21e;
  }
  .acts button.red {
    color: #e5484d;
  }
  .left {
    width: 100%;
    margin: 0;
    font-size: 12.5px;
    text-align: center;
    color: var(--ink-3);
  }
  .menu {
    display: flex;
    flex-direction: column;
    border-radius: 14px;
    background: var(--surface);
    padding: 2px 14px;
  }
  .menu button {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 12px 0;
    border-bottom: 1px solid var(--line);
    font-size: 14.5px;
    font-weight: 600;
    color: var(--ink);
    text-align: left;
  }
  .menu button:last-child {
    border-bottom: 0;
  }
  .menu button.on {
    color: var(--accent);
  }
  .info {
    margin: 0;
    padding: 4px 14px;
    border-radius: 14px;
    background: var(--surface);
  }
  .info div {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    padding: 10px 0;
    border-bottom: 1px solid var(--line);
    font-size: 13.5px;
  }
  .info div:last-child {
    border-bottom: 0;
  }
  .info dt {
    color: var(--ink-3);
  }
  .info dd {
    margin: 0;
    font-weight: 600;
    text-align: right;
  }
  .err {
    margin: 4px 0 0;
    font-size: 13.5px;
    font-weight: 600;
    color: #e5484d;
  }
  .none {
    display: flex;
    flex-direction: column;
    align-items: center;
    gap: 12px;
    margin-top: 60px;
    color: var(--ink-3);
    text-align: center;
  }
  .none p {
    margin: 0;
    font-size: 14.5px;
  }
</style>
