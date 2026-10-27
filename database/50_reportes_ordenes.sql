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
-- Filtros opcionales: tecnico y rango de fechas
-- ============================================================

CREATE OR ALTER PROCEDURE dbo.sp_Reporte_04_ProductividadTecnico
    @idTecnico INT = NULL,
    @fechaInicio DATE = NULL,
    @fechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

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

        COUNT(d.idDiagnostico) AS diagnosticos,

        SUM(
            CASE
                WHEN r.estado = 'FINALIZADA' THEN 1
                ELSE 0
            END
        ) AS reparacionesFinalizadas,

        SUM(ISNULL(act.horas, 0)) AS horasRegistradas,

        SUM(
            CASE
                WHEN r.estado = 'FINALIZADA'
                    THEN r.costoManoObra
                ELSE 0
            END
        ) AS manoObraGenerada

    FROM dbo.Usuario AS u

    INNER JOIN dbo.UsuarioRol AS ur
        ON ur.idUsuario = u.idUsuario

    INNER JOIN dbo.Rol AS rol
        ON rol.idRol = ur.idRol
       AND rol.nombre = 'TECNICO'

    LEFT JOIN dbo.Diagnostico AS d
        ON d.idTecnico = u.idUsuario
       AND (
            @fechaInicio IS NULL
            OR d.fechaDiagnostico >= @fechaInicio
       )
       AND (
            @fechaFin IS NULL
            OR d.fechaDiagnostico <
                DATEADD(DAY, 1, @fechaFin)
       )

    LEFT JOIN dbo.Reparacion AS r
        ON r.idDiagnostico = d.idDiagnostico

    LEFT JOIN
    (
        SELECT
            a.idReparacion,
            SUM(a.horas) AS horas
        FROM dbo.ActividadReparacion AS a
        GROUP BY a.idReparacion
    ) AS act
        ON act.idReparacion = r.idReparacion

    WHERE
        (@idTecnico IS NULL OR u.idUsuario = @idTecnico)

    GROUP BY
        u.idUsuario,
        u.nombreCompleto

    ORDER BY
        reparacionesFinalizadas DESC,
        tecnico;
END;
GO

SET NOEXEC OFF;
GO
