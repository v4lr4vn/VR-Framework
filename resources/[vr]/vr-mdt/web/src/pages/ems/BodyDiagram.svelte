<script>
  import Button from '../../components/Button.svelte';
  import IconButton from '../../components/IconButton.svelte';
  import { regions, kinds, severities, worst } from './meta.js';

  let { injuries = [], editable = false, onadd, height = 380 } = $props();

  let selected = $state(null);
  let kind = $state('gunshot');
  let severity = $state('moderate');

  const front = [
    { id: 'head', shape: 'ellipse', a: { cx: 100, cy: 38, rx: 21, ry: 25 }, c: [100, 38] },
    { id: 'neck', shape: 'rect', a: { x: 91, y: 62, width: 18, height: 14, rx: 4 }, c: [100, 69] },
    { id: 'chest', shape: 'rect', a: { x: 64, y: 77, width: 72, height: 63, rx: 14 }, c: [100, 108] },
    { id: 'abdomen', shape: 'rect', a: { x: 68, y: 142, width: 64, height: 56, rx: 10 }, c: [100, 170] },
    { id: 'right_arm', shape: 'rect', a: { x: 38, y: 80, width: 22, height: 148, rx: 11, transform: 'rotate(9 49 80)' }, c: [38, 150] },
    { id: 'left_arm', shape: 'rect', a: { x: 140, y: 80, width: 22, height: 148, rx: 11, transform: 'rotate(-9 151 80)' }, c: [162, 150] },
    { id: 'right_leg', shape: 'rect', a: { x: 69, y: 201, width: 29, height: 176, rx: 13 }, c: [83, 290] },
    { id: 'left_leg', shape: 'rect', a: { x: 102, y: 201, width: 29, height: 176, rx: 13 }, c: [117, 290] },
  ];

  const rear = [
    { shape: 'ellipse', a: { cx: 100, cy: 38, rx: 21, ry: 25 } },
    { shape: 'rect', a: { x: 91, y: 62, width: 18, height: 14, rx: 4 } },
    { shape: 'rect', a: { x: 38, y: 80, width: 22, height: 148, rx: 11, transform: 'rotate(9 49 80)' } },
    { shape: 'rect', a: { x: 140, y: 80, width: 22, height: 148, rx: 11, transform: 'rotate(-9 151 80)' } },
    { shape: 'rect', a: { x: 69, y: 201, width: 29, height: 176, rx: 13 } },
    { shape: 'rect', a: { x: 102, y: 201, width: 29, height: 176, rx: 13 } },
  ];
  const back = { id: 'back', shape: 'rect', a: { x: 64, y: 77, width: 72, height: 121, rx: 14 }, c: [100, 138] };

  const byRegion = $derived.by(() => {
    const m = {};
    for (const i of injuries) (m[i.region] ||= []).push(i);
    return m;
  });

  function level(id) {
    const list = byRegion[id];
    return list?.length ? worst(list) : 'none';
  }

  function describe(id) {
    const n = byRegion[id]?.length || 0;
    return `${regions[id]}${n ? `, ${n} ${n === 1 ? 'injury' : 'injuries'}` : ''}`;
  }

  function choose(id) {
    if (!editable) return;
    selected = selected === id ? null : id;
  }

  function key(e, id) {
    if (e.key === 'Enter' || e.key === ' ') {
      e.preventDefault();
      choose(id);
    }
  }

  function add() {
    if (!selected) return;
    onadd?.({ region: selected, kind, severity });
    selected = null;
  }
</script>

{#snippet region(r, k = 1)}
  {#if editable}
    <g class="region {level(r.id)}" class:on={selected === r.id} role="button" tabindex="0" aria-label={describe(r.id)} aria-pressed={selected === r.id} onclick={() => choose(r.id)} onkeydown={(e) => key(e, r.id)}>
      {#if r.shape === 'ellipse'}<ellipse {...r.a} />{:else}<rect {...r.a} />{/if}
    </g>
  {:else}
    <g class="region {level(r.id)}" role="img" aria-label={describe(r.id)}>
      {#if r.shape === 'ellipse'}<ellipse {...r.a} />{:else}<rect {...r.a} />{/if}
    </g>
  {/if}
  {#if byRegion[r.id]?.length}
    <g class="count" aria-hidden="true">
      <circle cx={r.c[0]} cy={r.c[1]} r={9 * k} />
      <text x={r.c[0]} y={r.c[1] + 4 * k} style:font-size="{11 * k}px">{byRegion[r.id].length}</text>
    </g>
  {/if}
{/snippet}

<div class="diagram">
  <svg viewBox="0 0 330 400" style:height="{height}px" aria-label="Body diagram" role="group">
    <text class="side" x="18" y="22">R</text>
    <text class="side" x="174" y="22">L</text>
    <text class="cap" x="100" y="396">FRONT</text>
    {#each front as r (r.id)}{@render region(r)}{/each}
    <g transform="translate(212 92) scale(0.56)">
      {#each rear as s}
        <g class="ghost" aria-hidden="true">{#if s.shape === 'ellipse'}<ellipse {...s.a} />{:else}<rect {...s.a} />{/if}</g>
      {/each}
      {@render region(back, 1.75)}
      <text class="cap big" x="100" y="404">BACK</text>
    </g>
  </svg>

  <div class="legend" aria-hidden="true">
    {#each severities as s}<span class="key {s.value}"><i></i>{s.label}</span>{/each}
  </div>

  {#if editable}
    {#if selected}
      <div class="add">
        <div class="ahead">
          <span class="eyebrow">Add injury</span>
          <b>{regions[selected]}</b>
          <IconButton icon="x" label="Cancel" size={26} onclick={() => (selected = null)} />
        </div>
        <div class="chips" role="radiogroup" aria-label="Kind of injury">
          {#each kinds as k}
            <button type="button" role="radio" aria-checked={kind === k.value} class="chip" class:on={kind === k.value} onclick={() => (kind = k.value)}>{k.label}</button>
          {/each}
        </div>
        <div class="chips" role="radiogroup" aria-label="Severity">
          {#each severities as s}
            <button type="button" role="radio" aria-checked={severity === s.value} class="chip sev {s.value}" class:on={severity === s.value} onclick={() => (severity = s.value)}>{s.label}</button>
          {/each}
        </div>
        <Button variant="primary" size="sm" icon="plus" onclick={add}>Add to {regions[selected].toLowerCase()}</Button>
      </div>
    {:else}
      <p class="tip">Click a body region to add an injury.</p>
    {/if}
  {/if}
</div>

<style>
  .diagram { display: flex; flex-direction: column; align-items: stretch; gap: 10px; }
  svg { width: 100%; display: block; }
  .region :global(rect), .region :global(ellipse) { fill: var(--panel-2); stroke: var(--line-3); stroke-width: 1.5; transition: fill 0.12s, stroke 0.12s; }
  .region[role='button'] { cursor: pointer; outline: none; }
  .region[role='button']:hover :global(rect), .region[role='button']:hover :global(ellipse) { stroke: var(--text-2); }
  .region[role='button']:focus-visible :global(rect), .region[role='button']:focus-visible :global(ellipse) { stroke: var(--accent); stroke-width: 2.5; }
  .region.on :global(rect), .region.on :global(ellipse) { stroke: var(--accent); stroke-width: 2.5; }
  .region.minor :global(rect), .region.minor :global(ellipse) { fill: var(--info-bg); stroke: var(--info); }
  .region.moderate :global(rect), .region.moderate :global(ellipse) { fill: #3A2C10; stroke: var(--accent); }
  .region.severe :global(rect), .region.severe :global(ellipse) { fill: #4A1A1C; stroke: var(--danger); }
  .region.critical :global(rect), .region.critical :global(ellipse) { fill: #8C2A27; stroke: var(--p1-text); }
  .ghost :global(rect), .ghost :global(ellipse) { fill: none; stroke: var(--line-2); stroke-width: 1.5; stroke-dasharray: 4 4; }
  .count circle { fill: var(--bg); stroke: var(--text-2); stroke-width: 1; }
  .count text { fill: var(--text); font-family: var(--mono); font-size: 11px; font-weight: 600; text-anchor: middle; }
  .side { fill: var(--faint); font-family: var(--mono); font-size: 12px; }
  .cap { fill: var(--faint); font-family: var(--mono); font-size: 10px; letter-spacing: 0.12em; text-anchor: middle; }
  .cap.big { font-size: 17px; }
  .legend { display: flex; justify-content: center; gap: 14px; color: var(--muted); font-size: 12px; }
  .key { display: inline-flex; align-items: center; gap: 5px; }
  .key i { width: 10px; height: 10px; border-radius: 3px; border: 1px solid; }
  .key.minor i { background: var(--info-bg); border-color: var(--info); }
  .key.moderate i { background: #3A2C10; border-color: var(--accent); }
  .key.severe i { background: #4A1A1C; border-color: var(--danger); }
  .key.critical i { background: #8C2A27; border-color: var(--p1-text); }
  .add { display: flex; flex-direction: column; gap: 8px; align-items: flex-start; padding: 10px 12px 12px; border-radius: var(--radius); border: 1px solid var(--accent-line); background: var(--panel); }
  .ahead { display: flex; align-items: center; gap: 8px; width: 100%; }
  .ahead b { flex: 1; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .chip { height: 26px; padding: 0 9px; border-radius: 13px; border: 1px solid var(--line-3); background: var(--bg-2); color: var(--text-2); font-size: 13px; }
  .chip:hover { color: var(--text); border-color: var(--text-2); }
  .chip.on { background: var(--accent); border-color: var(--accent); color: var(--accent-ink); font-weight: 600; }
  .chip.sev.on.minor { background: var(--info); border-color: var(--info); }
  .chip.sev.on.severe, .chip.sev.on.critical { background: var(--danger); border-color: var(--danger); }
  .tip { text-align: center; color: var(--faint); font-size: 13px; }
</style>
