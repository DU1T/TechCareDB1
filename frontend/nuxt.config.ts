// https://nuxt.com/docs/api/configuration/nuxt-config
export default defineNuxtConfig({
  compatibilityDate: '2025-07-15',
  devtools: { enabled: false },

  // SPA: no hace falta renderizar en el servidor y el login con JWT es más simple
  ssr: false,

  modules: ['@nuxt/ui', '@pinia/nuxt'],
  css: ['~/assets/css/main.css'],

  // Una sola paleta (ver main.css), sin modo oscuro y sin fuentes externas:
  // así el sistema funciona igual sin internet (por ejemplo, en la demo)
  ui: { colorMode: false, fonts: false },

  // Los íconos se empaquetan dentro de la app: no se piden a internet en la demo.
  // Si usas un ícono nuevo que no aparece, agrégalo a esta lista con el formato 'lucide:nombre'.
  icon: {
    clientBundle: {
      scan: true,
      icons: [
        'lucide:layout-dashboard',
        'lucide:users',
        'lucide:clipboard-plus',
        'lucide:wrench',
        'lucide:receipt',
        'lucide:chart-no-axes-column',
        'lucide:user-cog',
        'lucide:package',
        'lucide:log-out',
        'lucide:menu',
        'lucide:eye',
        'lucide:eye-off',
        'lucide:circle-alert',
        'lucide:boxes',
        'lucide:history',
        'lucide:truck',
        'lucide:plus',
        'lucide:trash-2',
        'lucide:search',
        'lucide:sliders-horizontal',
        'lucide:package-check',
        'lucide:arrow-left',
      ],
    },
  },

  runtimeConfig: {
    public: {
      // '/api' = API simulada que vive en server/api (sin depender del backend).
      // Cuando B publique la API real, pon en .env: NUXT_PUBLIC_API_BASE=http://localhost:5080/api
      apiBase: '/api',
      // Muestra los atajos de rol y activa la API simulada. Por defecto solo en desarrollo;
      // un build de producción la trae apagada salvo que se pida: NUXT_PUBLIC_MODO_SIMULADO=true
      modoSimulado: process.env.NODE_ENV !== 'production',
    },
  },

  app: {
    head: {
      title: 'TechCare',
      htmlAttrs: { lang: 'es' },
      meta: [{ name: 'theme-color', content: '#0d2b26' }],
      link: [{ rel: 'icon', type: 'image/svg+xml', href: '/favicon.svg' }],
    },
  },
})
