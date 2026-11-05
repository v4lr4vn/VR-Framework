import './styles/tokens.css';
import './styles/base.css';
import './styles/apps.css';
import { mount } from 'svelte';
import App from './App.svelte';
import { inGame } from './lib/nui.js';

const app = mount(App, { target: document.getElementById('app') });

// In a normal browser (npm run dev) there is no game, so a fake one answers instead. It is never part of the build.
if (!inGame && import.meta.env.DEV) {
  import('./dev/mock.js');
}

export default app;
