<script>
  import { tick } from 'svelte';
  import { parse, format, hsvToRgb, rgbToHsv, hasAlpha } from '../../lib/color.js';
  import { place, outside } from './popover.js';
  import Glyph from '../Glyph.svelte';

  let { value = $bindable(''), row, error = '' } = $props();
  const fmt = $derived(row.format || 'hex');
  const SWATCHES = ['#F5A524', '#FF8A3D', '#FF5A52', '#FF6F91', '#B79CFF', '#5AA9FF', '#4FD1E0', '#3DD68C', '#A6E05A', '#E6EDF5', '#8A9AB0', '#0A0E14'];

  const start = parse(value) || { r: 245, g: 165, b: 36, a: 1 };
  const hsv0 = rgbToHsv(start.r, start.g, start.b);
  let h = $state(hsv0[0]);
  let s = $state(hsv0[1]);
  let v = $state(hsv0[2]);
  let a = $state(start.a);
  let open = $state(false);
  let anchor = $state();
  let style = $state('');
  let text = $state(value || '');

  const rgb = $derived(hsvToRgb(h, s, v));
  const out = $derived(format({ r: rgb[0], g: rgb[1], b: rgb[2], a }, fmt));
  const hueColor = $derived(`rgb(${hsvToRgb(h, 1, 1).join(',')})`);

  const commit = () => {
    value = out;
    text = out;
  };

  const fromText = () => {
    const c = parse(text);
    if (!c) { text = value || ''; return; }
    const [hh, ss, vv] = rgbToHsv(c.r, c.g, c.b);
    h = hh; s = ss; v = vv; a = c.a;
    commit();
  };

  const drag = (node, fn) => {
    const go = (e) => {
      const r = node.getBoundingClientRect();
      fn(Math.min(1, Math.max(0, (e.clientX - r.left) / r.width)), Math.min(1, Math.max(0, (e.clientY - r.top) / r.height)));
      commit();
    };
    const down = (e) => {
      go(e);
      const up = () => { window.removeEventListener('mousemove', go); window.removeEventListener('mouseup', up); };
      window.addEventListener('mousemove', go);
      window.addEventListener('mouseup', up);
    };
    node.addEventListener('mousedown', down);
    return { destroy: () => node.removeEventListener('mousedown', down) };
  };

  const toggle = async () => {
    if (row.disabled) return;
    open = !open;
    if (open) {
      style = place(anchor, 300, 252);
      await tick();
    }
  };

  const swatch = (hex) => {
    text = hex;
    fromText();
  };
</script>

<div class="wrap" use:outside={() => (open = false)}>
  <div class="ctl" class:open class:bad={error} class:off={row.disabled} bind:this={anchor}>
    <button type="button" class="sw" onclick={toggle} disabled={row.disabled} aria-label="Pick colour" style:--c={value || 'transparent'}></button>
    <input class="mono" bind:value={text} onblur={fromText} onkeydown={(e) => e.key === 'Enter' && fromText()} placeholder={row.placeholder || '#F5A524'} disabled={row.disabled} spellcheck="false" />
  </div>
  {#if open}
    <div class="pop picker" {style} role="dialog" tabindex="-1" onkeydown={(e) => { if (e.key === 'Escape') { e.preventDefault(); e.stopPropagation(); open = false; } }}>
      <div class="sv" style:background-color={hueColor} use:drag={(x, y) => { s = x; v = 1 - y; }}>
        <span class="knob" style:left="{s * 100}%" style:top="{(1 - v) * 100}%" style:background={`rgb(${rgb.join(',')})`}></span>
      </div>
      <div class="hue" use:drag={(x) => (h = x * 360)}><span class="thumb" style:left="{(h / 360) * 100}%"></span></div>
      {#if hasAlpha(fmt)}
        <div class="alpha" style:--c={`rgb(${rgb.join(',')})`} use:drag={(x) => (a = Math.round(x * 100) / 100)}><span class="thumb" style:left="{a * 100}%"></span></div>
      {/if}
      <div class="sws">
        {#each SWATCHES as c}
          <button type="button" class="mini" style:background={c} onclick={() => swatch(c)} aria-label={c}></button>
        {/each}
      </div>
      <div class="out mono">{out}<span class="ok"><Glyph name="check" size={12} /></span></div>
    </div>
  {/if}
</div>

<style>
  .wrap { position: relative; }
  .sw { flex: none; width: 24px; height: 24px; margin-left: 6px; border-radius: 5px; border: 1px solid var(--line-3); background: linear-gradient(var(--c), var(--c)), repeating-conic-gradient(#2b3a50 0 25%, #111823 0 50%) 0 0 / 8px 8px; padding: 0; }
  .mono { font-family: var(--mono); font-size: 13px; }
  .picker { display: flex; flex-direction: column; gap: 10px; padding: 10px; }
  .sv { position: relative; height: 150px; border-radius: 6px; cursor: crosshair; background-image: linear-gradient(to top, #000, transparent), linear-gradient(to right, #fff, transparent); }
  .knob { position: absolute; width: 14px; height: 14px; border-radius: 50%; border: 2px solid #fff; box-shadow: 0 0 0 1px rgba(0,0,0,.5); transform: translate(-50%, -50%); pointer-events: none; }
  .hue, .alpha { position: relative; height: 12px; border-radius: 6px; cursor: pointer; }
  .hue { background: linear-gradient(90deg, #f00, #ff0, #0f0, #0ff, #00f, #f0f, #f00); }
  .alpha { background: linear-gradient(90deg, transparent, var(--c)), repeating-conic-gradient(#2b3a50 0 25%, #111823 0 50%) 0 0 / 8px 8px; }
  .thumb { position: absolute; top: 50%; width: 14px; height: 14px; border-radius: 50%; background: var(--text); border: 2px solid var(--bg); box-shadow: 0 0 0 1px var(--line-3); transform: translate(-50%, -50%); pointer-events: none; }
  .sws { display: grid; grid-template-columns: repeat(6, 1fr); gap: 6px; }
  .mini { height: 20px; border-radius: 4px; border: 1px solid var(--line-3); padding: 0; }
  .out { display: flex; align-items: center; justify-content: space-between; padding: 6px 8px; border-radius: 5px; background: var(--bg-2); color: var(--text-2); font-size: 12px; }
  .ok { color: var(--ok); display: inline-flex; }
</style>
