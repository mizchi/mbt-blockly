import { defineConfig } from 'vite';
import moonbit from 'vite-plugin-moonbit';

export default defineConfig({
  base: '/mbt-blockly/',
  plugins: [
    moonbit({
      watch: true,
      showLogs: true,
      mode: "debug",
    })
  ],
});
