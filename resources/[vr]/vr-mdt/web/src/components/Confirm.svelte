<script>
  import Modal from './Modal.svelte';
  import Button from './Button.svelte';
  import { confirmState, answerConfirm } from '../lib/confirm.svelte.js';
</script>

<Modal bind:open={confirmState.open} title={confirmState.title} width={440} onclose={() => answerConfirm(false)}>
  <p class="text">{confirmState.text}</p>
  {#snippet footer()}
    <Button variant="ghost" onclick={() => answerConfirm(false)}>{confirmState.no}</Button>
    <Button variant={confirmState.danger ? 'danger' : 'primary'} onclick={() => answerConfirm(true)}>{confirmState.yes}</Button>
  {/snippet}
</Modal>

<style>
  .text { color: var(--text-2); line-height: 1.5; }
</style>
