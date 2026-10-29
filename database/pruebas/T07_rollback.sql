/*
TECHCARE SOLUTIONS
T07 - Error a mitad de una transacción: nada queda a medias

Objetivo:
  A. Con XACT_ABORT ON y TRY/CATCH (como en los SP): se descuenta 1 unidad y luego se inserta un
     movimiento que no cuadra; CK_Movimiento_Cuadre lo rechaza (547), la transacción queda
     condenada (XACT_STATE = -1) y el ROLLBACK devuelve la existencia. No queda movimiento.
  B. Contraejemplo, sin XACT_ABORT: el mismo error NO deshace nada por sí solo; el descuento ya
     hecho sigue ahí y la transacción sigue abierta y "confirmable" (XACT_STATE = 1). Si alguien
     hiciera COMMIT, quedaría a medias. Por eso todos los SP usan SET XACT_ABORT ON.
  C. Todo o nada entre capas: dentro de una misma transacción, un ajuste que sí funcionó y luego
     un consumo que falla (50106). El ROLLBACK del SP deshace también el ajuste anterior.

Datos de entrada:
  Datos de prueba 80 a 85 cargados (reparaciones EN_PROCESO) y los usuarios bodega1 y tecnico1.

Este script NO confirma cambios: cada escenario termina en ROLLBACK.

Resultado esperado: todas las líneas dicen "OK" y la última dice "T07: 0 FALLA".
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
DECLARE @error INT, @estado SMALLINT, @trans INT, @durante INT;

DECLARE @b INT, @rp INT, @exist INT;
SELECT TOP 1 @b = idBodega, @rp = idRepuesto, @exist = existencia
FROM dbo.Inventario WHERE existencia > 0 ORDER BY idBodega, idRepuesto;
DECLARE @totMov INT = (SELECT COUNT(*) FROM dbo.MovimientoInventario);

/* ---------------- A. Con XACT_ABORT ON (como en los SP) ---------------- */
SET XACT_ABORT ON;
SET @error = 0;
BEGIN TRY
    BEGIN TRANSACTION;
        UPDATE dbo.Inventario SET existencia = existencia - 1 WHERE idBodega = @b AND idRepuesto = @rp;
        INSERT INTO dbo.MovimientoInventario (idBodega, idRepuesto, tipo, origen, cantidad,
               existenciaAnterior, existenciaResultante, idUsuario, observacion)
        VALUES (@b, @rp, 'SALIDA', 'AJUSTE', 1, @exist, 999, @bodega, N'T07: resultante incorrecta a propósito');
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SELECT @error = ERROR_NUMBER(), @estado = XACT_STATE();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;

INSERT @r VALUES (IIF(@error = 547, 1, 0), CONCAT(N'A: el movimiento que no cuadra lo rechaza CK_Movimiento_Cuadre -> error ', @error));
INSERT @r VALUES (IIF(@estado = -1, 1, 0), CONCAT(N'A: con XACT_ABORT ON la transacción queda condenada (XACT_STATE = ', @estado, N')'));
INSERT @r SELECT IIF(existencia = @exist, 1, 0), CONCAT(N'A: tras el ROLLBACK la existencia sigue en ', existencia, N' (antes ', @exist, N')')
FROM dbo.Inventario WHERE idBodega = @b AND idRepuesto = @rp;
INSERT @r VALUES (IIF((SELECT COUNT(*) FROM dbo.MovimientoInventario) = @totMov AND @@TRANCOUNT = 0, 1, 0),
                  N'A: no quedó ningún movimiento ni transacción abierta');

/* ---------------- B. Sin XACT_ABORT (contraejemplo) ---------------- */
SET XACT_ABORT OFF;
SET @error = 0;
BEGIN TRANSACTION;
    UPDATE dbo.Inventario SET existencia = existencia - 1 WHERE idBodega = @b AND idRepuesto = @rp;
    BEGIN TRY
        INSERT INTO dbo.MovimientoInventario (idBodega, idRepuesto, tipo, origen, cantidad,
               existenciaAnterior, existenciaResultante, idUsuario, observacion)
        VALUES (@b, @rp, 'SALIDA', 'AJUSTE', 1, @exist, 999, @bodega, N'T07: resultante incorrecta a propósito');
    END TRY
    BEGIN CATCH
        SELECT @error = ERROR_NUMBER(), @estado = XACT_STATE();
    END CATCH;
    SET @trans = @@TRANCOUNT;
    SET @durante = (SELECT existencia FROM dbo.Inventario WHERE idBodega = @b AND idRepuesto = @rp);
ROLLBACK TRANSACTION;   -- aquí se limpia a mano; un COMMIT dejaría la existencia descontada sin movimiento
SET XACT_ABORT ON;

INSERT @r VALUES (IIF(@error = 547 AND @estado = 1 AND @trans = 1, 1, 0),
                  CONCAT(N'B: sin XACT_ABORT el error ', @error, N' deja la transacción abierta (', @trans, N') y confirmable (XACT_STATE = ', @estado, N')'));
INSERT @r VALUES (IIF(@durante = @exist - 1, 1, 0),
                  CONCAT(N'B: el descuento ya estaba hecho sin su movimiento (', @exist, N' -> ', @durante, N'): un COMMIT lo dejaría a medias'));
INSERT @r SELECT IIF(existencia = @exist, 1, 0), CONCAT(N'B: tras el ROLLBACK manual la existencia vuelve a ', existencia)
FROM dbo.Inventario WHERE idBodega = @b AND idRepuesto = @rp;

/* ---------------- C. Todo o nada entre capas ---------------- */
DECLARE @rep INT, @tecnico INT;
SELECT TOP 1 @rep = r.idReparacion, @tecnico = r.idTecnico
FROM dbo.Reparacion r
INNER JOIN dbo.Diagnostico d   ON d.idDiagnostico = r.idDiagnostico
INNER JOIN dbo.OrdenServicio o ON o.idOrden = d.idOrden
WHERE r.estado = 'EN_PROCESO' AND o.estado = 'REPARACION'
ORDER BY r.idReparacion;
DECLARE @mucho INT = @exist + 100;

SET @error = 0;
BEGIN TRY
    BEGIN TRANSACTION;
        INSERT @ajuste EXEC dbo.sp_AjusteInventario @b, @rp, 1, @bodega, N'T07: ajuste que sí funciona';
        SET @durante = (SELECT existencia FROM dbo.Inventario WHERE idBodega = @b AND idRepuesto = @rp);
        EXEC dbo.sp_UtilizarRepuesto @rep, @b, @rp, @mucho, @tecnico;   -- falla: no hay tanto
    COMMIT TRANSACTION;
END TRY
BEGIN CATCH
    SET @error = ERROR_NUMBER();
    IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
END CATCH;

INSERT @r VALUES (IIF(@durante = @exist + 1, 1, 0), CONCAT(N'C: el ajuste se aplicó dentro de la transacción (', @exist, N' -> ', @durante, N')'));
INSERT @r VALUES (IIF(@error = 50106, 1, 0), CONCAT(N'C: luego el consumo de ', @mucho, N' falla -> error ', @error));
INSERT @r SELECT IIF(existencia = @exist AND (SELECT COUNT(*) FROM dbo.MovimientoInventario) = @totMov AND @@TRANCOUNT = 0, 1, 0),
                 CONCAT(N'C: también se deshizo el ajuste: existencia ', existencia, N' y el kárdex sin movimientos nuevos')
FROM dbo.Inventario WHERE idBodega = @b AND idRepuesto = @rp;

SELECT CONCAT(IIF(ok = 1, 'OK     ', 'FALLA  '), prueba) AS resultado FROM @r ORDER BY n;
SELECT CONCAT('T07: ', SUM(IIF(ok = 1, 1, 0)), ' OK, ', SUM(IIF(ok = 0, 1, 0)), ' FALLA') AS resumen FROM @r;
GO
SET NOEXEC OFF;
GO
