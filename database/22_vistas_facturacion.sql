/* =====================================================================
   22_vistas_facturacion.sql  |  Dueño: FRONTEND
   ---------------------------------------------------------------------
   TODO dbo.vw_FacturasSaldo             (reporte 10, dashboard)
     Factura + OrdenServicio + Equipo + Cliente
     totalPagado = dbo.fn_TotalPagado(idFactura), saldo = dbo.fn_SaldoFactura(idFactura)
     estadoPago = CASE WHEN saldo = 0 THEN 'PAGADA' WHEN totalPagado > 0 THEN 'PARCIAL' ELSE 'PENDIENTE' END
     OJO: NO hacer JOIN con Pago aquí (multiplica filas); los pagos van en otra consulta.
   TODO dbo.vw_DashboardResumen          (6.3: una sola fila con todos los contadores)
     ordenesAbiertas, enDiagnostico, enReparacion, listasParaEntregar,
     facturasConSaldo, repuestosBajoMinimo  (subconsultas COUNT)
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

SET NOEXEC OFF;
GO
