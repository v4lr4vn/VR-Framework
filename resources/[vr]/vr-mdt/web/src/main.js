import '@fontsource/ibm-plex-sans-condensed/latin-400.css';
import '@fontsource/ibm-plex-sans-condensed/latin-500.css';
import '@fontsource/ibm-plex-sans-condensed/latin-600.css';
import '@fontsource/ibm-plex-sans-condensed/latin-700.css';
import '@fontsource/ibm-plex-mono/latin-400.css';
import '@fontsource/ibm-plex-mono/latin-500.css';
import '@fontsource/ibm-plex-mono/latin-600.css';
import './styles/tokens.css';
import './styles/base.css';
import { mount } from 'svelte';
import App from './App.svelte';
import { inGame } from './lib/nui.js';

const app = mount(App, { target: document.getElementById('app') });

if (!inGame) {
  const params = new URLSearchParams(window.location.search);
  if (params.get('closed') !== '1') {
    const reserved = new Set(['page', 'dept', 'boss', 'closed', 'alert', 'console']);
    const routeParams = {};
    for (const [k, v] of params) {
      if (!reserved.has(k)) routeParams[k] = /^\d+$/.test(v) ? Number(v) : v;
    }
    setTimeout(() => window.postMessage({ type: 'open', page: params.get('page') || undefined, params: routeParams, console: params.get('console') === '1' }, '*'), 50);
  }
  if (params.get('alert') === '1') {
    setTimeout(() => window.postMessage({ type: 'alert', key: 'Y', seconds: 600, call: { id: 1043, code: '10-71', title: 'Shots fired', priority: 1, street: 'Grove St', description: 'Several shots near the basketball court.', info: [{ label: 'Weapon', value: 'Rifle' }] } }, '*'), 300);
    setTimeout(() => window.postMessage({ type: 'alert', key: 'Y', seconds: 600, call: { id: 1044, code: '911', title: '911 call', priority: 2, street: 'Vinewood Blvd', description: "Someone's breaking into my car." } }, '*'), 400);
  }
}

export default app;
