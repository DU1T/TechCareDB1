// API SIMULADA de POST /ordenes/{id}/entrega -> { idEntrega, numeroOrden, estado }
import { saldoDe } from '../../../utils/simuladoCaja'
import { ORDENES_SIM, facturaDe } from '../../../utils/simuladoOrdenes'

export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const fallo = (status: number, error: string) => { setResponseStatus(event, status); return { error } }
  const o = ORDENES_SIM[Number(getRouterParam(event, 'id'))]
  const body = await readBody<{ nombreRecibe?: string }>(event).catch(() => null)

  if (!body?.nombreRecibe?.trim()) return fallo(400, 'Revise la orden, el nombre de quien recibe y los datos de entrega.')
  if (!o) return fallo(409, 'La orden no existe.')
  if (o.estado !== 'LISTO') return fallo(409, 'Solo se puede entregar una orden en estado LISTO.')
  const f = facturaDe(o)
  if (f && saldoDe(f) > 0) return fallo(409, 'La factura tiene saldo pendiente: no se puede entregar hasta que esté pagada.')

  o.estado = 'ENTREGADO'
  o.entrega = { fecha: new Date().toISOString(), nombreRecibe: body.nombreRecibe.trim() }
  return { idEntrega: Date.now() % 100000, numeroOrden: o.numeroOrden, estado: 'ENTREGADO' }
})
