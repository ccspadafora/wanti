import { defineConfig } from 'vite'
import react from '@vitejs/plugin-react'

// En producción se sirve bajo /panel/ en el mismo origen que el API.
const base = process.env.VITE_BASE || '/'

export default defineConfig({
  base,
  plugins: [react()],
  server: {
    port: 5173,
    proxy: {
      '/api': {
        target: 'http://127.0.0.1:8000',
        changeOrigin: true,
      },
    },
  },
})
