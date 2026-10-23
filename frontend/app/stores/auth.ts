type Usuario = {
  idUsuario: number
  nombreCompleto: string
  roles: string[]
  permisos: string[]
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    token: null as string | null,
    usuario: null as Usuario | null,
  }),

  getters: {
    // auth.puede('PAGO_REGISTRAR'): sirve para mostrar u ocultar menús y botones.
    // Es comodidad visual; la seguridad real está en la API y en la base de datos.
    puede: (s) => (permiso: string) => s.usuario?.permisos.includes(permiso) ?? false,
  },

  actions: {
    async login(username: string, password: string) {
      const { public: cfg } = useRuntimeConfig()
      const r = await $fetch<{ token: string; usuario: Usuario }>('/auth/login', {
        baseURL: cfg.apiBase,
        method: 'POST',
        body: { username, password },
      })
      this.token = r.token
      this.usuario = r.usuario
      try {
        sessionStorage.setItem('tc_sesion', JSON.stringify(r))
      } catch {
        /* modo privado: la sesión vive solo en memoria */
      }
    },

    restaurar() {
      try {
        const s = sessionStorage.getItem('tc_sesion')
        if (s) {
          const r = JSON.parse(s)
          this.token = r.token
          this.usuario = r.usuario
        }
      } catch {
        /* sin almacenamiento: se pide login */
      }
    },

    logout() {
      this.token = null
      this.usuario = null
      try {
        sessionStorage.removeItem('tc_sesion')
      } catch {
        /* nada que limpiar */
      }
      navigateTo('/login')
    },
  },
})
