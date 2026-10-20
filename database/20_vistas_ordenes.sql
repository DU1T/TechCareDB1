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

/* ---------------------------------------------------------------------
   TODO (Backend):
   - dbo.fn_HistorialEquipo(@numeroSerie)  -> función de tabla en línea (inline TVF)
       una fila por orden del equipo: numeroOrden, fechaIngreso, estado, problema,
       diagnóstico (LEFT JOIN), técnico, costo mano de obra, total factura (LEFT JOIN).
       Base del reporte 3 y la prueba T11.
   --------------------------------------------------------------------- */

SET NOEXEC OFF;
GO
