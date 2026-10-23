/*
  Se ejecuta en cada cambio de ruta.
  - Sin sesión: todo lleva al login.
  - Con sesión: el login ya no se muestra.
  - Cada página declara su permiso con definePageMeta({ permiso: 'PAGO_REGISTRAR' }).
*/
export default defineNuxtRouteMiddleware((to) => {
  const auth = useAuthStore()
  if (!auth.token) auth.restaurar()

  if (to.path === '/login') {
    return auth.token ? navigateTo('/') : undefined
  }
  if (!auth.token) return navigateTo('/login')

  const permiso = to.meta.permiso as string | undefined
  if (permiso && !auth.puede(permiso)) return navigateTo('/')
})
