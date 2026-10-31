// API SIMULADA de GET /inventario/kardex (misma forma que sp_Reporte_09_Kardex).
// Como el real, NO viene ordenado por fecha sino por bodega y repuesto: así la pantalla de Inicio prueba que ordena ella.
export default defineEventHandler((event) => {
  requerirSimulado(event)
  const hace = (horas: number) => new Date(Date.now() - horas * 3600_000).toISOString().slice(0, 19)
  return [
    { fechaMovimiento: hace(70), bodega: 'Bodega Central', codigo: 'ALM-001', repuesto: 'SSD 480 GB SATA', tipo: 'ENTRADA', origen: 'COMPRA', documentoOrigen: 'Compra FAC-0098 · Distribuidora Tecno', cantidad: 10, existenciaAnterior: 4, existenciaResultante: 14, usuario: 'Bodeguero Uno' },
    { fechaMovimiento: hace(30), bodega: 'Bodega Central', codigo: 'ALM-001', repuesto: 'SSD 480 GB SATA', tipo: 'SALIDA', origen: 'REPARACION', documentoOrigen: 'Orden OS-000040', cantidad: 1, existenciaAnterior: 14, existenciaResultante: 13, usuario: 'Tecnico Dos' },
    { fechaMovimiento: hace(5), bodega: 'Bodega Central', codigo: 'BAT-002', repuesto: 'Batería laptop 6 celdas', tipo: 'SALIDA', origen: 'REPARACION', documentoOrigen: 'Orden OS-000037', cantidad: 2, existenciaAnterior: 6, existenciaResultante: 4, usuario: 'Tecnico Uno' },
    { fechaMovimiento: hace(50), bodega: 'Sucursal Zona 10', codigo: 'FUE-001', repuesto: 'Cargador 65 W USB-C', tipo: 'ENTRADA', origen: 'AJUSTE', documentoOrigen: 'Ajuste: conteo físico', cantidad: 3, existenciaAnterior: 2, existenciaResultante: 5, usuario: 'Bodeguero Dos' },
    { fechaMovimiento: hace(12), bodega: 'Sucursal Zona 10', codigo: 'FUE-001', repuesto: 'Cargador 65 W USB-C', tipo: 'ENTRADA', origen: 'DEVOLUCION', documentoOrigen: 'Devolución de la orden OS-000031', cantidad: 1, existenciaAnterior: 5, existenciaResultante: 6, usuario: 'Tecnico Uno' },
  ]
})
