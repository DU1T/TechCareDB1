/* =====================================================================
   20_vistas_ordenes.sql  |  Dueño: BACKEND  |  Vistas del dominio órdenes
   ---------------------------------------------------------------------
   vw_OrdenesActivas = vista de REFERENCIA (ya hecha, adaptada de la clase 1).
   Fíjese en: Usuario aparece 2 veces con alias distintos (recepcionista / tecnico)
   y LEFT JOIN al técnico porque la orden existe antes de asignarlo.
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
CREATE OR ALTER VIEW dbo.vw_OrdenesActivas
AS
SELECT
    o.idOrden,
    o.numeroOrden,
    o.fechaIngreso,
    o.fechaEstimada,
    o.prioridad,
    o.estado,
    eo.descripcion                         AS estadoDescripcion,
    c.idCliente,
    c.nombre                               AS cliente,
    c.nit                                  AS nitCliente,
    e.idEquipo,
    te.nombre                              AS tipoEquipo,
    m.nombre                               AS marca,
    e.modelo,
    e.numeroSerie,
    o.problemaReportado,
    recep.nombreCompleto                   AS recepcionista,
    o.idTecnicoAsignado,
    tec.nombreCompleto                     AS tecnicoAsignado,
    DATEDIFF(DAY, o.fechaIngreso, SYSDATETIME()) AS diasAbierta
FROM dbo.OrdenServicio o
INNER JOIN dbo.EstadoOrden eo ON eo.codigo = o.estado
INNER JOIN dbo.Equipo e       ON e.idEquipo = o.idEquipo
INNER JOIN dbo.Cliente c      ON c.idCliente = e.idCliente
INNER JOIN dbo.TipoEquipo te  ON te.idTipoEquipo = e.idTipoEquipo
INNER JOIN dbo.Marca m        ON m.idMarca = e.idMarca
INNER JOIN dbo.Usuario recep  ON recep.idUsuario = o.idUsuarioRecepcion
LEFT  JOIN dbo.Usuario tec    ON tec.idUsuario = o.idTecnicoAsignado
WHERE eo.esFinal = 0;
GO

-- ============================================================
-- PASO 116: fn_HistorialEquipo
-- Historial tecnico de un equipo por numero de serie
-- ============================================================

CREATE OR ALTER FUNCTION dbo.fn_HistorialEquipo
(
    @numeroSerie VARCHAR(60)
)
RETURNS TABLE
AS
RETURN
(
    SELECT
        o.idOrden,
        o.numeroOrden,
        o.fechaIngreso,
        o.estado,
        o.prioridad,
        o.problemaReportado,

        d.descripcion AS diagnostico,
        tec.nombreCompleto AS tecnico,

        r.estado AS estadoReparacion,
        r.costoManoObra,
        r.fechaFin,

        f.serie,
        f.numero,
        f.total AS totalFacturado

    FROM dbo.Equipo AS e

    INNER JOIN dbo.OrdenServicio AS o
        ON o.idEquipo = e.idEquipo

    LEFT JOIN dbo.Diagnostico AS d
        ON d.idOrden = o.idOrden

    LEFT JOIN dbo.Usuario AS tec
        ON tec.idUsuario = d.idTecnico

    LEFT JOIN dbo.Reparacion AS r
        ON r.idDiagnostico = d.idDiagnostico

    LEFT JOIN dbo.Factura AS f
        ON f.idOrden = o.idOrden
       AND f.estado = 'EMITIDA'

    WHERE e.numeroSerie = @numeroSerie
);
GO

SET NOEXEC OFF;
GO
