/*
TECHCARE SOLUTIONS
T04 · T05 - Consumir un repuesto en una reparación (sp_UtilizarRepuesto)

Objetivo:
  T04  Pedidos que el SP debe rechazar SIN dejar nada a medias (Inventario, DetalleRepuesto y
       MovimientoInventario iguales antes y después):
       más de lo que hay en la bodega (50106, el caso ALM-001 en BOD-MIX), cantidad 0 (50101),
       usuario sin rol de técnico (50102), reparación que no está en proceso (50103)
       y repuesto que no está en la bodega (50104).
  T05  Consumo válido: detalle con precio y costo HISTÓRICOS (los del catálogo en ese momento),
       existencia descontada, movimiento SALIDA de origen REPARACION que apunta a su detalle y
       encadena con el movimiento anterior; consumir la última unidad deja la existencia en 0.

Datos de entrada:
  Datos de prueba 80 a 85 cargados (reparaciones EN_PROCESO con la orden en REPARACION)
  y los usuarios tecnico1 y caja1.

Este script NO confirma cambios: T04 solo provoca errores y T05 va dentro de una transacción
que termina en ROLLBACK.

Resultado esperado: todas las líneas dicen "OK" y la última dice "T04-T05: 0 FALLA".
*/
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
SET NOCOUNT ON;

DECLARE @r TABLE (n INT IDENTITY, ok BIT, prueba NVARCHAR(200));
DECLARE @uso TABLE (idDetalleRepuesto INT, existenciaResultante INT);   -- recibe el SELECT del SP
DECLARE @caja INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'caja1');
DECLARE @error INT;

-- Una reparación EN_PROCESO (orden en REPARACION), con su técnico
DECLARE @rep INT, @tecnico INT;
SELECT TOP 1 @rep = r.idReparacion, @tecnico = r.idTecnico
FROM dbo.Reparacion r
INNER JOIN dbo.Diagnostico d   ON d.idDiagnostico = r.idDiagnostico
INNER JOIN dbo.OrdenServicio o ON o.idOrden = d.idOrden
WHERE r.estado = 'EN_PROCESO' AND o.estado = 'REPARACION'
ORDER BY r.idReparacion;
DECLARE @repCerrada INT = (SELECT MIN(idReparacion) FROM dbo.Reparacion WHERE estado = 'FINALIZADA');

-- ALM-001 en BOD-MIX (caso de la guía) y su existencia actual
DECLARE @mix INT = (SELECT idBodega FROM dbo.Bodega WHERE codigo = 'BOD-MIX');
DECLARE @alm INT = (SELECT idRepuesto FROM dbo.Repuesto WHERE codigo = 'ALM-001');
DECLARE @existMix INT = (SELECT existencia FROM dbo.Inventario WHERE idBodega = @mix AND idRepuesto = @alm);
DECLARE @pedido INT = @existMix + 1;

INSERT @r VALUES (IIF(@rep IS NOT NULL, 1, 0), CONCAT(N'datos: reparación ', @rep, N' en proceso; ALM-001 en BOD-MIX tiene ', @existMix));

-- Foto de las tres tablas que el SP toca
DECLARE @totInv BIGINT = (SELECT SUM(CAST(existencia AS BIGINT)) FROM dbo.Inventario);
DECLARE @totDet INT = (SELECT COUNT(*) FROM dbo.DetalleRepuesto);
DECLARE @totMov INT = (SELECT COUNT(*) FROM dbo.MovimientoInventario);

/* ---------------- T04: pedidos rechazados ---------------- */
SET @error = 0;
BEGIN TRY EXEC dbo.sp_UtilizarRepuesto @rep, @mix, @alm, @pedido, @tecnico; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 50106, 1, 0), CONCAT(N'T04 pedir ', @pedido, N' de ALM-001 en BOD-MIX (hay ', @existMix, N') -> error ', @error));

SET @error = 0;
BEGIN TRY EXEC dbo.sp_UtilizarRepuesto @rep, @mix, @alm, 0, @tecnico; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 50101, 1, 0), CONCAT(N'T04 cantidad 0 -> error ', @error));

SET @error = 0;
BEGIN TRY EXEC dbo.sp_UtilizarRepuesto @rep, @mix, @alm, 1, @caja; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 50102, 1, 0), CONCAT(N'T04 usuario de caja (no técnico) -> error ', @error));

SET @error = 0;
BEGIN TRY EXEC dbo.sp_UtilizarRepuesto @repCerrada, @mix, @alm, 1, @tecnico; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 50103, 1, 0), CONCAT(N'T04 reparación ya FINALIZADA -> error ', @error));

SET @error = 0;
BEGIN TRY EXEC dbo.sp_UtilizarRepuesto @rep, @mix, -1, 1, @tecnico; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 50104, 1, 0), CONCAT(N'T04 repuesto que no está en la bodega -> error ', @error));

INSERT @r VALUES (IIF((SELECT SUM(CAST(existencia AS BIGINT)) FROM dbo.Inventario) = @totInv
                      AND (SELECT COUNT(*) FROM dbo.DetalleRepuesto) = @totDet
                      AND (SELECT COUNT(*) FROM dbo.MovimientoInventario) = @totMov, 1, 0),
                  N'T04 nada cambió: inventario, repuestos usados y kárdex iguales que antes');
INSERT @r VALUES (IIF(@@TRANCOUNT = 0, 1, 0), N'T04 ninguna transacción quedó abierta');

/* ---------------- T05: consumo válido ---------------- */
-- Un repuesto con al menos 2 unidades en una bodega
DECLARE @b INT, @rp INT, @exist INT, @precio DECIMAL(12,2), @costo DECIMAL(12,2), @ultima INT;
SELECT TOP 1 @b = i.idBodega, @rp = i.idRepuesto, @exist = i.existencia, @precio = r.precioVenta, @costo = r.precioCompraRef
FROM dbo.Inventario i INNER JOIN dbo.Repuesto r ON r.idRepuesto = i.idRepuesto
WHERE i.existencia >= 2 AND r.estado = 'ACTIVO'
ORDER BY i.idBodega, i.idRepuesto;
SET @ultima = (SELECT TOP 1 existenciaResultante FROM dbo.MovimientoInventario
               WHERE idBodega = @b AND idRepuesto = @rp ORDER BY fechaMovimiento DESC, idMovimiento DESC);
DECLARE @resto INT = @exist - 1;

BEGIN TRANSACTION;

    INSERT @uso EXEC dbo.sp_UtilizarRepuesto @rep, @b, @rp, 1, @tecnico;
    DECLARE @det INT = (SELECT TOP 1 idDetalleRepuesto FROM @uso);

    INSERT @r SELECT IIF(d.idReparacion = @rep AND d.cantidad = 1 AND d.precioUnitario = @precio AND d.costoUnitario = @costo
                         AND d.estado = 'APLICADO' AND d.idUsuario = @tecnico, 1, 0),
                     CONCAT(N'T05 detalle con precio ', d.precioUnitario, N' y costo ', d.costoUnitario, N' del catálogo de hoy')
    FROM (SELECT 1 AS x) s LEFT JOIN dbo.DetalleRepuesto d ON d.idDetalleRepuesto = @det;

    INSERT @r SELECT IIF(existencia = @exist - 1, 1, 0), CONCAT(N'T05 existencia descontada: ', @exist, N' -> ', existencia)
    FROM dbo.Inventario WHERE idBodega = @b AND idRepuesto = @rp;

    INSERT @r SELECT IIF(m.tipo = 'SALIDA' AND m.origen = 'REPARACION' AND m.cantidad = 1 AND m.costoUnitario = @costo
                         AND m.idCompra IS NULL, 1, 0),
                     CONCAT(N'T05 movimiento ', m.tipo, N' ', m.origen, N' que apunta al detalle ', m.idDetalleRepuesto)
    FROM (SELECT 1 AS x) s LEFT JOIN dbo.MovimientoInventario m ON m.idDetalleRepuesto = @det;

    INSERT @r SELECT IIF(m.existenciaAnterior = @ultima AND m.existenciaResultante = @exist - 1, 1, 0),
                     CONCAT(N'T05 encadenado con el movimiento anterior: ', m.existenciaAnterior, N' -> ', m.existenciaResultante)
    FROM (SELECT 1 AS x) s LEFT JOIN dbo.MovimientoInventario m ON m.idDetalleRepuesto = @det;

    -- Consumir todo lo que queda: la existencia puede llegar a 0, nunca a menos
    DELETE @uso;
    INSERT @uso EXEC dbo.sp_UtilizarRepuesto @rep, @b, @rp, @resto, @tecnico;
    INSERT @r SELECT IIF(i.existencia = 0 AND v.estadoStock = 'SIN_STOCK', 1, 0),
                     CONCAT(N'T05 consumir las ', @resto, N' restantes deja existencia ', i.existencia, N' (', v.estadoStock, N')')
    FROM dbo.Inventario i INNER JOIN dbo.vw_InventarioActual v ON v.idBodega = i.idBodega AND v.idRepuesto = i.idRepuesto
    WHERE i.idBodega = @b AND i.idRepuesto = @rp;

    INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'T05 existencia = suma del kárdex (descuadres: ', COUNT(*), N')')
    FROM dbo.Inventario i
    OUTER APPLY (SELECT SUM(CASE m.tipo WHEN 'ENTRADA' THEN m.cantidad ELSE -m.cantidad END) AS neto
                 FROM dbo.MovimientoInventario m
                 WHERE m.idBodega = i.idBodega AND m.idRepuesto = i.idRepuesto) x
    WHERE i.existencia <> ISNULL(x.neto, 0);

ROLLBACK TRANSACTION;

INSERT @r VALUES (IIF((SELECT existencia FROM dbo.Inventario WHERE idBodega = @b AND idRepuesto = @rp) = @exist
                      AND (SELECT COUNT(*) FROM dbo.DetalleRepuesto) = @totDet
                      AND (SELECT COUNT(*) FROM dbo.MovimientoInventario) = @totMov, 1, 0),
                  CONCAT(N'después del ROLLBACK la existencia vuelve a ', @exist, N' y no quedan detalles ni movimientos'));

SELECT CONCAT(IIF(ok = 1, 'OK     ', 'FALLA  '), prueba) AS resultado FROM @r ORDER BY n;
SELECT CONCAT('T04-T05: ', SUM(IIF(ok = 1, 1, 0)), ' OK, ', SUM(IIF(ok = 0, 1, 0)), ' FALLA') AS resumen FROM @r;
GO
SET NOEXEC OFF;
GO
