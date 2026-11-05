<script>
  import { tick } from 'svelte';
  import Icon from '../Icon.svelte';
  import Glyph from '../Glyph.svelte';
  import { plain } from '../../lib/md.js';
  import { place, outside } from './popover.js';

  let { value = $bindable(null), row, error = '', multi = false } = $props();

  let open = $state(false);
  let query = $state('');
  let active = $state(0);
  let anchor = $state();
  let searchEl = $state();
  let style = $state('');

  const items = $derived((row.options || []).map((o) => (typeof o === 'object' && o !== null ? { value: o.value, label: plain(o.label ?? o.value) } : { value: o, label: plain(o) })));
  const shown = $derived(query ? items.filter((o) => o.label.toLowerCase().includes(query.toLowerCase())) : items);
  const picked = $derived(multi ? (Array.isArray(value) ? value : []) : value);
  const labelOf = (v) => items.find((o) => o.value === v)?.label ?? String(v);
  const isOn = (v) => (multi ? picked.includes(v) : picked === v);
  const limit = $derived(Number(row.maxSelectedValues) || 0);

  const toggle = async () => {
    if (row.disabled) return;
    open = !open;
    if (open) {
      query = '';
      active = Math.max(0, shown.findIndex((o) => isOn(o.value)));
      style = place(anchor, 260);
      await tick();
      searchEl?.focus();
    }
  };

  const choose = (o) => {
    if (!o) return;
    if (multi) {
      const cur = [...picked];
      const i = cur.indexOf(o.value);
      if (i >= 0) cur.splice(i, 1);
      else if (!limit || cur.length < limit) cur.push(o.value);
      value = cur;
    } else {
      value = o.value;
      open = false;
    }
  };

  const clear = (e) => {
    e.stopPropagation();
    value = multi ? [] : null;
  };

  const key = (e) => {
    if (!open) {
      if (e.key === 'Enter' || e.key === 'ArrowDown' || e.key === ' ') { e.preventDefault(); toggle(); }
      return;
    }
    if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); open = false; }
    else if (e.key === 'ArrowDown') { e.preventDefault(); active = Math.min(shown.length - 1, active + 1); }
    else if (e.key === 'ArrowUp') { e.preventDefault(); active = Math.max(0, active - 1); }
    else if (e.key === 'Enter') { e.preventDefault(); e.stopPropagation(); choose(shown[active]); }
  };
</script>

<div class="wrap" use:outside={() => (open = false)}>
  <div
    class="ctl sel"
    class:open
    class:bad={error}
    class:off={row.disabled}
    bind:this={anchor}
    role="button"
    tabindex={row.disabled ? -1 : 0}
    onclick={toggle}
    onkeydown={key}
  >
    {#if row.icon}<span class="lead"><Icon icon={row.icon} size={13} /></span>{/if}
    <span class="shown">
      {#if multi && picked.length}
        {#each picked as v}
          <span class="chip">{labelOf(v)}<button type="button" tabindex="-1" onclick={(e) => { e.stopPropagation(); choose({ value: v }); }} aria-label="Remove"><Glyph name="close" size={10} stroke={3} /></button></span>
        {/each}
      {:else if !multi && picked !== null && picked !== undefined && picked !== ''}
        <span class="val">{labelOf(picked)}</span>
      {:else}
        <span class="ph">{plain(row.placeholder || 'Select')}</span>
      {/if}
    </span>
    <span class="tail">
      {#if row.clearable && (multi ? picked.length : picked !== null && picked !== undefined)}
        <button class="tbtn" type="button" tabindex="-1" onclick={clear} aria-label="Clear"><Glyph name="close" size={11} /></button>
      {/if}
      <span class="caret" class:up={open}><Glyph name="down" size={13} /></span>
    </span>
  </div>
  {#if open}
    <div class="pop list scroll" {style} role="listbox" tabindex="-1" onkeydown={key}>
      {#if row.searchable || items.length > 8}
        <div class="search">
          <Glyph name="search" size={13} />
          <input bind:this={searchEl} bind:value={query} placeholder="Search" oninput={() => (active = 0)} spellcheck="false" />
        </div>
      {/if}
      {#each shown as o, i}
        <button type="button" class="item" class:on={isOn(o.value)} class:act={i === active} onmouseenter={() => (active = i)} onclick={() => choose(o)}>
          <span class="il">{o.label}</span>
          {#if isOn(o.value)}<Glyph name="check" size={13} stroke={2.8} />{/if}
        </button>
      {:else}
        <span class="none">No matches</span>
      {/each}
    </div>
  {/if}
</div>

<style>
  .wrap { position: relative; }
  .sel { cursor: pointer; padding-left: 12px; min-height: 36px; height: auto; outline: none; }
  .sel.off { cursor: default; }
  .sel .lead { margin-left: -12px; }
  .shown { flex: 1; min-width: 0; display: flex; flex-wrap: wrap; gap: 4px; padding: 5px 0; }
  .val { white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .ph { color: var(--faint); }
  .chip { display: inline-flex; align-items: center; gap: 4px; height: 22px; padding: 0 4px 0 8px; border-radius: 4px; background: var(--accent-soft); border: 1px solid var(--accent-line); color: var(--accent-2); font-size: 13px; font-weight: 600; }
  .chip button { display: inline-flex; align-items: center; justify-content: center; width: 16px; height: 16px; border: 0; border-radius: 3px; background: transparent; color: inherit; padding: 0; }
  .chip button:hover { background: rgba(245, 165, 36, 0.2); }
  .caret { display: inline-flex; padding: 0 4px; transition: transform 0.12s; }
  .caret.up { transform: rotate(180deg); }
  .list { display: flex; flex-direction: column; gap: 2px; overflow-y: auto; }
  .search { display: flex; align-items: center; gap: 8px; height: 32px; padding: 0 8px; margin-bottom: 4px; border-radius: var(--radius); background: var(--bg-2); border: 1px solid var(--line-2); color: var(--faint); flex: none; }
  .search input { flex: 1; min-width: 0; border: 0; outline: none; background: transparent; color: var(--text); }
  .item { display: flex; align-items: center; gap: 8px; min-height: 32px; padding: 0 10px; border-radius: 5px; border: 0; background: transparent; color: var(--text-2); text-align: left; flex: none; }
  .item.act { background: var(--panel-2); color: var(--text); }
  .item.on { color: var(--accent-2); }
  .il { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
  .none { padding: 8px 10px; color: var(--faint); font-size: 13px; }
</style>
