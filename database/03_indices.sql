/* =====================================================================
   03_indices.sql  |  NÚCLEO  |  Índices no agrupados justificados
   ---------------------------------------------------------------------
   Regla: cada índice responde "¿qué consulta concreta mejora?".
   Las PK y UNIQUE ya crean índices (p.ej. Equipo.numeroSerie): no se duplican.
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
-- NIT único salvo 'CF' (consumidor final puede repetirse). Índice único filtrado.
CREATE UNIQUE NONCLUSTERED INDEX UX_Cliente_Nit
    ON dbo.Cliente (nit) WHERE nit <> 'CF';
GO
-- Email de usuario único cuando existe.
CREATE UNIQUE NONCLUSTERED INDEX UX_Usuario_Email
    ON dbo.Usuario (email) WHERE email IS NOT NULL;
GO

-- IX1 Dashboard y reporte 1: WHERE estado IN (...) ORDER BY fechaIngreso
CREATE NONCLUSTERED INDEX IX_OrdenServicio_Estado_Fecha
    ON dbo.OrdenServicio (estado, fechaIngreso)
    INCLUDE (prioridad, idTecnicoAsignado, idEquipo);
GO

-- IX2 Reporte 3 / historial de equipo: WHERE idEquipo = @x ORDER BY fechaIngreso DESC
CREATE NONCLUSTERED INDEX IX_OrdenServicio_Equipo_Fecha
    ON dbo.OrdenServicio (idEquipo, fechaIngreso DESC);
GO

-- IX3 Reporte 2: equipos de un cliente (JOIN Equipo.idCliente = Cliente.idCliente)
CREATE NONCLUSTERED INDEX IX_Equipo_Cliente
    ON dbo.Equipo (idCliente);
GO

-- IX4 fn_SaldoFactura / fn_TotalPagado / reporte 10: SUM(monto) WHERE idFactura = @x AND estado = 'APLICADO'
CREATE NONCLUSTERED INDEX IX_Pago_Factura
    ON dbo.Pago (idFactura, estado) INCLUDE (monto, fechaPago, idMetodoPago);
GO

-- IX5 Reporte 9 (kárdex): movimientos de un repuesto en una bodega por fecha
CREATE NONCLUSTERED INDEX IX_Movimiento_Bodega_Repuesto_Fecha
    ON dbo.MovimientoInventario (idBodega, idRepuesto, fechaMovimiento)
    INCLUDE (tipo, origen, cantidad, existenciaResultante, idUsuario);
GO

-- IX6 Reportes 5 y 12, fn_TotalOrden: repuestos de una reparación
CREATE NONCLUSTERED INDEX IX_DetalleRepuesto_Reparacion
    ON dbo.DetalleRepuesto (idReparacion, estado)
    INCLUDE (idBodega, idRepuesto, cantidad, precioUnitario, costoUnitario);
GO

-- IX7 Trazabilidad / auditoría: historial de estados de una orden
CREATE NONCLUSTERED INDEX IX_HistorialEstado_Orden_Fecha
    ON dbo.HistorialEstadoOrden (idOrden, fechaCambio);
GO

-- IX8 Reporte 11: ingresos por período (WHERE fechaEmision BETWEEN ...)
CREATE NONCLUSTERED INDEX IX_Factura_FechaEmision
    ON dbo.Factura (fechaEmision) INCLUDE (estado, subtotal, impuesto, total);
GO

-- IX9 Reporte 4: diagnósticos por técnico en rango de fechas
CREATE NONCLUSTERED INDEX IX_Diagnostico_Tecnico_Fecha
    ON dbo.Diagnostico (idTecnico, fechaDiagnostico);
GO

-- IX10 Reporte 8: compras por proveedor y fecha
CREATE NONCLUSTERED INDEX IX_Compra_Proveedor_Fecha
    ON dbo.Compra (idProveedor, fechaCompra) INCLUDE (estado, idBodegaDestino);
GO

SET NOEXEC OFF;
GO
