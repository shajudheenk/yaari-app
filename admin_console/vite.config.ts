import react from '@vitejs/plugin-react'
import { defineConfig } from 'vite'

// https://vite.dev/config/
export default defineConfig({
  plugins: [react()],
  // Credentials live in a single .env at the repo root, shared with the
  // Flutter apps, rather than being duplicated per package.
  envDir: '..',
})
