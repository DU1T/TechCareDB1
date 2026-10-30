/* =====================================================================
   R16_integridad_directa.sql  |  C · Fullstack/Infra  |  Plan de pruebas (docs/PLAN_PRUEBAS.md)
   ---------------------------------------------------------------------
   R16: las restricciones deben impedir datos inválidos aunque se escriba DIRECTO en SQL Server,
   sin pasar por los procedimientos ni por la aplicación.
   I01–I18: operaciones inválidas que la base debe rechazar (OK = rechazada, FALLA = aceptada).
   I19–I20: pagos válidos escritos directo que la base debe aceptar (el trigger no estorba).
   I16–I17 se ejecutan como techcare_app (rol_app); si ese usuario no existe en la base, se omiten.
   Cada caso va en su propia transacción y termina en ROLLBACK: el script no deja cambios.
   Ejecutar como sa o db_owner sobre una base TechCare con los datos de prueba cargados.
   ===================================================================== */
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
SET NOCOUNT ON;
SET XACT_ABORT OFF;
GO
CREATE OR ALTER PROCEDURE #caso @id VARCHAR(4), @desc NVARCHAR(200), @sql NVARCHAR(MAX)
AS
BEGIN
    BEGIN TRAN;
    BEGIN TRY
        EXEC sys.sp_executesql @sql;
        PRINT CONCAT('FALLA ', @id, '  ', @desc, '  -> la base lo aceptó');
    END TRY
    BEGIN CATCH
        PRINT CONCAT('OK    ', @id, '  ', @desc, '  -> error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
    END CATCH;
    IF @@TRANCOUNT > 0 ROLLBACK;
END;
GO
EXEC #caso 'I01', N'Existencia negativa', N'UPDATE dbo.Inventario SET existencia = -1 WHERE idBodega = 1 AND idRepuesto = 1;';
EXEC #caso 'I02', N'Movimiento de kárdex que no cuadra (14 - 2 = 20)', N'
    INSERT INTO dbo.MovimientoInventario (idBodega, idRepuesto, tipo, origen, cantidad, existenciaAnterior, existenciaResultante, costoUnitario, idUsuario, observacion)
    VALUES (1, 1, ''SALIDA'', ''AJUSTE'', 2, 14, 20, 10, 1, N''prueba'');';
EXEC #caso 'I03', N'Borrar un movimiento del kárdex', N'DELETE TOP (1) FROM dbo.MovimientoInventario;';
EXEC #caso 'I04', N'Modificar un movimiento del kárdex', N'UPDATE TOP (1) dbo.MovimientoInventario SET cantidad = cantidad + 1;';
EXEC #caso 'I05', N'Segunda factura para una orden que ya tiene', N'UPDATE dbo.Factura SET idOrden = (SELECT idOrden FROM dbo.Factura WHERE idFactura = 2) WHERE idFactura = 1;';
EXEC #caso 'I06', N'Saltar de RECIBIDO a ENTREGADO', N'UPDATE dbo.OrdenServicio SET estado = ''ENTREGADO'' WHERE idOrden = (SELECT MIN(idOrden) FROM dbo.OrdenServicio WHERE estado = ''RECIBIDO'');';
EXEC #caso 'I07', N'Marcar ENTREGADO una orden LISTO con saldo pendiente', N'
    UPDATE o SET o.estado = ''ENTREGADO'' FROM dbo.OrdenServicio o
    WHERE o.idOrden = (SELECT MIN(v.idOrden) FROM dbo.vw_FacturasSaldo v JOIN dbo.OrdenServicio x ON x.idOrden = v.idOrden WHERE x.estado = ''LISTO'' AND v.saldo > 0);';
EXEC #caso 'I08', N'Pago que excede el saldo, insertado directo', N'
    DECLARE @f INT = (SELECT MIN(idFactura) FROM dbo.vw_FacturasSaldo WHERE saldo > 0);
    INSERT INTO dbo.Pago (idFactura, idMetodoPago, monto, idUsuarioCaja, estado) VALUES (@f, 1, 99999, 9, ''APLICADO'');';
EXEC #caso 'I09', N'Pago con monto cero', N'INSERT INTO dbo.Pago (idFactura, idMetodoPago, monto, idUsuarioCaja, estado) VALUES (1, 1, 0, 9, ''APLICADO'');';
EXEC #caso 'I10', N'Empresa con NIT CF', N'INSERT INTO dbo.Cliente (tipoCliente, nit, nombre, telefono) VALUES (''EMPRESA'', ''CF'', N''Empresa X'', ''1234'');';
EXEC #caso 'I11', N'Cliente sin teléfono ni correo', N'INSERT INTO dbo.Cliente (tipoCliente, nit, nombre) VALUES (''INDIVIDUAL'', ''CF'', N''Sin contacto'');';
EXEC #caso 'I12', N'Número de serie repetido', N'INSERT INTO dbo.Equipo (idCliente, idTipoEquipo, idMarca, modelo, numeroSerie) VALUES (1, 1, 1, N''X'', ''SN-00001'');';
EXEC #caso 'I13', N'Equipo de un cliente que no existe', N'INSERT INTO dbo.Equipo (idCliente, idTipoEquipo, idMarca, modelo, numeroSerie) VALUES (99999, 1, 1, N''X'', ''SN-NUEVA-99'');';
EXEC #caso 'I14', N'Borrar un cliente que tiene equipos (FK NO ACTION)', N'DELETE FROM dbo.Cliente WHERE idCliente = 1;';
EXEC #caso 'I15', N'Detalle de compra con cantidad cero', N'UPDATE TOP (1) dbo.DetalleCompra SET cantidad = 0;';
GO
IF USER_ID(N'techcare_app') IS NULL
    PRINT 'OMITIDO I16-I17: el usuario techcare_app no existe en esta base (ejecute 90_seguridad.sql)';
ELSE
BEGIN
    EXEC #caso 'I16', N'Usuario de la aplicación cambia el stock directo', N'
        EXECUTE AS USER = ''techcare_app'';
        BEGIN TRY UPDATE dbo.Inventario SET existencia = existencia + 5 WHERE idBodega = 1 AND idRepuesto = 1; END TRY
        BEGIN CATCH REVERT; THROW; END CATCH;
        REVERT;';
    EXEC #caso 'I17', N'Usuario de la aplicación inserta un pago directo', N'
        EXECUTE AS USER = ''techcare_app'';
        BEGIN TRY INSERT INTO dbo.Pago (idFactura, idMetodoPago, monto, idUsuarioCaja, estado) VALUES (1, 1, 1, 9, ''APLICADO''); END TRY
        BEGIN CATCH REVERT; THROW; END CATCH;
        REVERT;';
END;
GO
EXEC #caso 'I18', N'Subir directo el monto de un pago hasta pasar el total', N'
    UPDATE TOP (1) p SET p.monto = p.monto + 99999 FROM dbo.Pago p WHERE p.estado = ''APLICADO'';';
GO
/* I19–I20: pagos válidos escritos directo; deben aceptarse */
DECLARE @f INT = (SELECT MIN(idFactura) FROM dbo.vw_FacturasSaldo WHERE saldo > 10);
DECLARE @saldo DECIMAL(12,2) = dbo.fn_SaldoFactura(@f);
BEGIN TRAN;
BEGIN TRY
    INSERT INTO dbo.Pago (idFactura, idMetodoPago, monto, idUsuarioCaja, estado) VALUES (@f, 1, 1, 9, 'APLICADO');
    PRINT CONCAT('OK    I19  Pago directo de Q1 dentro del saldo (factura ', @f, ')  -> aceptado; saldo ', dbo.fn_SaldoFactura(@f));
    INSERT INTO dbo.Pago (idFactura, idMetodoPago, monto, idUsuarioCaja, estado) VALUES (@f, 1, @saldo - 1, 9, 'APLICADO');
    PRINT CONCAT('OK    I20  Pago directo que completa el total  -> aceptado; saldo ', dbo.fn_SaldoFactura(@f));
END TRY
BEGIN CATCH
    PRINT CONCAT('FALLA I19/I20  pago válido rechazado -> error ', ERROR_NUMBER(), ': ', ERROR_MESSAGE());
END CATCH;
IF @@TRANCOUNT > 0 ROLLBACK;
GO
SET NOEXEC OFF;
GO
