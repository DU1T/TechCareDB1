/*
TECHCARE SOLUTIONS
T13 - Estado del stock (OK, BAJO_MINIMO, SIN_STOCK) en varias bodegas y el dashboard

Objetivo:
  1. vw_InventarioActual calcula bien estadoStock en TODAS las filas:
     existencia = 0 -> SIN_STOCK; existencia <= stockMinimo -> BAJO_MINIMO; si no, OK.
  2. vw_DashboardResumen.repuestosBajoMinimo cuenta las filas que no están en OK.
  3. Con ajustes reales (sp_AjusteInventario) un repuesto pasa OK -> BAJO_MINIMO (justo en el mínimo)
     -> SIN_STOCK -> OK, y el mismo repuesto tiene un estado distinto en cada bodega.

Datos de entrada:
  Datos de prueba 80 a 85 cargados y el usuario bodega1.

Este script NO confirma cambios: los ajustes van dentro de una transacción que termina en ROLLBACK.

Resultado esperado: todas las líneas dicen "OK" y la última dice "T13: 0 FALLA".
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

-- 1. La regla de la vista, fila por fila, contra la tabla
INSERT @r SELECT CASE WHEN COUNT(*) = 0 THEN 1 ELSE 0 END,
                 CONCAT(N'estadoStock correcto en las ', (SELECT COUNT(*) FROM dbo.Inventario), N' filas (diferencias: ', COUNT(*), N')')
FROM dbo.vw_InventarioActual v
INNER JOIN dbo.Inventario i ON i.idBodega = v.idBodega AND i.idRepuesto = v.idRepuesto
WHERE v.estadoStock <> CASE WHEN i.existencia = 0              THEN 'SIN_STOCK'
                            WHEN i.existencia <= i.stockMinimo THEN 'BAJO_MINIMO'
                            ELSE 'OK' END;

INSERT @r SELECT CASE WHEN COUNT(DISTINCT idBodega) >= 2 THEN 1 ELSE 0 END,
                 CONCAT(N'hay BAJO_MINIMO en varias bodegas (', COUNT(DISTINCT idBodega), N')')
FROM dbo.vw_InventarioActual WHERE estadoStock = 'BAJO_MINIMO';

-- 2. El dashboard cuenta lo mismo que la vista
DECLARE @noOk INT = (SELECT COUNT(*) FROM dbo.vw_InventarioActual WHERE estadoStock <> 'OK');
INSERT @r SELECT CASE WHEN repuestosBajoMinimo = @noOk THEN 1 ELSE 0 END,
                 CONCAT(N'dashboard: repuestosBajoMinimo = ', repuestosBajoMinimo, N' (vista: ', @noOk, N')')
FROM dbo.vw_DashboardResumen;

-- 3. Transiciones con ajustes reales. Se elige un repuesto en OK en una bodega que esté en al menos dos.
DECLARE @b INT, @rep INT, @exist INT, @min INT, @otraB INT;
SELECT TOP 1 @b = i.idBodega, @rep = i.idRepuesto, @exist = i.existencia, @min = i.stockMinimo
FROM dbo.Inventario i
WHERE i.existencia > i.stockMinimo AND i.stockMinimo > 0
  AND EXISTS (SELECT 1 FROM dbo.Inventario o
              WHERE o.idRepuesto = i.idRepuesto AND o.idBodega <> i.idBodega AND o.existencia > 0)
ORDER BY i.idBodega, i.idRepuesto;
SELECT TOP 1 @otraB = idBodega FROM dbo.Inventario
WHERE idRepuesto = @rep AND idBodega <> @b AND existencia > 0 ORDER BY idBodega;

DECLARE @estadoOtraAntes VARCHAR(12) = (SELECT estadoStock FROM dbo.vw_InventarioActual WHERE idBodega = @otraB AND idRepuesto = @rep);
DECLARE @estado VARCHAR(12), @dash INT, @dashAntes INT = (SELECT repuestosBajoMinimo FROM dbo.vw_DashboardResumen);
DECLARE @cant INT;

BEGIN TRANSACTION;

    -- Bajar justo hasta el mínimo: el mínimo cuenta como BAJO_MINIMO (<=)
    SET @cant = @min - @exist;
    INSERT @ajuste EXEC dbo.sp_AjusteInventario @b, @rep, @cant, @bodega, N'T13: bajar al mínimo';
    SELECT @estado = estadoStock FROM dbo.vw_InventarioActual WHERE idBodega = @b AND idRepuesto = @rep;
    SET @dash = (SELECT repuestosBajoMinimo FROM dbo.vw_DashboardResumen);
    INSERT @r VALUES (IIF(@estado = 'BAJO_MINIMO', 1, 0), CONCAT(N'existencia = mínimo (', @min, N') -> ', @estado));
    INSERT @r VALUES (IIF(@dash = @dashAntes + 1, 1, 0), CONCAT(N'dashboard sube de ', @dashAntes, N' a ', @dash));

    -- Bajar a cero
    SET @cant = -@min;
    INSERT @ajuste EXEC dbo.sp_AjusteInventario @b, @rep, @cant, @bodega, N'T13: dejar en cero';
    SELECT @estado = estadoStock FROM dbo.vw_InventarioActual WHERE idBodega = @b AND idRepuesto = @rep;
    INSERT @r VALUES (IIF(@estado = 'SIN_STOCK', 1, 0), CONCAT(N'existencia = 0 -> ', @estado));

    -- El mismo repuesto en otra bodega no cambia (el estado depende de bodega + repuesto)
    INSERT @r SELECT IIF(estadoStock = @estadoOtraAntes, 1, 0),
                     CONCAT(N'mismo repuesto en otra bodega sigue en ', estadoStock, N' (antes ', @estadoOtraAntes, N')')
    FROM dbo.vw_InventarioActual WHERE idBodega = @otraB AND idRepuesto = @rep;
    INSERT @r SELECT IIF(COUNT(DISTINCT idBodega) >= 2, 1, 0), CONCAT(N'SIN_STOCK ahora en ', COUNT(DISTINCT idBodega), N' bodegas')
    FROM dbo.vw_InventarioActual WHERE estadoStock = 'SIN_STOCK';

    -- Subir a mínimo + 1: vuelve a OK
    SET @cant = @min + 1;
    INSERT @ajuste EXEC dbo.sp_AjusteInventario @b, @rep, @cant, @bodega, N'T13: reponer';
    SELECT @estado = estadoStock FROM dbo.vw_InventarioActual WHERE idBodega = @b AND idRepuesto = @rep;
    INSERT @r VALUES (IIF(@estado = 'OK', 1, 0), CONCAT(N'existencia = mínimo + 1 -> ', @estado));
    INSERT @r SELECT IIF(COUNT(*) = 3, 1, 0), CONCAT(N'cada ajuste dejó su movimiento AJUSTE en el kárdex (', COUNT(*), N')')
    FROM dbo.MovimientoInventario WHERE idBodega = @b AND idRepuesto = @rep AND origen = 'AJUSTE' AND observacion LIKE N'T13:%';

ROLLBACK TRANSACTION;

INSERT @r SELECT IIF(existencia = @exist, 1, 0), CONCAT(N'después del ROLLBACK la existencia vuelve a ', existencia)
FROM dbo.Inventario WHERE idBodega = @b AND idRepuesto = @rep;

SELECT CONCAT(IIF(ok = 1, 'OK     ', 'FALLA  '), prueba) AS resultado FROM @r ORDER BY n;
SELECT CONCAT('T13: ', SUM(IIF(ok = 1, 1, 0)), ' OK, ', SUM(IIF(ok = 0, 1, 0)), ' FALLA') AS resumen FROM @r;
GO
SET NOEXEC OFF;
GO
