<script>
  import { untrack } from 'svelte';
  import Modal from '../../components/Modal.svelte';
  import Button from '../../components/Button.svelte';
  import Field from '../../components/Field.svelte';
  import Input from '../../components/Input.svelte';
  import Textarea from '../../components/Textarea.svelte';
  import Select from '../../components/Select.svelte';
  import Checkbox from '../../components/Checkbox.svelte';
  import { request, clock } from '../../lib/state.svelte.js';
  import { inDays } from './labels.js';

  let { open = $bindable(false), post = null, onsaved } = $props();

  let title = $state('');
  let body = $state('');
  let pinned = $state(false);
  let expiry = $state('0');
  let busy = $state(false);

  const editing = $derived(!!post?.id);
  const options = $derived([
    ...(post?.expiresAt && post.expiresAt > clock.now ? [{ value: 'keep', label: `Keep current, expires in ${inDays(post.expiresAt, clock.now)}` }] : []),
    { value: '0', label: 'Never' },
    { value: '1', label: 'After 1 day' },
    { value: '3', label: 'After 3 days' },
    { value: '7', label: 'After 1 week' },
    { value: '14', label: 'After 2 weeks' },
    { value: '30', label: 'After 30 days' },
    { value: '90', label: 'After 90 days' },
  ]);
  const valid = $derived(title.trim().length >= 3 && body.trim().length > 0);

  $effect(() => {
    if (!open) return;
    untrack(() => {
      title = post?.title || '';
      body = post?.body || '';
      pinned = !!post?.pinned;
      expiry = post?.expiresAt && post.expiresAt > clock.now ? 'keep' : '0';
      busy = false;
    });
  });

  async function submit(e) {
    e?.preventDefault();
    if (!valid || busy) return;
    busy = true;
    const data = { title: title.trim(), body, pinned };
    if (editing) data.id = post.id;
    if (expiry === 'keep') data.keepExpiry = true;
    else if (expiry !== '0') data.expiresDays = Number(expiry);
    const res = await request('bulletin.save', data, { success: editing ? 'Post updated' : 'Posted to the bulletin' });
    busy = false;
    if (res.ok) {
      open = false;
      onsaved?.(res.data);
    }
  }
</script>

<Modal bind:open title={editing ? 'Edit post' : 'New bulletin post'} width={600}>
  <form class="form" onsubmit={submit}>
    <Field label="Title" id="bp-title"><Input id="bp-title" bind:value={title} maxlength={96} placeholder="Shift briefing, policy change, event" autofocus /></Field>
    <Field label="Message" id="bp-body" hint="{body.length} / 8000">
      <Textarea id="bp-body" bind:value={body} rows={9} maxlength={8000} placeholder="What everyone needs to know" />
    </Field>
    <div class="row">
      <Checkbox id="bp-pin" bind:checked={pinned} label="Pin to the top" />
      <span class="grow"></span>
      <label class="lbl" for="bp-exp">Remove</label>
      <div class="exp"><Select id="bp-exp" bind:value={expiry} {options} /></div>
    </div>
  </form>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => (open = false)}>Cancel</Button>
    <Button variant="primary" icon={editing ? 'check' : 'megaphone'} busy={busy} disabled={!valid} onclick={submit}>{editing ? 'Save changes' : 'Post'}</Button>
  {/snippet}
</Modal>

<style>
  .form { display: flex; flex-direction: column; gap: 14px; }
  .row { display: flex; align-items: center; gap: 10px; }
  .grow { flex: 1; }
  .lbl { color: var(--muted); font-size: 12px; font-weight: 600; letter-spacing: 0.04em; text-transform: uppercase; }
  .exp { width: 250px; }
</style>
