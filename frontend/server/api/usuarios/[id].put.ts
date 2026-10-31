import { USUARIOS, rol } from '../../utils/simuladoUsuarios'
// API SIMULADA de PUT /usuarios/{id}: password opcional (solo si se quiere cambiar)
export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const u = USUARIOS.find((x) => x.idUsuario === Number(getRouterParam(event, 'id')))
  if (!u) throw createError({ statusCode: 404, data: { error: 'El usuario no existe.' } })
  const b = await readBody(event)
  if (b.password != null && String(b.password).length < 8) throw createError({ statusCode: 400, data: { error: 'La nueva contraseña debe tener al menos 8 caracteres.' } })
  Object.assign(u, { username: b.username, nombreCompleto: b.nombreCompleto, email: b.email ?? null, telefono: b.telefono ?? null, estado: b.estado, roles: (b.idRoles as number[]).map(rol) })
  return u
})
