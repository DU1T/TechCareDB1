/*
TECHCARE SOLUTIONS
R14 - El kárdex no se edita ni se borra; un error se corrige con un ajuste

Objetivo:
  1. DELETE y UPDATE sobre MovimientoInventario los rechaza trg_MovimientoInventario_Inmutable (51010),
     aunque los haga sa directo en la base, y el movimiento queda igual.
  2. La corrección correcta es sp_AjusteInventario: deja un movimiento AJUSTE nuevo, con motivo,
     encadenado al anterior, y la existencia sigue cuadrando con el kárdex.
  3. Tampoco se borran documentos con historia: una factura con pagos y una compra recibida
     no se pueden eliminar (FK con NO ACTION, error 547); se anulan.

Datos de entrada:
  Datos de prueba 80 a 85 cargados y el usuario bodega1.

Este script NO confirma cambios: los intentos de borrar fallan, y el ajuste va dentro de una
transacción que termina en ROLLBACK.

Resultado esperado: todas las líneas dicen "OK" y la última dice "R14: 0 FALLA".
*/
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
SET NOCOUNT ON;

DECLARE @r TABLE (n INT IDENTITY, ok BIT, prueba NVARCHAR(200));
DECLARE @ajuste TABLE (idMovimiento BIGINT, existenciaResultante INT);   -- recibe el SELECT del SP
DECLARE @bodega INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'bodega1');
DECLARE @error INT;

-- Foto del kárdex antes
DECLARE @total INT = (SELECT COUNT(*) FROM dbo.MovimientoInventario);
DECLARE @mov BIGINT = (SELECT MIN(idMovimiento) FROM dbo.MovimientoInventario);
DECLARE @foto TABLE (idMovimiento BIGINT, tipo VARCHAR(7), cantidad INT, existenciaAnterior INT,
                     existenciaResultante INT, fechaMovimiento DATETIME2(0), observacion NVARCHAR(250));
INSERT @foto SELECT idMovimiento, tipo, cantidad, existenciaAnterior, existenciaResultante, fechaMovimiento, observacion
FROM dbo.MovimientoInventario WHERE idMovimiento = @mov;

-- 1. Intentos de editar o borrar (como sa: ni el dueño de la base puede)
SET @error = 0;
BEGIN TRY DELETE FROM dbo.MovimientoInventario WHERE idMovimiento = @mov; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 51010, 1, 0), CONCAT(N'DELETE de un movimiento -> error ', @error));

SET @error = 0;
BEGIN TRY DELETE FROM dbo.MovimientoInventario; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 51010, 1, 0), CONCAT(N'DELETE de todo el kárdex -> error ', @error));

SET @error = 0;
BEGIN TRY UPDATE dbo.MovimientoInventario SET cantidad = cantidad + 1 WHERE idMovimiento = @mov; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 51010, 1, 0), CONCAT(N'UPDATE de cantidad -> error ', @error));

SET @error = 0;
BEGIN TRY UPDATE dbo.MovimientoInventario SET observacion = N'editado' WHERE idMovimiento = @mov; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 51010, 1, 0), CONCAT(N'UPDATE solo de la observación -> error ', @error));

INSERT @r SELECT IIF(COUNT(*) = @total, 1, 0), CONCAT(N'el kárdex sigue con ', COUNT(*), N' movimientos (antes ', @total, N')')
FROM dbo.MovimientoInventario;
INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'el movimiento ', @mov, N' quedó igual (diferencias: ', COUNT(*), N')')
FROM (SELECT * FROM @foto
      EXCEPT SELECT idMovimiento, tipo, cantidad, existenciaAnterior, existenciaResultante, fechaMovimiento, observacion
             FROM dbo.MovimientoInventario WHERE idMovimiento = @mov) d;

-- 2. La corrección correcta: un ajuste (se encontró 1 unidad dañada)
DECLARE @b INT, @rep INT, @exist INT;
SELECT TOP 1 @b = idBodega, @rep = idRepuesto, @exist = existencia
FROM dbo.Inventario WHERE existencia > 0 ORDER BY idBodega, idRepuesto;
DECLARE @ultimaResultante INT = (SELECT TOP 1 existenciaResultante FROM dbo.MovimientoInventario
                                 WHERE idBodega = @b AND idRepuesto = @rep ORDER BY fechaMovimiento DESC, idMovimiento DESC);

BEGIN TRANSACTION;
    INSERT @ajuste EXEC dbo.sp_AjusteInventario @b, @rep, -1, @bodega, N'R14: unidad dañada en revisión';

    INSERT @r SELECT IIF(m.origen = 'AJUSTE' AND m.tipo = 'SALIDA' AND m.cantidad = 1 AND m.observacion LIKE N'R14:%', 1, 0),
                     CONCAT(N'el ajuste es un movimiento nuevo: ', m.origen, N' ', m.tipo, N' de ', m.cantidad, N' con motivo')
    FROM dbo.MovimientoInventario m INNER JOIN @ajuste a ON a.idMovimiento = m.idMovimiento;
    INSERT @r SELECT IIF(m.existenciaAnterior = @ultimaResultante AND m.existenciaResultante = @exist - 1, 1, 0),
                     CONCAT(N'encadenado al anterior: ', m.existenciaAnterior, N' -> ', m.existenciaResultante)
    FROM dbo.MovimientoInventario m INNER JOIN @ajuste a ON a.idMovimiento = m.idMovimiento;

    -- Cuadre: existencia = entradas - salidas en todas las filas del inventario
    INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'existencia = suma del kárdex tras el ajuste (descuadres: ', COUNT(*), N')')
    FROM dbo.Inventario i
    OUTER APPLY (SELECT SUM(CASE m.tipo WHEN 'ENTRADA' THEN m.cantidad ELSE -m.cantidad END) AS neto
                 FROM dbo.MovimientoInventario m
                 WHERE m.idBodega = i.idBodega AND m.idRepuesto = i.idRepuesto) x
    WHERE i.existencia <> ISNULL(x.neto, 0);
ROLLBACK TRANSACTION;

INSERT @r SELECT IIF(COUNT(*) = @total, 1, 0), CONCAT(N'después del ROLLBACK el kárdex vuelve a ', COUNT(*), N' movimientos')
FROM dbo.MovimientoInventario;

-- 3. Documentos con historia no se borran: se anulan
DECLARE @factura INT = (SELECT MIN(idFactura) FROM dbo.Pago);
SET @error = 0;
BEGIN TRY DELETE FROM dbo.Factura WHERE idFactura = @factura; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 547, 1, 0), CONCAT(N'DELETE de una factura con pagos -> error ', @error, N' (FK)'));

DECLARE @compra INT = (SELECT MIN(idCompra) FROM dbo.Compra WHERE estado = 'RECIBIDA');
SET @error = 0;
BEGIN TRY DELETE FROM dbo.Compra WHERE idCompra = @compra; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 547, 1, 0), CONCAT(N'DELETE de una compra recibida -> error ', @error, N' (FK)'));

INSERT @r SELECT IIF(EXISTS (SELECT 1 FROM dbo.Factura WHERE idFactura = @factura)
                 AND EXISTS (SELECT 1 FROM dbo.Compra WHERE idCompra = @compra), 1, 0),
                 N'la factura y la compra siguen en la base';

SELECT CONCAT(IIF(ok = 1, 'OK     ', 'FALLA  '), prueba) AS resultado FROM @r ORDER BY n;
SELECT CONCAT('R14: ', SUM(IIF(ok = 1, 1, 0)), ' OK, ', SUM(IIF(ok = 0, 1, 0)), ' FALLA') AS resumen FROM @r;
GO
SET NOEXEC OFF;
GO
