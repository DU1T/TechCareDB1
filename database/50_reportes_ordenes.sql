/* =====================================================================
   50_reportes_ordenes.sql  |  Dueño: BACKEND  |  Reportes 1, 2, 3, 4
   ---------------------------------------------------------------------
   Cada reporte = un SP dbo.sp_Reporte_NN_<Nombre> con parámetros de filtro
   opcionales (@fechaInicio, @fechaFin, @idCliente, @idTecnico, @idBodega...).
   Reglas del enunciado (5.1): sin SELECT *, sin DISTINCT para tapar duplicados,
   alias legibles, LEFT JOIN donde la información es opcional.
   Patrón de filtro opcional:  WHERE (@idTecnico IS NULL OR d.idTecnico = @idTecnico)
   Ver la tabla de reportes en el plan, sección 7.
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

-- ============================================================
-- REPORTE 03: Historial tecnico de un equipo
-- Permite consultar todas las ordenes por numero de serie
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.sp_Reporte_03_HistorialEquipo
    @numeroSerie VARCHAR(60)
AS
BEGIN
    SET NOCOUNT ON;

    IF NULLIF(LTRIM(RTRIM(@numeroSerie)), '') IS NULL
    BEGIN
        ;THROW 50280,
            'Debe indicar el numero de serie del equipo.',
            1;
    END;

    SELECT
        h.numeroOrden,
        h.fechaIngreso,
        h.estado,
        h.prioridad,
        h.problemaReportado,
        h.diagnostico,
        h.tecnico,
        h.estadoReparacion,
        h.costoManoObra,
        h.fechaFin,
        h.serie,
        h.numero,
        h.totalFacturado
    FROM dbo.fn_HistorialEquipo(@numeroSerie) AS h
    ORDER BY h.fechaIngreso DESC, h.numeroOrden DESC;
END;
GO

-- ============================================================
-- REPORTE 01: Ordenes activas
-- Filtros opcionales: estado, prioridad y tecnico
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.sp_Reporte_01_OrdenesActivas
    @estado VARCHAR(25) = NULL,
    @prioridad VARCHAR(10) = NULL,
    @idTecnico INT = NULL
AS
BEGIN
    SET NOCOUNT ON;

    SELECT
        v.numeroOrden,
        v.fechaIngreso,
        v.diasAbierta,
        v.estado,
        v.estadoDescripcion,
        v.prioridad,
        v.cliente,
        v.nitCliente,
        v.tipoEquipo,
        v.marca,
        v.modelo,
        v.numeroSerie,
        v.recepcionista,
        v.tecnicoAsignado,
        v.fechaEstimada
    FROM dbo.vw_OrdenesActivas AS v
    WHERE (@estado IS NULL OR v.estado = @estado)
      AND (@prioridad IS NULL OR v.prioridad = @prioridad)
      AND (@idTecnico IS NULL OR v.idTecnicoAsignado = @idTecnico)
    ORDER BY
        CASE v.prioridad
            WHEN 'URGENTE' THEN 1
            WHEN 'ALTA' THEN 2
            WHEN 'MEDIA' THEN 3
            ELSE 4
        END,
        v.fechaIngreso;
END;
GO

-- ============================================================
-- REPORTE 02: Historial completo de un cliente
-- Filtros opcionales: idCliente o NIT
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.sp_Reporte_02_HistorialCliente
    @idCliente INT = NULL,
    @nit VARCHAR(15) = NULL
AS
BEGIN
    SET NOCOUNT ON;
        -- Tratar NIT vacio o con espacios como NULL
    SET @nit = NULLIF(LTRIM(RTRIM(@nit)), '');

    -- Se requiere al menos un criterio de busqueda
    IF @idCliente IS NULL AND
       NULLIF(LTRIM(RTRIM(@nit)), '') IS NULL
    BEGIN
        ;THROW 50281,
            'Debe indicar el ID del cliente o su NIT.',
            1;
    END;

    SELECT
        c.nombre AS cliente,
        c.nit,
        c.tipoCliente,

        e.numeroSerie,
        te.nombre AS tipoEquipo,
        m.nombre AS marca,
        e.modelo,

        o.numeroOrden,
        o.fechaIngreso,
        o.estado,

        d.descripcion AS diagnostico,
        tec.nombreCompleto AS tecnico,

        f.serie,
        f.numero,
        f.total AS totalFacturado

    FROM dbo.Cliente AS c

    LEFT JOIN dbo.Equipo AS e
        ON e.idCliente = c.idCliente

    LEFT JOIN dbo.TipoEquipo AS te
        ON te.idTipoEquipo = e.idTipoEquipo

    LEFT JOIN dbo.Marca AS m
        ON m.idMarca = e.idMarca

    LEFT JOIN dbo.OrdenServicio AS o
        ON o.idEquipo = e.idEquipo

    LEFT JOIN dbo.Diagnostico AS d
        ON d.idOrden = o.idOrden

    LEFT JOIN dbo.Usuario AS tec
        ON tec.idUsuario = d.idTecnico

    LEFT JOIN dbo.Factura AS f
        ON f.idOrden = o.idOrden
       AND f.estado = 'EMITIDA'

    WHERE (@idCliente IS NULL OR c.idCliente = @idCliente)
      AND (@nit IS NULL OR c.nit = @nit)

    ORDER BY o.fechaIngreso DESC, o.idOrden DESC;
END;
GO

-- ============================================================
-- REPORTE 04: Productividad por tecnico
-- Cada metrica se atribuye al tecnico que realizo el trabajo
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.sp_Reporte_04_ProductividadTecnico
    @idTecnico INT = NULL,
    @fechaInicio DATE = NULL,
    @fechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    -- Validar rango de fechas
    IF @fechaInicio IS NOT NULL
       AND @fechaFin IS NOT NULL
       AND @fechaInicio > @fechaFin
    BEGIN
        ;THROW 50282,
            'La fecha inicial no puede ser posterior a la fecha final.',
            1;
    END;

    SELECT
        u.idUsuario,
        u.nombreCompleto AS tecnico,

        dg.diagnosticos,
        rp.reparacionesFinalizadas,

        ISNULL(ac.horas, 0) AS horasRegistradas,
        ISNULL(rp.manoObra, 0) AS manoObraGenerada

    FROM dbo.Usuario AS u

    INNER JOIN dbo.UsuarioRol AS ur
        ON ur.idUsuario = u.idUsuario

    INNER JOIN dbo.Rol AS rol
        ON rol.idRol = ur.idRol
       AND rol.nombre = 'TECNICO'

    -- Diagnosticos: tecnico que realizo el diagnostico
    OUTER APPLY
    (
        SELECT
            COUNT(*) AS diagnosticos
        FROM dbo.Diagnostico AS d
        WHERE d.idTecnico = u.idUsuario
          AND (
                @fechaInicio IS NULL
                OR d.fechaDiagnostico >= @fechaInicio
          )
          AND (
                @fechaFin IS NULL
                OR d.fechaDiagnostico <
                    DATEADD(DAY, 1, @fechaFin)
          )
    ) AS dg

    -- Reparaciones: tecnico que realizo la reparacion
    OUTER APPLY
    (
        SELECT
            COUNT(*) AS reparacionesFinalizadas,
            SUM(r.costoManoObra) AS manoObra
        FROM dbo.Reparacion AS r
        WHERE r.idTecnico = u.idUsuario
          AND r.estado = 'FINALIZADA'
          AND (
                @fechaInicio IS NULL
                OR r.fechaFin >= @fechaInicio
          )
          AND (
                @fechaFin IS NULL
                OR r.fechaFin <
                    DATEADD(DAY, 1, @fechaFin)
          )
    ) AS rp

    -- Actividades: tecnico que registro las horas
    OUTER APPLY
    (
        SELECT
            SUM(a.horas) AS horas
        FROM dbo.ActividadReparacion AS a
        WHERE a.idTecnico = u.idUsuario
          AND (
                @fechaInicio IS NULL
                OR a.fechaActividad >= @fechaInicio
          )
          AND (
                @fechaFin IS NULL
                OR a.fechaActividad <
                    DATEADD(DAY, 1, @fechaFin)
          )
    ) AS ac

    WHERE
        (@idTecnico IS NULL OR u.idUsuario = @idTecnico)

    ORDER BY
        rp.reparacionesFinalizadas DESC,
        u.nombreCompleto;
END;
GO

SET NOEXEC OFF;
GO
