/* =====================================================================
   84_datos_facturacion.sql  |  Dueño: FRONTEND
   ---------------------------------------------------------------------
   Requiere 80-83 (órdenes en LISTO).
   - 30+ facturas con sp_FacturarOrden.
   - 40+ pagos con sp_RegistrarPago: facturas pagadas completas, una con 3 pagos,
     varias con saldo pendiente, métodos distintos.
   - Entregas con sp_EntregarOrden solo de órdenes con saldo 0.
   - Opcional: un pago anulado con sp_AnularPago (R14).
   ---------------------------------------------------------------------
   Los datos de prueba se reparten en 6 archivos, uno por dueño; el build los
   une EN ESTE ORDEN en TechCare_DatosPrueba.sql (entregable 03):
     80_datos_usuarios.sql     B  10+ usuarios con hash real y sus roles (los genera el backend)
     81_datos_maestros.sql     C  clientes, equipos, repuestos, inventario (stockMinimo), proveedores
     82_datos_compras.sql      C  20+ compras vía SP (17 recibidas, 3+ PENDIENTES)
     83_datos_ordenes.sql      B  60+ órdenes, 45+ diagnósticos, 35+ reparaciones, repuestos usados
     84_datos_facturacion.sql  A  30+ facturas, 40+ pagos, entregas
     85_datos_escenarios.sql   C  fechas repartidas, escenarios de la defensa y verificación de mínimos
   REGLA DE ORO: todo lo transaccional se crea LLAMANDO A LOS SP. Si un SP falla
   al generar datos, encontraron un bug antes que el profesor.
   Para recuperar el id que crea un SP, búsquelo después por su llave de negocio
   (no use INSERT ... EXEC con SP que tienen transacción: falla con el error 3915).
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
