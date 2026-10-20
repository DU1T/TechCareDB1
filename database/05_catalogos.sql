/* =====================================================================
   05_catalogos.sql  |  NÚCLEO  |  Datos estructurales (forman parte del master)
   ---------------------------------------------------------------------
   Roles, permisos, estados de la orden, transiciones, métodos de pago,
   catálogos base. Los USUARIOS no van aquí: su hash lo genera el backend
   (ver 80_datos_prueba.sql).
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
/* ---------- Roles ---------- */
INSERT INTO dbo.Rol (nombre, descripcion) VALUES
 ('ADMINISTRADOR', N'Acceso total al sistema'),
 ('RECEPCION',     N'Registra clientes, equipos, órdenes y entregas'),
 ('TECNICO',       N'Diagnostica, repara y consume repuestos'),
 ('BODEGA',        N'Gestiona inventario, proveedores y compras'),
 ('CAJA',          N'Factura y registra pagos');
GO

/* ---------- Permisos (el backend los lee para autorizar endpoints) ---------- */
INSERT INTO dbo.Permiso (codigo, descripcion) VALUES
 ('USUARIO_GESTIONAR',    N'Crear/editar usuarios y roles'),
 ('CLIENTE_GESTIONAR',    N'Crear/editar clientes y equipos'),
 ('ORDEN_CREAR',          N'Registrar órdenes de servicio'),
 ('ORDEN_CAMBIAR_ESTADO', N'Cambiar estado de una orden'),
 ('DIAGNOSTICO_REGISTRAR',N'Registrar diagnóstico'),
 ('REPARACION_GESTIONAR', N'Iniciar/finalizar reparaciones'),
 ('REPUESTO_CONSUMIR',    N'Asignar repuestos a una reparación'),
 ('CATALOGO_GESTIONAR',   N'Repuestos, categorías, bodegas, proveedores'),
 ('COMPRA_REGISTRAR',     N'Registrar compras'),
 ('COMPRA_RECIBIR',       N'Recibir compras en inventario'),
 ('FACTURA_EMITIR',       N'Facturar una orden'),
 ('PAGO_REGISTRAR',       N'Registrar pagos'),
 ('ENTREGA_REGISTRAR',    N'Entregar y cerrar una orden'),
 ('REPORTE_VER',          N'Ver reportes y dashboard');
GO

INSERT INTO dbo.RolPermiso (idRol, idPermiso)
SELECT r.idRol, p.idPermiso
FROM (VALUES
    ('RECEPCION','CLIENTE_GESTIONAR'), ('RECEPCION','ORDEN_CREAR'), ('RECEPCION','ORDEN_CAMBIAR_ESTADO'),
    ('RECEPCION','ENTREGA_REGISTRAR'), ('RECEPCION','REPORTE_VER'),
    ('TECNICO','DIAGNOSTICO_REGISTRAR'), ('TECNICO','REPARACION_GESTIONAR'), ('TECNICO','REPUESTO_CONSUMIR'),
    ('TECNICO','ORDEN_CAMBIAR_ESTADO'), ('TECNICO','REPORTE_VER'),
    ('BODEGA','CATALOGO_GESTIONAR'), ('BODEGA','COMPRA_REGISTRAR'), ('BODEGA','COMPRA_RECIBIR'), ('BODEGA','REPORTE_VER'),
    ('CAJA','FACTURA_EMITIR'), ('CAJA','PAGO_REGISTRAR'), ('CAJA','ENTREGA_REGISTRAR'), ('CAJA','REPORTE_VER')
) AS m(rol, permiso)
JOIN dbo.Rol r     ON r.nombre = m.rol
JOIN dbo.Permiso p ON p.codigo = m.permiso
UNION ALL
SELECT r.idRol, p.idPermiso            -- el administrador tiene todos
FROM dbo.Rol r CROSS JOIN dbo.Permiso p
WHERE r.nombre = 'ADMINISTRADOR';
GO

/* ---------- Estados de la orden ---------- */
INSERT INTO dbo.EstadoOrden (codigo, descripcion, secuencia, esInicial, esFinal) VALUES
 ('RECIBIDO',               N'Equipo recibido en recepción',          1, 1, 0),
 ('DIAGNOSTICO',            N'En diagnóstico técnico',                2, 0, 0),
 ('ESPERANDO_AUTORIZACION', N'Esperando autorización del cliente',    3, 0, 0),
 ('REPARACION',             N'En reparación',                         4, 0, 0),
 ('LISTO',                  N'Listo para entregar',                   5, 0, 0),
 ('ENTREGADO',              N'Entregado al cliente (cerrada)',        6, 0, 1),
 ('CANCELADO',              N'Orden cancelada (cerrada)',             7, 0, 1);
GO

/* ---------- Transiciones permitidas (máquina de estados) ---------- */
INSERT INTO dbo.TransicionEstado (estadoOrigen, estadoDestino) VALUES
 ('RECIBIDO',               'DIAGNOSTICO'),
 ('RECIBIDO',               'CANCELADO'),
 ('DIAGNOSTICO',            'ESPERANDO_AUTORIZACION'),
 ('DIAGNOSTICO',            'CANCELADO'),
 ('ESPERANDO_AUTORIZACION', 'REPARACION'),   -- cliente autoriza
 ('ESPERANDO_AUTORIZACION', 'LISTO'),        -- cliente NO autoriza: se devuelve sin reparar
 ('ESPERANDO_AUTORIZACION', 'CANCELADO'),
 ('REPARACION',             'LISTO'),
 ('REPARACION',             'CANCELADO'),
 ('LISTO',                  'ENTREGADO');
GO

/* ---------- Catálogos base ---------- */
INSERT INTO dbo.MetodoPago (nombre, requiereReferencia) VALUES
 ('EFECTIVO', 0), ('TARJETA', 1), ('TRANSFERENCIA', 1), ('CHEQUE', 1);
GO

INSERT INTO dbo.TipoEquipo (nombre) VALUES
 (N'Laptop'), (N'Computadora de escritorio'), (N'Impresora'), (N'Equipo de red'),
 (N'Monitor'), (N'Tablet'), (N'Servidor'), (N'Otro');
GO

INSERT INTO dbo.Marca (nombre) VALUES
 (N'Dell'), (N'HP'), (N'Lenovo'), (N'Asus'), (N'Acer'), (N'Apple'),
 (N'Epson'), (N'Canon'), (N'Brother'), (N'Cisco'), (N'TP-Link'), (N'Samsung'), (N'Genérica');
GO

INSERT INTO dbo.CategoriaRepuesto (nombre) VALUES
 (N'Almacenamiento'), (N'Memoria RAM'), (N'Pantallas'), (N'Baterías'), (N'Teclados'),
 (N'Fuentes y cargadores'), (N'Tintas y tóner'), (N'Redes'), (N'Tarjetas madre'), (N'Ventilación y térmico');
GO

INSERT INTO dbo.Bodega (codigo, nombre, ubicacion) VALUES
 ('BOD-CEN', N'Bodega Central',      N'Zona 4, Ciudad de Guatemala'),
 ('BOD-Z10', N'Sucursal Zona 10',    N'Zona 10, Ciudad de Guatemala'),
 ('BOD-MIX', N'Sucursal Mixco',      N'Mixco, Guatemala');
GO

SET NOEXEC OFF;
GO
