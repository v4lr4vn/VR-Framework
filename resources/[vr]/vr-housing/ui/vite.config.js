import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'
import postcss from './postcss.config.js';
import { resolve } from "path";

export default defineConfig({
  css: {
    postcss,
  },
  plugins: [svelte({
  })],
  base: './',
  resolve: {
    alias: {
      "@assets": resolve("./src/assets"),
      "@components": resolve("./src/components"),
      "@providers": resolve("./src/providers"),
      "@store": resolve("./src/store"),
      "@utils": resolve("./src/utils"),
      "@customTypes": resolve("./src/customTypes"),
    },
  },
  build: {
    emptyOutDir: true,
    outDir: '../html',
    assetsDir: './',
    rollupOptions: {
      output: {
        entryFileNames: `[name].js`,
        chunkFileNames: `[name].js`,
        assetFileNames: `[name].[ext]`
      }
    }
  },
})
