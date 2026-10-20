/* =====================================================================
   21_vistas_inventario.sql  |  Dueño: FULLSTACK/INFRA
   ---------------------------------------------------------------------
   TODO dbo.vw_InventarioActual          (reportes 6 y 7, dashboard, T13)
     Inventario + Repuesto + CategoriaRepuesto + Bodega
     columnas: bodega, categoria, codigo, repuesto, existencia, stockMinimo,
               precioVenta, valorInventario = existencia * precioCompraRef,
               estadoStock = CASE WHEN existencia = 0 THEN 'SIN_STOCK'
                                  WHEN existencia <= stockMinimo THEN 'BAJO_MINIMO'
                                  ELSE 'OK' END
   TODO dbo.vw_MovimientosInventario     (reporte 9)
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

SET NOEXEC OFF;
GO
