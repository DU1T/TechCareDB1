// API SIMULADA de POST /ordenes/{id}/factura -> { idFactura, serie, numero, total }
import { FACTURAS } from '../../../utils/simuladoCaja'
import { ORDENES_SIM } from '../../../utils/simuladoOrdenes'

export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const fallo = (status: number, error: string) => { setResponseStatus(event, status); return { error } }
  const o = ORDENES_SIM[Number(getRouterParam(event, 'id'))]
  const body = await readBody<{ nitFacturacion?: string; nombreFacturacion?: string }>(event).catch(() => null)

  if (!o) return fallo(409, 'La orden no existe.')
  if (o.estado !== 'LISTO') return fallo(409, 'Solo se puede facturar una orden en estado LISTO.')
  if (o.idFactura) return fallo(409, 'La orden ya tiene una factura (R11).')

  const idFactura = Math.max(0, ...FACTURAS.map((f) => f.idFactura)) + 1
  const total = Math.round(o.manoObra * 1.12 * 100) / 100
  FACTURAS.push({
    idFactura,
    numeroFactura: `A-${String(10 + idFactura).padStart(6, '0')}`,
    fechaEmision: new Date().toISOString(),
    numeroOrden: o.numeroOrden,
    cliente: body?.nombreFacturacion?.trim() || o.cliente,
    nitFacturacion: body?.nitFacturacion?.trim() || o.nit,
    total,
    totalPagado: 0,
  })
  o.idFactura = idFactura
  return { idFactura, serie: 'A', numero: 10 + idFactura, total }
})
