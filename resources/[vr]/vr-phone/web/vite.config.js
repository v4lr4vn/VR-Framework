import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

// Builds into ../html, which is what the resource serves as its ui_page.
// Every app is a dynamic import (see src/lib/apps.js), so Vite splits each one into its own file
// and the phone only downloads an app when it is first opened.
export default defineConfig({
  plugins: [svelte()],
  base: './',
  build: {
    outDir: '../html',
    emptyOutDir: true,
    assetsInlineLimit: 0,
    chunkSizeWarningLimit: 900,
  },
});
