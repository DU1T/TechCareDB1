/* =====================================================================
   43_sp_facturacion.sql  |  Dueño: FRONTEND  |  Facturación, pagos, entrega
   ---------------------------------------------------------------------
   Códigos de error: 50300-50399.  Plantilla: sp_UtilizarRepuesto.
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
   TODO dbo.sp_FacturarOrden                                   (T08, R11)
       @idOrden INT, @idUsuario INT, @nitFacturacion VARCHAR(15) = NULL,
       @nombreFacturacion NVARCHAR(150) = NULL, @direccionFacturacion NVARCHAR(250) = NULL
     -> rol CAJA; orden en LISTO; sin factura previa (UQ_Factura_Orden lo garantiza igual)
     -> NIT/nombre por defecto = los del cliente (Equipo -> Cliente)
     -> subtotal = dbo.fn_TotalOrden(@idOrden); impuesto = ROUND(subtotal * 0.12, 2); total = subtotal + impuesto
     -> INSERT Factura + DetalleFactura:
          línea 1 MANO_OBRA (cantidad 1, precio = costoManoObra de la reparación) si > 0
          una línea REPUESTO por cada DetalleRepuesto APLICADO (precio HISTÓRICO, idDetalleRepuesto)
       Tip: numeroLinea con ROW_NUMBER() OVER (ORDER BY idDetalleRepuesto) + 1
     -> todo en una transacción; devuelve idFactura, serie, numero, total

   HECHO dbo.sp_RegistrarPago (arriba, modelo).

   TODO dbo.sp_AnularPago   @idPago, @idUsuario, @motivo                  (R14)
     -> estado ANULADO + motivo (nunca DELETE)

   TODO dbo.sp_EntregarOrden                                    (4.1, 2.8)
       @idOrden INT, @idUsuarioEntrega INT, @nombreRecibe NVARCHAR(120),
       @documentoRecibe VARCHAR(20) = NULL, @observaciones NVARCHAR(300) = NULL
     -> orden en LISTO; si hubo reparación: factura EMITIDA con saldo 0
     -> INSERT Entrega + sp_EstablecerContexto + UPDATE estado ENTREGADO
        (el trigger vuelve a validar: doble protección)
   --------------------------------------------------------------------- */

SET NOEXEC OFF;
GO
