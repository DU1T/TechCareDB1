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


-- ============================================================
-- sp_RegistrarAutorizacionCliente
-- Registra la respuesta del cliente al diagnostico.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarAutorizacionCliente
    @idOrden INT,
    @autorizado BIT,
    @idUsuario INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @idOrden IS NULL OR @idOrden <= 0
        THROW 50230, 'La orden indicada no es valida.', 1;

    IF @autorizado IS NULL
        THROW 50231, 'Debe indicar si el cliente autoriza.', 1;

    IF ISNULL(dbo.fn_UsuarioTieneRol(@idUsuario, 'RECEPCION'), 0) = 0
       AND ISNULL(dbo.fn_UsuarioTieneRol(@idUsuario, 'TECNICO'), 0) = 0
        THROW 50232, 'El usuario no puede registrar la respuesta del cliente.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado VARCHAR(25);
        DECLARE @idDiagnostico INT;
        DECLARE @respuesta BIT;

        SELECT @estado = estado
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE idOrden = @idOrden;

        IF @estado IS NULL
            THROW 50233, 'La orden no existe.', 1;

        IF @estado <> 'ESPERANDO_AUTORIZACION'
            THROW 50234, 'La orden no esta esperando autorizacion.', 1;

        SELECT
            @idDiagnostico = idDiagnostico,
            @respuesta = autorizado
        FROM dbo.Diagnostico WITH (UPDLOCK, HOLDLOCK)
        WHERE idOrden = @idOrden;

        IF @idDiagnostico IS NULL
            THROW 50235, 'La orden no tiene diagnostico.', 1;

        IF @respuesta IS NOT NULL
            THROW 50236, 'El cliente ya respondio al diagnostico.', 1;

        UPDATE dbo.Diagnostico
        SET autorizado = @autorizado,
            fechaRespuestaCliente = SYSDATETIME()
        WHERE idDiagnostico = @idDiagnostico;

        IF @autorizado = 0
        BEGIN
            EXEC dbo.sp_EstablecerContexto
                @idUsuario = @idUsuario,
                @observacion = N'Cliente rechazo la reparacion';

            UPDATE dbo.OrdenServicio
            SET estado = 'LISTO'
            WHERE idOrden = @idOrden
              AND estado = 'ESPERANDO_AUTORIZACION';

            IF @@ROWCOUNT <> 1
                THROW 50237, 'No se pudo registrar el rechazo.', 1;
        END;

        COMMIT TRANSACTION;

        EXEC dbo.sp_EstablecerContexto
            @idUsuario = NULL,
            @observacion = NULL;

        SELECT
            o.idOrden,
            o.estado,
            d.autorizado
        FROM dbo.OrdenServicio AS o
        INNER JOIN dbo.Diagnostico AS d
            ON d.idOrden = o.idOrden
        WHERE o.idOrden = @idOrden;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        EXEC dbo.sp_EstablecerContexto
            @idUsuario = NULL,
            @observacion = NULL;

        THROW;
    END CATCH;
END;
GO

-- ============================================================
-- sp_IniciarReparacion
-- Crea una reparacion cuando el cliente ha autorizado.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_IniciarReparacion
    @idOrden INT,
    @idTecnico INT
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @idOrden IS NULL OR @idOrden <= 0
        THROW 50240, 'La orden indicada no es valida.', 1;

    IF ISNULL(dbo.fn_UsuarioTieneRol(@idTecnico, 'TECNICO'), 0) = 0
        THROW 50241, 'El usuario no tiene rol TECNICO.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado VARCHAR(25);
        DECLARE @idDiagnostico INT;
        DECLARE @autorizado BIT;
        DECLARE @idReparacion INT;

        SELECT @estado = estado
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE idOrden = @idOrden;

        IF @estado IS NULL
            THROW 50242, 'La orden no existe.', 1;

        IF @estado <> 'ESPERANDO_AUTORIZACION'
            THROW 50243, 'La orden no permite iniciar reparacion.', 1;

        SELECT
            @idDiagnostico = idDiagnostico,
            @autorizado = autorizado
        FROM dbo.Diagnostico WITH (UPDLOCK, HOLDLOCK)
        WHERE idOrden = @idOrden;

        IF @idDiagnostico IS NULL
            THROW 50244, 'La orden no tiene diagnostico.', 1;

        IF ISNULL(@autorizado, 0) <> 1
            THROW 50245, 'El cliente no ha autorizado la reparacion.', 1;

        IF EXISTS (
            SELECT 1
            FROM dbo.Reparacion WITH (UPDLOCK, HOLDLOCK)
            WHERE idDiagnostico = @idDiagnostico
        )
            THROW 50246, 'Ya existe una reparacion para el diagnostico.', 1;

        INSERT INTO dbo.Reparacion
            (idDiagnostico, idTecnico)
        VALUES
            (@idDiagnostico, @idTecnico);

        SET @idReparacion = CAST(SCOPE_IDENTITY() AS INT);

        EXEC dbo.sp_EstablecerContexto
            @idUsuario = @idTecnico,
            @observacion = N'Reparacion iniciada';

        UPDATE dbo.OrdenServicio
        SET estado = 'REPARACION',
            idTecnicoAsignado = @idTecnico
        WHERE idOrden = @idOrden
          AND estado = 'ESPERANDO_AUTORIZACION';

        IF @@ROWCOUNT <> 1
            THROW 50247, 'No se pudo iniciar la reparacion.', 1;

        COMMIT TRANSACTION;

        EXEC dbo.sp_EstablecerContexto
            @idUsuario = NULL,
            @observacion = NULL;

        SELECT
            @idReparacion AS idReparacion,
            @idOrden AS idOrden,
            'EN_PROCESO' AS estadoReparacion,
            'REPARACION' AS estadoOrden;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        EXEC dbo.sp_EstablecerContexto
            @idUsuario = NULL,
            @observacion = NULL;

        THROW;
    END CATCH;
END;
GO


-- ============================================================
-- sp_RegistrarActividad
-- Registra actividades durante una reparacion.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_RegistrarActividad
    @idReparacion INT,
    @idTecnico INT,
    @descripcion NVARCHAR(300),
    @horas DECIMAL(5,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @idReparacion IS NULL OR @idReparacion <= 0
        THROW 50250, 'La reparacion indicada no es valida.', 1;

    IF ISNULL(dbo.fn_UsuarioTieneRol(@idTecnico, 'TECNICO'), 0) = 0
        THROW 50251, 'El usuario no tiene rol TECNICO.', 1;

    IF NULLIF(LTRIM(RTRIM(@descripcion)), N'') IS NULL
        THROW 50252, 'Debe describir la actividad realizada.', 1;

    IF @horas IS NULL OR @horas <= 0 OR @horas > 24
        THROW 50253, 'Las horas deben ser mayores que cero y maximo 24.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estado VARCHAR(12);
        DECLARE @numeroSiguiente INT;
        DECLARE @numeroActividad SMALLINT;

        -- Bloquear la reparacion serializa las actividades
        -- concurrentes sobre la misma reparacion.
        SELECT @estado = estado
        FROM dbo.Reparacion WITH (UPDLOCK, HOLDLOCK)
        WHERE idReparacion = @idReparacion;

        IF @estado IS NULL
            THROW 50254, 'La reparacion no existe.', 1;

        IF @estado <> 'EN_PROCESO'
            THROW 50255, 'La reparacion no esta en proceso.', 1;

        SELECT @numeroSiguiente =
            ISNULL(MAX(CAST(numeroActividad AS INT)), 0) + 1
        FROM dbo.ActividadReparacion WITH (UPDLOCK, HOLDLOCK)
        WHERE idReparacion = @idReparacion;

        IF @numeroSiguiente > 32767
            THROW 50256, 'Se alcanzo el limite de actividades.', 1;

        SET @numeroActividad = CAST(@numeroSiguiente AS SMALLINT);

        INSERT INTO dbo.ActividadReparacion
            (idReparacion, numeroActividad, idTecnico,
             descripcion, horas)
        VALUES
            (@idReparacion, @numeroActividad, @idTecnico,
             @descripcion, @horas);

        COMMIT TRANSACTION;

        SELECT
            @idReparacion AS idReparacion,
            @numeroActividad AS numeroActividad;
    END TRY
    BEGIN CATCH
        IF XACT_STATE() <> 0
            ROLLBACK TRANSACTION;

        THROW;
    END CATCH;
END;
GO

-- ============================================================
-- sp_FinalizarReparacion
-- Finaliza la reparacion y deja la orden LISTO.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_FinalizarReparacion
    @idReparacion INT,
    @idTecnico INT,
    @descripcionTrabajo NVARCHAR(1000),
    @costoManoObra DECIMAL(12,2)
AS
BEGIN
    SET NOCOUNT ON;
    SET XACT_ABORT ON;

    IF @idReparacion IS NULL OR @idReparacion <= 0
        THROW 50260, 'La reparacion indicada no es valida.', 1;

    IF ISNULL(dbo.fn_UsuarioTieneRol(@idTecnico, 'TECNICO'), 0) = 0
        THROW 50261, 'El usuario no tiene rol TECNICO.', 1;

    IF NULLIF(LTRIM(RTRIM(@descripcionTrabajo)), N'') IS NULL
        THROW 50262, 'Debe describir el trabajo realizado.', 1;

    IF @costoManoObra IS NULL OR @costoManoObra < 0
        THROW 50263, 'El costo de mano de obra no puede ser negativo.', 1;

    BEGIN TRY
        BEGIN TRANSACTION;

        DECLARE @estadoReparacion VARCHAR(12);
        DECLARE @idOrden INT;
        DECLARE @estadoOrden VARCHAR(25);

        -- Identificar la orden de la reparacion
        SELECT @idOrden = d.idOrden
        FROM dbo.Reparacion AS r
        INNER JOIN dbo.Diagnostico AS d
            ON d.idDiagnostico = r.idDiagnostico
        WHERE r.idReparacion = @idReparacion;

        IF @idOrden IS NULL
            THROW 50264, 'La reparacion no existe.', 1;

        -- Bloquear primero la orden
        SELECT @estadoOrden = estado
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE idOrden = @idOrden;

        IF @estadoOrden IS NULL OR @estadoOrden <> 'REPARACION'
            THROW 50266, 'La orden no esta en reparacion.', 1;

        -- Después bloquear la reparacion
        SELECT @estadoReparacion = estado
        FROM dbo.Reparacion WITH (UPDLOCK, HOLDLOCK)
        WHERE idReparacion = @idReparacion;

        IF @estadoReparacion IS NULL OR @estadoReparacion <> 'EN_PROCESO'
            THROW 50265, 'La reparacion no esta en proceso.', 1;

        IF @estadoReparacion IS NULL
            THROW 50264, 'La reparacion no existe.', 1;

        IF @estadoReparacion <> 'EN_PROCESO'
            THROW 50265, 'La reparacion no esta en proceso.', 1;

        SELECT @estadoOrden = estado
        FROM dbo.OrdenServicio WITH (UPDLOCK, HOLDLOCK)
        WHERE idOrden = @idOrden;

        IF @estadoOrden <> 'REPARACION' OR @estadoOrden IS NULL
            THROW 50266, 'La orden no esta en reparacion.', 1;

        UPDATE dbo.Reparacion
        SET estado = 'FINALIZADA',
            fechaFin = SYSDATETIME(),
            descripcionTrabajo = @descripcionTrabajo,
            costoManoObra = @costoManoObra
        WHERE idReparacion = @idReparacion
          AND estado = 'EN_PROCESO';

        IF @@ROWCOUNT <> 1
            THROW 50267, 'No se pudo finalizar la reparacion.', 1;

        EXEC dbo.sp_EstablecerContexto
            @idUsuario = @idTecnico,
            @observacion = N'Reparacion finalizada';

        UPDATE dbo.OrdenServicio
        SET estado = 'LISTO'
        WHERE idOrden = @idOrden
          AND estado = 'REPARACION';

        IF @@ROWCOUNT <> 1
            THROW 50268, 'No se pudo actualizar el estado de la orden.', 1;

        COMMIT TRANSACTION;

        EXEC dbo.sp_EstablecerContexto
            @idUsuario = NULL,
            @observacion = NULL;

        SELECT
            @idReparacion AS idReparacion,
            @idOrden AS idOrden,
            'FINALIZADA' AS estadoReparacion,
            'LISTO' AS estadoOrden;
    END TRY
    BEGIN CATCH
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

   HECHO dbo.sp_RegistrarAutorizacionCliente
       @idOrden, @autorizado BIT, @idUsuario
     -> diagnóstico pendiente (autorizado IS NULL); guarda respuesta y fecha
     -> autorizado = 0 => orden a LISTO (se devuelve sin reparar)

   HECHO dbo.sp_IniciarReparacion                              (R04)
       @idOrden, @idTecnico
     -> rol TECNICO; diagnóstico existe y autorizado = 1; orden en ESPERANDO_AUTORIZACION
     -> INSERT Reparacion (EN_PROCESO) + orden a REPARACION

   HECHO dbo.sp_RegistrarActividad
       @idReparacion, @idTecnico, @descripcion, @horas
     -> numeroActividad = MAX+1 de esa reparación (con UPDLOCK)

   HECHO dbo.sp_FinalizarReparacion
       @idReparacion, @idTecnico, @descripcionTrabajo NVARCHAR(1000), @costoManoObra DECIMAL(12,2)
     -> reparación EN_PROCESO; fechaFin = SYSDATETIME(); estado FINALIZADA
     -> orden a LISTO
   --------------------------------------------------------------------- */

SET NOEXEC OFF;
GO
