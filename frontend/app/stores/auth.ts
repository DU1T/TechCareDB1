type Usuario = {
  idUsuario: number
  nombreCompleto: string
  roles: string[]
  permisos: string[]
}

// Lo que llegue de la API (o de sessionStorage) se normaliza: roles y permisos siempre son arreglos
function normalizar(u: Partial<Usuario> | null | undefined): Usuario {
  return {
    idUsuario: Number(u?.idUsuario ?? 0),
    nombreCompleto: String(u?.nombreCompleto ?? ''),
    roles: Array.isArray(u?.roles) ? u.roles : [],
    permisos: Array.isArray(u?.permisos) ? u.permisos : [],
  }
}

export const useAuthStore = defineStore('auth', {
  state: () => ({
    token: null as string | null,
    usuario: null as Usuario | null,
  }),

  getters: {
    // auth.puede('PAGO_REGISTRAR'): sirve para mostrar u ocultar menús y botones.
    // Es comodidad visual; la seguridad real está en la API y en la base de datos.
    puede: (s) => (permiso: string) => s.usuario?.permisos?.includes(permiso) ?? false,
  },

  actions: {
    async login(username: string, password: string) {
      const { public: cfg } = useRuntimeConfig()
      const r = await $fetch<{ token: string; usuario: Usuario }>('/auth/login', {
        baseURL: cfg.apiBase,
        method: 'POST',
        body: { username, password },
      })
      if (!r?.token) throw new Error('RESPUESTA_INVALIDA')
      const usuario = normalizar(r.usuario)
      this.token = r.token
      this.usuario = usuario
      try {
        sessionStorage.setItem('tc_sesion', JSON.stringify({ token: r.token, usuario }))
      } catch {
        /* modo privado: la sesión vive solo en memoria */
      }
    },

    restaurar() {
      try {
        const s = sessionStorage.getItem('tc_sesion')
        if (s) {
          const r = JSON.parse(s)
          if (r?.token) {
            this.token = r.token
            this.usuario = normalizar(r.usuario)
          }
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
