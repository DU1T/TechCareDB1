// API SIMULADA de GET /metodos-pago (ver server/utils/simuladoCaja.ts)
import { METODOS } from '../utils/simuladoCaja'

export default defineEventHandler((event) => {
  requerirSimulado(event)
  return METODOS
})
