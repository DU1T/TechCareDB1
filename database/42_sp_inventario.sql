/* =====================================================================
   42_sp_inventario.sql  |  Dueño: FULLSTACK/INFRA  |  Inventario y compras
   ---------------------------------------------------------------------
   sp_UtilizarRepuesto = SP de REFERENCIA (ya hecho). Mejora la versión de la
   clase 1 en un punto clave para la defensa: valida la existencia DENTRO de la
   transacción con UPDLOCK/HOLDLOCK, así dos técnicos no pueden consumir la
   última unidad al mismo tiempo (escenario "¿qué puede salir mal?" de la clase).
   Códigos de error de este archivo: 50100-50199.
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
CREATE OR ALTER PROCEDURE dbo.sp_UtilizarRepuesto
    @idReparacion INT,
    @idBodega     INT,
    @idRepuesto   INT,
    @cantidad     INT,
    @idUsuario    INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- Validaciones que no dependen de datos que otro pueda cambiar
    IF @cantidad IS NULL OR @cantidad <= 0
        THROW 50101, 'La cantidad debe ser mayor que cero.', 1;

    IF dbo.fn_UsuarioTieneRol(@idUsuario, 'TECNICO') = 0
        THROW 50102, 'El usuario no está autorizado como técnico (R03).', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- La reparación debe existir, estar EN_PROCESO y su orden en REPARACION
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Reparacion r
            INNER JOIN dbo.Diagnostico d   ON d.idDiagnostico = r.idDiagnostico
            INNER JOIN dbo.OrdenServicio o ON o.idOrden = d.idOrden
            WHERE r.idReparacion = @idReparacion
              AND r.estado = 'EN_PROCESO'
              AND o.estado = 'REPARACION')
            THROW 50103, 'La reparación no existe o no está en proceso.', 1;

        DECLARE @existencia     INT;
        DECLARE @precioVenta    DECIMAL(12,2);
        DECLARE @costoRef       DECIMAL(12,2);
        DECLARE @estadoRepuesto VARCHAR(10);

        -- UPDLOCK + HOLDLOCK bloquea la fila de inventario hasta el COMMIT:
        -- un segundo técnico espera aquí y luego lee la existencia ya descontada.
        SELECT @existencia     = i.existencia,
               @precioVenta    = r.precioVenta,
               @costoRef       = r.precioCompraRef,
               @estadoRepuesto = r.estado
        FROM dbo.Inventario i WITH (UPDLOCK, HOLDLOCK)
        INNER JOIN dbo.Repuesto r ON r.idRepuesto = i.idRepuesto
        WHERE i.idBodega = @idBodega
          AND i.idRepuesto = @idRepuesto;

        IF @existencia IS NULL
            THROW 50104, 'El repuesto no está registrado en la bodega seleccionada (R06).', 1;

        IF @estadoRepuesto <> 'ACTIVO'
            THROW 50105, 'El repuesto está inactivo.', 1;

        IF @existencia < @cantidad
            THROW 50106, 'Existencia insuficiente en la bodega seleccionada (R06/R10).', 1;

        -- 1. Detalle con precio y costo HISTÓRICOS congelados (R09)
        INSERT INTO dbo.DetalleRepuesto
            (idReparacion, idBodega, idRepuesto, cantidad, precioUnitario, costoUnitario, idUsuario)
        VALUES
            (@idReparacion, @idBodega, @idRepuesto, @cantidad, @precioVenta, @costoRef, @idUsuario);

        DECLARE @idDetalle INT = CAST(SCOPE_IDENTITY() AS INT);

        -- 2. Descontar inventario (CK_Inventario_Existencia es la última red de seguridad)
        UPDATE dbo.Inventario
           SET existencia = existencia - @cantidad,
               fechaUltimoMovimiento = SYSDATETIME()
         WHERE idBodega = @idBodega
           AND idRepuesto = @idRepuesto;

        -- 3. Movimiento de salida con documento origen (R07)
        INSERT INTO dbo.MovimientoInventario
            (idBodega, idRepuesto, tipo, origen, cantidad, existenciaAnterior, existenciaResultante,
             costoUnitario, idUsuario, idDetalleRepuesto)
        VALUES
            (@idBodega, @idRepuesto, 'SALIDA', 'REPARACION', @cantidad, @existencia, @existencia - @cantidad,
             @costoRef, @idUsuario, @idDetalle);

        COMMIT TRANSACTION;

        SELECT @idDetalle AS idDetalleRepuesto,
               @existencia - @cantidad AS existenciaResultante;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

-- sp_RecibirCompra: procedimiento modelo de este dominio (mismo código que la guía y el plan).
CREATE OR ALTER PROCEDURE dbo.sp_RecibirCompra
    @idCompra  INT,
    @idUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_UsuarioTieneRol(@idUsuario, 'BODEGA') = 0
        THROW 50110, 'El usuario no tiene rol de bodega.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @idBodega INT, @estado VARCHAR(10);

        -- Bloquea la compra: dos personas no pueden recibirla a la vez
        SELECT @idBodega = c.idBodegaDestino, @estado = c.estado
        FROM dbo.Compra c WITH (UPDLOCK, HOLDLOCK)
        WHERE c.idCompra = @idCompra;

        IF @estado IS NULL        THROW 50111, 'La compra no existe.', 1;
        IF @estado <> 'PENDIENTE' THROW 50112, 'Solo se puede recibir una compra PENDIENTE.', 1;

        -- 1. Repuestos que aún no están en esa bodega: crear su fila con existencia 0
        INSERT INTO dbo.Inventario (idBodega, idRepuesto, existencia)
        SELECT @idBodega, dc.idRepuesto, 0
        FROM dbo.DetalleCompra dc
        WHERE dc.idCompra = @idCompra
          AND NOT EXISTS (SELECT 1 FROM dbo.Inventario i
                          WHERE i.idBodega = @idBodega AND i.idRepuesto = dc.idRepuesto);

        -- 2. Sumar existencias y capturar antes/después de cada fila
        DECLARE @mov TABLE (idRepuesto INT PRIMARY KEY, anterior INT, resultante INT);

        UPDATE i
           SET i.existencia = i.existencia + dc.cantidad,
               i.fechaUltimoMovimiento = SYSDATETIME()
        OUTPUT inserted.idRepuesto, deleted.existencia, inserted.existencia
          INTO @mov (idRepuesto, anterior, resultante)
        FROM dbo.Inventario i
        INNER JOIN dbo.DetalleCompra dc ON dc.idRepuesto = i.idRepuesto
        WHERE dc.idCompra = @idCompra
          AND i.idBodega = @idBodega;

        -- 3. Un movimiento ENTRADA por línea, con su documento origen (CK_Movimiento_Cuadre lo verifica)
        INSERT INTO dbo.MovimientoInventario
            (idBodega, idRepuesto, tipo, origen, cantidad, existenciaAnterior, existenciaResultante,
             costoUnitario, idUsuario, idCompra)
        SELECT @idBodega, m.idRepuesto, 'ENTRADA', 'COMPRA', dc.cantidad, m.anterior, m.resultante,
               dc.costoUnitario, @idUsuario, @idCompra
        FROM @mov m
        INNER JOIN dbo.DetalleCompra dc ON dc.idCompra = @idCompra AND dc.idRepuesto = m.idRepuesto;

        -- 4. Cerrar la compra (CK_Compra_Recepcion exige fecha y usuario)
        UPDATE dbo.Compra
           SET estado = 'RECIBIDA', fechaRecepcion = SYSDATETIME(), idUsuarioRecepcion = @idUsuario
         WHERE idCompra = @idCompra;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
        THROW;
    END CATCH;
END;
GO

/* ---------------------------------------------------------------------
   TODO (Fullstack/Infra) — contratos en el plan, sección 7:

   dbo.sp_RegistrarCompra
       @idProveedor INT, @idBodegaDestino INT, @numeroDocumento VARCHAR(30),
       @idUsuario INT, @detalle dbo.TipoDetalleCompra READONLY, @observaciones NVARCHAR(300) = NULL
     -> valida proveedor/bodega activos, rol BODEGA, detalle no vacío, repuestos activos
     -> INSERT Compra (PENDIENTE) + DetalleCompra en una transacción
     -> devuelve SELECT @idCompra AS idCompra

   dbo.sp_RecibirCompra -> HECHO arriba (modelo).

   dbo.sp_AjusteInventario  @idBodega, @idRepuesto, @cantidad INT (+/-), @idUsuario, @motivo
     -> conteo físico / corrección; movimiento origen AJUSTE con observación obligatoria

   dbo.sp_DevolverRepuesto  @idDetalleRepuesto, @idUsuario, @motivo     (opcional, R14)
     -> marca DetalleRepuesto como DEVUELTO, regresa stock, movimiento DEVOLUCION
   --------------------------------------------------------------------- */

SET NOEXEC OFF;
GO
