/*
  API SIMULADA (solo para desarrollo del frontend).
  Tiene la misma forma que la API real de B:
    POST /auth/login  { username, password }
      200 -> { token, usuario: { idUsuario, nombreCompleto, roles, permisos } }
      401 -> { error: 'mensaje legible' }
  Cuando B publique la suya, cambia NUXT_PUBLIC_API_BASE en .env y este archivo deja de usarse.
*/
const REPORTE = ['REPORTE_VER']

const POR_ROL: Record<string, string[]> = {
  RECEPCION: ['CLIENTE_GESTIONAR', 'ORDEN_CREAR', 'ORDEN_CAMBIAR_ESTADO', 'ENTREGA_REGISTRAR', ...REPORTE],
  TECNICO: ['DIAGNOSTICO_REGISTRAR', 'REPARACION_GESTIONAR', 'REPUESTO_CONSUMIR', 'ORDEN_CAMBIAR_ESTADO', ...REPORTE],
  BODEGA: ['CATALOGO_GESTIONAR', 'COMPRA_REGISTRAR', 'COMPRA_RECIBIR', ...REPORTE],
  CAJA: ['FACTURA_EMITIR', 'PAGO_REGISTRAR', 'ENTREGA_REGISTRAR', ...REPORTE],
}
POR_ROL.ADMINISTRADOR = [...new Set([...Object.values(POR_ROL).flat(), 'USUARIO_GESTIONAR'])]

const USUARIOS: Record<string, { idUsuario: number; nombreCompleto: string; rol: string }> = {
  recepcion1: { idUsuario: 1, nombreCompleto: 'Usuario de Recepción', rol: 'RECEPCION' },
  tecnico1: { idUsuario: 2, nombreCompleto: 'Usuario Técnico', rol: 'TECNICO' },
  bodega1: { idUsuario: 3, nombreCompleto: 'Usuario de Bodega', rol: 'BODEGA' },
  caja1: { idUsuario: 4, nombreCompleto: 'Usuario de Caja', rol: 'CAJA' },
  administrador1: { idUsuario: 5, nombreCompleto: 'Usuario Administrador', rol: 'ADMINISTRADOR' },
}

export default defineEventHandler(async (event) => {
  const { username, password } = await readBody<{ username?: string; password?: string }>(event)
  await new Promise((r) => setTimeout(r, 250)) // se nota el estado "cargando", como con una red real

  const u = USUARIOS[String(username ?? '').trim().toLowerCase()]
  if (!u || password !== 'Demo2026!') {
    setResponseStatus(event, 401)
    return { error: 'Usuario o contraseña incorrectos.' }
  }

  return {
    token: `simulado.${u.idUsuario}.${Date.now()}`,
    usuario: {
      idUsuario: u.idUsuario,
      nombreCompleto: u.nombreCompleto,
      roles: [u.rol],
      permisos: POR_ROL[u.rol],
    },
  }
})
