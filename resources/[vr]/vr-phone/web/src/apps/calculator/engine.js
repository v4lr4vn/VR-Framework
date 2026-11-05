// A small calculator engine. It reads the text and works it out itself (no eval, so nothing typed can run as code).
//   numbers  1  2.5  .5  1e3        operators  + - × ÷ * / ^       percent  50%        factorial  5!
//   functions  sin cos tan asin acos atan ln log sqrt abs     constants  π pi e       brackets  ( )  (a missing ")" is added)
// Brackets and a number next to each other multiply: 2π  3(4+1)  (1+2)(3+4)
// Angles are degrees when `deg` is true, radians when it is false.

const FUNCS = {
  sin: (x, deg) => Math.sin(deg ? (x * Math.PI) / 180 : x),
  cos: (x, deg) => Math.cos(deg ? (x * Math.PI) / 180 : x),
  tan: (x, deg) => Math.tan(deg ? (x * Math.PI) / 180 : x),
  asin: (x, deg) => (deg ? (Math.asin(x) * 180) / Math.PI : Math.asin(x)),
  acos: (x, deg) => (deg ? (Math.acos(x) * 180) / Math.PI : Math.acos(x)),
  atan: (x, deg) => (deg ? (Math.atan(x) * 180) / Math.PI : Math.atan(x)),
  ln: (x) => Math.log(x),
  log: (x) => Math.log10(x),
  sqrt: (x) => Math.sqrt(x),
  abs: (x) => Math.abs(x),
};
const CONSTS = { pi: Math.PI, e: Math.E };

function tokenize(src) {
  const text = String(src).replace(/\s+/g, '');
  const out = [];
  let i = 0;
  while (i < text.length) {
    const ch = text[i];
    if (/[0-9.]/.test(ch)) {
      const m = /^(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?/.exec(text.slice(i));
      if (!m) throw new Error('number');
      // "2e" followed by a letter would be the constant e, so only take the exponent when digits follow.
      out.push({ t: 'num', v: parseFloat(m[0]) });
      i += m[0].length;
      if (text[i] === '.') throw new Error('number'); // 2.5.1
    } else if (/[a-zπ√]/i.test(ch)) {
      if (ch === 'π') { out.push({ t: 'const', v: Math.PI }); i++; continue; }
      if (ch === '√') { out.push({ t: 'fn', v: 'sqrt' }); i++; continue; }
      const m = /^[a-z]+/i.exec(text.slice(i))[0].toLowerCase();
      if (m in FUNCS) out.push({ t: 'fn', v: m });
      else if (m in CONSTS) out.push({ t: 'const', v: CONSTS[m] });
      else throw new Error('word');
      i += m.length;
    } else if ('+-−×÷*/^%!()'.includes(ch)) {
      out.push({ t: 'op', v: ch === '−' ? '-' : ch === '×' ? '*' : ch === '÷' ? '/' : ch });
      i++;
    } else {
      throw new Error('char');
    }
  }
  return out;
}

export function evaluate(src, deg = true) {
  const toks = tokenize(src);
  let pos = 0;
  const peek = () => toks[pos];
  const isOp = (v) => peek() && peek().t === 'op' && peek().v === v;

  function expr() {
    let v = term();
    while (isOp('+') || isOp('-')) {
      const op = toks[pos++].v;
      const r = term();
      v = op === '+' ? v + r : v - r;
    }
    return v;
  }

  // Something that can start a value: a number, a constant, a function or "(".
  const startsValue = () => peek() && (peek().t === 'num' || peek().t === 'const' || peek().t === 'fn' || (peek().t === 'op' && peek().v === '('));

  function term() {
    let v = unary();
    for (;;) {
      if (isOp('*') || isOp('/')) {
        const op = toks[pos++].v;
        const r = unary();
        if (op === '/' && r === 0) throw new Error('divide');
        v = op === '*' ? v * r : v / r;
      } else if (startsValue()) {
        v *= unary(); // 2π, 3(4+1)
      } else break;
    }
    return v;
  }

  function power() {
    const base = postfix();
    if (isOp('^')) {
      pos++;
      return Math.pow(base, unary());
    }
    return base;
  }

  // "-2^2" is -(2^2). The exponent may have its own sign: 2^-1.
  function unary() {
    if (isOp('-')) { pos++; return -unary(); }
    if (isOp('+')) { pos++; return unary(); }
    return power();
  }

  function postfix() {
    let v = primary();
    for (;;) {
      if (isOp('%')) { pos++; v /= 100; }
      else if (isOp('!')) {
        pos++;
        if (!Number.isInteger(v) || v < 0 || v > 170) throw new Error('factorial');
        let f = 1;
        for (let k = 2; k <= v; k++) f *= k;
        v = f;
      } else break;
    }
    return v;
  }

  function primary() {
    const tok = toks[pos];
    if (!tok) throw new Error('end');
    if (tok.t === 'num' || tok.t === 'const') { pos++; return tok.v; }
    if (tok.t === 'fn') {
      pos++;
      let arg;
      if (isOp('(')) {
        pos++;
        arg = expr();
        if (isOp(')')) pos++; // a missing ")" at the end is fine
      } else {
        arg = unary(); // √9, sin30
      }
      return FUNCS[tok.v](arg, deg);
    }
    if (isOp('(')) {
      pos++;
      const v = expr();
      if (isOp(')')) pos++;
      return v;
    }
    throw new Error('syntax');
  }

  const result = expr();
  if (pos < toks.length) throw new Error('syntax');
  if (!Number.isFinite(result)) throw new Error('range');
  return result;
}

// 12 significant digits, no trailing zeros, e-notation for very big or very small numbers.
export function format(n) {
  if (n === 0 || Object.is(n, -0)) return '0';
  const abs = Math.abs(n);
  if (abs >= 1e15 || abs < 1e-9) return n.toExponential(8).replace(/\.?0+e/, 'e').replace('e+', 'e');
  let s = Number(n.toPrecision(12)).toString();
  if (s.includes('e')) s = n.toFixed(10).replace(/\.?0+$/, '');
  return s;
}
