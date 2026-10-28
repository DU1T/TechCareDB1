/* =====================================================================
   22_vistas_facturacion.sql  |  Dueño: FRONTEND
   ---------------------------------------------------------------------
   vw_FacturasSaldo    reporte 10 y dashboard. Una fila por factura. NO se une con Pago:
                       una factura con 3 pagos saldría 3 veces. Los pagos se piden aparte.
                       totalPagado y saldo vienen de las funciones (R13: el saldo no se guarda).
   vw_DashboardResumen una sola fila con los contadores del dashboard (6.3).
   Requiere 21_vistas_inventario.sql (vw_InventarioActual).
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

CREATE OR ALTER VIEW dbo.vw_FacturasSaldo
AS
SELECT f.idFactura,
       f.serie,
       f.numero,
       CONCAT(f.serie, N'-', RIGHT('000000' + CAST(f.numero AS VARCHAR(10)), 6)) AS numeroFactura,
       f.fechaEmision,
       f.estado                 AS estadoFactura,
       f.idOrden,
       o.numeroOrden,
       c.idCliente,
       c.nombre                 AS cliente,
       c.nit                    AS nitCliente,
       f.nitFacturacion,
       f.nombreFacturacion,
       f.subtotal,
       f.impuesto,
       f.total,
       x.totalPagado,
       x.saldo,
       CASE WHEN f.estado = 'ANULADA' THEN 'ANULADA'
            WHEN x.saldo = 0          THEN 'PAGADA'
            WHEN x.totalPagado > 0    THEN 'PARCIAL'
            ELSE 'PENDIENTE' END    AS estadoPago
FROM dbo.Factura f
INNER JOIN dbo.OrdenServicio o ON o.idOrden   = f.idOrden
INNER JOIN dbo.Equipo e        ON e.idEquipo  = o.idEquipo
INNER JOIN dbo.Cliente c       ON c.idCliente = e.idCliente
CROSS APPLY (SELECT dbo.fn_TotalPagado(f.idFactura) AS totalPagado,
                    dbo.fn_SaldoFactura(f.idFactura) AS saldo) x;
GO

CREATE OR ALTER VIEW dbo.vw_DashboardResumen
AS
SELECT
    (SELECT COUNT(*) FROM dbo.OrdenServicio o
       INNER JOIN dbo.EstadoOrden eo ON eo.codigo = o.estado
      WHERE eo.esFinal = 0)                                                  AS ordenesAbiertas,
    (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE estado = 'RECIBIDO')       AS recibidas,
    (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE estado = 'DIAGNOSTICO')    AS enDiagnostico,
    (SELECT COUNT(*) FROM dbo.OrdenServicio
      WHERE estado = 'ESPERANDO_AUTORIZACION')                               AS esperandoAutorizacion,
    (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE estado = 'REPARACION')     AS enReparacion,
    (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE estado = 'LISTO')          AS listasParaEntregar,
    (SELECT COUNT(*) FROM dbo.vw_FacturasSaldo
      WHERE estadoFactura = 'EMITIDA' AND saldo > 0)                         AS facturasConSaldo,
    (SELECT ISNULL(SUM(saldo), 0) FROM dbo.vw_FacturasSaldo
      WHERE estadoFactura = 'EMITIDA')                                       AS saldoPorCobrar,
    (SELECT COUNT(*) FROM dbo.vw_InventarioActual
      WHERE estadoStock <> 'OK')                                             AS repuestosBajoMinimo;
GO

SET NOEXEC OFF;
GO