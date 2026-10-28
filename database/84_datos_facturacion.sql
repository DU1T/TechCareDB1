/* =====================================================================
   84_datos_facturacion.sql  |  Dueño: FRONTEND
   ---------------------------------------------------------------------
   Requiere 80-83 (órdenes en LISTO).
   - 30+ facturas con sp_FacturarOrden.
   - 40+ pagos con sp_RegistrarPago: facturas pagadas completas, una con 3 pagos,
     varias con saldo pendiente, métodos distintos.
   - Entregas con sp_EntregarOrden solo de órdenes con saldo 0.
   - Opcional: un pago anulado con sp_AnularPago (R14).
   ---------------------------------------------------------------------
   Los datos de prueba se reparten en 6 archivos, uno por dueño; el build los
   une EN ESTE ORDEN en TechCare_DatosPrueba.sql (entregable 03):
     80_datos_usuarios.sql     B  10+ usuarios con hash real y sus roles (los genera el backend)
     81_datos_maestros.sql     C  clientes, equipos, repuestos, inventario (stockMinimo), proveedores
     82_datos_compras.sql      C  20+ compras vía SP (17 recibidas, 3+ PENDIENTES)
     83_datos_ordenes.sql      B  60+ órdenes, 45+ diagnósticos, 35+ reparaciones, repuestos usados
     84_datos_facturacion.sql  A  30+ facturas, 40+ pagos, entregas
     85_datos_escenarios.sql   C  fechas repartidas, escenarios de la defensa y verificación de mínimos
   REGLA DE ORO: todo lo transaccional se crea LLAMANDO A LOS SP. Si un SP falla
   al generar datos, encontraron un bug antes que el profesor.
   Para recuperar el id que crea un SP, búsquelo después por su llave de negocio
   (no use INSERT ... EXEC con SP que tienen transacción: falla con el error 3915).
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @cajaA INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'caja1');
DECLARE @cajaB INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'caja2');
DECLARE @recA  INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'recepcion1');
DECLARE @recB  INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'recepcion2');
DECLARE @mEfectivo      INT = (SELECT idMetodoPago FROM dbo.MetodoPago WHERE nombre = 'EFECTIVO');
DECLARE @mTarjeta       INT = (SELECT idMetodoPago FROM dbo.MetodoPago WHERE nombre = 'TARJETA');
DECLARE @mTransferencia INT = (SELECT idMetodoPago FROM dbo.MetodoPago WHERE nombre = 'TRANSFERENCIA');
DECLARE @mCheque        INT = (SELECT idMetodoPago FROM dbo.MetodoPago WHERE nombre = 'CHEQUE');

IF @cajaA IS NULL OR @cajaB IS NULL OR @recA IS NULL OR @recB IS NULL
   OR @mEfectivo IS NULL OR @mTarjeta IS NULL OR @mTransferencia IS NULL OR @mCheque IS NULL
BEGIN
    RAISERROR(N'84: faltan usuarios caja1/caja2/recepcion1/recepcion2 (archivo 80) o métodos de pago (archivo 05).', 16, 1);
    RETURN;
END;

-- Cola de órdenes LISTO con reparación cobrable y sin factura, siempre en el mismo orden
IF OBJECT_ID('tempdb..#Cola') IS NOT NULL DROP TABLE #Cola;
SELECT ROW_NUMBER() OVER (ORDER BY o.idOrden) AS rn, o.idOrden
INTO #Cola
FROM dbo.OrdenServicio o
WHERE o.estado = 'LISTO'
  AND dbo.fn_TotalOrden(o.idOrden) > 0
  AND NOT EXISTS (SELECT 1 FROM dbo.Factura f WHERE f.idOrden = o.idOrden);

DECLARE @disponibles INT = (SELECT COUNT(*) FROM #Cola);
IF @disponibles < 30
BEGIN
    RAISERROR(N'84: se necesitan 30 órdenes LISTO con monto y sin factura y solo hay %d. Cargue primero el archivo 83.', 16, 1, @disponibles);
    RETURN;
END;

/* Reparto de las 30 primeras órdenes (las demás quedan LISTO sin factura para las demos en vivo):
     1-10   un solo pago que la cubre completa
     11-13  tres pagos (el último completa)
     14-19  dos pagos (el segundo completa)
     20-25  un pago parcial (la 25 tiene además un pago anulado por error, R14)
     26-27  sin pagos (saldo completo)
     28-30  un pago parcial pequeño
   Métodos de pago rotando; tarjeta, transferencia y cheque llevan referencia.
   Se entregan las órdenes 1-14 (pagadas); la 15-19 quedan pagadas y listas para entregar. */
DECLARE @rn INT = 1, @idOrden INT, @idFactura INT, @total DECIMAL(12,2),
        @caja INT, @rec INT, @monto DECIMAL(12,2), @resto DECIMAL(12,2),
        @m1 INT, @m2 INT, @m3 INT, @r1 VARCHAR(60), @r2 VARCHAR(60), @r3 VARCHAR(60),
        @pagoError INT, @nombreRecibe NVARCHAR(120), @documento VARCHAR(20);

WHILE @rn <= 30
BEGIN
    SELECT @idOrden = idOrden FROM #Cola WHERE rn = @rn;
    SET @caja = CASE WHEN @rn % 2 = 1 THEN @cajaA ELSE @cajaB END;
    SET @rec  = CASE WHEN @rn % 2 = 1 THEN @recA  ELSE @recB  END;

    EXEC dbo.sp_FacturarOrden @idOrden = @idOrden, @idUsuario = @caja;
    SELECT @idFactura = idFactura, @total = total FROM dbo.Factura WHERE idOrden = @idOrden;

    SET @m1 = CHOOSE( @rn      % 4 + 1, @mEfectivo, @mTarjeta, @mTransferencia, @mCheque);
    SET @m2 = CHOOSE((@rn + 1) % 4 + 1, @mEfectivo, @mTarjeta, @mTransferencia, @mCheque);
    SET @m3 = CHOOSE((@rn + 2) % 4 + 1, @mEfectivo, @mTarjeta, @mTransferencia, @mCheque);
    SET @r1 = CASE WHEN @m1 = @mEfectivo THEN NULL ELSE CONCAT('AUT-', @idFactura, '-1') END;
    SET @r2 = CASE WHEN @m2 = @mEfectivo THEN NULL ELSE CONCAT('AUT-', @idFactura, '-2') END;
    SET @r3 = CASE WHEN @m3 = @mEfectivo THEN NULL ELSE CONCAT('AUT-', @idFactura, '-3') END;

    IF @rn <= 10
    BEGIN
        EXEC dbo.sp_RegistrarPago @idFactura = @idFactura, @idMetodoPago = @m1, @monto = @total,
             @idUsuario = @caja, @referencia = @r1;
    END
    ELSE IF @rn <= 13
    BEGIN
        SET @monto = ROUND(@total / 3, 2);
        EXEC dbo.sp_RegistrarPago @idFactura = @idFactura, @idMetodoPago = @m1, @monto = @monto,
             @idUsuario = @caja, @referencia = @r1;
        EXEC dbo.sp_RegistrarPago @idFactura = @idFactura, @idMetodoPago = @m2, @monto = @monto,
             @idUsuario = @caja, @referencia = @r2;
        SET @resto = dbo.fn_SaldoFactura(@idFactura);
        EXEC dbo.sp_RegistrarPago @idFactura = @idFactura, @idMetodoPago = @m3, @monto = @resto,
             @idUsuario = @caja, @referencia = @r3;
    END
    ELSE IF @rn <= 19
    BEGIN
        SET @monto = ROUND(@total / 2, 2);
        EXEC dbo.sp_RegistrarPago @idFactura = @idFactura, @idMetodoPago = @m1, @monto = @monto,
             @idUsuario = @caja, @referencia = @r1;
        SET @resto = dbo.fn_SaldoFactura(@idFactura);
        EXEC dbo.sp_RegistrarPago @idFactura = @idFactura, @idMetodoPago = @m2, @monto = @resto,
             @idUsuario = @caja, @referencia = @r2;
    END
    ELSE IF @rn <= 25
    BEGIN
        IF @rn = 25
        BEGIN
            -- Pago registrado por error y anulado con motivo (R14: se anula, nunca se borra)
            SET @monto = ROUND(@total * 0.10, 2);
            EXEC dbo.sp_RegistrarPago @idFactura = @idFactura, @idMetodoPago = @m3, @monto = @monto,
                 @idUsuario = @caja, @referencia = @r3;
            SELECT @pagoError = MAX(idPago) FROM dbo.Pago WHERE idFactura = @idFactura;
            EXEC dbo.sp_AnularPago @idPago = @pagoError, @idUsuario = @caja,
                 @motivo = N'Pago registrado por error de captura';
        END;
        SET @monto = ROUND(@total * 0.40, 2);
        EXEC dbo.sp_RegistrarPago @idFactura = @idFactura, @idMetodoPago = @m1, @monto = @monto,
             @idUsuario = @caja, @referencia = @r1;
    END
    ELSE IF @rn >= 28
    BEGIN
        SET @monto = ROUND(@total * 0.25, 2);
        EXEC dbo.sp_RegistrarPago @idFactura = @idFactura, @idMetodoPago = @m1, @monto = @monto,
             @idUsuario = @caja, @referencia = @r1;
    END;
    -- rn 26 y 27: se quedan sin pagos

    -- Entrega de las 14 primeras (pagadas completas)
    IF @rn <= 14
    BEGIN
        SELECT @nombreRecibe = LEFT(c.nombre, 120)
        FROM dbo.OrdenServicio o
        INNER JOIN dbo.Equipo  e ON e.idEquipo  = o.idEquipo
        INNER JOIN dbo.Cliente c ON c.idCliente = e.idCliente
        WHERE o.idOrden = @idOrden;
        SET @documento = CAST(2000000000000 + @idOrden AS VARCHAR(20));
        EXEC dbo.sp_EntregarOrden @idOrden = @idOrden, @idUsuarioEntrega = @rec,
             @nombreRecibe = @nombreRecibe, @documentoRecibe = @documento,
             @observaciones = N'Entrega conforme';
    END;

    SET @rn += 1;
END;

-- Órdenes LISTO que el cliente no autorizó (sin reparación): se entregan sin factura
DECLARE curSinFactura CURSOR LOCAL FAST_FORWARD FOR
    SELECT TOP (2) o.idOrden
    FROM dbo.OrdenServicio o
    WHERE o.estado = 'LISTO'
      AND NOT EXISTS (SELECT 1 FROM dbo.Factura f WHERE f.idOrden = o.idOrden)
      AND NOT EXISTS (SELECT 1
                      FROM dbo.Diagnostico d
                      INNER JOIN dbo.Reparacion r ON r.idDiagnostico = d.idDiagnostico
                      WHERE d.idOrden = o.idOrden AND r.estado = 'FINALIZADA')
    ORDER BY o.idOrden;

OPEN curSinFactura;
FETCH NEXT FROM curSinFactura INTO @idOrden;
WHILE @@FETCH_STATUS = 0
BEGIN
    SELECT @nombreRecibe = LEFT(c.nombre, 120)
    FROM dbo.OrdenServicio o
    INNER JOIN dbo.Equipo  e ON e.idEquipo  = o.idEquipo
    INNER JOIN dbo.Cliente c ON c.idCliente = e.idCliente
    WHERE o.idOrden = @idOrden;
    EXEC dbo.sp_EntregarOrden @idOrden = @idOrden, @idUsuarioEntrega = @recA,
         @nombreRecibe = @nombreRecibe, @observaciones = N'Equipo devuelto sin reparar';
    FETCH NEXT FROM curSinFactura INTO @idOrden;
END;
CLOSE curSinFactura;
DEALLOCATE curSinFactura;

-- Verificación de mínimos y resumen
DECLARE @nFacturas INT = (SELECT COUNT(*) FROM dbo.Factura WHERE estado = 'EMITIDA');
DECLARE @nPagos    INT = (SELECT COUNT(*) FROM dbo.Pago);
DECLARE @nEntregas INT = (SELECT COUNT(*) FROM dbo.Entrega);
IF @nFacturas < 30 OR @nPagos < 40
    RAISERROR(N'84: no se alcanzaron los mínimos (30 facturas y 40 pagos). Facturas: %d, pagos: %d.', 16, 1, @nFacturas, @nPagos);

SELECT @nFacturas AS facturas,
       @nPagos    AS pagos,
       (SELECT COUNT(*) FROM dbo.Pago WHERE estado = 'ANULADO') AS pagosAnulados,
       (SELECT COUNT(*) FROM (SELECT idFactura FROM dbo.Pago WHERE estado = 'APLICADO'
                              GROUP BY idFactura HAVING COUNT(*) = 3) t)  AS facturasCon3Pagos,
       (SELECT COUNT(*) FROM dbo.vw_FacturasSaldo WHERE estadoPago = 'PAGADA')    AS pagadas,
       (SELECT COUNT(*) FROM dbo.vw_FacturasSaldo WHERE estadoPago = 'PARCIAL')   AS parciales,
       (SELECT COUNT(*) FROM dbo.vw_FacturasSaldo WHERE estadoPago = 'PENDIENTE') AS pendientes,
       @nEntregas AS entregas;
GO

SET NOEXEC OFF;
GO
