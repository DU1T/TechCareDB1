import { CLIENTES } from '../../utils/simuladoClientes'
// API SIMULADA de GET /clientes?buscar=
export default defineEventHandler((event) => {
  requerirSimulado(event)
  const t = String(getQuery(event).buscar ?? '').trim().toLowerCase()
  return CLIENTES.filter((c) => !t || c.nombre.toLowerCase().includes(t) || c.nit.toLowerCase().includes(t))
})
