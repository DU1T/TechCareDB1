/* =====================================================================
   43_sp_facturacion.sql  |  Dueño: FRONTEND  |  Facturación, pagos, entrega
   ---------------------------------------------------------------------
   Códigos de error: 50300-50399.  Plantilla: sp_UtilizarRepuesto.
   Códigos: 50301-50308 pago · 50310-50314 facturar · 50315-50318 anular pago · 50319-50324 entregar.
   Contratos completos en el plan, sección 7.
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
-- sp_RegistrarPago: procedimiento modelo de este dominio (mismo código que la guía y el plan).
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarPago
    @idFactura     INT,
    @idMetodoPago  INT,
    @monto         DECIMAL(12,2),
    @idUsuario     INT,
    @referencia    VARCHAR(60) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_UsuarioTieneRol(@idUsuario, 'CAJA') = 0
        THROW 50301, 'El usuario no tiene rol de caja.', 1;

    IF @monto IS NULL OR @monto <= 0
        THROW 50302, 'El monto debe ser mayor que cero.', 1;

    DECLARE @requiereRef BIT;
    SELECT @requiereRef = mp.requiereReferencia
    FROM dbo.MetodoPago mp
    WHERE mp.idMetodoPago = @idMetodoPago AND mp.estado = 'ACTIVO';

    IF @requiereRef IS NULL
        THROW 50303, 'Método de pago inválido o inactivo.', 1;
    IF @requiereRef = 1 AND NULLIF(LTRIM(RTRIM(@referencia)), '') IS NULL
        THROW 50304, 'Este método de pago requiere número de referencia.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado VARCHAR(10);

        -- Bloquea la factura: un segundo cajero espera aquí y después ve el saldo ya actualizado
        SELECT @estado = f.estado
        FROM dbo.Factura f WITH (UPDLOCK, HOLDLOCK)
        WHERE f.idFactura = @idFactura;

        IF @estado IS NULL      THROW 50305, 'La factura no existe.', 1;
        IF @estado <> 'EMITIDA' THROW 50306, 'La factura está anulada.', 1;

        DECLARE @saldo DECIMAL(12,2) = dbo.fn_SaldoFactura(@idFactura);

        IF @saldo = 0      THROW 50307, 'La factura ya está pagada.', 1;
        IF @monto > @saldo THROW 50308, 'El pago excede el saldo pendiente de la factura (R12).', 1;

        INSERT INTO dbo.Pago (idFactura, idMetodoPago, monto, referencia, idUsuarioCaja)
        VALUES (@idFactura, @idMetodoPago, @monto, @referencia, @idUsuario);

        DECLARE @idPago INT = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT TRANSACTION;

        SELECT @idPago AS idPago, @saldo - @monto AS saldoRestante;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------------------------------------------------------------------
   Bloqueo: orden de adquisición de candados. Para no provocar interbloqueos (deadlocks),
   todo SP de este archivo toma los candados en el mismo orden:  Orden -> Factura -> Pago.
   (sp_RegistrarPago solo bloquea la Factura, así que no forma ciclo con los demás.)
   --------------------------------------------------------------------- */

-- sp_FacturarOrden (R11, R09). Códigos: 50301, 50310 a 50314.
CREATE OR ALTER PROCEDURE dbo.sp_FacturarOrden
    @idOrden              INT,
    @idUsuario            INT,
    @nitFacturacion       VARCHAR(15)   = NULL,
    @nombreFacturacion    NVARCHAR(150) = NULL,
    @direccionFacturacion NVARCHAR(250) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_UsuarioTieneRol(@idUsuario, 'CAJA') = 0
        THROW 50301, 'El usuario no tiene rol de caja.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado        VARCHAR(25);
        DECLARE @nitCliente    VARCHAR(15);
        DECLARE @nombreCliente NVARCHAR(150);
        DECLARE @dirCliente    NVARCHAR(250);

        -- Bloquea la orden: dos cajeros no pueden facturarla a la vez
        SELECT @estado        = o.estado,
               @nitCliente    = c.nit,
               @nombreCliente = c.nombre,
               @dirCliente    = c.direccion
        FROM dbo.OrdenServicio o WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Equipo  e ON e.idEquipo  = o.idEquipo
        INNER JOIN dbo.Cliente c ON c.idCliente = e.idCliente
        WHERE o.idOrden = @idOrden;

        IF @estado IS NULL    THROW 50311, 'La orden no existe.', 1;
        IF @estado <> 'LISTO' THROW 50312, 'Solo se puede facturar una orden en estado LISTO.', 1;

        -- R11: una factura por orden (UQ_Factura_Orden lo garantiza igual, aunque falle esta validación)
        IF EXISTS (SELECT 1 FROM dbo.Factura WHERE idOrden = @idOrden)
            THROW 50313, 'La orden ya tiene factura (R11).', 1;

        DECLARE @subtotal DECIMAL(12,2) = dbo.fn_TotalOrden(@idOrden);
        IF @subtotal <= 0
            THROW 50314, 'No hay montos que facturar; entregue la orden sin factura.', 1;

        DECLARE @tasa     DECIMAL(5,4)  = 0.12;                      -- IVA 12 %
        DECLARE @impuesto DECIMAL(12,2) = ROUND(@subtotal * @tasa, 2);
        DECLARE @total    DECIMAL(12,2) = @subtotal + @impuesto;     -- CK_Factura_Total exige que cuadre exacto

        INSERT INTO dbo.Factura
            (idOrden, nitFacturacion, nombreFacturacion, direccionFacturacion,
             subtotal, tasaImpuesto, impuesto, total, idUsuarioEmite)
        VALUES
            (@idOrden,
             ISNULL(NULLIF(LTRIM(RTRIM(@nitFacturacion)), ''),        @nitCliente),
             ISNULL(NULLIF(LTRIM(RTRIM(@nombreFacturacion)), N''),    @nombreCliente),
             ISNULL(NULLIF(LTRIM(RTRIM(@direccionFacturacion)), N''), @dirCliente),
             @subtotal, @tasa, @impuesto, @total, @idUsuario);

        DECLARE @idFactura INT = CAST(SCOPE_IDENTITY() AS INT);

        -- Línea 1: mano de obra (si la reparación tuvo costo)
        INSERT INTO dbo.DetalleFactura (idFactura, numeroLinea, tipoLinea, descripcion, cantidad, precioUnitario)
        SELECT @idFactura, 1, 'MANO_OBRA', N'Mano de obra ' + o.numeroOrden, 1, r.costoManoObra
        FROM dbo.OrdenServicio o
        INNER JOIN dbo.Diagnostico d ON d.idOrden = o.idOrden
        INNER JOIN dbo.Reparacion  r ON r.idDiagnostico = d.idDiagnostico
        WHERE o.idOrden = @idOrden
          AND r.estado = 'FINALIZADA'
          AND r.costoManoObra > 0;

        DECLARE @base SMALLINT = (SELECT COUNT(*) FROM dbo.DetalleFactura WHERE idFactura = @idFactura);

        -- Una línea por repuesto aplicado, con su precio HISTÓRICO (R09), numerada a continuación
        INSERT INTO dbo.DetalleFactura
            (idFactura, numeroLinea, tipoLinea, descripcion, cantidad, precioUnitario, idDetalleRepuesto)
        SELECT @idFactura,
               CAST(@base + ROW_NUMBER() OVER (ORDER BY dr.idDetalleRepuesto) AS SMALLINT),
               'REPUESTO', rp.nombre, dr.cantidad, dr.precioUnitario, dr.idDetalleRepuesto
        FROM dbo.Diagnostico d
        INNER JOIN dbo.Reparacion      r  ON r.idDiagnostico = d.idDiagnostico
        INNER JOIN dbo.DetalleRepuesto dr ON dr.idReparacion = r.idReparacion AND dr.estado = 'APLICADO'
        INNER JOIN dbo.Repuesto        rp ON rp.idRepuesto   = dr.idRepuesto
        WHERE d.idOrden = @idOrden;

        -- Verificación defensiva: las líneas deben sumar exactamente el subtotal
        IF ISNULL((SELECT SUM(subtotalLinea) FROM dbo.DetalleFactura WHERE idFactura = @idFactura), 0) <> @subtotal
            THROW 50310, 'Las líneas de la factura no cuadran con el total de la orden.', 1;

        COMMIT TRANSACTION;

        SELECT f.idFactura, f.serie, f.numero, f.total
        FROM dbo.Factura f
        WHERE f.idFactura = @idFactura;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- sp_AnularPago (R14: nunca DELETE). Códigos: 50301, 50315 a 50318.
CREATE OR ALTER PROCEDURE dbo.sp_AnularPago
    @idPago     INT,
    @idUsuario  INT,
    @motivo     NVARCHAR(250)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_UsuarioTieneRol(@idUsuario, 'CAJA') = 0
        THROW 50301, 'El usuario no tiene rol de caja.', 1;

    IF NULLIF(LTRIM(RTRIM(@motivo)), N'') IS NULL
        THROW 50315, 'Debe indicar el motivo de la anulación (R14).', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @idFactura INT;
        DECLARE @idOrden   INT;

        -- Estos dos datos no cambian nunca, por eso se leen sin bloquear
        SELECT @idFactura = p.idFactura, @idOrden = f.idOrden
        FROM dbo.Pago p
        INNER JOIN dbo.Factura f ON f.idFactura = p.idFactura
        WHERE p.idPago = @idPago;

        IF @idFactura IS NULL THROW 50316, 'El pago no existe.', 1;

        -- Orden de candados: Orden -> Factura -> Pago
        DECLARE @estadoOrden VARCHAR(25);
        SELECT @estadoOrden = o.estado
        FROM dbo.OrdenServicio o WITH (UPDLOCK, ROWLOCK)
        WHERE o.idOrden = @idOrden;

        -- Si la orden ya se entregó, anular el pago dejaría saldo pendiente después de entregar
        IF @estadoOrden = 'ENTREGADO'
            THROW 50318, 'No se puede anular un pago de una orden ya entregada.', 1;

        SELECT @idFactura = f.idFactura
        FROM dbo.Factura f WITH (UPDLOCK, HOLDLOCK)
        WHERE f.idFactura = @idFactura;

        DECLARE @estadoPago VARCHAR(10);
        SELECT @estadoPago = p.estado
        FROM dbo.Pago p WITH (UPDLOCK, HOLDLOCK)
        WHERE p.idPago = @idPago;

        IF @estadoPago <> 'APLICADO' THROW 50317, 'El pago ya está anulado.', 1;

        UPDATE dbo.Pago
           SET estado = 'ANULADO',
               motivoAnulacion = LTRIM(RTRIM(@motivo))
         WHERE idPago = @idPago;

        COMMIT TRANSACTION;

        -- El saldo no se guarda (R13): se vuelve a calcular y sube por sí solo
        SELECT @idPago AS idPago, dbo.fn_SaldoFactura(@idFactura) AS saldoActual;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- sp_EntregarOrden (R16: doble protección con trg_OrdenServicio_Estado). Códigos: 50319 a 50324.
CREATE OR ALTER PROCEDURE dbo.sp_EntregarOrden
    @idOrden           INT,
    @idUsuarioEntrega  INT,
    @nombreRecibe      NVARCHAR(120),
    @documentoRecibe   VARCHAR(20)   = NULL,
    @observaciones     NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_UsuarioTieneRol(@idUsuarioEntrega, 'RECEPCION') = 0
       AND dbo.fn_UsuarioTieneRol(@idUsuarioEntrega, 'CAJA') = 0
        THROW 50319, 'El usuario no tiene rol de recepción ni de caja.', 1;

    IF NULLIF(LTRIM(RTRIM(@nombreRecibe)), N'') IS NULL
        THROW 50320, 'Debe indicar el nombre de quien recibe el equipo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado VARCHAR(25);

        -- Orden de candados: Orden -> Factura
        SELECT @estado = o.estado
        FROM dbo.OrdenServicio o WITH (UPDLOCK, HOLDLOCK)
        WHERE o.idOrden = @idOrden;

        IF @estado IS NULL    THROW 50321, 'La orden no existe.', 1;
        IF @estado <> 'LISTO' THROW 50322, 'Solo se puede entregar una orden en estado LISTO.', 1;

        DECLARE @huboReparacion BIT = CASE WHEN EXISTS (
            SELECT 1
            FROM dbo.Diagnostico d
            INNER JOIN dbo.Reparacion r ON r.idDiagnostico = d.idDiagnostico
            WHERE d.idOrden = @idOrden AND r.estado = 'FINALIZADA') THEN 1 ELSE 0 END;

        -- Factura vigente (si existe), bloqueada para que nadie la modifique mientras se entrega
        DECLARE @idFactura INT;
        SELECT @idFactura = f.idFactura
        FROM dbo.Factura f WITH (UPDLOCK, HOLDLOCK)
        WHERE f.idOrden = @idOrden AND f.estado = 'EMITIDA';

        -- Si hubo reparación se cobró: sin factura no se entrega. Una orden rechazada por el cliente sí sale sin factura.
        IF @huboReparacion = 1 AND @idFactura IS NULL
            THROW 50323, 'La orden tiene una reparación y todavía no tiene factura vigente.', 1;

        IF @idFactura IS NOT NULL AND dbo.fn_SaldoFactura(@idFactura) > 0
            THROW 50324, 'La factura tiene saldo pendiente; registre el pago antes de entregar (R12).', 1;

        INSERT INTO dbo.Entrega (idOrden, idUsuarioEntrega, nombreRecibe, documentoRecibe, observaciones)
        VALUES (@idOrden, @idUsuarioEntrega, LTRIM(RTRIM(@nombreRecibe)), @documentoRecibe, @observaciones);

        DECLARE @idEntrega INT = CAST(SCOPE_IDENTITY() AS INT);

        -- El trigger registra en el historial quién y por qué (lee el contexto de sesión) y vuelve a validar el cierre
        DECLARE @obsHistorial NVARCHAR(300) = LEFT(N'Entrega a ' + LTRIM(RTRIM(@nombreRecibe)), 300);
        EXEC dbo.sp_EstablecerContexto @idUsuario = @idUsuarioEntrega, @observacion = @obsHistorial;

        UPDATE dbo.OrdenServicio
           SET estado = 'ENTREGADO'
         WHERE idOrden = @idOrden;

        COMMIT TRANSACTION;

        EXEC dbo.sp_EstablecerContexto @idUsuario = NULL, @observacion = NULL;

        SELECT @idEntrega AS idEntrega, o.numeroOrden, o.estado
        FROM dbo.OrdenServicio o
        WHERE o.idOrden = @idOrden;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        EXEC dbo.sp_EstablecerContexto @idUsuario = NULL, @observacion = NULL;
        THROW;
    END CATCH;
END;
GO

SET NOEXEC OFF;
GO
