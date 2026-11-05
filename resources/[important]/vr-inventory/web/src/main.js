import './vendor/fa/css/fontawesome.min.css';
import './vendor/fa/css/solid.min.css';
import './vendor/fa/css/regular.min.css';
import './styles/fonts.css';
import './styles/tokens.css';
import './styles/base.css';
import { mount } from 'svelte';
import App from './App.svelte';

mount(App, { target: document.getElementById('app') });
