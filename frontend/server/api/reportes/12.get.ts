/*
  API SIMULADA de GET /reportes/12?idOrden= (misma forma que la real: 5 resultados con nombre).
  Orden 1: completa y entregada. Orden 2: recién recibida (sin diagnóstico ni factura). Otras: 404.
*/
export default defineEventHandler((event) => {
  requerirSimulado(event)
  const id = Number(getQuery(event).idOrden)

  if (id === 1) {
    return {
      encabezado: {
        numeroOrden: 'OS-000001', fechaIngreso: '2026-10-10T08:00:00', estado: 'ENTREGADO', prioridad: 'ALTA',
        problemaReportado: 'No enciende después de una caída', cliente: 'María López', nitCliente: '1234567-8',
        tipoEquipo: 'Laptop', marca: 'Lenovo', modelo: 'ThinkPad E14', numeroSerie: 'PF3KX812',
        recepcionista: 'Recepcionista Uno', fechaDiagnostico: '2026-10-10T10:00:00',
        diagnostico: 'Memoria RAM dañada; se recomienda reemplazo.', tecnicoDiagnostico: 'Técnico Uno',
        costoManoObraEstimado: 150, respuestaCliente: 'AUTORIZADO', inicioReparacion: '2026-10-10T14:00:00',
        finReparacion: '2026-10-10T16:00:00', estadoReparacion: 'FINALIZADA', descripcionTrabajo: 'Cambio de memoria RAM DDR5 16 GB.',
        tecnicoReparacion: 'Técnico Uno', costoManoObra: 150, numeroFactura: 'A-000001', fechaEmision: '2026-10-10T16:30:00',
        subtotal: 800, impuesto: 96, total: 896, totalPagado: 896, saldo: 0,
        fechaEntrega: '2026-10-10T18:00:00', nombreRecibe: 'María López', entregadoPor: 'Recepcionista Uno',
      },
      repuestos: [
        { bodega: 'Bodega Central', codigo: 'RAM-003', repuesto: 'Memoria DDR5 16 GB', cantidad: 1, precioUnitario: 650, subtotal: 650, estado: 'APLICADO', fechaRegistro: '2026-10-10T14:50:00', registradoPor: 'Técnico Uno' },
      ],
      movimientos: [
        { fechaMovimiento: '2026-10-10T14:50:00', tipo: 'SALIDA', origen: 'REPARACION', bodega: 'Bodega Central', codigo: 'RAM-003', repuesto: 'Memoria DDR5 16 GB', cantidad: 1, existenciaAnterior: 7, existenciaResultante: 6, usuario: 'Técnico Uno' },
      ],
      pagos: [
        { fechaPago: '2026-10-10T16:42:00', metodoPago: 'CHEQUE', monto: 448, referencia: 'AUT-1-1', estado: 'APLICADO', cajero: 'Cajero Uno', motivoAnulacion: null },
        { fechaPago: '2026-10-10T17:05:00', metodoPago: 'EFECTIVO', monto: 448, referencia: null, estado: 'APLICADO', cajero: 'Cajero Uno', motivoAnulacion: null },
      ],
      historial: [
        { estadoAnterior: null, estadoNuevo: 'RECIBIDO', fechaCambio: '2026-10-10T08:00:00', usuario: 'Recepcionista Uno', observacion: 'Orden registrada' },
        { estadoAnterior: 'RECIBIDO', estadoNuevo: 'DIAGNOSTICO', fechaCambio: '2026-10-10T09:00:00', usuario: 'Técnico Uno', observacion: 'Inicio del diagnóstico' },
        { estadoAnterior: 'DIAGNOSTICO', estadoNuevo: 'REPARACION', fechaCambio: '2026-10-10T14:00:00', usuario: 'Técnico Uno', observacion: 'Reparación iniciada' },
        { estadoAnterior: 'REPARACION', estadoNuevo: 'LISTO', fechaCambio: '2026-10-10T16:00:00', usuario: 'Técnico Uno', observacion: 'Reparación finalizada' },
        { estadoAnterior: 'LISTO', estadoNuevo: 'ENTREGADO', fechaCambio: '2026-10-10T18:00:00', usuario: 'Recepcionista Uno', observacion: 'Entrega a María López' },
      ],
    }
  }

  if (id === 2) {
    return {
      encabezado: {
        numeroOrden: 'OS-000002', fechaIngreso: '2026-10-26T14:10:00', estado: 'RECIBIDO', prioridad: 'MEDIA',
        problemaReportado: 'Pantalla rota', cliente: 'Carlos Méndez', nitCliente: 'CF', tipoEquipo: 'Celular', marca: 'Samsung',
        modelo: 'A54', numeroSerie: 'R58T1XJ2', recepcionista: 'Recepcionista Uno', fechaDiagnostico: null, diagnostico: null,
        tecnicoDiagnostico: null, costoManoObraEstimado: null, respuestaCliente: null, inicioReparacion: null, finReparacion: null,
        estadoReparacion: null, descripcionTrabajo: null, tecnicoReparacion: null, costoManoObra: null, numeroFactura: null,
        fechaEmision: null, subtotal: null, impuesto: null, total: null, totalPagado: null, saldo: null,
        fechaEntrega: null, nombreRecibe: null, entregadoPor: null,
      },
      repuestos: [],
      movimientos: [],
      pagos: [],
      historial: [
        { estadoAnterior: null, estadoNuevo: 'RECIBIDO', fechaCambio: '2026-10-26T14:10:00', usuario: 'Recepcionista Uno', observacion: 'Orden registrada' },
      ],
    }
  }

  setResponseStatus(event, 404)
  return { error: 'La orden no existe.' }
})
