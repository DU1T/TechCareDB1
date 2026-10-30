/*
  Órdenes simuladas con estado, para probar facturar, cobrar, anular un pago y entregar (solo modo simulado).
  Orden 4: LISTO sin factura (se puede facturar). Orden 24: LISTO con factura A-000012 pendiente de pago.
*/
import { FACTURAS, METODOS, PAGOS, saldoDe, type FacturaSim } from './simuladoCaja'

type OrdenSim = {
  numeroOrden: string
  estado: string
  cliente: string
  nit: string
  tipoEquipo: string
  marca: string
  modelo: string
  serie: string
  problema: string
  manoObra: number
  idFactura: number | null
  entrega: { fecha: string; nombreRecibe: string } | null
}

export const ORDENES_SIM: Record<number, OrdenSim> = {
  4: { numeroOrden: 'OS-000004', estado: 'LISTO', cliente: 'Taller Los Pinos, S.A.', nit: '9876543-2', tipoEquipo: 'Impresora', marca: 'HP', modelo: 'LaserJet M404', serie: 'VNB3K29', problema: 'Atasca el papel', manoObra: 300, idFactura: null, entrega: null },
  24: { numeroOrden: 'OS-000024', estado: 'LISTO', cliente: 'Taller Los Pinos, S.A.', nit: '9876543-2', tipoEquipo: 'Laptop', marca: 'Dell', modelo: 'Latitude 5420', serie: 'D5420-77A', problema: 'Se apaga sola', manoObra: 1200, idFactura: 2, entrega: null },
}

export const facturaDe = (o: OrdenSim): FacturaSim | undefined => FACTURAS.find((f) => f.idFactura === o.idFactura)

// Misma forma que la respuesta real de GET /reportes/12 (5 resultados con nombre)
export function trazabilidadSimulada(id: number) {
  const o = ORDENES_SIM[id]
  if (!o) return null
  const f = facturaDe(o)
  const pagos = f ? PAGOS.filter((p) => p.idFactura === f.idFactura) : []
  const subtotal = f ? Math.round((f.total / 1.12) * 100) / 100 : null
  return {
    encabezado: {
      idOrden: id, numeroOrden: o.numeroOrden, fechaIngreso: '2026-10-22T09:00:00', estado: o.estado, prioridad: 'MEDIA',
      problemaReportado: o.problema, cliente: o.cliente, nitCliente: o.nit, tipoEquipo: o.tipoEquipo, marca: o.marca, modelo: o.modelo,
      numeroSerie: o.serie, recepcionista: 'Recepcionista Uno', fechaDiagnostico: '2026-10-22T11:00:00', diagnostico: 'Falla identificada y reparable.',
      tecnicoDiagnostico: 'Técnico Uno', costoManoObraEstimado: o.manoObra, respuestaCliente: 'AUTORIZADO', inicioReparacion: '2026-10-23T09:00:00',
      finReparacion: '2026-10-23T15:00:00', estadoReparacion: 'FINALIZADA', descripcionTrabajo: 'Reparación realizada y probada.',
      tecnicoReparacion: 'Técnico Uno', costoManoObra: o.manoObra,
      idFactura: f?.idFactura ?? null, numeroFactura: f?.numeroFactura ?? null, fechaEmision: f?.fechaEmision ?? null,
      subtotal, impuesto: f && subtotal != null ? Math.round((f.total - subtotal) * 100) / 100 : null, total: f?.total ?? null,
      totalPagado: f?.totalPagado ?? null, saldo: f ? saldoDe(f) : null,
      fechaEntrega: o.entrega?.fecha ?? null, nombreRecibe: o.entrega?.nombreRecibe ?? null, entregadoPor: o.entrega ? 'Recepcionista Uno' : null,
    },
    repuestos: [],
    movimientos: [],
    pagos: pagos.map((p) => ({
      idPago: p.idPago, fechaPago: p.fechaPago, metodoPago: METODOS.find((m) => m.idMetodoPago === p.idMetodoPago)?.nombre,
      monto: p.monto, referencia: p.referencia, estado: p.estado, cajero: 'Cajero Uno', motivoAnulacion: p.motivoAnulacion,
    })),
    historial: [
      { estadoAnterior: null, estadoNuevo: 'RECIBIDO', fechaCambio: '2026-10-22T09:00:00', usuario: 'Recepcionista Uno', observacion: 'Orden registrada' },
      { estadoAnterior: 'REPARACION', estadoNuevo: 'LISTO', fechaCambio: '2026-10-23T15:00:00', usuario: 'Técnico Uno', observacion: 'Reparación finalizada' },
      ...(o.entrega ? [{ estadoAnterior: 'LISTO', estadoNuevo: 'ENTREGADO', fechaCambio: o.entrega.fecha, usuario: 'Recepcionista Uno', observacion: `Entrega a ${o.entrega.nombreRecibe}` }] : []),
    ],
  }
}
