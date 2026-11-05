<script>
  import { ui, persist, reportMap } from '../lib/store.svelte.js';

  let { id, name, show = true, place, children } = $props();

  let el = $state();
  let pos = $state([0, 0]);
  let drag = null;
  let moved = false;

  const clamp = (v, a, b) => Math.max(a, Math.min(b, v));

  function compute() {
    if (!el) return;
    const vw = window.innerWidth, vh = window.innerHeight;
    const w = el.offsetWidth, h = el.offsetHeight;
    const p = ui.layout[id];
    pos = p
      ? [clamp(p.x * vw, 0, Math.max(0, vw - w)), clamp(p.y * vh, 0, Math.max(0, vh - h))]
      : place(vw, vh, w, h);
  }

  $effect(() => {
    ui.layout[id];
    ui.ready;
    el;
    compute();
  });

  $effect(() => {
    if (id !== 'map' || !el || !ui.ready) return;
    pos[0];
    pos[1];
    const t = setTimeout(() => reportMap(el), 300);
    return () => clearTimeout(t);
  });

  function down(e) {
    if (!ui.edit) return;
    e.preventDefault();
    el.setPointerCapture(e.pointerId);
    drag = { sx: e.clientX, sy: e.clientY, ox: pos[0], oy: pos[1] };
    moved = false;
  }

  function move(e) {
    if (!drag) return;
    moved = true;
    const vw = window.innerWidth, vh = window.innerHeight;
    pos = [
      clamp(Math.round((drag.ox + e.clientX - drag.sx) / 8) * 8, 0, Math.max(0, vw - el.offsetWidth)),
      clamp(Math.round((drag.oy + e.clientY - drag.sy) / 8) * 8, 0, Math.max(0, vh - el.offsetHeight)),
    ];
  }

  function up() {
    if (!drag) return;
    drag = null;
    if (!moved) return;
    ui.layout[id] = { x: pos[0] / window.innerWidth, y: pos[1] / window.innerHeight };
    persist();
  }

  function unpin(e) {
    if (!ui.edit || !id.startsWith('stat_')) return;
    e.preventDefault();
    delete ui.layout[id];
    persist();
  }
</script>

<svelte:window onresize={compute} />

<div
  class="grp"
  class:edit={ui.edit}
  class:off={!show}
  data-n={name}
  bind:this={el}
  style:left="{pos[0]}px"
  style:top="{pos[1]}px"
  onpointerdown={down}
  onpointermove={move}
  onpointerup={up}
  oncontextmenu={unpin}
>
  {@render children()}
</div>
