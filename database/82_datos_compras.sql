/* =====================================================================
   82_datos_compras.sql  |  Dueño: FULLSTACK/INFRA
   ---------------------------------------------------------------------
   - 20+ compras con EXEC dbo.sp_RegistrarCompra; recibir 17 con sp_RecibirCompra
     y dejar 3+ PENDIENTES. Un mismo repuesto comprado en 2-3 bodegas.
   - Dejar un repuesto con existencia 0 en una bodega y existencia en otra (T04)
     y 3+ repuestos bajo el mínimo (reporte 7, dashboard).
   Patrón:
     DECLARE @d dbo.TipoDetalleCompra, @idCompra INT;
     INSERT INTO @d (idRepuesto, cantidad, costoUnitario) VALUES (1, 10, 150.00), (2, 5, 420.50);
     EXEC dbo.sp_RegistrarCompra @idProveedor = 1, @idBodegaDestino = 1,
          @numeroDocumento = 'FAC-1001', @idUsuario = 4, @detalle = @d;
     SELECT @idCompra = idCompra FROM dbo.Compra WHERE idProveedor = 1 AND numeroDocumento = 'FAC-1001';
     EXEC dbo.sp_RecibirCompra @idCompra = @idCompra, @idUsuario = 4;
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

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @bodeguero INT = (SELECT idUsuario FROM dbo.Usuario WHERE username = 'bodega1');
DECLARE @i INT = 1, @idCompra INT, @idProveedor INT, @idBodega INT, @doc VARCHAR(30);
DECLARE @d dbo.TipoDetalleCompra;

WHILE @i <= 20
BEGIN
    SELECT @idProveedor = p.idProveedor
    FROM (SELECT idProveedor, ROW_NUMBER() OVER (ORDER BY idProveedor) AS k FROM dbo.Proveedor) p
    WHERE p.k = (@i - 1) % 8 + 1;

    SELECT @idBodega = idBodega FROM dbo.Bodega
    WHERE codigo = CHOOSE((@i - 1) % 3 + 1, 'BOD-CEN', 'BOD-Z10', 'BOD-MIX');

    SET @doc = CONCAT('FAC-', 1000 + @i);

    DELETE FROM @d;
    INSERT INTO @d (idRepuesto, cantidad, costoUnitario)
    SELECT r.idRepuesto, 3 + (r.k + @i) % 6, r.precioCompraRef
    FROM (SELECT idRepuesto, precioCompraRef, ROW_NUMBER() OVER (ORDER BY idRepuesto) AS k FROM dbo.Repuesto) r
    WHERE (r.k + @i) % 4 = 0;

    EXEC dbo.sp_RegistrarCompra @idProveedor = @idProveedor, @idBodegaDestino = @idBodega,
         @numeroDocumento = @doc, @idUsuario = @bodeguero, @detalle = @d;
    SELECT @idCompra = idCompra FROM dbo.Compra WHERE idProveedor = @idProveedor AND numeroDocumento = @doc;

    IF @i <= 17
        EXEC dbo.sp_RecibirCompra @idCompra = @idCompra, @idUsuario = @bodeguero;   -- 18, 19 y 20 quedan PENDIENTES

    SET @i += 1;
END;

/* Escenarios de inventario con ajustes (cada uno deja su movimiento AJUSTE con motivo):
   a) ALM-001 sin stock en BOD-MIX pero con stock en BOD-CEN (T04: "existencia insuficiente en esa bodega")
   b) RAM-001, BAT-001 y PAN-001 bajo el mínimo en BOD-Z10 (reporte 7, dashboard, T13) */
DECLARE @aj TABLE (n INT IDENTITY(1,1) PRIMARY KEY, codigoBodega VARCHAR(10), codigoRepuesto VARCHAR(30), dejarEn INT);
INSERT INTO @aj (codigoBodega, codigoRepuesto, dejarEn) VALUES
 ('BOD-MIX', 'ALM-001', 0), ('BOD-Z10', 'RAM-001', 1), ('BOD-Z10', 'BAT-001', 1), ('BOD-Z10', 'PAN-001', 1);

DECLARE @k INT = 1, @b INT, @r INT, @cant INT;
WHILE @k <= (SELECT COUNT(*) FROM @aj)
BEGIN
    SELECT @b = b.idBodega, @r = rp.idRepuesto, @cant = a.dejarEn - inv.existencia
    FROM @aj a
    INNER JOIN dbo.Bodega b      ON b.codigo = a.codigoBodega
    INNER JOIN dbo.Repuesto rp   ON rp.codigo = a.codigoRepuesto
    INNER JOIN dbo.Inventario inv ON inv.idBodega = b.idBodega AND inv.idRepuesto = rp.idRepuesto
    WHERE a.n = @k;

    IF @cant <> 0
        EXEC dbo.sp_AjusteInventario @idBodega = @b, @idRepuesto = @r, @cantidad = @cant,
             @idUsuario = @bodeguero, @motivo = N'Conteo físico: unidades dañadas o faltantes';
    SET @k += 1;
END;
GO

SET NOEXEC OFF;
GO
