/* =====================================================================
   40_sp_comunes.sql  |  NÚCLEO (defiende: BACKEND)
   ---------------------------------------------------------------------
   Convención de códigos de error (THROW) para no chocar entre integrantes:
     50000-50099  núcleo / comunes
     50100-50199  inventario y compras      (Fullstack/Infra)
     50200-50299  órdenes, diagnóstico, reparación (Backend)
     50300-50399  facturación, pagos, entrega (Frontend)
     51000-51099  triggers
   El backend traduce 50000-51099 a HTTP 409/422 con el mensaje tal cual.

   Patrón obligatorio para SP con transacción (clase 1):
     SET XACT_ABORT ON; BEGIN TRY BEGIN TRAN ... COMMIT END TRY
     BEGIN CATCH IF @@TRANCOUNT > 0 ROLLBACK; THROW; END CATCH
   Regla del equipo: un SP transaccional NO llama a otro SP transaccional
   (evita transacciones anidadas). Para cambiar estado dentro de otro proceso:
   EXEC dbo.sp_EstablecerContexto ...; UPDATE OrdenServicio SET estado = ...
   y el trigger valida + audita.
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
-- Guarda usuario y observación en la sesión para que los triggers los lean.
-- No abre transacción: se puede llamar desde cualquier SP.
CREATE OR ALTER PROCEDURE dbo.sp_EstablecerContexto
    @idUsuario   INT,
    @observacion NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    EXEC sys.sp_set_session_context @key = N'idUsuario',   @value = @idUsuario;
    EXEC sys.sp_set_session_context @key = N'observacion', @value = @observacion;
END;
GO

-- Cambio manual de estado desde la UI (ej. cancelar, pasar a DIAGNOSTICO).
-- La validación de la transición y el historial los hace el trigger.
CREATE OR ALTER PROCEDURE dbo.sp_CambiarEstadoOrden
    @idOrden      INT,
    @estadoNuevo  VARCHAR(25),
    @idUsuario    INT,
    @observacion  NVARCHAR(300) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF NOT EXISTS (SELECT 1 FROM dbo.Usuario WHERE idUsuario = @idUsuario AND estado = 'ACTIVO')
        THROW 50001, 'Usuario inválido o inactivo.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.EstadoOrden WHERE codigo = @estadoNuevo)
        THROW 50002, 'El estado destino no existe.', 1;

    IF @estadoNuevo = 'CANCELADO' AND NULLIF(LTRIM(RTRIM(@observacion)), N'') IS NULL
        THROW 50003, 'Para cancelar una orden debe indicar el motivo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estadoActual VARCHAR(25);

        -- UPDLOCK: nadie más cambia esta orden hasta el COMMIT
        SELECT @estadoActual = o.estado
        FROM dbo.OrdenServicio o WITH (UPDLOCK, ROWLOCK)
        WHERE o.idOrden = @idOrden;

        IF @estadoActual IS NULL
            THROW 50004, 'La orden no existe.', 1;

        IF @estadoActual = @estadoNuevo
            THROW 50005, 'La orden ya se encuentra en ese estado.', 1;

        EXEC dbo.sp_EstablecerContexto @idUsuario = @idUsuario, @observacion = @observacion;

        UPDATE dbo.OrdenServicio
           SET estado = @estadoNuevo
         WHERE idOrden = @idOrden;              -- el trigger valida y registra historial

        COMMIT TRANSACTION;

        EXEC dbo.sp_EstablecerContexto @idUsuario = NULL, @observacion = NULL;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        EXEC dbo.sp_EstablecerContexto @idUsuario = NULL, @observacion = NULL;
        THROW;
    END CATCH;
END;
GO

SET NOEXEC OFF;
GO
