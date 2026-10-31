import { USUARIOS, rol, type UsuarioSim } from '../../utils/simuladoUsuarios'
// API SIMULADA de POST /usuarios: devuelve el usuario creado
export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const b = await readBody(event)
  if (!b.password || String(b.password).length < 8) throw createError({ statusCode: 400, data: { error: 'La contraseña debe tener al menos 8 caracteres.' } })
  if (USUARIOS.some((u) => u.username.toLowerCase() === String(b.username).toLowerCase())) throw createError({ statusCode: 409, data: { error: 'Ya existe un usuario con ese username.' } })
  const u: UsuarioSim = {
    idUsuario: Math.max(...USUARIOS.map((x) => x.idUsuario)) + 1, username: b.username, nombreCompleto: b.nombreCompleto,
    email: b.email ?? null, telefono: b.telefono ?? null, estado: 'ACTIVO', fechaCreacion: new Date().toISOString().slice(0, 19),
    roles: (b.idRoles as number[]).map(rol),
  }
  USUARIOS.push(u)
  return u
})
