import { t } from './i18n.js';

// The words for a reason from the server. An app's own text comes first (`notes.err.full`), then the general text (`err.full`),
// then "the phone did not answer".
export function scopedError(reason, scope) {
  for (const key of [`${scope}.err.${reason}`, `err.${reason}`]) {
    const text = t(key);
    if (text !== key) return text;
  }
  return t('err.timeout');
}
