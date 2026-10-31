import { CLIENTES } from '../../../utils/simuladoClientes'
// API SIMULADA de GET /clientes/{id}
export default defineEventHandler((event) => {
  requerirSimulado(event)
  const c = CLIENTES.find((x) => x.idCliente === Number(getRouterParam(event, 'id')))
  if (!c) throw createError({ statusCode: 404, data: { error: 'Cliente no encontrado.' } })
  return c
})
