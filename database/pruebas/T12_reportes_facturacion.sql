/* ============================================================
   T12: Reportes 10, 11 y 12 (facturación y trazabilidad)
   Solo LEE datos (no confirma cambios). Ejecutar en su base TechCare_<nombre>
   después de reconstruir (incluye 84_datos_facturacion.sql).
   ============================================================ */
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
SET NOCOUNT ON;

-- Orden con factura, repuestos y varios pagos, para probar el reporte 12
DECLARE @orden INT = (SELECT TOP 1 f.idOrden
                      FROM dbo.Factura f
                      WHERE (SELECT COUNT(*) FROM dbo.Pago p WHERE p.idFactura = f.idFactura) >= 2
                        AND EXISTS (SELECT 1 FROM dbo.DetalleFactura d WHERE d.idFactura = f.idFactura AND d.tipoLinea = 'REPUESTO')
                      ORDER BY f.idFactura);

PRINT '--- Reporte 10: facturas con saldo (2 resultados: facturas, pagos) ---';
EXEC dbo.sp_Reporte_10_FacturasSaldo;
PRINT '--- Reporte 10: todas las facturas, rango de fechas ---';
EXEC dbo.sp_Reporte_10_FacturasSaldo @soloConSaldo = 0, @fechaInicio = '2026-01-01', @fechaFin = '2026-12-31';

PRINT '--- Reporte 11: ingresos por mes ---';
EXEC dbo.sp_Reporte_11_IngresosPeriodo;

PRINT '--- Reporte 12: trazabilidad (5 resultados) ---';
EXEC dbo.sp_Reporte_12_Trazabilidad @idOrden = @orden;

PRINT '--- Verificaciones ---';
-- 1) El reporte 10 no repite facturas (una fila por factura)
IF (SELECT COUNT(*) FROM dbo.vw_FacturasSaldo WHERE estadoFactura='EMITIDA' AND saldo > 0)
 = (SELECT COUNT(*) FROM dbo.Factura f WHERE f.estado='EMITIDA' AND dbo.fn_SaldoFactura(f.idFactura) > 0)
    PRINT 'OK  R10: facturas con saldo coinciden con fn_SaldoFactura';
ELSE PRINT 'FALLA R10: no coincide el conteo de facturas con saldo';

-- 2) El reporte 11 debe sumar lo mismo que las facturas EMITIDAS (si el impuesto se inflara, no coincidiría)
DECLARE @totalFacturas DECIMAL(14,2) = (SELECT SUM(total) FROM dbo.Factura WHERE estado = 'EMITIDA');
DECLARE @r11 TABLE (anio INT, mes INT, periodo VARCHAR(10), facturas INT, ingresoManoObra DECIMAL(14,2),
                    ingresoRepuestos DECIMAL(14,2), subtotal DECIMAL(14,2), impuesto DECIMAL(14,2), total DECIMAL(14,2));
INSERT INTO @r11 EXEC dbo.sp_Reporte_11_IngresosPeriodo;
IF (SELECT SUM(total) FROM @r11) = @totalFacturas
   AND (SELECT SUM(ingresoManoObra + ingresoRepuestos) FROM @r11) = (SELECT SUM(subtotal) FROM @r11)
    PRINT 'OK  R11: el total del reporte coincide con las facturas emitidas';
ELSE PRINT 'FALLA R11: el total no coincide con las facturas emitidas';

-- 3) Orden inexistente y fechas invertidas devuelven error controlado
BEGIN TRY EXEC dbo.sp_Reporte_12_Trazabilidad @idOrden = -1; PRINT 'FALLA R12 sin error'; END TRY
BEGIN CATCH PRINT IIF(ERROR_NUMBER()=50327,'OK  R12: orden inexistente -> 50327','FALLA R12 error '+CAST(ERROR_NUMBER() AS VARCHAR(10))); END CATCH
BEGIN TRY EXEC dbo.sp_Reporte_11_IngresosPeriodo @fechaInicio='2026-12-31', @fechaFin='2026-01-01'; PRINT 'FALLA R11 sin error'; END TRY
BEGIN CATCH PRINT IIF(ERROR_NUMBER()=50325,'OK  R11: fechas invertidas -> 50325','FALLA R11 error '+CAST(ERROR_NUMBER() AS VARCHAR(10))); END CATCH
GO
SET NOEXEC OFF;
GO
