import { CLIENTES } from '../../../utils/simuladoClientes'
// API SIMULADA de PUT /clientes/{id}
export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const c = CLIENTES.find((x) => x.idCliente === Number(getRouterParam(event, 'id')))
  if (!c) throw createError({ statusCode: 404, data: { error: 'Cliente no encontrado.' } })
  const b = await readBody(event)
  Object.assign(c, { tipoCliente: b.tipoCliente, nit: b.nit, nombre: b.nombre, telefono: b.telefono ?? null, email: b.email ?? null, direccion: b.direccion ?? null, estado: b.estado ?? c.estado })
  return { idCliente: c.idCliente, nombre: c.nombre }
})
