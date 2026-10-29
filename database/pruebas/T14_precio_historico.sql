/*
TECHCARE SOLUTIONS
T14 - Cambiar el precio de un repuesto no cambia lo ya registrado y queda auditado

Objetivo:
  1. Se sube el precio de venta (+10 %) y el de compra (+5 %) de un repuesto que ya está facturado.
  2. No cambia nada histórico: líneas y totales de sus facturas, saldo, repuestos usados
     (precio y costo congelados), costos de compra y el kárdex.
  3. trg_Repuesto_AuditoriaPrecio deja una fila con el precio anterior y el nuevo, y el usuario
     de la aplicación tomado de SESSION_CONTEXT (sp_EstablecerContexto).
  4. El trigger es set-based (un UPDATE de 2 repuestos deja 2 filas) y no audita si el precio no cambia.

Datos de entrada:
  Datos de prueba 80 a 85 cargados (facturas con líneas de repuesto) y el usuario administrador1.

Este script NO confirma cambios: todo va dentro de una transacción que termina en ROLLBACK.

Resultado esperado: todas las líneas dicen "OK" y la última dice "T14: 0 FALLA".
*/
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
SET NOCOUNT ON;

DECLARE @r TABLE (n INT IDENTITY, ok BIT, prueba NVARCHAR(200));
DECLARE @admin INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'administrador1');

-- Un repuesto cobrado en una factura EMITIDA, y otro cualquiera para la prueba set-based
DECLARE @rep INT = (SELECT TOP 1 dr.idRepuesto
                    FROM dbo.DetalleFactura df
                    INNER JOIN dbo.Factura f          ON f.idFactura = df.idFactura
                    INNER JOIN dbo.DetalleRepuesto dr ON dr.idDetalleRepuesto = df.idDetalleRepuesto
                    WHERE f.estado = 'EMITIDA' AND df.tipoLinea = 'REPUESTO'
                    ORDER BY df.idFactura, df.numeroLinea);
DECLARE @otro INT = (SELECT MIN(idRepuesto) FROM dbo.Repuesto WHERE idRepuesto <> @rep);
DECLARE @codigo VARCHAR(30), @ventaAntes DECIMAL(12,2), @compraAntes DECIMAL(12,2);
SELECT @codigo = codigo, @ventaAntes = precioVenta, @compraAntes = precioCompraRef FROM dbo.Repuesto WHERE idRepuesto = @rep;

-- Foto de todo lo histórico que toca a ese repuesto, ANTES del cambio
DECLARE @facturas TABLE (idFactura INT PRIMARY KEY);
INSERT @facturas SELECT DISTINCT df.idFactura FROM dbo.DetalleFactura df
INNER JOIN dbo.DetalleRepuesto dr ON dr.idDetalleRepuesto = df.idDetalleRepuesto WHERE dr.idRepuesto = @rep;

DECLARE @fotoFactura TABLE (idFactura INT, subtotal DECIMAL(12,2), impuesto DECIMAL(12,2), total DECIMAL(12,2), saldo DECIMAL(12,2));
INSERT @fotoFactura SELECT f.idFactura, f.subtotal, f.impuesto, f.total, dbo.fn_SaldoFactura(f.idFactura)
FROM dbo.Factura f INNER JOIN @facturas x ON x.idFactura = f.idFactura;

DECLARE @fotoLineas TABLE (idFactura INT, numeroLinea SMALLINT, precioUnitario DECIMAL(12,2), subtotalLinea DECIMAL(12,2));
INSERT @fotoLineas SELECT df.idFactura, df.numeroLinea, df.precioUnitario, df.subtotalLinea
FROM dbo.DetalleFactura df INNER JOIN @facturas x ON x.idFactura = df.idFactura;

DECLARE @fotoUsados TABLE (idDetalleRepuesto INT, precioUnitario DECIMAL(12,2), costoUnitario DECIMAL(12,2));
INSERT @fotoUsados SELECT idDetalleRepuesto, precioUnitario, costoUnitario FROM dbo.DetalleRepuesto WHERE idRepuesto = @rep;

DECLARE @fotoCompras TABLE (idCompra INT, costoUnitario DECIMAL(12,2));
INSERT @fotoCompras SELECT idCompra, costoUnitario FROM dbo.DetalleCompra WHERE idRepuesto = @rep;

DECLARE @fotoKardex TABLE (idMovimiento BIGINT, costoUnitario DECIMAL(12,2));
INSERT @fotoKardex SELECT idMovimiento, costoUnitario FROM dbo.MovimientoInventario WHERE idRepuesto = @rep;

DECLARE @auditAntes INT = (SELECT COUNT(*) FROM dbo.AuditoriaPrecioRepuesto);
INSERT @r VALUES (IIF((SELECT COUNT(*) FROM @facturas) > 0, 1, 0),
                  CONCAT(N'repuesto ', @codigo, N' aparece en ', (SELECT COUNT(*) FROM @facturas), N' factura(s) y ',
                         (SELECT COUNT(*) FROM @fotoUsados), N' uso(s) en reparaciones'));

BEGIN TRANSACTION;

    -- El cambio de precio, hecho por un usuario de la app (así lo hace el backend)
    EXEC dbo.sp_EstablecerContexto @idUsuario = @admin, @observacion = N'T14: cambio de precio';
    UPDATE dbo.Repuesto
       SET precioVenta     = ROUND(precioVenta * 1.10, 2),
           precioCompraRef = ROUND(precioCompraRef * 1.05, 2)
     WHERE idRepuesto = @rep;

    INSERT @r SELECT IIF(precioVenta = ROUND(@ventaAntes * 1.10, 2), 1, 0),
                     CONCAT(N'precio de venta del catálogo: ', @ventaAntes, N' -> ', precioVenta)
    FROM dbo.Repuesto WHERE idRepuesto = @rep;

    -- Nada histórico cambió (EXCEPT devuelve las filas distintas entre la foto y lo actual)
    INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'facturas: subtotal, impuesto, total y saldo iguales (diferencias: ', COUNT(*), N')')
    FROM (SELECT * FROM @fotoFactura
          EXCEPT SELECT f.idFactura, f.subtotal, f.impuesto, f.total, dbo.fn_SaldoFactura(f.idFactura)
                 FROM dbo.Factura f INNER JOIN @facturas x ON x.idFactura = f.idFactura) d;
    INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'líneas de factura iguales (diferencias: ', COUNT(*), N')')
    FROM (SELECT * FROM @fotoLineas
          EXCEPT SELECT df.idFactura, df.numeroLinea, df.precioUnitario, df.subtotalLinea
                 FROM dbo.DetalleFactura df INNER JOIN @facturas x ON x.idFactura = df.idFactura) d;
    INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'repuestos usados: precio y costo congelados (diferencias: ', COUNT(*), N')')
    FROM (SELECT * FROM @fotoUsados
          EXCEPT SELECT idDetalleRepuesto, precioUnitario, costoUnitario FROM dbo.DetalleRepuesto WHERE idRepuesto = @rep) d;
    INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'costos de compra iguales (diferencias: ', COUNT(*), N')')
    FROM (SELECT * FROM @fotoCompras
          EXCEPT SELECT idCompra, costoUnitario FROM dbo.DetalleCompra WHERE idRepuesto = @rep) d;
    INSERT @r SELECT IIF(COUNT(*) = 0, 1, 0), CONCAT(N'kárdex igual (diferencias: ', COUNT(*), N')')
    FROM (SELECT * FROM @fotoKardex
          EXCEPT SELECT idMovimiento, costoUnitario FROM dbo.MovimientoInventario WHERE idRepuesto = @rep) d;

    -- La auditoría: una fila con antes/después y el usuario de la app
    INSERT @r SELECT IIF(COUNT(*) = 1, 1, 0), CONCAT(N'auditoría: ', COUNT(*), N' fila nueva')
    FROM dbo.AuditoriaPrecioRepuesto WHERE idRepuesto = @rep;
    INSERT @r SELECT IIF(precioVentaAnterior = @ventaAntes AND precioVentaNuevo = ROUND(@ventaAntes * 1.10, 2)
                         AND precioCompraAnterior = @compraAntes AND precioCompraNuevo = ROUND(@compraAntes * 1.05, 2), 1, 0),
                     CONCAT(N'auditoría guarda venta ', precioVentaAnterior, N' -> ', precioVentaNuevo,
                            N' y compra ', precioCompraAnterior, N' -> ', precioCompraNuevo)
    FROM (SELECT 1 AS x) s LEFT JOIN dbo.AuditoriaPrecioRepuesto ON idRepuesto = @rep;   -- sin fila de auditoría, sale FALLA
    INSERT @r SELECT IIF(a.idUsuario = @admin, 1, 0), CONCAT(N'auditoría guarda el usuario de la app: ', u.username, N' (en la base: ', a.usuarioBD, N')')
    FROM (SELECT 1 AS x) s
    LEFT JOIN dbo.AuditoriaPrecioRepuesto a ON a.idRepuesto = @rep
    LEFT JOIN dbo.Usuario u ON u.idUsuario = a.idUsuario;

    -- Set-based: un solo UPDATE de 2 repuestos deja 2 filas
    UPDATE dbo.Repuesto SET precioVenta = precioVenta + 1 WHERE idRepuesto IN (@rep, @otro);
    INSERT @r SELECT IIF(COUNT(*) - @auditAntes = 3, 1, 0), CONCAT(N'UPDATE de 2 repuestos deja 2 filas más (total ', COUNT(*) - @auditAntes, N' nuevas)')
    FROM dbo.AuditoriaPrecioRepuesto;

    -- Cambiar otra columna, o "cambiar" el precio por el mismo valor, no audita
    UPDATE dbo.Repuesto SET descripcion = ISNULL(descripcion, N'') + N' ', precioVenta = precioVenta WHERE idRepuesto = @rep;
    INSERT @r SELECT IIF(COUNT(*) - @auditAntes = 3, 1, 0), CONCAT(N'cambio sin precio distinto no audita (siguen ', COUNT(*) - @auditAntes, N' nuevas)')
    FROM dbo.AuditoriaPrecioRepuesto;

ROLLBACK TRANSACTION;

INSERT @r SELECT IIF(precioVenta = @ventaAntes AND (SELECT COUNT(*) FROM dbo.AuditoriaPrecioRepuesto) = @auditAntes, 1, 0),
                 CONCAT(N'después del ROLLBACK el precio vuelve a ', precioVenta, N' y la auditoría a ', @auditAntes, N' filas')
FROM dbo.Repuesto WHERE idRepuesto = @rep;

SELECT CONCAT(IIF(ok = 1, 'OK     ', 'FALLA  '), prueba) AS resultado FROM @r ORDER BY n;
SELECT CONCAT('T14: ', SUM(IIF(ok = 1, 1, 0)), ' OK, ', SUM(IIF(ok = 0, 1, 0)), ' FALLA') AS resumen FROM @r;
GO
SET NOEXEC OFF;
GO
