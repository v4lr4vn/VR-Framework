<script>
  let { name, size = 16, stroke = 2, class: cls = '' } = $props();

  const icons = {
    radio: ['M4 10a8 8 0 0 1 16 0', 'M8 10a4 4 0 0 1 8 0', 'circle:12,14,2', 'M12 16v5'],
    mic: ['M9 5a3 3 0 0 1 6 0v6a3 3 0 0 1-6 0z', 'M5 11a7 7 0 0 0 14 0', 'M12 18v3'],
    headphones: ['M4 15v-3a8 8 0 0 1 16 0v3', 'M4 14h3v6H4z', 'M17 14h3v6h-3z'],
    broadcast: ['circle:12,12,2', 'M8.5 8.5a5 5 0 0 0 0 7', 'M15.5 8.5a5 5 0 0 1 0 7', 'M5.6 5.6a9 9 0 0 0 0 12.8', 'M18.4 5.6a9 9 0 0 1 0 12.8'],
    desk: ['M3 5h18v11H3z', 'M8 20h8', 'M12 16v4'],
    units: ['circle:9,8,3', 'M3 20a6 6 0 0 1 12 0', 'circle:17,9,2.5', 'M15.5 20a5 5 0 0 1 5.5-5'],
    bulletin: ['M3 11h18', 'M5 11V7a2 2 0 0 1 2-2h10a2 2 0 0 1 2 2v4', 'M4 11v7h3v-2h10v2h3v-7'],
    person: ['circle:12,8,4', 'M4 21a8 8 0 0 1 16 0'],
    car: ['M5 16V11l2-5h10l2 5v5', 'M3 16h18v3H3z', 'circle:7.5,13,1', 'circle:16.5,13,1'],
    crosshair: ['circle:12,12,8', 'circle:12,12,3', 'M12 2v4M12 18v4M2 12h4M18 12h4'],
    alert: ['M12 3 2 20h20L12 3Z', 'M12 10v4M12 17h.01'],
    report: ['M7 3h7l5 5v13H7z', 'M14 3v5h5M10 13h6M10 17h6'],
    folder: ['M3 7h6l2 2h10v10H3z'],
    scale: ['M12 3v18M5 7h14', 'm5 7-3 7a3 3 0 0 0 6 0L5 7ZM19 7l-3 7a3 3 0 0 0 6 0l-3-7Z'],
    list: ['M8 6h13M8 12h13M8 18h13M3 6h.01M3 12h.01M3 18h.01'],
    court: ['M4 21h16M6 18V9M10 18V9M14 18V9M18 18V9M3 9l9-6 9 6'],
    shield: ['M12 2 4 5v6c0 5 3.4 9.3 8 11 4.6-1.7 8-6 8-11V5l-8-3Z'],
    shieldcheck: ['M12 2 4 5v6c0 5 3.4 9.3 8 11 4.6-1.7 8-6 8-11V5l-8-3Z', 'm9 12 2 2 4-4'],
    grad: ['m2 9 10-5 10 5-10 5L2 9Z', 'M6 11v5c3 2 9 2 12 0v-5'],
    camera: ['M3 7h12v10H3z', 'm15 10 6-3v10l-6-3'],
    lock: ['M6 11h12v10H6z', 'M8 11V7a4 4 0 0 1 8 0v4'],
    medical: ['M10 3h4v7h7v4h-7v7h-4v-7H3v-4h7z'],
    heart: ['M12 20s-7-4.5-7-10a4 4 0 0 1 7-2.6A4 4 0 0 1 19 10c0 5.5-7 10-7 10Z'],
    search: ['circle:11,11,7', 'm20 20-3.5-3.5'],
    plus: ['M12 5v14M5 12h14'],
    minus: ['M5 12h14'],
    x: ['M6 6l12 12M18 6 6 18'],
    check: ['m5 12 5 5 9-10'],
    chevron: ['m9 6 6 6-6 6'],
    chevrondown: ['m6 9 6 6 6-6'],
    back: ['m15 6-6 6 6 6'],
    pin: ['M12 21s-7-6.2-7-12a7 7 0 0 1 14 0c0 5.8-7 12-7 12Z', 'circle:12,9,2.5'],
    navigate: ['m3 11 18-8-8 18-2-8-8-2Z'],
    note: ['M4 5h16v11H8l-4 4z'],
    edit: ['M4 20h4L19 9l-4-4L4 16z', 'm13 7 4 4'],
    trash: ['M4 7h16M10 11v6M14 11v6', 'M6 7l1 13h10l1-13M9 7V4h6v3'],
    phone: ['M5 4h4l2 5-3 2a11 11 0 0 0 5 5l2-3 5 2v4a2 2 0 0 1-2 2A16 16 0 0 1 3 6a2 2 0 0 1 2-2'],
    eye: ['M2 12s3.5-7 10-7 10 7 10 7-3.5 7-10 7-10-7-10-7Z', 'circle:12,12,3'],
    store: ['M4 10v10h16V10', 'M3 10 5 4h14l2 6', 'M3 10h18', 'M9 20v-6h6v6'],
    bank: ['M3 10h18L12 4 3 10Z', 'M5 10v8M9 10v8M15 10v8M19 10v8M3 20h18'],
    home: ['M4 11 12 4l8 7', 'M6 10v10h12V10'],
    gavel: ['m14 4 6 6M11 7l6 6M8 10l6 6M3 21l6-6', 'm9 9 6-6 6 6-6 6z'],
    clock: ['circle:12,12,9', 'M12 7v5l3 2'],
    calendar: ['M4 6h16v15H4z', 'M4 10h16M8 3v4M16 3v4'],
    image: ['M4 5h16v14H4z', 'circle:9,10,1.8', 'm4 17 5-5 4 4 3-3 4 4'],
    settings: ['circle:12,12,3', 'M12 2v3M12 19v3M2 12h3M19 12h3M4.9 4.9 7 7M17 17l2.1 2.1M4.9 19.1 7 17M17 7l2.1-2.1'],
    logout: ['M15 4h4v16h-4', 'M10 8l-4 4 4 4M6 12h10'],
    filter: ['M4 5h16l-6 7v6l-4 2v-8z'],
    flag: ['M5 21V4', 'M5 4h12l-2 4 2 4H5'],
    star: ['m12 3 2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z'],
    money: ['M3 7h18v10H3z', 'circle:12,12,2.5', 'M6 10v4M18 10v4'],
    link: ['M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7l-1 1', 'M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7l1-1'],
    unlink: ['M10 14a4 4 0 0 0 5.7 0l3-3a4 4 0 0 0-5.7-5.7', 'M14 10a4 4 0 0 0-5.7 0l-3 3a4 4 0 0 0 5.7 5.7', 'M3 3l18 18'],
    layers: ['m12 3 9 5-9 5-9-5 9-5Z', 'm3 13 9 5 9-5'],
    target: ['circle:12,12,9', 'circle:12,12,5', 'circle:12,12,1'],
    users: ['circle:9,8,3', 'M3 20a6 6 0 0 1 12 0', 'circle:17,9,2.5', 'M15.5 20a5 5 0 0 1 5.5-5'],
    key: ['circle:8,15,4', 'm11 12 9-9M17 6l3 3'],
    box: ['m12 3 8 4.5v9L12 21l-8-4.5v-9z', 'm4 7.5 8 4.5 8-4.5M12 12v9'],
    fingerprint: ['M12 11v3a8 8 0 0 1-2 5', 'M8 11a4 4 0 0 1 8 0v2a12 12 0 0 1-1 5', 'M5 15a10 10 0 0 0 1-4 6 6 0 0 1 12 0', 'M5 7a9 9 0 0 1 14 0'],
    dot: ['circle:12,12,4'],
    more: ['circle:5,12,1.5', 'circle:12,12,1.5', 'circle:19,12,1.5'],
    refresh: ['M20 11a8 8 0 1 0-2.3 5.7', 'M20 4v7h-7'],
    print: ['M7 9V3h10v6', 'M5 9h14v8h-3v4H8v-4H5z'],
    bolt: ['M13 2 4 14h7l-1 8 9-12h-7z'],
  };

  const extra = import.meta.glob('../lib/icons/*.js', { eager: true });
  for (const m of Object.values(extra)) Object.assign(icons, m.default || {});

  const parts = $derived(
    (icons[name] || icons.dot).map((p) => {
      if (p.startsWith('circle:')) {
        const [cx, cy, r] = p.slice(7).split(',').map(Number);
        return { circle: true, cx, cy, r };
      }
      return { d: p };
    }),
  );
</script>

<svg class={cls} width={size} height={size} viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width={stroke} stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">
  {#each parts as p}
    {#if p.circle}
      <circle cx={p.cx} cy={p.cy} r={p.r} />
    {:else}
      <path d={p.d} />
    {/if}
  {/each}
</svg>

<style>
  svg { flex: none; display: block; }
</style>
