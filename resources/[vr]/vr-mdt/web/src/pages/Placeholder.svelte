<script>
  import Empty from '../components/Empty.svelte';
  let { label = 'This section' } = $props();
</script>

<div class="wrap">
  <Empty icon="settings" title={label} text="This section is being built." />
</div>

<style>
  .wrap { flex: 1; display: flex; }
</style>
