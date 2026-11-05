// Text for the screen. Add a language by adding a file in src/locales and listing it here.
// Anything missing falls back to English, and then to the key itself.
import en from '../locales/en.js';

const dictionaries = { en };
let current = 'en';

export function setLocale(code) {
  const short = String(code || 'en').toLowerCase().split(/[-_]/)[0];
  current = dictionaries[short] ? short : 'en';
}

// t('lock.wrong')  or  t('lock.wait', { n: 30 })
export function t(key, vars) {
  let text = dictionaries[current][key] ?? en[key] ?? key;
  if (vars) {
    text = text.replace(/\{(\w+)\}/g, (_, name) => (vars[name] !== undefined ? String(vars[name]) : `{${name}}`));
  }
  return text;
}
