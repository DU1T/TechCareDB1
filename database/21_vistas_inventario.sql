/* =====================================================================
   21_vistas_inventario.sql  |  Dueño: FULLSTACK/INFRA
   ---------------------------------------------------------------------
   dbo.vw_InventarioActual          (reportes 6 y 7, dashboard, T13)
     Inventario + Repuesto + CategoriaRepuesto + Bodega
     columnas: bodega, categoria, codigo, repuesto, existencia, stockMinimo,
               precioVenta, valorInventario = existencia * precioCompraRef,
               estadoStock = CASE WHEN existencia = 0 THEN 'SIN_STOCK'
                                  WHEN existencia <= stockMinimo THEN 'BAJO_MINIMO'
                                  ELSE 'OK' END
   dbo.vw_MovimientosInventario     (reporte 9)
     MovimientoInventario + Bodega + Repuesto + Usuario
     LEFT JOIN Compra/Proveedor (si origen COMPRA)
     LEFT JOIN DetalleRepuesto -> Reparacion -> Diagnostico -> OrdenServicio (si origen REPARACION)
     documentoOrigen = CASE origen WHEN 'COMPRA' THEN 'COMPRA ' + numeroDocumento
                                   WHEN 'REPARACION' THEN numeroOrden ... END
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

CREATE OR ALTER VIEW dbo.vw_InventarioActual
AS
SELECT i.idBodega, b.codigo AS codigoBodega, b.nombre AS bodega,
       r.idRepuesto, r.codigo, r.nombre AS repuesto,
       cat.idCategoria, cat.nombre AS categoria,
       i.existencia, i.stockMinimo, r.precioCompraRef, r.precioVenta,
       CAST(i.existencia * r.precioCompraRef AS DECIMAL(14,2)) AS valorInventario,
       CASE WHEN i.existencia = 0              THEN 'SIN_STOCK'
            WHEN i.existencia <= i.stockMinimo THEN 'BAJO_MINIMO'
            ELSE 'OK' END AS estadoStock,
       i.fechaUltimoMovimiento
FROM dbo.Inventario i
INNER JOIN dbo.Bodega b              ON b.idBodega = i.idBodega
INNER JOIN dbo.Repuesto r            ON r.idRepuesto = i.idRepuesto
INNER JOIN dbo.CategoriaRepuesto cat ON cat.idCategoria = r.idCategoria;
GO

CREATE OR ALTER VIEW dbo.vw_MovimientosInventario
AS
SELECT mv.idMovimiento, mv.fechaMovimiento, mv.tipo, mv.origen,
       mv.idBodega, b.nombre AS bodega, mv.idRepuesto, r.codigo, r.nombre AS repuesto,
       mv.cantidad, mv.existenciaAnterior, mv.existenciaResultante, mv.costoUnitario,
       u.nombreCompleto AS usuario,
       CASE mv.origen
            WHEN 'COMPRA'     THEN CONCAT(N'Compra ', c.numeroDocumento, N' · ', p.nombre)
            WHEN 'REPARACION' THEN CONCAT(N'Orden ', o.numeroOrden)
            WHEN 'DEVOLUCION' THEN CONCAT(N'Devolución de la orden ', o.numeroOrden)
            ELSE CONCAT(N'Ajuste: ', mv.observacion) END AS documentoOrigen,
       mv.idCompra, o.idOrden
FROM dbo.MovimientoInventario mv
INNER JOIN dbo.Bodega b             ON b.idBodega = mv.idBodega
INNER JOIN dbo.Repuesto r           ON r.idRepuesto = mv.idRepuesto
INNER JOIN dbo.Usuario u            ON u.idUsuario = mv.idUsuario
LEFT  JOIN dbo.Compra c             ON c.idCompra = mv.idCompra
LEFT  JOIN dbo.Proveedor p          ON p.idProveedor = c.idProveedor
LEFT  JOIN dbo.DetalleRepuesto dr   ON dr.idDetalleRepuesto = mv.idDetalleRepuesto
LEFT  JOIN dbo.Reparacion rep       ON rep.idReparacion = dr.idReparacion
LEFT  JOIN dbo.Diagnostico d        ON d.idDiagnostico = rep.idDiagnostico
LEFT  JOIN dbo.OrdenServicio o      ON o.idOrden = d.idOrden;
GO

SET NOEXEC OFF;
GO
