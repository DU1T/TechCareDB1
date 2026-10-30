// API SIMULADA de POST /pagos/{id}/anulacion -> { idPago, saldoActual }
import { FACTURAS, PAGOS, recalcular, saldoDe } from '../../../utils/simuladoCaja'
import { ORDENES_SIM } from '../../../utils/simuladoOrdenes'

export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const fallo = (status: number, error: string) => { setResponseStatus(event, status); return { error } }
  const p = PAGOS.find((x) => x.idPago === Number(getRouterParam(event, 'id')))
  const body = await readBody<{ motivo?: string }>(event).catch(() => null)

  if (!body?.motivo?.trim()) return fallo(400, 'Indique un pago valido y un motivo de anulacion de hasta 250 caracteres.')
  if (!p) return fallo(409, 'El pago no existe.')
  if (p.estado === 'ANULADO') return fallo(409, 'El pago ya está anulado.')
  const f = FACTURAS.find((x) => x.idFactura === p.idFactura)!
  const orden = Object.values(ORDENES_SIM).find((o) => o.idFactura === f.idFactura)
  if (orden?.estado === 'ENTREGADO') return fallo(409, 'No se puede anular un pago de una orden ya entregada.')

  p.estado = 'ANULADO'
  p.motivoAnulacion = body.motivo.trim()
  recalcular(f)
  return { idPago: p.idPago, saldoActual: saldoDe(f) }
})
