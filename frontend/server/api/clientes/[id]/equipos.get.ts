import { EQUIPOS } from '../../../utils/simuladoClientes'
// API SIMULADA de GET /clientes/{id}/equipos
export default defineEventHandler((event) => {
  requerirSimulado(event)
  const id = Number(getRouterParam(event, 'id'))
  return EQUIPOS.filter((e) => e.idCliente === id).sort((a, b) => b.idEquipo - a.idEquipo)
})
