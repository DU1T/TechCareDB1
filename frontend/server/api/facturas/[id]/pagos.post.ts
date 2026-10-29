// API SIMULADA de POST /facturas/{id}/pagos -> { idPago, saldoRestante }
import { FACTURAS, METODOS, saldoDe } from '../../../utils/simuladoCaja'

export default defineEventHandler(async (event) => {
  requerirSimulado(event)
  const f = FACTURAS.find((x) => x.idFactura === Number(getRouterParam(event, 'id')))
  const body = await readBody<{ idMetodoPago?: number; monto?: number; referencia?: string }>(event).catch(() => null)
  const fallo = (status: number, error: string) => { setResponseStatus(event, status); return { error } }

  if (!f) return fallo(409, 'La factura no existe.')
  const metodo = METODOS.find((m) => m.idMetodoPago === body?.idMetodoPago)
  if (!metodo || typeof body?.monto !== 'number') return fallo(400, 'Indique método de pago y monto.')
  if (metodo.requiereReferencia && !body.referencia?.trim()) return fallo(409, 'Este método de pago requiere número de referencia.')
  const saldo = saldoDe(f)
  if (saldo === 0) return fallo(409, 'La factura ya está pagada.')
  if (Math.round(body.monto * 100) > Math.round(saldo * 100)) return fallo(409, 'El pago excede el saldo pendiente de la factura (R12).')

  f.totalPagado = Math.round((f.totalPagado + body.monto) * 100) / 100
  return { idPago: Date.now() % 100000, saldoRestante: saldoDe(f) }
})
