<script>
  import { onMount } from 'svelte';
  import TwoPane from '../../ui/TwoPane.svelte';
  import Glyph from '../../ui/Glyph.svelte';
  import { phone } from '../../lib/store.svelte.js';
  import { evaluate, format } from './engine.js';
  import { t } from '../../lib/i18n.js';

  // Display and history on one side, keys on the other. With the phone open or half open there are science keys too.
  let expr = $state('');
  let shownResult = $state('');
  let error = $state(false);
  let fresh = $state(false); // the last thing was "=": the next digit starts again, the next operator carries on
  let deg = $state(true);
  let history = $state([]);

  const wide = $derived(phone.fold !== 'cover');
  const OPS = '+−×÷^';

  // The answer so far, worked out as you type.
  const preview = $derived.by(() => {
    if (!expr || fresh) return '';
    try {
      const v = evaluate(expr, deg);
      const text = format(v);
      return text === expr ? '' : text;
    } catch {
      return '';
    }
  });

  function add(text) {
    error = false;
    if (fresh) {
      const startsOver = /^[0-9.(πe]|^(sin|cos|tan|asin|acos|atan|ln|log|√|abs)/.test(text);
      expr = startsOver ? '' : shownResult.replace('-', '−');
      fresh = false;
    }
    const last = expr.slice(-1);
    if (OPS.includes(text) && OPS.includes(last)) {
      // two operators in a row: the new one wins (but "×−" for a negative number is kept)
      if (text === '−' && '×÷^'.includes(last)) expr += text;
      else expr = expr.slice(0, -1) + text;
      return;
    }
    if (text === '.') {
      const seg = expr.split(/[^0-9.]/).pop();
      if (seg.includes('.')) return;
    }
    if (expr.length >= 60) return;
    expr += text;
  }

  function back() {
    error = false;
    if (fresh) {
      fresh = false;
      expr = '';
      return;
    }
    // a function name such as "sin(" goes in one step
    const m = /(sin|cos|tan|asin|acos|atan|ln|log|abs|√)\($/.exec(expr);
    expr = m ? expr.slice(0, -m[0].length) : expr.slice(0, -1);
  }

  function clear() {
    expr = '';
    shownResult = '';
    error = false;
    fresh = false;
  }

  function equals() {
    if (!expr || fresh) return;
    try {
      const v = evaluate(expr, deg);
      const text = format(v);
      history = [{ expr, result: text }, ...history].slice(0, 30);
      shownResult = text;
      fresh = true;
      error = false;
    } catch {
      error = true;
    }
  }

  function useHistory(h) {
    expr = h.result.replace('-', '−');
    fresh = false;
    error = false;
  }

  function press(key) {
    if (key.act === 'ac') clear();
    else if (key.act === 'back') back();
    else if (key.act === '=') equals();
    else if (key.act === 'deg') deg = !deg;
    else add(key.text);
  }

  const science = [
    { label: 'sin', text: 'sin(' }, { label: 'cos', text: 'cos(' }, { label: 'tan', text: 'tan(' }, { label: 'ln', text: 'ln(' },
    { label: 'log', text: 'log(' }, { label: '√', text: '√(' }, { label: 'x²', text: '^2' }, { label: 'xʸ', text: '^' },
    { label: 'π', text: 'π' }, { label: 'e', text: 'e' }, { label: '(', text: '(' }, { label: ')', text: ')' },
    { label: 'n!', text: '!' }, { label: 'abs', text: 'abs(' }, { label: 'asin', text: 'asin(' }, { label: 'acos', text: 'acos(' },
  ];
  const main = [
    { label: 'AC', act: 'ac', kind: 'fn' }, { label: '⌫', act: 'back', kind: 'fn' }, { label: '%', text: '%', kind: 'fn' }, { label: '÷', text: '÷', kind: 'op' },
    { label: '7', text: '7' }, { label: '8', text: '8' }, { label: '9', text: '9' }, { label: '×', text: '×', kind: 'op' },
    { label: '4', text: '4' }, { label: '5', text: '5' }, { label: '6', text: '6' }, { label: '−', text: '−', kind: 'op' },
    { label: '1', text: '1' }, { label: '2', text: '2' }, { label: '3', text: '3' }, { label: '+', text: '+', kind: 'op' },
    { label: '0', text: '0', wide: true }, { label: '.', text: '.' }, { label: '=', act: '=', kind: 'eq' },
  ];

  // Keys on a real keyboard work too, unless a text box has them.
  function onkey(e) {
    if (e.target instanceof HTMLElement && /^(INPUT|TEXTAREA|SELECT)$/.test(e.target.tagName)) return;
    if (e.ctrlKey || e.metaKey || e.altKey) return;
    const k = e.key;
    if (/^[0-9.]$/.test(k)) add(k);
    else if (k === '+') add('+');
    else if (k === '-') add('−');
    else if (k === '*' || k === 'x') add('×');
    else if (k === '/') add('÷');
    else if (k === '^') add('^');
    else if (k === '(' || k === ')') add(k);
    else if (k === '%') add('%');
    else if (k === '!') add('!');
    else if (k === 'Enter' || k === '=') equals();
    else if (k === 'Backspace') back();
    else if (k === 'c' || k === 'C') clear();
    else return;
    e.preventDefault();
  }
  onMount(() => {
    window.addEventListener('keydown', onkey);
    return () => window.removeEventListener('keydown', onkey);
  });
</script>

{#snippet display()}
  <div class="screen">
    {#if wide}
      <button class="degbtn" onclick={() => (deg = !deg)} aria-label={t('calculator.angle')}>{deg ? t('calculator.deg') : t('calculator.rad')}</button>
    {/if}
    <div class="expr" class:small={expr.length > 14}>{expr || '0'}</div>
    <div class="res" class:err={error}>
      {#if error}{t('calculator.error')}{:else if fresh}{shownResult}{:else if preview}= {preview}{:else}&nbsp;{/if}
    </div>
  </div>
  {#if wide && history.length}
    <div class="ap-label">{t('calculator.history')}</div>
    <ul class="ap-list hist">
      {#each history as h, i (i)}
        <li><button class="ap-row" onclick={() => useHistory(h)}><span class="he">{h.expr}</span><span class="hr">= {h.result}</span></button></li>
      {/each}
    </ul>
  {/if}
{/snippet}

{#snippet keys()}
  <div class="pad" class:wide>
    {#if wide}
      <div class="sci">
        {#each science as k (k.label)}
          <button class="key sci-key" onclick={() => press(k)}>{k.label}</button>
        {/each}
      </div>
    {/if}
    <div class="main">
      {#each main as k (k.label)}
        <button class="key {k.kind ?? ''}" class:wide2={k.wide} onclick={() => press(k)}>{k.label}</button>
      {/each}
    </div>
  </div>
{/snippet}

<TwoPane list={keys} detail={display} swap cover="stack" />

<style>
  .screen {
    position: relative;
    display: flex;
    flex-direction: column;
    align-items: flex-end;
    justify-content: flex-end;
    min-height: 110px;
    padding: 10px 6px;
    gap: 4px;
  }
  .degbtn {
    position: absolute;
    top: 6px;
    left: 4px;
    padding: 4px 10px;
    border-radius: 10px;
    background: var(--surface-2);
    font-size: 12px;
    font-weight: 700;
    color: var(--ink-2);
  }
  .expr {
    max-width: 100%;
    font-size: 38px;
    font-weight: 500;
    text-align: right;
    word-break: break-all;
    color: var(--ink);
  }
  .expr.small {
    font-size: 26px;
  }
  .res {
    font-size: 22px;
    font-weight: 600;
    color: var(--ink-3);
    min-height: 28px;
  }
  .res.err {
    color: #e5484d;
  }
  .hist {
    max-height: 220px;
    overflow-y: auto;
  }
  .he {
    flex: 1;
    min-width: 0;
    font-size: 14px;
    color: var(--ink-3);
    white-space: nowrap;
    overflow: hidden;
    text-overflow: ellipsis;
  }
  .hr {
    font-size: 15px;
    font-weight: 700;
  }
  .pad {
    display: flex;
    gap: 14px;
  }
  .sci {
    flex: 1;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
    align-content: start;
  }
  .main {
    flex: 1.1;
    min-width: 0;
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
  }
  .key {
    height: 52px;
    border-radius: 16px;
    background: var(--surface);
    border: 1px solid var(--line);
    font-size: 20px;
    font-weight: 600;
    color: var(--ink);
  }
  .key:active {
    background: var(--surface-3);
  }
  .key.fn {
    background: var(--surface-2);
  }
  .key.op {
    background: var(--accent-soft);
    color: var(--accent);
  }
  .key.eq {
    background: var(--accent);
    color: var(--on-accent);
    border-color: transparent;
  }
  .key.wide2 {
    grid-column: span 2;
  }
  .sci-key {
    height: 44px;
    font-size: 15px;
    background: var(--surface-2);
    border-color: transparent;
  }
</style>
