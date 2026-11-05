<script>
  import IconButton from '../../components/IconButton.svelte';
  import Icon from '../../components/Icon.svelte';
  import { agoWords, dateTime } from '../../lib/format.js';
  import { clock } from '../../lib/state.svelte.js';
  import { inDays } from './labels.js';

  let { post, canEdit = false, onedit, ondelete } = $props();
  let expanded = $state(false);

  const long = $derived(post.body.length > 420 || post.body.split('\n').length > 7);
  const edited = $derived(post.updatedAt && post.updatedAt - post.createdAt > 60);
</script>

<article class="post" class:pinned={post.pinned}>
  <header>
    {#if post.pinned}<span class="pin" title="Pinned"><Icon name="pushpin" size={14} /></span>{/if}
    <h3>{post.title}</h3>
    {#if canEdit}
      <div class="acts">
        <IconButton icon="edit" label="Edit post" size={28} onclick={() => onedit?.(post)} />
        <IconButton icon="trash" label="Delete post" size={28} variant="danger" onclick={() => ondelete?.(post)} />
      </div>
    {/if}
  </header>
  <p class="meta">
    <span class="author">{post.authorName || 'Command'}</span>{' · '}<span title={dateTime(post.createdAt)}>{agoWords(post.createdAt)}</span>
    {#if edited}{' · '}<span title={dateTime(post.updatedAt)}>edited</span>{/if}
    {#if post.expiresAt}{' · '}<span class="exp">expires in {inDays(post.expiresAt, clock.now)}</span>{/if}
  </p>
  <div class="body" class:clamp={long && !expanded}>{post.body}</div>
  {#if long}
    <button type="button" class="more" aria-expanded={expanded} onclick={() => (expanded = !expanded)}>{expanded ? 'Show less' : 'Show more'}</button>
  {/if}
</article>

<style>
  .post { display: flex; flex-direction: column; gap: 6px; padding: 14px 16px 16px; border-radius: var(--radius-lg); background: var(--panel); border: 1px solid var(--line-2); min-width: 0; }
  .pinned { border-color: var(--accent-line); box-shadow: inset 0 3px 0 var(--accent); }
  header { display: flex; align-items: flex-start; gap: 8px; min-width: 0; }
  .pin { color: var(--accent); padding-top: 3px; flex: none; }
  h3 { flex: 1; min-width: 0; font-size: 17px; font-weight: 700; line-height: 1.3; overflow-wrap: anywhere; }
  .acts { display: flex; gap: 2px; margin: -4px -6px 0 0; flex: none; }
  .meta { color: var(--muted); font-size: 13px; }
  .author { color: var(--text-2); font-weight: 600; }
  .exp { color: var(--p2-text); }
  .body { color: var(--text-2); line-height: 1.55; white-space: pre-wrap; overflow-wrap: anywhere; margin-top: 4px; user-select: text; }
  .clamp { display: -webkit-box; -webkit-line-clamp: 6; line-clamp: 6; -webkit-box-orient: vertical; overflow: hidden; }
  .more { align-self: flex-start; border: 0; background: transparent; padding: 0; color: var(--accent); font-weight: 600; font-size: 13px; }
  .more:hover { color: var(--accent-2); }
</style>
