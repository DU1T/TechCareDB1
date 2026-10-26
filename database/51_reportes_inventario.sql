/* =====================================================================
   51_reportes_inventario.sql  |  Dueño: FULLSTACK/INFRA  |  Reportes 5, 6, 7, 8, 9
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

-- Reporte 5: repuestos usados por orden, técnico y bodega, con costo y venta HISTÓRICOS (8 tablas)
CREATE OR ALTER PROCEDURE dbo.sp_Reporte_05_RepuestosUtilizados
    @fechaInicio DATE = NULL, @fechaFin DATE = NULL, @idTecnico INT = NULL, @idBodega INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT o.numeroOrden, dr.fechaRegistro, tec.nombreCompleto AS tecnico, b.nombre AS bodega,
           rp.codigo, rp.nombre AS repuesto, cat.nombre AS categoria, dr.cantidad,
           dr.costoUnitario, dr.precioUnitario,
           CAST(dr.cantidad * dr.costoUnitario AS DECIMAL(12,2))                      AS costoTotal,
           CAST(dr.cantidad * dr.precioUnitario AS DECIMAL(12,2))                     AS ventaTotal,
           CAST(dr.cantidad * (dr.precioUnitario - dr.costoUnitario) AS DECIMAL(12,2)) AS margen
    FROM dbo.DetalleRepuesto dr
    INNER JOIN dbo.Reparacion rep        ON rep.idReparacion = dr.idReparacion
    INNER JOIN dbo.Diagnostico d         ON d.idDiagnostico = rep.idDiagnostico
    INNER JOIN dbo.OrdenServicio o       ON o.idOrden = d.idOrden
    INNER JOIN dbo.Usuario tec           ON tec.idUsuario = dr.idUsuario
    INNER JOIN dbo.Bodega b              ON b.idBodega = dr.idBodega
    INNER JOIN dbo.Repuesto rp           ON rp.idRepuesto = dr.idRepuesto
    INNER JOIN dbo.CategoriaRepuesto cat ON cat.idCategoria = rp.idCategoria
    WHERE dr.estado = 'APLICADO'
      AND (@fechaInicio IS NULL OR dr.fechaRegistro >= @fechaInicio)
      AND (@fechaFin    IS NULL OR dr.fechaRegistro <  DATEADD(DAY, 1, @fechaFin))
      AND (@idTecnico   IS NULL OR dr.idUsuario = @idTecnico)
      AND (@idBodega    IS NULL OR dr.idBodega = @idBodega)
    ORDER BY dr.fechaRegistro, o.numeroOrden;
END;
GO

-- Reporte 6: inventario actual por bodega, categoría y repuesto
CREATE OR ALTER PROCEDURE dbo.sp_Reporte_06_Inventario
    @idBodega INT = NULL, @idCategoria INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.bodega, v.categoria, v.codigo, v.repuesto, v.existencia, v.stockMinimo,
           v.precioCompraRef, v.valorInventario, v.estadoStock
    FROM dbo.vw_InventarioActual v
    WHERE (@idBodega    IS NULL OR v.idBodega = @idBodega)
      AND (@idCategoria IS NULL OR v.idCategoria = @idCategoria)
    ORDER BY v.bodega, v.categoria, v.repuesto;
END;
GO

-- Reporte 7: existencia igual o menor al mínimo, ordenado por lo que falta
CREATE OR ALTER PROCEDURE dbo.sp_Reporte_07_BajoMinimo
    @idBodega INT = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.bodega, v.codigo, v.repuesto, v.categoria, v.existencia, v.stockMinimo,
           v.stockMinimo - v.existencia AS faltante, v.estadoStock
    FROM dbo.vw_InventarioActual v
    WHERE v.existencia <= v.stockMinimo
      AND (@idBodega IS NULL OR v.idBodega = @idBodega)
    ORDER BY faltante DESC, v.bodega;
END;
GO

-- Reporte 8: compras por proveedor con detalle y costo HISTÓRICO (6 tablas; incluye PENDIENTES)
CREATE OR ALTER PROCEDURE dbo.sp_Reporte_08_ComprasProveedor
    @idProveedor INT = NULL, @fechaInicio DATE = NULL, @fechaFin DATE = NULL, @estado VARCHAR(10) = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT p.nombre AS proveedor, c.numeroDocumento, c.fechaCompra, c.estado, c.fechaRecepcion,
           b.nombre AS bodegaDestino, reg.nombreCompleto AS registradaPor,
           rp.codigo, rp.nombre AS repuesto, dc.cantidad, dc.costoUnitario,
           CAST(dc.cantidad * dc.costoUnitario AS DECIMAL(12,2)) AS subtotal
    FROM dbo.Compra c
    INNER JOIN dbo.Proveedor p      ON p.idProveedor = c.idProveedor
    INNER JOIN dbo.Bodega b         ON b.idBodega = c.idBodegaDestino
    INNER JOIN dbo.Usuario reg      ON reg.idUsuario = c.idUsuarioRegistro
    INNER JOIN dbo.DetalleCompra dc ON dc.idCompra = c.idCompra
    INNER JOIN dbo.Repuesto rp      ON rp.idRepuesto = dc.idRepuesto
    WHERE (@idProveedor IS NULL OR c.idProveedor = @idProveedor)
      AND (@estado      IS NULL OR c.estado = @estado)
      AND (@fechaInicio IS NULL OR c.fechaCompra >= @fechaInicio)
      AND (@fechaFin    IS NULL OR c.fechaCompra <  DATEADD(DAY, 1, @fechaFin))
    ORDER BY p.nombre, c.fechaCompra, rp.codigo;
END;
GO

-- Reporte 9: kárdex con documento origen, tipo y usuario (usa IX_Movimiento_Bodega_Repuesto_Fecha)
CREATE OR ALTER PROCEDURE dbo.sp_Reporte_09_Kardex
    @idBodega INT = NULL, @idRepuesto INT = NULL, @fechaInicio DATE = NULL, @fechaFin DATE = NULL
AS
BEGIN
    SET NOCOUNT ON;
    SELECT v.fechaMovimiento, v.bodega, v.codigo, v.repuesto, v.tipo, v.origen, v.documentoOrigen,
           v.cantidad, v.existenciaAnterior, v.existenciaResultante, v.usuario
    FROM dbo.vw_MovimientosInventario v
    WHERE (@idBodega    IS NULL OR v.idBodega = @idBodega)
      AND (@idRepuesto  IS NULL OR v.idRepuesto = @idRepuesto)
      AND (@fechaInicio IS NULL OR v.fechaMovimiento >= @fechaInicio)
      AND (@fechaFin    IS NULL OR v.fechaMovimiento <  DATEADD(DAY, 1, @fechaFin))
    ORDER BY v.bodega, v.repuesto, v.fechaMovimiento, v.idMovimiento;
END;
GO

SET NOEXEC OFF;
GO
