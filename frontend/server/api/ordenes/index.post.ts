import { EQUIPOS } from '../../utils/simuladoClientes'
// API SIMULADA de POST /ordenes (devuelve {idOrden, numeroOrden}); 50204: equipo inexistente o inactivo
let ultima = 100
export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const b = await readBody(event)
  const eq = EQUIPOS.find((e) => e.idEquipo === b.idEquipo)
  if (!eq || eq.estado !== 'ACTIVO') throw createError({ statusCode: 409, data: { error: 'El equipo no existe o no está activo.' } })
  ultima += 1
  return { idOrden: ultima, numeroOrden: `OS-${String(ultima).padStart(6, '0')}` }
})
