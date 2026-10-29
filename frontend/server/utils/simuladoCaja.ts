/*
  Datos en memoria para probar la pantalla de Caja sin la API real (solo modo simulado).
  Reproduce las reglas del SP: pago <= saldo (50308), referencia obligatoria (50304).
*/
export const METODOS = [
  { idMetodoPago: 1, nombre: 'EFECTIVO', requiereReferencia: false },
  { idMetodoPago: 2, nombre: 'TARJETA', requiereReferencia: true },
  { idMetodoPago: 3, nombre: 'TRANSFERENCIA', requiereReferencia: true },
  { idMetodoPago: 4, nombre: 'CHEQUE', requiereReferencia: true },
]

export const FACTURAS = [
  { idFactura: 1, numeroFactura: 'A-000011', fechaEmision: '2026-10-20T10:15:00', numeroOrden: 'OS-000021', cliente: 'María López', nitFacturacion: '1234567-8', total: 560, totalPagado: 200 },
  { idFactura: 2, numeroFactura: 'A-000012', fechaEmision: '2026-10-21T15:40:00', numeroOrden: 'OS-000024', cliente: 'Taller Los Pinos, S.A.', nitFacturacion: '9876543-2', total: 1344, totalPagado: 0 },
  { idFactura: 3, numeroFactura: 'A-000013', fechaEmision: '2026-10-26T09:05:00', numeroOrden: 'OS-000030', cliente: 'Carlos Méndez', nitFacturacion: 'CF', total: 95.5, totalPagado: 50 },
].map((f) => ({ ...f }))

export const saldoDe = (f: { total: number; totalPagado: number }) => Math.round((f.total - f.totalPagado) * 100) / 100
