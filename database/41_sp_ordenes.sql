/* =====================================================================
   41_sp_ordenes.sql  |  Dueño: BACKEND  |  Órdenes, diagnóstico, reparación
   ---------------------------------------------------------------------
   Códigos de error: 50200-50299.  Use sp_CambiarEstadoOrden y sp_UtilizarRepuesto
   como plantilla. Recuerde: dentro de su transacción, para cambiar el estado use
     EXEC dbo.sp_EstablecerContexto @idUsuario, N'observación';
     UPDATE dbo.OrdenServicio SET estado = 'X' WHERE idOrden = @idOrden;
   (NO llame a sp_CambiarEstadoOrden desde otro SP transaccional.)
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
-- sp_RegistrarOrdenServicio: procedimiento modelo de este dominio (mismo código que la guía y el plan).
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarOrdenServicio
    @idEquipo            INT,
    @idUsuarioRecepcion  INT,
    @problemaReportado   NVARCHAR(500),
    @prioridad           VARCHAR(10)   = 'MEDIA',
    @fechaEstimada       DATE          = NULL,
    @observaciones       NVARCHAR(500) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF dbo.fn_UsuarioTieneRol(@idUsuarioRecepcion, 'RECEPCION') = 0
        THROW 50201, 'El usuario no tiene rol de recepción.', 1;

    IF NULLIF(LTRIM(RTRIM(@problemaReportado)), N'') IS NULL
        THROW 50202, 'Debe describir el problema reportado.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        -- Bloquea el equipo: dos recepcionistas no pueden abrirle orden al mismo tiempo
        IF NOT EXISTS (
            SELECT 1
            FROM dbo.Equipo e WITH (UPDLOCK, HOLDLOCK)
            INNER JOIN dbo.Cliente c ON c.idCliente = e.idCliente
            WHERE e.idEquipo = @idEquipo
              AND e.estado = 'ACTIVO'
              AND c.estado = 'ACTIVO')
            THROW 50203, 'El equipo no existe, no está activo o su cliente está inactivo.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.OrdenServicio o
            INNER JOIN dbo.EstadoOrden eo ON eo.codigo = o.estado
            WHERE o.idEquipo = @idEquipo
              AND eo.esFinal = 0)
            THROW 50204, 'El equipo ya tiene una orden abierta.', 1;

        EXEC dbo.sp_EstablecerContexto @idUsuario = @idUsuarioRecepcion, @observacion = N'Orden registrada';

        INSERT INTO dbo.OrdenServicio
            (idEquipo, idUsuarioRecepcion, problemaReportado, prioridad, fechaEstimada, observaciones)
        VALUES
            (@idEquipo, @idUsuarioRecepcion, @problemaReportado, @prioridad, @fechaEstimada, @observaciones);

        -- SCOPE_IDENTITY y no @@IDENTITY: el trigger inserta en HistorialEstadoOrden,
        -- y @@IDENTITY devolvería el id del historial, no el de la orden.
        DECLARE @idOrden INT = CAST(SCOPE_IDENTITY() AS INT);

        COMMIT TRANSACTION;
        EXEC dbo.sp_EstablecerContexto @idUsuario = NULL, @observacion = NULL;

        SELECT o.idOrden, o.numeroOrden
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

-- ============================================================
-- sp_RegistrarDiagnostico
-- Registra el diagnostico tecnico de una orden de servicio.
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.sp_RegistrarDiagnostico
    @idOrden INT,
    @idTecnico INT,
    @descripcion NVARCHAR(1000),
    @costoManoObraEstimado DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    -- 1. Validar los parametros recibidos
    IF @idOrden IS NULL OR @idOrden <= 0
        THROW 50210, 'El identificador de la orden no es valido.', 1;

    IF @idTecnico IS NULL OR @idTecnico <= 0
        THROW 50211, 'El identificador del tecnico no es valido.', 1;

    IF NULLIF(LTRIM(RTRIM(@descripcion)), N'') IS NULL
        THROW 50212, 'Debe ingresar una descripcion del diagnostico.', 1;

    IF @costoManoObraEstimado IS NULL
       OR @costoManoObraEstimado < 0
        THROW 50213, 'El costo estimado debe ser mayor o igual a cero.', 1;

    -- 2. Validar que el usuario tenga rol TECNICO
    IF ISNULL(dbo.fn_UsuarioTieneRol(@idTecnico, 'TECNICO'), 0) = 0
        THROW 50214, 'El usuario no tiene rol TECNICO.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estadoActual VARCHAR(25);
        DECLARE @idDiagnostico INT;

        -- 3. Consultar y bloquear la orden
        SELECT @estadoActual = estado
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE idOrden = @idOrden;

        IF @estadoActual IS NULL
            THROW 50215, 'La orden de servicio no existe.', 1;

        -- Solo se admiten estos dos estados
        IF @estadoActual NOT IN ('RECIBIDO', 'DIAGNOSTICO')
            THROW 50216, 'La orden no permite registrar un diagnostico.', 1;

        -- 4. Evitar diagnosticos duplicados
        IF EXISTS (
            SELECT 1
            FROM dbo.Diagnostico
            WHERE idOrden = @idOrden
        )
            THROW 50217, 'La orden ya tiene un diagnostico registrado.', 1;

        -- 5. Insertar el diagnostico
        INSERT INTO dbo.Diagnostico (
            idOrden,
            idTecnico,
            descripcion,
            costoManoObraEstimado
        )
        VALUES (
            @idOrden,
            @idTecnico,
            @descripcion,
            @costoManoObraEstimado
        );

        SET @idDiagnostico = CAST(SCOPE_IDENTITY() AS INT);

        -- 6. Asignar el tecnico si todavia no existe asignacion
        UPDATE dbo.OrdenServicio
        SET idTecnicoAsignado = @idTecnico
        WHERE idOrden = @idOrden
          AND idTecnicoAsignado IS NULL;

        -- 7. Pasar de RECIBIDO a DIAGNOSTICO cuando corresponda
        IF @estadoActual = 'RECIBIDO'
        BEGIN
            EXEC dbo.sp_EstablecerContexto
                @idUsuario = @idTecnico,
                @observacion = N'Inicio del diagnostico tecnico';

            UPDATE dbo.OrdenServicio
            SET estado = 'DIAGNOSTICO'
            WHERE idOrden = @idOrden
              AND estado = 'RECIBIDO';

            IF @@ROWCOUNT <> 1
                THROW 50218, 'No se pudo iniciar el diagnostico.', 1;
        END;

        -- 8. Pasar a ESPERANDO_AUTORIZACION
        EXEC dbo.sp_EstablecerContexto
            @idUsuario = @idTecnico,
            @observacion = N'Diagnostico registrado; pendiente de autorizacion';

        UPDATE dbo.OrdenServicio
        SET estado = 'ESPERANDO_AUTORIZACION'
        WHERE idOrden = @idOrden
          AND estado = 'DIAGNOSTICO';

        IF @@ROWCOUNT <> 1
            THROW 50219, 'No se pudo actualizar el estado final.', 1;

        -- 9. Confirmar todos los cambios
        COMMIT TRANSACTION;

        -- Limpiar el contexto de la sesion
        EXEC dbo.sp_EstablecerContexto
            @idUsuario = NULL,
            @observacion = NULL;

        -- 10. Devolver el resultado
        SELECT
            @idDiagnostico AS idDiagnostico,
            @idOrden AS idOrden,
            'ESPERANDO_AUTORIZACION' AS estado,
            N'Diagnostico registrado correctamente' AS mensaje;

    END TRY
    BEGIN CATCH
        -- Revertir todo si ocurre un error
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        EXEC dbo.sp_EstablecerContexto
            @idUsuario = NULL,
            @observacion = NULL;

        THROW;
    END CATCH;
END;
GO









/* ---------------------------------------------------------------------
   HECHO dbo.sp_RegistrarOrdenServicio (arriba, modelo).

   HECHO dbo.sp_RegistrarDiagnostico                          (T03)
       @idOrden, @idTecnico, @descripcion NVARCHAR(1000), @costoManoObraEstimado DECIMAL(12,2)
     -> rol TECNICO; orden en RECIBIDO o DIAGNOSTICO; sin diagnóstico previo
     -> INSERT Diagnostico; asigna idTecnicoAsignado si está NULL
     -> si estaba en RECIBIDO pasa a DIAGNOSTICO y luego a ESPERANDO_AUTORIZACION (2 UPDATE => 2 filas de historial)

   TODO dbo.sp_RegistrarAutorizacionCliente
       @idOrden, @autorizado BIT, @idUsuario
     -> diagnóstico pendiente (autorizado IS NULL); guarda respuesta y fecha
     -> autorizado = 0 => orden a LISTO (se devuelve sin reparar)

   TODO dbo.sp_IniciarReparacion                              (R04)
       @idOrden, @idTecnico
     -> rol TECNICO; diagnóstico existe y autorizado = 1; orden en ESPERANDO_AUTORIZACION
     -> INSERT Reparacion (EN_PROCESO) + orden a REPARACION

   TODO dbo.sp_RegistrarActividad
       @idReparacion, @idTecnico, @descripcion, @horas
     -> numeroActividad = MAX+1 de esa reparación (con UPDLOCK)

   TODO dbo.sp_FinalizarReparacion
       @idReparacion, @idTecnico, @descripcionTrabajo NVARCHAR(1000), @costoManoObra DECIMAL(12,2)
     -> reparación EN_PROCESO; fechaFin = SYSDATETIME(); estado FINALIZADA
     -> orden a LISTO
   --------------------------------------------------------------------- */

SET NOEXEC OFF;
GO
