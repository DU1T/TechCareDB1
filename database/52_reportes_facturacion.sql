/* =====================================================================
   52_reportes_facturacion.sql  |  Dueño: FRONTEND  |  Reportes 10, 11, 12 (trazabilidad)
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
-- REPORTE 10: Facturas con saldo (cuentas por cobrar)
-- Filtros opcionales: solo con saldo, cliente y rango de fechas de emisión.
-- Devuelve DOS conjuntos de resultados, en este orden:
--   1) una fila por factura (desde vw_FacturasSaldo, sin JOIN con Pago)
--   2) el detalle de pagos de esas mismas facturas
-- Los pagos van aparte: unidos a la factura, una con 3 pagos saldría 3 veces.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_Reporte_10_FacturasSaldo
    @soloConSaldo BIT  = 1,
    @idCliente    INT  = NULL,
    @fechaInicio  DATE = NULL,
    @fechaFin     DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @fechaInicio IS NOT NULL AND @fechaFin IS NOT NULL AND @fechaInicio > @fechaFin
        THROW 50325, 'La fecha inicial no puede ser posterior a la fecha final.', 1;

    -- Las facturas que cumplen los filtros: ambos resultados salen de esta misma lista
    DECLARE @facturas TABLE (idFactura INT NOT NULL PRIMARY KEY);

    INSERT INTO @facturas (idFactura)
    SELECT v.idFactura
    FROM dbo.vw_FacturasSaldo AS v
    WHERE v.estadoFactura = 'EMITIDA'
      AND (@soloConSaldo = 0 OR v.saldo > 0)
      AND (@idCliente IS NULL OR v.idCliente = @idCliente)
      AND (@fechaInicio IS NULL OR v.fechaEmision >= @fechaInicio)
      AND (@fechaFin    IS NULL OR v.fechaEmision <  DATEADD(DAY, 1, @fechaFin));

    -- 1) Facturas
    SELECT v.numeroFactura,
           v.fechaEmision,
           v.numeroOrden,
           v.cliente,
           v.nitFacturacion,
           v.total,
           v.totalPagado,
           v.saldo,
           v.estadoPago
    FROM dbo.vw_FacturasSaldo AS v
    INNER JOIN @facturas AS fl ON fl.idFactura = v.idFactura
    ORDER BY v.saldo DESC, v.fechaEmision, v.idFactura;

    -- 2) Pagos de esas facturas
    SELECT v.numeroFactura,
           p.fechaPago,
           mp.nombre          AS metodoPago,
           p.monto,
           p.referencia,
           p.estado           AS estadoPago,
           u.nombreCompleto   AS cajero,
           p.motivoAnulacion
    FROM @facturas AS fl
    INNER JOIN dbo.vw_FacturasSaldo AS v ON v.idFactura = fl.idFactura
    INNER JOIN dbo.Pago        AS p  ON p.idFactura     = fl.idFactura
    INNER JOIN dbo.MetodoPago  AS mp ON mp.idMetodoPago = p.idMetodoPago
    INNER JOIN dbo.Usuario     AS u  ON u.idUsuario     = p.idUsuarioCaja
    ORDER BY v.fechaEmision, v.idFactura, p.fechaPago, p.idPago;
END;
GO

-- ============================================================
-- REPORTE 11: Ingresos por periodo (mes a mes), separando mano de obra y repuestos
-- Filtros opcionales: rango de fechas de emisión (el último día se incluye completo).
-- Las líneas (DetalleFactura) y las cabeceras (Factura) se resumen por separado y se unen
-- por mes: si el impuesto se sumara después de unir con las líneas, se multiplicaría por
-- el número de líneas de cada factura.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_Reporte_11_IngresosPeriodo
    @fechaInicio DATE = NULL,
    @fechaFin    DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;

    IF @fechaInicio IS NOT NULL AND @fechaFin IS NOT NULL AND @fechaInicio > @fechaFin
        THROW 50325, 'La fecha inicial no puede ser posterior a la fecha final.', 1;

    WITH lineas AS (
        SELECT YEAR(f.fechaEmision)  AS anio,
               MONTH(f.fechaEmision) AS mes,
               SUM(CASE WHEN df.tipoLinea = 'MANO_OBRA' THEN df.subtotalLinea ELSE 0 END) AS ingresoManoObra,
               SUM(CASE WHEN df.tipoLinea = 'REPUESTO'  THEN df.subtotalLinea ELSE 0 END) AS ingresoRepuestos
        FROM dbo.Factura AS f
        INNER JOIN dbo.DetalleFactura AS df ON df.idFactura = f.idFactura
        WHERE f.estado = 'EMITIDA'
          AND (@fechaInicio IS NULL OR f.fechaEmision >= @fechaInicio)
          AND (@fechaFin    IS NULL OR f.fechaEmision <  DATEADD(DAY, 1, @fechaFin))
        GROUP BY YEAR(f.fechaEmision), MONTH(f.fechaEmision)
    ),
    cabeceras AS (
        SELECT YEAR(f.fechaEmision)  AS anio,
               MONTH(f.fechaEmision) AS mes,
               COUNT(*)              AS facturas,
               SUM(f.subtotal)       AS subtotal,
               SUM(f.impuesto)       AS impuesto,
               SUM(f.total)          AS total
        FROM dbo.Factura AS f
        WHERE f.estado = 'EMITIDA'
          AND (@fechaInicio IS NULL OR f.fechaEmision >= @fechaInicio)
          AND (@fechaFin    IS NULL OR f.fechaEmision <  DATEADD(DAY, 1, @fechaFin))
        GROUP BY YEAR(f.fechaEmision), MONTH(f.fechaEmision)
    )
    SELECT c.anio,
           c.mes,
           CONCAT(c.anio, '-', RIGHT('0' + CAST(c.mes AS VARCHAR(2)), 2)) AS periodo,
           c.facturas,
           l.ingresoManoObra,
           l.ingresoRepuestos,
           c.subtotal,
           c.impuesto,
           c.total
    FROM cabeceras AS c
    INNER JOIN lineas AS l ON l.anio = c.anio AND l.mes = c.mes
    ORDER BY c.anio, c.mes;
END;
GO

-- ============================================================
-- REPORTE 12: Trazabilidad completa de una orden
-- Devuelve CINCO conjuntos de resultados, en este orden:
--   1) encabezado (una fila): orden, cliente, equipo, diagnóstico, reparación, factura y entrega
--   2) repuestos usados (precio histórico)
--   3) movimientos de inventario de esos repuestos
--   4) pagos
--   5) historial de estados
-- Una orden tiene varios repuestos Y varios pagos. Unidos en un solo SELECT, cada repuesto se
-- repetiría por cada pago (producto cartesiano) y los totales saldrían inflados; DISTINCT no lo
-- arregla (oculta el error y puede borrar filas legítimas). La solución es una consulta por
-- cada relación de uno a muchos. El encabezado sí usa un solo SELECT porque todas sus uniones
-- son de uno a uno (UQ por orden en Diagnostico, Reparacion, Factura y Entrega), con LEFT JOIN
-- porque cada etapa puede no haber ocurrido todavía.
-- ============================================================
CREATE OR ALTER PROCEDURE dbo.sp_Reporte_12_Trazabilidad
    @idOrden INT
AS
BEGIN
    SET NOCOUNT ON;

    IF @idOrden IS NULL
        THROW 50326, 'Debe indicar la orden.', 1;

    IF NOT EXISTS (SELECT 1 FROM dbo.OrdenServicio WHERE idOrden = @idOrden)
        THROW 50327, 'La orden no existe.', 1;

    -- 1) Encabezado
    SELECT o.numeroOrden,
           o.fechaIngreso,
           o.estado,
           o.prioridad,
           o.problemaReportado,
           c.nombre                 AS cliente,
           c.nit                    AS nitCliente,
           te.nombre                AS tipoEquipo,
           m.nombre                 AS marca,
           e.modelo,
           e.numeroSerie,
           recep.nombreCompleto     AS recepcionista,
           d.fechaDiagnostico,
           d.descripcion            AS diagnostico,
           tdiag.nombreCompleto     AS tecnicoDiagnostico,
           d.costoManoObraEstimado,
           CASE d.autorizado WHEN 1 THEN 'AUTORIZADO'
                             WHEN 0 THEN 'RECHAZADO'
                             ELSE CASE WHEN d.idDiagnostico IS NULL THEN NULL ELSE 'PENDIENTE' END
           END                      AS respuestaCliente,
           r.fechaInicio            AS inicioReparacion,
           r.fechaFin               AS finReparacion,
           r.estado                 AS estadoReparacion,
           r.descripcionTrabajo,
           trep.nombreCompleto      AS tecnicoReparacion,
           r.costoManoObra,
           CASE WHEN f.idFactura IS NULL THEN NULL
                ELSE CONCAT(f.serie, '-', RIGHT('000000' + CAST(f.numero AS VARCHAR(10)), 6)) END AS numeroFactura,
           f.fechaEmision,
           f.subtotal,
           f.impuesto,
           f.total,
           CASE WHEN f.idFactura IS NULL THEN NULL ELSE dbo.fn_TotalPagado(f.idFactura)  END AS totalPagado,
           CASE WHEN f.idFactura IS NULL THEN NULL ELSE dbo.fn_SaldoFactura(f.idFactura) END AS saldo,
           en.fechaEntrega,
           en.nombreRecibe,
           uent.nombreCompleto      AS entregadoPor
    FROM dbo.OrdenServicio AS o
    INNER JOIN dbo.Equipo       AS e     ON e.idEquipo      = o.idEquipo
    INNER JOIN dbo.Cliente      AS c     ON c.idCliente     = e.idCliente
    INNER JOIN dbo.TipoEquipo   AS te    ON te.idTipoEquipo = e.idTipoEquipo
    INNER JOIN dbo.Marca        AS m     ON m.idMarca       = e.idMarca
    INNER JOIN dbo.Usuario      AS recep ON recep.idUsuario = o.idUsuarioRecepcion
    LEFT  JOIN dbo.Diagnostico  AS d     ON d.idOrden       = o.idOrden
    LEFT  JOIN dbo.Usuario      AS tdiag ON tdiag.idUsuario = d.idTecnico
    LEFT  JOIN dbo.Reparacion   AS r     ON r.idDiagnostico = d.idDiagnostico
    LEFT  JOIN dbo.Usuario      AS trep  ON trep.idUsuario  = r.idTecnico
    LEFT  JOIN dbo.Factura      AS f     ON f.idOrden       = o.idOrden
    LEFT  JOIN dbo.Entrega      AS en    ON en.idOrden      = o.idOrden
    LEFT  JOIN dbo.Usuario      AS uent  ON uent.idUsuario  = en.idUsuarioEntrega
    WHERE o.idOrden = @idOrden;

    -- 2) Repuestos usados, con el precio histórico (R09)
    SELECT b.nombre                                    AS bodega,
           rp.codigo,
           rp.nombre                                   AS repuesto,
           dr.cantidad,
           dr.precioUnitario,
           CAST(dr.cantidad * dr.precioUnitario AS DECIMAL(12,2)) AS subtotal,
           dr.estado,
           dr.fechaRegistro,
           u.nombreCompleto                            AS registradoPor
    FROM dbo.Diagnostico AS d
    INNER JOIN dbo.Reparacion      AS r  ON r.idDiagnostico = d.idDiagnostico
    INNER JOIN dbo.DetalleRepuesto AS dr ON dr.idReparacion = r.idReparacion
    INNER JOIN dbo.Bodega          AS b  ON b.idBodega      = dr.idBodega
    INNER JOIN dbo.Repuesto        AS rp ON rp.idRepuesto   = dr.idRepuesto
    INNER JOIN dbo.Usuario         AS u  ON u.idUsuario     = dr.idUsuario
    WHERE d.idOrden = @idOrden
    ORDER BY dr.idDetalleRepuesto;

    -- 3) Movimientos de inventario que esos repuestos generaron
    SELECT mv.fechaMovimiento,
           mv.tipo,
           mv.origen,
           mv.bodega,
           mv.codigo,
           mv.repuesto,
           mv.cantidad,
           mv.existenciaAnterior,
           mv.existenciaResultante,
           mv.usuario
    FROM dbo.vw_MovimientosInventario AS mv
    WHERE mv.idOrden = @idOrden
    ORDER BY mv.fechaMovimiento, mv.idMovimiento;

    -- 4) Pagos de la factura de la orden (aplicados y anulados)
    SELECT p.fechaPago,
           mp.nombre         AS metodoPago,
           p.monto,
           p.referencia,
           p.estado,
           u.nombreCompleto  AS cajero,
           p.motivoAnulacion
    FROM dbo.Factura AS f
    INNER JOIN dbo.Pago       AS p  ON p.idFactura     = f.idFactura
    INNER JOIN dbo.MetodoPago AS mp ON mp.idMetodoPago = p.idMetodoPago
    INNER JOIN dbo.Usuario    AS u  ON u.idUsuario     = p.idUsuarioCaja
    WHERE f.idOrden = @idOrden
    ORDER BY p.fechaPago, p.idPago;

    -- 5) Historial de estados (si el cambio se hizo directo en la base, sale el usuario de la base)
    SELECT h.estadoAnterior,
           h.estadoNuevo,
           h.fechaCambio,
           COALESCE(u.nombreCompleto, h.usuarioBD) AS usuario,
           h.observacion
    FROM dbo.HistorialEstadoOrden AS h
    LEFT JOIN dbo.Usuario AS u ON u.idUsuario = h.idUsuario
    WHERE h.idOrden = @idOrden
    ORDER BY h.fechaCambio, h.idHistorial;
END;
GO

SET NOEXEC OFF;
GO
