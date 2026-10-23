/*
  Toda llamada a la API pasa por aquí:
  - agrega el token en cada petición
  - 401: la sesión venció o no existe, vuelve al login
  - 403: el rol no tiene permiso para esa acción
  - 409 / 422: el mensaje viene del THROW del procedimiento almacenado y se muestra tal cual
*/
export const useApi = () => {
  const config = useRuntimeConfig()
  const auth = useAuthStore()
  const toast = useToast()

  return $fetch.create({
    baseURL: config.public.apiBase,

    onRequest({ options }) {
      if (auth.token) {
        const headers = new Headers(options.headers)
        headers.set('Authorization', `Bearer ${auth.token}`)
        options.headers = headers
      }
    },

    onResponseError({ response }) {
      if (response.status === 401) return auth.logout()

      const mensaje =
        response.status === 403
          ? 'Tu rol no tiene permiso para esta acción.'
          : (typeof response._data?.error === 'string' ? response._data.error : 'Ocurrió un error inesperado. Intenta de nuevo.')

      toast.add({ title: 'No se pudo completar', description: mensaje, color: 'error' })
    },
  })
}
