/*
TECHCARE SOLUTIONS
T08 · T09 · T10 y entrega - Facturar, pagar, anular pago y entregar

Objetivo:
  T08  Facturar una orden LISTO: líneas de mano de obra y repuestos, total = subtotal + 12 %.
       Facturar otra vez y facturar una orden que no está LISTO deben fallar.
  T09  Dos pagos parciales y uno que completa: el saldo baja y termina en 0.
  T10  Pago mayor al saldo y tarjeta sin referencia: el SP rechaza y no inserta nada.
  Extra  Entregar con saldo pendiente (50324), anular pago sin motivo (50315),
         anular el pago de una orden ya entregada (50318) y el UPDATE directo desde SSMS (trigger 51003).

Datos de entrada:
  Hacen falta los datos de prueba 80 a 83 cargados (órdenes en LISTO con reparación finalizada y sin factura)
  y los usuarios caja1 y recepcion1.

IMPORTANTE: este script CONFIRMA cambios (crea facturas, pagos y una entrega). Ejecútelo en su base
personal (TechCare_Front), NUNCA en la compartida. Para repetirlo, reconstruya la base o use otra orden.

Resultado esperado: cada bloque imprime "OK ..." y ningún bloque imprime "FALLA".
*/
USE TechCare_Front;
GO
SET NOCOUNT ON;

DECLARE @caja INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'caja1');
DECLARE @recepcion INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'recepcion1');
DECLARE @efectivo INT = (SELECT idMetodoPago FROM dbo.MetodoPago WHERE nombre = 'EFECTIVO');
DECLARE @tarjeta INT = (SELECT idMetodoPago FROM dbo.MetodoPago WHERE nombre = 'TARJETA');

-- Dos órdenes LISTO con reparación finalizada, con costo y sin factura
DECLARE @ordenA INT, @ordenB INT, @ordenNoListo INT;

SELECT @ordenA = MIN(o.idOrden) FROM dbo.OrdenServicio o
WHERE o.estado = 'LISTO' AND dbo.fn_TotalOrden(o.idOrden) > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.Factura f WHERE f.idOrden = o.idOrden);

SELECT @ordenB = MIN(o.idOrden) FROM dbo.OrdenServicio o
WHERE o.estado = 'LISTO' AND dbo.fn_TotalOrden(o.idOrden) > 0 AND o.idOrden <> @ordenA
  AND NOT EXISTS (SELECT 1 FROM dbo.Factura f WHERE f.idOrden = o.idOrden);

SELECT @ordenNoListo = MIN(idOrden) FROM dbo.OrdenServicio WHERE estado NOT IN ('LISTO', 'ENTREGADO');

IF @caja IS NULL OR @recepcion IS NULL OR @ordenA IS NULL OR @ordenB IS NULL
BEGIN
    PRINT 'FALLA: faltan datos (usuarios caja1/recepcion1 o dos órdenes LISTO sin factura). Cargue 80-83.';
    RETURN;
END;

PRINT CONCAT('Orden A = ', @ordenA, ' · Orden B = ', @ordenB, ' · Orden no LISTO = ', ISNULL(CAST(@ordenNoListo AS VARCHAR(10)), 'ninguna'));

/* ------------------------------ T08: facturar ------------------------------ */
DECLARE @facA INT, @totalA DECIMAL(12,2), @subtotalA DECIMAL(12,2) = dbo.fn_TotalOrden(@ordenA);

EXEC dbo.sp_FacturarOrden @idOrden = @ordenA, @idUsuario = @caja;
-- Se recupera por la llave de negocio (no se usa INSERT ... EXEC: falla con el error 3915 si el SP hace ROLLBACK)
SELECT @facA = idFactura, @totalA = total FROM dbo.Factura WHERE idOrden = @ordenA;

SELECT 'T08 factura' AS prueba, f.idFactura, f.serie, f.numero, f.nitFacturacion, f.nombreFacturacion,
       f.subtotal, f.impuesto, f.total
FROM dbo.Factura f WHERE f.idFactura = @facA;

SELECT 'T08 líneas' AS prueba, numeroLinea, tipoLinea, descripcion, cantidad, precioUnitario, subtotalLinea
FROM dbo.DetalleFactura WHERE idFactura = @facA ORDER BY numeroLinea;

PRINT IIF(@totalA = @subtotalA + ROUND(@subtotalA * 0.12, 2),
          'OK   T08: total = subtotal + 12 %', 'FALLA T08: el total no cuadra con subtotal + 12 %');

BEGIN TRY
    EXEC dbo.sp_FacturarOrden @idOrden = @ordenA, @idUsuario = @caja;
    PRINT 'FALLA T08: la segunda factura NO fue rechazada';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 50313, 'OK   T08: segunda factura rechazada (50313)', CONCAT('FALLA T08: error inesperado ', ERROR_NUMBER(), ' ', ERROR_MESSAGE()));
END CATCH;

IF @ordenNoListo IS NOT NULL
BEGIN
    BEGIN TRY
        EXEC dbo.sp_FacturarOrden @idOrden = @ordenNoListo, @idUsuario = @caja;
        PRINT 'FALLA T08: se facturó una orden que no está LISTO';
    END TRY
    BEGIN CATCH
        PRINT IIF(ERROR_NUMBER() = 50312, 'OK   T08: orden que no está LISTO rechazada (50312)', CONCAT('FALLA T08: error inesperado ', ERROR_NUMBER(), ' ', ERROR_MESSAGE()));
    END CATCH;
END;

BEGIN TRY
    EXEC dbo.sp_FacturarOrden @idOrden = @ordenB, @idUsuario = @recepcion;   -- recepción no puede facturar
    PRINT 'FALLA T08: recepción pudo facturar';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 50301, 'OK   T08: usuario sin rol de caja rechazado (50301)', CONCAT('FALLA T08: error inesperado ', ERROR_NUMBER()));
END CATCH;

/* ------------------- T09: dos parciales y uno que completa ------------------ */
DECLARE @p DECIMAL(12,2) = ROUND(@totalA / 3, 2);
DECLARE @pagoParcial1 INT, @saldo DECIMAL(12,2);

EXEC dbo.sp_RegistrarPago @idFactura = @facA, @idMetodoPago = @efectivo, @monto = @p, @idUsuario = @caja;
SELECT @pagoParcial1 = MAX(idPago) FROM dbo.Pago WHERE idFactura = @facA;
SELECT @saldo = dbo.fn_SaldoFactura(@facA);
PRINT IIF(@saldo = @totalA - @p, CONCAT('OK   T09: pago 1, saldo = ', @saldo), 'FALLA T09: saldo tras el pago 1');

EXEC dbo.sp_RegistrarPago @idFactura = @facA, @idMetodoPago = @efectivo, @monto = @p, @idUsuario = @caja;
SELECT @saldo = dbo.fn_SaldoFactura(@facA);
PRINT IIF(@saldo = @totalA - 2 * @p, CONCAT('OK   T09: pago 2, saldo = ', @saldo), 'FALLA T09: saldo tras el pago 2');

-- Intento de entrega con saldo pendiente
BEGIN TRY
    EXEC dbo.sp_EntregarOrden @idOrden = @ordenA, @idUsuarioEntrega = @recepcion, @nombreRecibe = N'Cliente de prueba';
    PRINT 'FALLA: se entregó una orden con saldo pendiente';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 50324, 'OK   Entrega con saldo pendiente rechazada (50324)', CONCAT('FALLA: error inesperado ', ERROR_NUMBER(), ' ', ERROR_MESSAGE()));
END CATCH;

DECLARE @resto DECIMAL(12,2) = dbo.fn_SaldoFactura(@facA);
EXEC dbo.sp_RegistrarPago @idFactura = @facA, @idMetodoPago = @efectivo, @monto = @resto, @idUsuario = @caja;
SELECT @saldo = dbo.fn_SaldoFactura(@facA);
PRINT IIF(@saldo = 0, 'OK   T09: el tercer pago completa la factura, saldo = 0', CONCAT('FALLA T09: saldo final ', @saldo));

BEGIN TRY
    EXEC dbo.sp_RegistrarPago @idFactura = @facA, @idMetodoPago = @efectivo, @monto = 1, @idUsuario = @caja;
    PRINT 'FALLA T09: se aceptó un pago sobre una factura pagada';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 50307, 'OK   T09: factura ya pagada rechazada (50307)', CONCAT('FALLA T09: error inesperado ', ERROR_NUMBER()));
END CATCH;

SELECT 'T09 pagos' AS prueba, p.idPago, p.monto, p.estado, p.fechaPago, mp.nombre AS metodo
FROM dbo.Pago p INNER JOIN dbo.MetodoPago mp ON mp.idMetodoPago = p.idMetodoPago
WHERE p.idFactura = @facA ORDER BY p.idPago;

/* -------------- T10: pago mayor al saldo y tarjeta sin referencia ------------ */
DECLARE @facB INT, @totalB DECIMAL(12,2);
EXEC dbo.sp_FacturarOrden @idOrden = @ordenB, @idUsuario = @caja;
SELECT @facB = idFactura, @totalB = total FROM dbo.Factura WHERE idOrden = @ordenB;

DECLARE @pagosAntes INT = (SELECT COUNT(*) FROM dbo.Pago WHERE idFactura = @facB);
DECLARE @montoExcesivo DECIMAL(12,2) = @totalB + 1;     -- los parámetros de EXEC no admiten expresiones

BEGIN TRY
    EXEC dbo.sp_RegistrarPago @idFactura = @facB, @idMetodoPago = @efectivo, @monto = @montoExcesivo, @idUsuario = @caja;
    PRINT 'FALLA T10: el pago excesivo NO fue rechazado';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 50308, 'OK   T10: pago mayor al saldo rechazado (50308)', CONCAT('FALLA T10: error inesperado ', ERROR_NUMBER(), ' ', ERROR_MESSAGE()));
END CATCH;

BEGIN TRY
    EXEC dbo.sp_RegistrarPago @idFactura = @facB, @idMetodoPago = @tarjeta, @monto = 1, @idUsuario = @caja;
    PRINT 'FALLA T10: tarjeta sin referencia NO fue rechazada';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 50304, 'OK   T10: tarjeta sin referencia rechazada (50304)', CONCAT('FALLA T10: error inesperado ', ERROR_NUMBER()));
END CATCH;

DECLARE @pagosDespues INT = (SELECT COUNT(*) FROM dbo.Pago WHERE idFactura = @facB);
PRINT IIF(@pagosDespues = @pagosAntes,
          'OK   T10: ningún pago fue insertado', 'FALLA T10: se insertó un pago que debió rechazarse');
SELECT 'T10 saldo sin cambios' AS prueba, dbo.fn_SaldoFactura(@facB) AS saldo, @totalB AS total;

/* ------------------------- Anular pago (R14) y entregar ---------------------- */
-- Pago parcial en la orden B para probar la anulación mientras la orden sigue en LISTO
DECLARE @pagoB INT;
EXEC dbo.sp_RegistrarPago @idFactura = @facB, @idMetodoPago = @efectivo, @monto = 10, @idUsuario = @caja;
SELECT @pagoB = MAX(idPago) FROM dbo.Pago WHERE idFactura = @facB;

BEGIN TRY
    EXEC dbo.sp_AnularPago @idPago = @pagoB, @idUsuario = @caja, @motivo = N'   ';
    PRINT 'FALLA: se anuló un pago sin motivo';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 50315, 'OK   Anular sin motivo rechazado (50315)', CONCAT('FALLA: error inesperado ', ERROR_NUMBER()));
END CATCH;

EXEC dbo.sp_AnularPago @idPago = @pagoB, @idUsuario = @caja, @motivo = N'Prueba T10: error de captura';
DECLARE @estadoPagoB VARCHAR(10) = (SELECT estado FROM dbo.Pago WHERE idPago = @pagoB);
DECLARE @saldoB DECIMAL(12,2) = dbo.fn_SaldoFactura(@facB);
PRINT IIF(@estadoPagoB = 'ANULADO' AND @saldoB = @totalB,
          'OK   Pago anulado (no borrado) y el saldo volvió a subir', 'FALLA: la anulación no dejó el estado esperado');

BEGIN TRY
    EXEC dbo.sp_AnularPago @idPago = @pagoB, @idUsuario = @caja, @motivo = N'otra vez';
    PRINT 'FALLA: se anuló dos veces el mismo pago';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 50317, 'OK   Anular un pago ya anulado rechazado (50317)', CONCAT('FALLA: error inesperado ', ERROR_NUMBER()));
END CATCH;

-- Entrega de la orden A (factura pagada completa)
EXEC dbo.sp_EntregarOrden @idOrden = @ordenA, @idUsuarioEntrega = @recepcion,
     @nombreRecibe = N'Cliente de prueba', @documentoRecibe = '1234567890101', @observaciones = N'Prueba T08-T10';

DECLARE @estadoOrdenA VARCHAR(25) = (SELECT estado FROM dbo.OrdenServicio WHERE idOrden = @ordenA);
PRINT IIF(@estadoOrdenA = 'ENTREGADO',
          'OK   Orden A entregada', 'FALLA: la orden A no quedó ENTREGADO');

SELECT 'Historial orden A' AS prueba, estadoAnterior, estadoNuevo, fechaCambio, idUsuario, observacion
FROM dbo.HistorialEstadoOrden WHERE idOrden = @ordenA ORDER BY fechaCambio;

BEGIN TRY
    EXEC dbo.sp_AnularPago @idPago = @pagoParcial1, @idUsuario = @caja, @motivo = N'Intento tardío';
    PRINT 'FALLA: se anuló un pago de una orden entregada';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 50318, 'OK   Anular el pago de una orden entregada rechazado (50318)', CONCAT('FALLA: error inesperado ', ERROR_NUMBER()));
END CATCH;

-- Doble protección (R16): el trigger corta el UPDATE directo aunque alguien se salte el SP
BEGIN TRY
    UPDATE dbo.OrdenServicio SET estado = 'ENTREGADO' WHERE idOrden = @ordenB;
    PRINT 'FALLA: el UPDATE directo a ENTREGADO NO fue rechazado';
END TRY
BEGIN CATCH
    PRINT IIF(ERROR_NUMBER() = 51003, 'OK   UPDATE directo a ENTREGADO rechazado por el trigger (51003)', CONCAT('FALLA: error inesperado ', ERROR_NUMBER(), ' ', ERROR_MESSAGE()));
END CATCH;
GO
