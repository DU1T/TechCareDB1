// API SIMULADA de GET /facturas?conSaldo=true (misma forma que vw_FacturasSaldo)
import { FACTURAS, saldoDe } from '../../utils/simuladoCaja'

export default defineEventHandler((event) => {
  requerirSimulado(event)
  const soloSaldo = getQuery(event).conSaldo === 'true'
  return FACTURAS.map((f) => {
    const saldo = saldoDe(f)
    return { ...f, saldo, estadoPago: saldo === 0 ? 'PAGADA' : f.totalPagado > 0 ? 'PARCIAL' : 'PENDIENTE' }
  }).filter((f) => !soloSaldo || f.saldo > 0)
})
