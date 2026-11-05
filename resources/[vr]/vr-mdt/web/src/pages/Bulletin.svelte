<script>
  import { untrack } from 'svelte';
  import Button from '../components/Button.svelte';
  import Empty from '../components/Empty.svelte';
  import Spinner from '../components/Spinner.svelte';
  import BulletinPost from './department/BulletinPost.svelte';
  import BulletinModal from './department/BulletinModal.svelte';
  import { request, session, can } from '../lib/state.svelte.js';
  import { confirm } from '../lib/confirm.svelte.js';
  import { on } from '../lib/nui.js';

  let items = $state([]);
  let page = $state(1);
  let more = $state(false);
  let loading = $state(true);
  let loadingMore = $state(false);
  let failed = $state(false);
  let composing = $state(false);
  let editing = $state(null);
  let timer;

  async function load(quiet = false) {
    if (!quiet) loading = true;
    const res = await request('bulletin.list', { page: 1 }, { quiet: true });
    loading = false;
    failed = !res.ok && !items.length;
    if (res.ok) {
      items = res.data.items;
      more = res.data.more;
      page = 1;
    }
  }

  async function loadMore() {
    loadingMore = true;
    const res = await request('bulletin.list', { page: page + 1 });
    loadingMore = false;
    if (res.ok) {
      const seen = new Set(items.map((p) => p.id));
      items = [...items, ...res.data.items.filter((p) => !seen.has(p.id))];
      more = res.data.more;
      page += 1;
    }
  }

  $effect(() => {
    untrack(() => load());
    const off = on('bulletin:changed', () => {
      clearTimeout(timer);
      timer = setTimeout(() => load(true), 200);
    });
    return () => {
      off();
      clearTimeout(timer);
    };
  });

  const pinned = $derived(items.filter((p) => p.pinned));
  const latest = $derived(items.filter((p) => !p.pinned));
  const canPost = $derived(can('bulletin.post'));

  function compose() {
    editing = null;
    composing = true;
  }

  function edit(post) {
    editing = post;
    composing = true;
  }

  async function remove(post) {
    const ok = await confirm({ title: 'Delete this post?', text: `"${post.title}" will be removed for everyone.`, yes: 'Delete', danger: true });
    if (!ok) return;
    const res = await request('bulletin.delete', { id: post.id }, { success: 'Post deleted' });
    if (res.ok) items = items.filter((p) => p.id !== post.id);
  }

  function saved(post) {
    const rest = items.filter((p) => p.id !== post.id);
    items = [post, ...rest].sort((a, b) => Number(b.pinned) - Number(a.pinned) || b.createdAt - a.createdAt || b.id - a.id);
  }
</script>

<div class="page">
  <header class="ph">
    <div>
      <h1>Bulletin</h1>
      <p class="muted">Notices for everyone in the {session.dept?.short || 'department'}</p>
    </div>
    {#if canPost}
      <Button variant="primary" icon="megaphone" onclick={compose}>New post</Button>
    {/if}
  </header>

  <div class="body scroll">
    {#if loading && !items.length}
      <Spinner label="Loading the bulletin" />
    {:else if failed}
      <Empty icon="alert" title="Couldn't load the bulletin">
        <Button icon="refresh" onclick={() => load()}>Try again</Button>
      </Empty>
    {:else if !items.length}
      <Empty icon="bulletin" title="Nothing posted" text={canPost ? 'Post shift briefings, policy changes and events here. Pinned posts stay on top.' : 'Command staff post briefings and announcements here.'}>
        {#if canPost}<Button icon="megaphone" onclick={compose}>Write the first post</Button>{/if}
      </Empty>
    {:else}
      <div class="cols" class:solo={!pinned.length}>
        <section class="feed">
          <h2 class="eyebrow">Latest · {latest.length}{more ? '+' : ''}</h2>
          {#each latest as post (post.id)}
            <BulletinPost {post} canEdit={canPost} onedit={edit} ondelete={remove} />
          {:else}
            <p class="none">Only pinned posts right now.</p>
          {/each}
          {#if more}
            <div class="moreRow"><Button icon="chevrondown" busy={loadingMore} onclick={loadMore}>Load older posts</Button></div>
          {/if}
        </section>
        {#if pinned.length}
          <section class="pins">
            <h2 class="eyebrow">Pinned · {pinned.length}</h2>
            {#each pinned as post (post.id)}
              <BulletinPost {post} canEdit={canPost} onedit={edit} ondelete={remove} />
            {/each}
          </section>
        {/if}
      </div>
    {/if}
  </div>
</div>

<BulletinModal bind:open={composing} post={editing} onsaved={saved} />

<style>
  .page { flex: 1; display: flex; flex-direction: column; min-height: 0; padding: 20px 24px 0; gap: 16px; }
  .ph { display: flex; align-items: flex-end; justify-content: space-between; gap: 20px; }
  h1 { font-size: 24px; font-weight: 700; }
  .body { flex: 1; min-height: 0; display: flex; flex-direction: column; gap: 22px; padding-bottom: 24px; }
  .cols { display: grid; grid-template-columns: minmax(0, 1fr) 460px; gap: 20px; align-items: start; }
  .cols.solo { grid-template-columns: minmax(0, 920px); }
  section { display: flex; flex-direction: column; gap: 10px; min-width: 0; }
  .pins { position: sticky; top: 0; }
  .none { color: var(--faint); padding: 8px 0; }
  .moreRow { display: flex; justify-content: center; padding-top: 4px; }
</style>
