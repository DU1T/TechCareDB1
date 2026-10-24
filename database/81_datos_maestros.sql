/* =====================================================================
   81_datos_maestros.sql  |  Dueño: FULLSTACK/INFRA
   ---------------------------------------------------------------------
   Inserts directos (son datos maestros, no procesos):
   - 30+ clientes individuales y empresariales; UNO SIN ÓRDENES (reporte 2).
   - 45+ equipos; varios clientes con 2-3 equipos; números de serie únicos.
   - 30+ repuestos en las 10 categorías, precios variados.
   - 60+ filas de Inventario con existencia = 0 y stockMinimo variado
     (las existencias las llenan las compras en 82).
   - 8+ proveedores.
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

/* 1) 32 clientes: 20 individuales (2 con CF) y 12 empresas.
      El último cliente NO tendrá equipos: es el "cliente sin órdenes" del enunciado (reporte 2). */
;WITH n AS (SELECT TOP (32) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects)
INSERT INTO dbo.Cliente (tipoCliente, nit, nombre, telefono, email, direccion)
SELECT CASE WHEN i <= 20 THEN 'INDIVIDUAL' ELSE 'EMPRESA' END,
       CASE WHEN i IN (5, 10) THEN 'CF' ELSE CONCAT(1000000 + i * 7919, '-', i % 10) END,
       CASE WHEN i <= 20
            THEN CONCAT(CHOOSE(i % 10 + 1, N'Ana', N'Luis', N'María', N'Carlos', N'Sofía',
                                         N'José', N'Lucía', N'Pedro', N'Elena', N'Jorge'), N' ',
                        CHOOSE(i / 10 + 1, N'López', N'Pérez', N'García'))
            ELSE CHOOSE(i - 20, N'Distribuidora El Sol, S.A.', N'Colegio Los Pinos', N'Farmacia Central',
                        N'Constructora Maya, S.A.', N'Café Altiplano', N'Bufete Morales y Asociados',
                        N'Clínica San Rafael', N'Agroexport Jalapa, S.A.', N'Hotel Las Flores',
                        N'Ferretería La Unión', N'Transportes Rápidos, S.A.', N'Academia Futuro') END,
       CONCAT('5', RIGHT(CONCAT('0000000', i * 1234567 % 10000000), 7)),
       CONCAT('cliente', i, '@correo.test'),
       CONCAT(N'Zona ', i % 18 + 1, N', Ciudad de Guatemala')
FROM n;

/* 2) 70 equipos repartidos entre los primeros 31 clientes (2 o 3 cada uno).
      B necesita uno por orden abierta en 83; el mínimo del enunciado es 45. */
;WITH n AS (SELECT TOP (70) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) AS i FROM sys.all_objects),
      c AS (SELECT idCliente, ROW_NUMBER() OVER (ORDER BY idCliente) AS k
            FROM dbo.Cliente
            WHERE idCliente < (SELECT MAX(idCliente) FROM dbo.Cliente))
INSERT INTO dbo.Equipo (idCliente, idTipoEquipo, idMarca, modelo, numeroSerie)
SELECT c.idCliente,
       te.idTipoEquipo,
       m.idMarca,
       CONCAT(m.nombre, N' ', CHOOSE(n.i % 4 + 1, N'Pro', N'Plus', N'Office', N'Lite'), N' ', 100 + n.i),
       CONCAT('SN-', RIGHT(CONCAT('00000', n.i), 5))
FROM n
INNER JOIN c ON c.k = (n.i - 1) % 31 + 1
INNER JOIN dbo.TipoEquipo te ON te.nombre = CHOOSE(n.i % 5 + 1, N'Laptop', N'Computadora de escritorio', N'Impresora', N'Monitor', N'Tablet')
INNER JOIN dbo.Marca m       ON m.nombre  = CHOOSE(n.i % 5 + 1, N'Dell', N'HP', N'Epson', N'Samsung', N'Lenovo');

/* 3) 30 repuestos, 3 por categoría */
INSERT INTO dbo.Repuesto (codigo, nombre, idCategoria, precioCompraRef, precioVenta)
SELECT v.codigo, v.nombre, cat.idCategoria, v.costo, v.venta
FROM (VALUES
 ('ALM-001', N'SSD 480 GB SATA',              N'Almacenamiento',         210.00,  350.00),
 ('ALM-002', N'SSD 1 TB NVMe',                N'Almacenamiento',         480.00,  750.00),
 ('ALM-003', N'Disco duro 1 TB 2.5"',         N'Almacenamiento',         290.00,  450.00),
 ('RAM-001', N'Memoria DDR4 8 GB',            N'Memoria RAM',            160.00,  275.00),
 ('RAM-002', N'Memoria DDR4 16 GB',           N'Memoria RAM',            300.00,  490.00),
 ('RAM-003', N'Memoria DDR5 16 GB',           N'Memoria RAM',            420.00,  650.00),
 ('PAN-001', N'Pantalla 14" HD',              N'Pantallas',              520.00,  850.00),
 ('PAN-002', N'Pantalla 15.6" FHD',           N'Pantallas',              640.00,  990.00),
 ('PAN-003', N'Pantalla táctil 13"',          N'Pantallas',              980.00, 1450.00),
 ('BAT-001', N'Batería laptop 3 celdas',      N'Baterías',               260.00,  420.00),
 ('BAT-002', N'Batería laptop 6 celdas',      N'Baterías',               340.00,  540.00),
 ('BAT-003', N'Batería CMOS CR2032',          N'Baterías',                 5.00,   15.00),
 ('TEC-001', N'Teclado laptop español',       N'Teclados',               180.00,  300.00),
 ('TEC-002', N'Teclado USB',                  N'Teclados',                60.00,  110.00),
 ('TEC-003', N'Teclado retroiluminado',       N'Teclados',               260.00,  410.00),
 ('FUE-001', N'Cargador 65 W USB-C',          N'Fuentes y cargadores',   150.00,  260.00),
 ('FUE-002', N'Cargador 90 W punta delgada',  N'Fuentes y cargadores',   170.00,  290.00),
 ('FUE-003', N'Fuente de poder ATX 500 W',    N'Fuentes y cargadores',   310.00,  495.00),
 ('TIN-001', N'Cartucho de tinta negra',      N'Tintas y tóner',          95.00,  160.00),
 ('TIN-002', N'Cartucho de tinta a color',    N'Tintas y tóner',         110.00,  185.00),
 ('TIN-003', N'Tóner láser negro',            N'Tintas y tóner',         380.00,  590.00),
 ('RED-001', N'Tarjeta de red WiFi 6',        N'Redes',                  140.00,  240.00),
 ('RED-002', N'Cable de red Cat6 3 m',        N'Redes',                   20.00,   45.00),
 ('RED-003', N'Switch 8 puertos',             N'Redes',                  190.00,  310.00),
 ('TMA-001', N'Tarjeta madre laptop',         N'Tarjetas madre',        1100.00, 1650.00),
 ('TMA-002', N'Tarjeta madre ATX',            N'Tarjetas madre',         850.00, 1300.00),
 ('TMA-003', N'Placa de carga USB-C',         N'Tarjetas madre',          90.00,  165.00),
 ('VEN-001', N'Ventilador laptop',            N'Ventilación y térmico',   80.00,  150.00),
 ('VEN-002', N'Pasta térmica 4 g',            N'Ventilación y térmico',   25.00,   60.00),
 ('VEN-003', N'Disipador CPU',                N'Ventilación y térmico',  120.00,  210.00)
) AS v (codigo, nombre, categoria, costo, venta)
INNER JOIN dbo.CategoriaRepuesto cat ON cat.nombre = v.categoria;

/* 4) Inventario: cada repuesto en las 3 bodegas (90 filas), existencia 0 y mínimo variado.
      El stock real lo ponen las compras de 82, así cada unidad tiene su movimiento. */
INSERT INTO dbo.Inventario (idBodega, idRepuesto, existencia, stockMinimo)
SELECT b.idBodega, r.idRepuesto, 0, 2 + (r.idRepuesto + b.idBodega) % 4
FROM dbo.Repuesto r
CROSS JOIN dbo.Bodega b;

/* 5) 8 proveedores */
INSERT INTO dbo.Proveedor (nit, nombre, contacto, telefono, email, direccion) VALUES
 ('4521873-1', N'Tecnología Global, S.A.',   N'Marta Ruiz',    '22345678', 'ventas@tecglobal.test',  N'Zona 9, Guatemala'),
 ('3398712-5', N'Importadora Digital',       N'Óscar Lima',    '22456789', 'pedidos@impdigital.test', N'Zona 4, Guatemala'),
 ('5512098-3', N'Repuestos Express',         N'Julia Castro',  '22567890', 'info@rexpress.test',     N'Mixco, Guatemala'),
 ('6623401-7', N'Distribuidora Byte',        N'Mario Paz',     '22678901', 'ventas@byte.test',       N'Zona 10, Guatemala'),
 ('7734512-9', N'Tintas y Más',              N'Rosa Méndez',   '22789012', 'tintas@ymas.test',       N'Zona 1, Guatemala'),
 ('8845623-2', N'Redes Centroamérica',       N'Iván Solís',    '22890123', 'redes@ca.test',          N'Villa Nueva, Guatemala'),
 ('9956734-4', N'PowerTech',                 N'Laura Vega',    '22901234', 'power@tech.test',        N'Zona 12, Guatemala'),
 ('1067845-6', N'Componentes del Valle',     N'Raúl Ortiz',    '23012345', 'valle@comp.test',        N'Jalapa, Guatemala');
GO

SET NOEXEC OFF;
GO
