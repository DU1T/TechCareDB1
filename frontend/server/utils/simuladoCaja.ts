/*
  Datos en memoria para probar Caja y las acciones de la orden sin la API real (solo modo simulado).
  Reproduce las reglas de los SP: pago <= saldo (50308), referencia obligatoria (50304).
*/
export const METODOS = [
  { idMetodoPago: 1, nombre: 'EFECTIVO', requiereReferencia: false },
  { idMetodoPago: 2, nombre: 'TARJETA', requiereReferencia: true },
  { idMetodoPago: 3, nombre: 'TRANSFERENCIA', requiereReferencia: true },
  { idMetodoPago: 4, nombre: 'CHEQUE', requiereReferencia: true },
]

export type PagoSim = {
  idPago: number
  idFactura: number
  idMetodoPago: number
  monto: number
  referencia: string | null
  fechaPago: string
  estado: 'APLICADO' | 'ANULADO'
  motivoAnulacion: string | null
}

export const PAGOS: PagoSim[] = [
  { idPago: 1, idFactura: 1, idMetodoPago: 1, monto: 200, referencia: null, fechaPago: '2026-10-20T11:00:00', estado: 'APLICADO', motivoAnulacion: null },
  { idPago: 2, idFactura: 3, idMetodoPago: 1, monto: 50, referencia: null, fechaPago: '2026-10-26T10:00:00', estado: 'APLICADO', motivoAnulacion: null },
]

export type FacturaSim = {
  idFactura: number
  numeroFactura: string
  fechaEmision: string
  numeroOrden: string
  cliente: string
  nitFacturacion: string
  total: number
  totalPagado: number
}

export const FACTURAS: FacturaSim[] = [
  { idFactura: 1, numeroFactura: 'A-000011', fechaEmision: '2026-10-20T10:15:00', numeroOrden: 'OS-000021', cliente: 'María López', nitFacturacion: '1234567-8', total: 560, totalPagado: 200 },
  { idFactura: 2, numeroFactura: 'A-000012', fechaEmision: '2026-10-21T15:40:00', numeroOrden: 'OS-000024', cliente: 'Taller Los Pinos, S.A.', nitFacturacion: '9876543-2', total: 1344, totalPagado: 0 },
  { idFactura: 3, numeroFactura: 'A-000013', fechaEmision: '2026-10-26T09:05:00', numeroOrden: 'OS-000030', cliente: 'Carlos Méndez', nitFacturacion: 'CF', total: 95.5, totalPagado: 50 },
]

const redondear = (n: number) => Math.round(n * 100) / 100
export const saldoDe = (f: { total: number; totalPagado: number }) => redondear(f.total - f.totalPagado)

// El total pagado nunca se guarda aparte: se calcula con los pagos APLICADOS (igual que fn_TotalPagado)
export function recalcular(f: FacturaSim) {
  f.totalPagado = redondear(PAGOS.filter((p) => p.idFactura === f.idFactura && p.estado === 'APLICADO').reduce((s, p) => s + p.monto, 0))
}
