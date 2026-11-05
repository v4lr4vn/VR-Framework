<script>
  import { nui, money } from '../lib/api.js';

  let { p, onclose } = $props();

  const STATUS = { open: ['New', 'info'], billed: ['Billed', 'warn'], paid: ['Paid', 'accent'] };
  let filter = $state('all');
  const now = Math.floor(Date.now() / 1000);
  const ago = (t) => {
    const s = Math.max(0, now - (t || now));
    if (s < 3600) return `${Math.max(1, Math.floor(s / 60))}m ago`;
    if (s < 86400) return `${Math.floor(s / 3600)}h ago`;
    return `${Math.floor(s / 86400)}d ago`;
  };
  let list = $derived(filter === 'all' ? p.orders : p.orders.filter((o) => o.status === filter));
  const count = (k) => p.orders.filter((o) => o.status === k).length;
</script>

<section class="board card" aria-label="Work orders">
  <header>
    <span class="logo"><i class="fa-solid fa-clipboard-list"></i></span>
    <div class="title"><h1>Work orders</h1><p class="sub">Customer orders and paid jobs waiting to be fitted</p></div>
    <button class="x" onclick={onclose} aria-label="Close"><i class="fa-solid fa-xmark"></i></button>
  </header>

  <nav class="tabs">
    <button class="tab" class:on={filter === 'all'} onclick={() => (filter = 'all')}>All <span class="count">{p.orders.length}</span></button>
    <button class="tab" class:on={filter === 'paid'} onclick={() => (filter = 'paid')}>To fit <span class="count">{count('paid')}</span></button>
    <button class="tab" class:on={filter === 'open'} onclick={() => (filter = 'open')}>New <span class="count">{count('open')}</span></button>
    <button class="tab" class:on={filter === 'billed'} onclick={() => (filter = 'billed')}>Billed <span class="count">{count('billed')}</span></button>
  </nav>

  <div class="list scroll">
    {#each list as o (o.id)}
      <button class="row" onclick={() => nui('openOrder', { id: o.id })}>
        <span class="id num">#{o.id}</span>
        <div class="rm">
          <span class="rv">{o.vehicle || 'Vehicle'} <span class="plate num">{o.plate}</span></span>
          <span class="hint">{o.customer || 'Customer'} · {o.workshop || 'Workshop'} · {ago(o.created)}</span>
        </div>
        <div class="rp">
          <span class="chip {STATUS[o.status]?.[1] || ''}">{STATUS[o.status]?.[0] || o.status}</span>
          <span class="hint num">{o.done}/{o.tasks} fitted</span>
        </div>
        <span class="num total">{money(o.total)}</span>
        <i class="fa-solid fa-chevron-right go"></i>
      </button>
    {/each}
    {#if !list.length}
      <div class="empty"><i class="fa-solid fa-clipboard"></i>No orders here</div>
    {/if}
  </div>
</section>

<style>
  .board { width: 680px; max-width: calc(100vw - 32px); height: 560px; max-height: calc(100vh - 32px); display: flex; flex-direction: column; overflow: hidden; }
  header { display: flex; align-items: center; gap: 12px; padding: 14px 16px; border-bottom: 1px solid var(--line-2); background: linear-gradient(180deg, rgba(26, 36, 51, 0.6), transparent); }
  .logo { width: 38px; height: 38px; border-radius: var(--radius); display: grid; place-items: center; background: var(--accent); color: var(--accent-ink); font-size: 15px; }
  .title { flex: 1; }
  h1 { font-size: 17px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.03em; }
  .sub { color: var(--muted); font-size: 12px; }
  .x { width: 34px; height: 34px; border-radius: var(--radius); border: 1px solid var(--line-3); background: var(--panel); color: var(--muted); }
  .x:hover { color: var(--text); border-color: var(--danger-line); background: var(--danger-bg); }
  .tabs { padding: 0 12px; }
  .list { flex: 1; min-height: 0; padding: 12px 16px 16px; display: flex; flex-direction: column; gap: 6px; }
  .row { display: grid; grid-template-columns: 44px 1fr 110px 80px 14px; align-items: center; gap: 12px; padding: 10px 12px; border-radius: var(--radius); border: 1px solid var(--line-2); background: var(--panel); color: inherit; text-align: left; }
  .row:hover { border-color: var(--accent-line); background: var(--panel-2); }
  .id { color: var(--accent-2); font-weight: 600; }
  .rm { display: flex; flex-direction: column; gap: 2px; min-width: 0; }
  .rv { font-size: 13px; font-weight: 700; display: flex; align-items: center; gap: 8px; }
  .plate { padding: 1px 6px; border-radius: 3px; background: #e9eef4; color: #18212d; font-size: 10px; font-weight: 600; letter-spacing: 0.08em; border: 1px solid #9fb0c4; }
  .rp { display: flex; flex-direction: column; align-items: flex-start; gap: 3px; }
  .rp .chip { height: 20px; font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; }
  .total { text-align: right; font-size: 13px; color: var(--text-2); }
  .go { color: var(--faint); font-size: 11px; }
</style>
