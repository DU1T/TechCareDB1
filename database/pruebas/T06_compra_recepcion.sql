/*
TECHCARE SOLUTIONS
T06 - Registrar y recibir una compra (sp_RegistrarCompra + sp_RecibirCompra)

Objetivo:
  1. Errores que no dejan nada: usuario sin rol de bodega (50110), compra sin líneas (50115),
     documento del proveedor repetido (50119) y recibir una compra ya RECIBIDA (50112).
  2. Registrar: la compra queda PENDIENTE, sus líneas guardan el costo de ESTA compra (no el del
     catálogo) y todavía no se mueve el inventario.
  3. Recibir: las existencias suben, hay un movimiento ENTRADA de origen COMPRA por línea que apunta
     a la compra, la compra pasa a RECIBIDA con fecha y usuario, y un repuesto que la bodega
     no tenía obtiene su fila de inventario. El kárdex sigue cuadrando.

Datos de entrada:
  Datos de prueba 80 a 85 cargados (proveedores, bodegas y compras RECIBIDAS) y los usuarios
  bodega1 y caja1.

Este script NO confirma cambios: los errores no guardan nada y el registro y la recepción van
dentro de una transacción que termina en ROLLBACK.

Resultado esperado: todas las líneas dicen "OK" y la última dice "T06: 0 FALLA".
*/
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
SET NOCOUNT ON;

DECLARE @r TABLE (n INT IDENTITY, ok BIT, prueba NVARCHAR(200));
DECLARE @nueva TABLE (idCompra INT);   -- recibe el SELECT de sp_RegistrarCompra
DECLARE @bodega INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'bodega1');
DECLARE @caja INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'caja1');
DECLARE @error INT;

DECLARE @prov INT = (SELECT MIN(idProveedor) FROM dbo.Proveedor WHERE estado = 'ACTIVO');
DECLARE @dest INT = (SELECT idBodega FROM dbo.Bodega WHERE codigo = 'BOD-CEN');
DECLARE @doc VARCHAR(30) = CONCAT('T06-', FORMAT(SYSDATETIME(), 'yyyyMMddHHmmss'));

-- Dos repuestos que ya están en la bodega destino, con un costo distinto al del catálogo
DECLARE @detalle dbo.TipoDetalleCompra;
INSERT @detalle (idRepuesto, cantidad, costoUnitario)
SELECT TOP 2 i.idRepuesto, 5, r.precioCompraRef - 10
FROM dbo.Inventario i INNER JOIN dbo.Repuesto r ON r.idRepuesto = i.idRepuesto
WHERE i.idBodega = @dest AND r.precioCompraRef > 10 AND r.estado = 'ACTIVO'
ORDER BY i.idRepuesto;

-- Foto antes
DECLARE @antes TABLE (idRepuesto INT PRIMARY KEY, existencia INT);
INSERT @antes SELECT i.idRepuesto, i.existencia FROM dbo.Inventario i INNER JOIN @detalle d ON d.idRepuesto = i.idRepuesto
WHERE i.idBodega = @dest;
DECLARE @totCompras INT = (SELECT COUNT(*) FROM dbo.Compra);
DECLARE @totMov INT = (SELECT COUNT(*) FROM dbo.MovimientoInventario);
DECLARE @totInvFilas INT = (SELECT COUNT(*) FROM dbo.Inventario);

/* ---------------- 1. Errores ---------------- */
SET @error = 0;
BEGIN TRY EXEC dbo.sp_RegistrarCompra @prov, @dest, @doc, @caja, @detalle; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 50110, 1, 0), CONCAT(N'registrar con usuario de caja (no bodega) -> error ', @error));

DECLARE @vacio dbo.TipoDetalleCompra;
SET @error = 0;
BEGIN TRY EXEC dbo.sp_RegistrarCompra @prov, @dest, @doc, @bodega, @vacio; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 50115, 1, 0), CONCAT(N'registrar sin líneas -> error ', @error));

DECLARE @provRep INT, @docRep VARCHAR(30);
SELECT TOP 1 @provRep = idProveedor, @docRep = numeroDocumento FROM dbo.Compra ORDER BY idCompra;
SET @error = 0;
BEGIN TRY EXEC dbo.sp_RegistrarCompra @provRep, @dest, @docRep, @bodega, @detalle; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 50119, 1, 0), CONCAT(N'documento del proveedor repetido (', @docRep, N') -> error ', @error));

DECLARE @recibida INT = (SELECT MIN(idCompra) FROM dbo.Compra WHERE estado = 'RECIBIDA');
SET @error = 0;
BEGIN TRY EXEC dbo.sp_RecibirCompra @recibida, @bodega; END TRY
BEGIN CATCH SET @error = ERROR_NUMBER(); END CATCH;
INSERT @r VALUES (IIF(@error = 50112, 1, 0), CONCAT(N'recibir otra vez una compra RECIBIDA -> error ', @error));

INSERT @r VALUES (IIF((SELECT COUNT(*) FROM dbo.Compra) = @totCompras
                      AND (SELECT COUNT(*) FROM dbo.MovimientoInventario) = @totMov
                      AND @@TRANCOUNT = 0, 1, 0),
                  N'los errores no dejaron compras, movimientos ni transacciones abiertas');

/* ---------------- 2 y 3. Registrar y recibir ---------------- */
BEGIN TRANSACTION;

    -- Un repuesto nuevo, que la bodega todavía no tiene (lo crea la prueba)
    DECLARE @cat INT = (SELECT MIN(idCategoria) FROM dbo.CategoriaRepuesto);
    INSERT INTO dbo.Repuesto (codigo, nombre, idCategoria, precioCompraRef, precioVenta)
    VALUES ('T06-NUEVO', N'Repuesto de prueba T06', @cat, 100, 150);
    DECLARE @nuevo INT = CAST(SCOPE_IDENTITY() AS INT);
    INSERT @detalle (idRepuesto, cantidad, costoUnitario) VALUES (@nuevo, 3, 95);

    INSERT @nueva EXEC dbo.sp_RegistrarCompra @prov, @dest, @doc, @bodega, @detalle, N'Prueba T06';
    DECLARE @compra INT = (SELECT idCompra FROM @nueva);

    INSERT @r SELECT IIF(c.estado = 'PENDIENTE' AND c.fechaRecepcion IS NULL AND c.idUsuarioRecepcion IS NULL, 1, 0),
                     CONCAT(N'compra ', @compra, N' registrada en ', c.estado)
    FROM (SELECT 1 AS x) s LEFT JOIN dbo.Compra c ON c.idCompra = @compra;
    INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'cada línea guarda el costo de esta compra, no el del catálogo (diferencias: ', COUNT(*), N')')
    FROM (SELECT idRepuesto, cantidad, costoUnitario FROM @detalle
          EXCEPT SELECT idRepuesto, cantidad, costoUnitario FROM dbo.DetalleCompra WHERE idCompra = @compra) d;
    INSERT @r VALUES (IIF((SELECT COUNT(*) FROM dbo.MovimientoInventario) = @totMov, 1, 0),
                      N'registrar todavía no mueve el inventario');

    EXEC dbo.sp_RecibirCompra @compra, @bodega;

    INSERT @r SELECT IIF(c.estado = 'RECIBIDA' AND c.fechaRecepcion IS NOT NULL AND c.idUsuarioRecepcion = @bodega, 1, 0),
                     CONCAT(N'compra en ', c.estado, N' con fecha y usuario de recepción')
    FROM dbo.Compra c WHERE c.idCompra = @compra;

    INSERT @r SELECT IIF(COUNT(*) = 0 AND (SELECT COUNT(*) FROM @antes) = 2, 1, 0),
                     CONCAT(N'existencias de los ', (SELECT COUNT(*) FROM @antes), N' repuestos suben en la cantidad comprada (diferencias: ', COUNT(*), N')')
    FROM @antes a
    INNER JOIN dbo.DetalleCompra dc ON dc.idCompra = @compra AND dc.idRepuesto = a.idRepuesto
    INNER JOIN dbo.Inventario i     ON i.idBodega = @dest AND i.idRepuesto = a.idRepuesto
    WHERE i.existencia <> a.existencia + dc.cantidad;

    INSERT @r SELECT IIF(i.existencia = 3 AND (SELECT COUNT(*) FROM dbo.Inventario) = @totInvFilas + 1, 1, 0),
                     CONCAT(N'el repuesto nuevo obtiene su fila en la bodega con ', i.existencia, N' unidades')
    FROM (SELECT 1 AS x) s LEFT JOIN dbo.Inventario i ON i.idBodega = @dest AND i.idRepuesto = @nuevo;

    INSERT @r SELECT IIF(COUNT(*) = 3 AND COUNT(DISTINCT m.idRepuesto) = 3
                         AND SUM(IIF(m.tipo = 'ENTRADA' AND m.origen = 'COMPRA' AND m.costoUnitario = dc.costoUnitario
                                     AND m.cantidad = dc.cantidad, 1, 0)) = 3, 1, 0),
                     CONCAT(N'un movimiento ENTRADA de COMPRA por línea, con su costo (', COUNT(*), N' de 3)')
    FROM dbo.MovimientoInventario m
    INNER JOIN dbo.DetalleCompra dc ON dc.idCompra = m.idCompra AND dc.idRepuesto = m.idRepuesto
    WHERE m.idCompra = @compra;

    INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'existencia = suma del kárdex (descuadres: ', COUNT(*), N')')
    FROM dbo.Inventario i
    OUTER APPLY (SELECT SUM(CASE m.tipo WHEN 'ENTRADA' THEN m.cantidad ELSE -m.cantidad END) AS neto
                 FROM dbo.MovimientoInventario m
                 WHERE m.idBodega = i.idBodega AND m.idRepuesto = i.idRepuesto) x
    WHERE i.existencia <> ISNULL(x.neto, 0);

ROLLBACK TRANSACTION;

INSERT @r VALUES (IIF((SELECT COUNT(*) FROM dbo.Compra) = @totCompras
                      AND (SELECT COUNT(*) FROM dbo.MovimientoInventario) = @totMov
                      AND (SELECT COUNT(*) FROM dbo.Inventario) = @totInvFilas
                      AND NOT EXISTS (SELECT 1 FROM dbo.Repuesto WHERE codigo = 'T06-NUEVO'), 1, 0),
                  N'después del ROLLBACK no queda la compra, ni sus movimientos, ni el repuesto de prueba');

SELECT CONCAT(IIF(ok = 1, 'OK     ', 'FALLA  '), prueba) AS resultado FROM @r ORDER BY n;
SELECT CONCAT('T06: ', SUM(IIF(ok = 1, 1, 0)), ' OK, ', SUM(IIF(ok = 0, 1, 0)), ' FALLA') AS resumen FROM @r;
GO
SET NOEXEC OFF;
GO
