/* =====================================================================
   02_tablas.sql  |  NÚCLEO  |  Tablas + PK + FK + UNIQUE + DEFAULT + CHECK
   ---------------------------------------------------------------------
   Convenciones:
     PK_<Tabla>, FK_<Hija>_<Padre>[_<rol>], UQ_<Tabla>_<Col>,
     CK_<Tabla>_<Regla>, DF_<Tabla>_<Col>
   Fechas: DATETIME2(0) con SYSDATETIME(). Dinero: DECIMAL(12,2).
   Borrado: NO ACTION en todo lo transaccional (R14: no se borra, se anula).
            CASCADE solo en tablas asociativas puras (UsuarioRol, RolPermiso).
   Orden: padres antes que hijos (respeta dependencias).
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
/* =========================================================
   1. SEGURIDAD Y ACCESO
   ========================================================= */
CREATE TABLE dbo.Rol (
    idRol        INT IDENTITY(1,1) NOT NULL,
    nombre       VARCHAR(30)   NOT NULL,           -- ADMINISTRADOR, RECEPCION, TECNICO, BODEGA, CAJA
    descripcion  NVARCHAR(200) NULL,
    CONSTRAINT PK_Rol PRIMARY KEY (idRol),
    CONSTRAINT UQ_Rol_Nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.Permiso (
    idPermiso    INT IDENTITY(1,1) NOT NULL,
    codigo       VARCHAR(50)   NOT NULL,           -- ej. ORDEN_CREAR (lo usa el backend para autorizar)
    descripcion  NVARCHAR(200) NULL,
    CONSTRAINT PK_Permiso PRIMARY KEY (idPermiso),
    CONSTRAINT UQ_Permiso_Codigo UNIQUE (codigo)
);
GO

-- N:M Rol <-> Permiso  (PK compuesta)
CREATE TABLE dbo.RolPermiso (
    idRol      INT NOT NULL,
    idPermiso  INT NOT NULL,
    CONSTRAINT PK_RolPermiso PRIMARY KEY (idRol, idPermiso),
    CONSTRAINT FK_RolPermiso_Rol     FOREIGN KEY (idRol)     REFERENCES dbo.Rol(idRol)         ON DELETE CASCADE,
    CONSTRAINT FK_RolPermiso_Permiso FOREIGN KEY (idPermiso) REFERENCES dbo.Permiso(idPermiso) ON DELETE CASCADE
);
GO

CREATE TABLE dbo.Usuario (
    idUsuario       INT IDENTITY(1,1) NOT NULL,
    username        VARCHAR(50)   NOT NULL,
    passwordHash    VARCHAR(255)  NOT NULL,        -- hash + salt generado por el backend .NET
    nombreCompleto  NVARCHAR(120) NOT NULL,
    email           VARCHAR(120)  NULL,
    telefono        VARCHAR(20)   NULL,
    estado          VARCHAR(10)   NOT NULL CONSTRAINT DF_Usuario_Estado DEFAULT ('ACTIVO'),
    fechaCreacion   DATETIME2(0)  NOT NULL CONSTRAINT DF_Usuario_FechaCreacion DEFAULT (SYSDATETIME()),
    ultimoAcceso    DATETIME2(0)  NULL,
    CONSTRAINT PK_Usuario PRIMARY KEY (idUsuario),
    CONSTRAINT UQ_Usuario_Username UNIQUE (username),
    CONSTRAINT CK_Usuario_Estado CHECK (estado IN ('ACTIVO','INACTIVO')),
    -- Defensa extra: un hash real (PBKDF2/BCrypt) nunca mide menos de 40 caracteres.
    -- Impide guardar por error una contraseña en texto plano corta.
    CONSTRAINT CK_Usuario_PasswordHash CHECK (LEN(passwordHash) >= 40)
);
GO

-- N:M Usuario <-> Rol  (PK compuesta)
CREATE TABLE dbo.UsuarioRol (
    idUsuario        INT NOT NULL,
    idRol            INT NOT NULL,
    fechaAsignacion  DATETIME2(0) NOT NULL CONSTRAINT DF_UsuarioRol_Fecha DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_UsuarioRol PRIMARY KEY (idUsuario, idRol),
    CONSTRAINT FK_UsuarioRol_Usuario FOREIGN KEY (idUsuario) REFERENCES dbo.Usuario(idUsuario) ON DELETE CASCADE,
    CONSTRAINT FK_UsuarioRol_Rol     FOREIGN KEY (idRol)     REFERENCES dbo.Rol(idRol)         ON DELETE CASCADE
);
GO

/* =========================================================
   2. CLIENTES Y EQUIPOS
   ========================================================= */
CREATE TABLE dbo.Cliente (
    idCliente      INT IDENTITY(1,1) NOT NULL,
    tipoCliente    VARCHAR(12)   NOT NULL,
    nit            VARCHAR(15)   NOT NULL,          -- 'CF' permitido (consumidor final); único si no es CF
    nombre         NVARCHAR(150) NOT NULL,          -- nombre de la persona o razón social
    telefono       VARCHAR(20)   NULL,
    email          VARCHAR(120)  NULL,
    direccion      NVARCHAR(250) NULL,
    estado         VARCHAR(10)   NOT NULL CONSTRAINT DF_Cliente_Estado DEFAULT ('ACTIVO'),
    fechaRegistro  DATETIME2(0)  NOT NULL CONSTRAINT DF_Cliente_FechaRegistro DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Cliente PRIMARY KEY (idCliente),
    CONSTRAINT CK_Cliente_Tipo     CHECK (tipoCliente IN ('INDIVIDUAL','EMPRESA')),
    CONSTRAINT CK_Cliente_Estado   CHECK (estado IN ('ACTIVO','INACTIVO')),
    CONSTRAINT CK_Cliente_Contacto CHECK (telefono IS NOT NULL OR email IS NOT NULL),
    CONSTRAINT CK_Cliente_NitEmpresa CHECK (tipoCliente = 'INDIVIDUAL' OR nit <> 'CF')  -- una empresa siempre tiene NIT
);
GO

CREATE TABLE dbo.TipoEquipo (
    idTipoEquipo INT IDENTITY(1,1) NOT NULL,
    nombre       NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_TipoEquipo PRIMARY KEY (idTipoEquipo),
    CONSTRAINT UQ_TipoEquipo_Nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.Marca (
    idMarca INT IDENTITY(1,1) NOT NULL,
    nombre  NVARCHAR(50) NOT NULL,
    CONSTRAINT PK_Marca PRIMARY KEY (idMarca),
    CONSTRAINT UQ_Marca_Nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.Equipo (
    idEquipo       INT IDENTITY(1,1) NOT NULL,
    idCliente      INT           NOT NULL,
    idTipoEquipo   INT           NOT NULL,
    idMarca        INT           NOT NULL,
    modelo         NVARCHAR(80)  NOT NULL,
    numeroSerie    VARCHAR(60)   NOT NULL,
    descripcion    NVARCHAR(300) NULL,
    estado         VARCHAR(10)   NOT NULL CONSTRAINT DF_Equipo_Estado DEFAULT ('ACTIVO'),
    fechaRegistro  DATETIME2(0)  NOT NULL CONSTRAINT DF_Equipo_FechaRegistro DEFAULT (SYSDATETIME()),
    CONSTRAINT PK_Equipo PRIMARY KEY (idEquipo),
    CONSTRAINT UQ_Equipo_NumeroSerie UNIQUE (numeroSerie),       -- también sirve de índice de búsqueda (reporte 3)
    CONSTRAINT FK_Equipo_Cliente    FOREIGN KEY (idCliente)    REFERENCES dbo.Cliente(idCliente),
    CONSTRAINT FK_Equipo_TipoEquipo FOREIGN KEY (idTipoEquipo) REFERENCES dbo.TipoEquipo(idTipoEquipo),
    CONSTRAINT FK_Equipo_Marca      FOREIGN KEY (idMarca)      REFERENCES dbo.Marca(idMarca),
    CONSTRAINT CK_Equipo_Estado CHECK (estado IN ('ACTIVO','INACTIVO','BAJA'))
);
GO

/* =========================================================
   3. ÓRDENES DE SERVICIO (máquina de estados en la BD)
   ========================================================= */
CREATE TABLE dbo.EstadoOrden (
    codigo       VARCHAR(25)   NOT NULL,
    descripcion  NVARCHAR(100) NOT NULL,
    secuencia    TINYINT       NOT NULL,           -- orden de presentación
    esInicial    BIT           NOT NULL CONSTRAINT DF_EstadoOrden_EsInicial DEFAULT (0),
    esFinal      BIT           NOT NULL CONSTRAINT DF_EstadoOrden_EsFinal   DEFAULT (0),
    CONSTRAINT PK_EstadoOrden PRIMARY KEY (codigo),
    CONSTRAINT CK_EstadoOrden_InicialFinal CHECK (NOT (esInicial = 1 AND esFinal = 1))
);
GO

-- N:M EstadoOrden <-> EstadoOrden (transiciones permitidas). PK compuesta.
CREATE TABLE dbo.TransicionEstado (
    estadoOrigen   VARCHAR(25) NOT NULL,
    estadoDestino  VARCHAR(25) NOT NULL,
    CONSTRAINT PK_TransicionEstado PRIMARY KEY (estadoOrigen, estadoDestino),
    CONSTRAINT FK_TransicionEstado_Origen  FOREIGN KEY (estadoOrigen)  REFERENCES dbo.EstadoOrden(codigo),
    CONSTRAINT FK_TransicionEstado_Destino FOREIGN KEY (estadoDestino) REFERENCES dbo.EstadoOrden(codigo),
    CONSTRAINT CK_TransicionEstado_Distinto CHECK (estadoOrigen <> estadoDestino)
);
GO

-- El cliente se obtiene por Equipo.idCliente (3FN: no se duplica en la orden).
CREATE TABLE dbo.OrdenServicio (
    idOrden             INT IDENTITY(1,1) NOT NULL,
    numeroOrden         AS ('OS-' + RIGHT('000000' + CAST(idOrden AS VARCHAR(10)), 6)) PERSISTED,
    idEquipo            INT           NOT NULL,
    idUsuarioRecepcion  INT           NOT NULL,
    idTecnicoAsignado   INT           NULL,        -- NULL mientras no se asigna técnico
    fechaIngreso        DATETIME2(0)  NOT NULL CONSTRAINT DF_OrdenServicio_FechaIngreso DEFAULT (SYSDATETIME()),
    problemaReportado   NVARCHAR(500) NOT NULL,
    prioridad           VARCHAR(10)   NOT NULL CONSTRAINT DF_OrdenServicio_Prioridad DEFAULT ('MEDIA'),
    estado              VARCHAR(25)   NOT NULL CONSTRAINT DF_OrdenServicio_Estado DEFAULT ('RECIBIDO'),
    fechaEstimada       DATE          NULL,
    observaciones       NVARCHAR(500) NULL,
    CONSTRAINT PK_OrdenServicio PRIMARY KEY (idOrden),
    CONSTRAINT UQ_OrdenServicio_Numero UNIQUE (numeroOrden),
    CONSTRAINT FK_OrdenServicio_Equipo     FOREIGN KEY (idEquipo)           REFERENCES dbo.Equipo(idEquipo),
    CONSTRAINT FK_OrdenServicio_Recepcion  FOREIGN KEY (idUsuarioRecepcion) REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT FK_OrdenServicio_Tecnico    FOREIGN KEY (idTecnicoAsignado)  REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT FK_OrdenServicio_Estado     FOREIGN KEY (estado)             REFERENCES dbo.EstadoOrden(codigo),
    CONSTRAINT CK_OrdenServicio_Prioridad CHECK (prioridad IN ('BAJA','MEDIA','ALTA','URGENTE')),
    CONSTRAINT CK_OrdenServicio_FechaEstimada CHECK (fechaEstimada IS NULL OR fechaEstimada >= CAST(fechaIngreso AS DATE))
);
GO

-- R05: todo cambio de estado queda aquí (lo llena el trigger trg_OrdenServicio_Estado)
CREATE TABLE dbo.HistorialEstadoOrden (
    idHistorial     BIGINT IDENTITY(1,1) NOT NULL,
    idOrden         INT           NOT NULL,
    estadoAnterior  VARCHAR(25)   NULL,            -- NULL en la creación de la orden
    estadoNuevo     VARCHAR(25)   NOT NULL,
    fechaCambio     DATETIME2(0)  NOT NULL CONSTRAINT DF_HistorialEstado_Fecha DEFAULT (SYSDATETIME()),
    idUsuario       INT           NULL,            -- usuario de la aplicación (vía SESSION_CONTEXT)
    usuarioBD       NVARCHAR(128) NOT NULL CONSTRAINT DF_HistorialEstado_UsuarioBD DEFAULT (SUSER_SNAME()),
    observacion     NVARCHAR(300) NULL,
    CONSTRAINT PK_HistorialEstadoOrden PRIMARY KEY (idHistorial),
    CONSTRAINT FK_HistorialEstado_Orden    FOREIGN KEY (idOrden)        REFERENCES dbo.OrdenServicio(idOrden),
    CONSTRAINT FK_HistorialEstado_Anterior FOREIGN KEY (estadoAnterior) REFERENCES dbo.EstadoOrden(codigo),
    CONSTRAINT FK_HistorialEstado_Nuevo    FOREIGN KEY (estadoNuevo)    REFERENCES dbo.EstadoOrden(codigo),
    CONSTRAINT FK_HistorialEstado_Usuario  FOREIGN KEY (idUsuario)      REFERENCES dbo.Usuario(idUsuario)
);
GO

/* =========================================================
   4. DIAGNÓSTICO Y REPARACIÓN
   ========================================================= */
-- 1 orden : 0..1 diagnóstico
CREATE TABLE dbo.Diagnostico (
    idDiagnostico          INT IDENTITY(1,1) NOT NULL,
    idOrden                INT            NOT NULL,
    idTecnico              INT            NOT NULL,
    fechaDiagnostico       DATETIME2(0)   NOT NULL CONSTRAINT DF_Diagnostico_Fecha DEFAULT (SYSDATETIME()),
    descripcion            NVARCHAR(1000) NOT NULL,
    costoManoObraEstimado  DECIMAL(12,2)  NOT NULL,
    autorizado             BIT            NULL,    -- NULL = pendiente, 1 = cliente autorizó, 0 = rechazó
    fechaRespuestaCliente  DATETIME2(0)   NULL,
    CONSTRAINT PK_Diagnostico PRIMARY KEY (idDiagnostico),
    CONSTRAINT UQ_Diagnostico_Orden UNIQUE (idOrden),
    CONSTRAINT FK_Diagnostico_Orden   FOREIGN KEY (idOrden)   REFERENCES dbo.OrdenServicio(idOrden),
    CONSTRAINT FK_Diagnostico_Tecnico FOREIGN KEY (idTecnico) REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT CK_Diagnostico_Costo CHECK (costoManoObraEstimado >= 0),
    CONSTRAINT CK_Diagnostico_Respuesta CHECK (
        (autorizado IS NULL AND fechaRespuestaCliente IS NULL) OR
        (autorizado IS NOT NULL AND fechaRespuestaCliente IS NOT NULL))
);
GO

-- R04 a nivel de BD: una reparación EXIGE un diagnóstico (FK NOT NULL). La orden se llega por Diagnostico.
CREATE TABLE dbo.Reparacion (
    idReparacion        INT IDENTITY(1,1) NOT NULL,
    idDiagnostico       INT            NOT NULL,
    idTecnico           INT            NOT NULL,
    fechaInicio         DATETIME2(0)   NOT NULL CONSTRAINT DF_Reparacion_FechaInicio DEFAULT (SYSDATETIME()),
    fechaFin            DATETIME2(0)   NULL,
    descripcionTrabajo  NVARCHAR(1000) NULL,
    costoManoObra       DECIMAL(12,2)  NOT NULL CONSTRAINT DF_Reparacion_Costo DEFAULT (0),
    estado              VARCHAR(12)    NOT NULL CONSTRAINT DF_Reparacion_Estado DEFAULT ('EN_PROCESO'),
    CONSTRAINT PK_Reparacion PRIMARY KEY (idReparacion),
    CONSTRAINT UQ_Reparacion_Diagnostico UNIQUE (idDiagnostico),
    CONSTRAINT FK_Reparacion_Diagnostico FOREIGN KEY (idDiagnostico) REFERENCES dbo.Diagnostico(idDiagnostico),
    CONSTRAINT FK_Reparacion_Tecnico     FOREIGN KEY (idTecnico)     REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT CK_Reparacion_Costo   CHECK (costoManoObra >= 0),
    CONSTRAINT CK_Reparacion_Estado  CHECK (estado IN ('EN_PROCESO','FINALIZADA','CANCELADA')),
    CONSTRAINT CK_Reparacion_Fechas  CHECK (fechaFin IS NULL OR fechaFin >= fechaInicio),
    CONSTRAINT CK_Reparacion_FinalizadaConFecha CHECK (estado <> 'FINALIZADA' OR fechaFin IS NOT NULL)
);
GO

-- Entidad débil: actividades de una reparación (PK compuesta)
CREATE TABLE dbo.ActividadReparacion (
    idReparacion     INT           NOT NULL,
    numeroActividad  SMALLINT      NOT NULL,
    idTecnico        INT           NOT NULL,
    descripcion      NVARCHAR(300) NOT NULL,
    fechaActividad   DATETIME2(0)  NOT NULL CONSTRAINT DF_Actividad_Fecha DEFAULT (SYSDATETIME()),
    horas            DECIMAL(5,2)  NOT NULL,
    CONSTRAINT PK_ActividadReparacion PRIMARY KEY (idReparacion, numeroActividad),
    CONSTRAINT FK_Actividad_Reparacion FOREIGN KEY (idReparacion) REFERENCES dbo.Reparacion(idReparacion),
    CONSTRAINT FK_Actividad_Tecnico    FOREIGN KEY (idTecnico)    REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT CK_Actividad_Horas CHECK (horas > 0 AND horas <= 24)
);
GO

/* =========================================================
   5. CATÁLOGO DE REPUESTOS E INVENTARIO
   ========================================================= */
CREATE TABLE dbo.CategoriaRepuesto (
    idCategoria  INT IDENTITY(1,1) NOT NULL,
    nombre       NVARCHAR(60) NOT NULL,
    CONSTRAINT PK_CategoriaRepuesto PRIMARY KEY (idCategoria),
    CONSTRAINT UQ_CategoriaRepuesto_Nombre UNIQUE (nombre)
);
GO

CREATE TABLE dbo.Repuesto (
    idRepuesto       INT IDENTITY(1,1) NOT NULL,
    codigo           VARCHAR(30)   NOT NULL,
    nombre           NVARCHAR(120) NOT NULL,
    descripcion      NVARCHAR(300) NULL,
    idCategoria      INT           NOT NULL,
    precioCompraRef  DECIMAL(12,2) NOT NULL,       -- precio de referencia ACTUAL (no histórico)
    precioVenta      DECIMAL(12,2) NOT NULL,       -- precio de venta ACTUAL (no histórico)
    estado           VARCHAR(10)   NOT NULL CONSTRAINT DF_Repuesto_Estado DEFAULT ('ACTIVO'),
    CONSTRAINT PK_Repuesto PRIMARY KEY (idRepuesto),
    CONSTRAINT UQ_Repuesto_Codigo UNIQUE (codigo),
    CONSTRAINT FK_Repuesto_Categoria FOREIGN KEY (idCategoria) REFERENCES dbo.CategoriaRepuesto(idCategoria),
    CONSTRAINT CK_Repuesto_PrecioCompra CHECK (precioCompraRef >= 0),
    CONSTRAINT CK_Repuesto_PrecioVenta  CHECK (precioVenta >= 0),
    CONSTRAINT CK_Repuesto_Estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);
GO

CREATE TABLE dbo.Bodega (
    idBodega   INT IDENTITY(1,1) NOT NULL,
    codigo     VARCHAR(10)   NOT NULL,
    nombre     NVARCHAR(80)  NOT NULL,
    ubicacion  NVARCHAR(200) NULL,
    estado     VARCHAR(10)   NOT NULL CONSTRAINT DF_Bodega_Estado DEFAULT ('ACTIVA'),
    CONSTRAINT PK_Bodega PRIMARY KEY (idBodega),
    CONSTRAINT UQ_Bodega_Codigo UNIQUE (codigo),
    CONSTRAINT CK_Bodega_Estado CHECK (estado IN ('ACTIVA','INACTIVA'))
);
GO

-- N:M Bodega <-> Repuesto con atributos (PK compuesta). Solo la modifican los SP.
CREATE TABLE dbo.Inventario (
    idBodega               INT          NOT NULL,
    idRepuesto             INT          NOT NULL,
    existencia             INT          NOT NULL CONSTRAINT DF_Inventario_Existencia DEFAULT (0),
    stockMinimo            INT          NOT NULL CONSTRAINT DF_Inventario_StockMinimo DEFAULT (0),
    fechaUltimoMovimiento  DATETIME2(0) NULL,
    CONSTRAINT PK_Inventario PRIMARY KEY (idBodega, idRepuesto),
    CONSTRAINT FK_Inventario_Bodega   FOREIGN KEY (idBodega)   REFERENCES dbo.Bodega(idBodega),
    CONSTRAINT FK_Inventario_Repuesto FOREIGN KEY (idRepuesto) REFERENCES dbo.Repuesto(idRepuesto),
    CONSTRAINT CK_Inventario_Existencia  CHECK (existencia >= 0),     -- R10
    CONSTRAINT CK_Inventario_StockMinimo CHECK (stockMinimo >= 0)
);
GO

/* =========================================================
   6. PROVEEDORES Y COMPRAS
   ========================================================= */
CREATE TABLE dbo.Proveedor (
    idProveedor  INT IDENTITY(1,1) NOT NULL,
    nit          VARCHAR(15)   NOT NULL,
    nombre       NVARCHAR(150) NOT NULL,
    contacto     NVARCHAR(120) NULL,
    telefono     VARCHAR(20)   NULL,
    email        VARCHAR(120)  NULL,
    direccion    NVARCHAR(250) NULL,
    estado       VARCHAR(10)   NOT NULL CONSTRAINT DF_Proveedor_Estado DEFAULT ('ACTIVO'),
    CONSTRAINT PK_Proveedor PRIMARY KEY (idProveedor),
    CONSTRAINT UQ_Proveedor_Nit UNIQUE (nit),
    CONSTRAINT CK_Proveedor_Estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);
GO

CREATE TABLE dbo.Compra (
    idCompra            INT IDENTITY(1,1) NOT NULL,
    idProveedor         INT           NOT NULL,
    idBodegaDestino     INT           NOT NULL,
    numeroDocumento     VARCHAR(30)   NOT NULL,    -- número de factura/pedido del proveedor
    fechaCompra         DATETIME2(0)  NOT NULL CONSTRAINT DF_Compra_Fecha DEFAULT (SYSDATETIME()),
    estado              VARCHAR(10)   NOT NULL CONSTRAINT DF_Compra_Estado DEFAULT ('PENDIENTE'),
    idUsuarioRegistro   INT           NOT NULL,
    idUsuarioRecepcion  INT           NULL,
    fechaRecepcion      DATETIME2(0)  NULL,
    observaciones       NVARCHAR(300) NULL,
    CONSTRAINT PK_Compra PRIMARY KEY (idCompra),
    CONSTRAINT UQ_Compra_ProveedorDocumento UNIQUE (idProveedor, numeroDocumento),
    CONSTRAINT FK_Compra_Proveedor  FOREIGN KEY (idProveedor)        REFERENCES dbo.Proveedor(idProveedor),
    CONSTRAINT FK_Compra_Bodega     FOREIGN KEY (idBodegaDestino)    REFERENCES dbo.Bodega(idBodega),
    CONSTRAINT FK_Compra_Registro   FOREIGN KEY (idUsuarioRegistro)  REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT FK_Compra_Recepcion  FOREIGN KEY (idUsuarioRecepcion) REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT CK_Compra_Estado CHECK (estado IN ('PENDIENTE','RECIBIDA','ANULADA')),
    CONSTRAINT CK_Compra_Recepcion CHECK (
        (estado = 'RECIBIDA'  AND fechaRecepcion IS NOT NULL AND idUsuarioRecepcion IS NOT NULL) OR
        (estado <> 'RECIBIDA' AND fechaRecepcion IS NULL     AND idUsuarioRecepcion IS NULL)),
    CONSTRAINT CK_Compra_FechaRecepcion CHECK (fechaRecepcion IS NULL OR fechaRecepcion >= fechaCompra)
);
GO

-- N:M Compra <-> Repuesto (PK compuesta). costoUnitario = costo HISTÓRICO (R09).
CREATE TABLE dbo.DetalleCompra (
    idCompra       INT           NOT NULL,
    idRepuesto     INT           NOT NULL,
    cantidad       INT           NOT NULL,
    costoUnitario  DECIMAL(12,2) NOT NULL,
    CONSTRAINT PK_DetalleCompra PRIMARY KEY (idCompra, idRepuesto),
    CONSTRAINT FK_DetalleCompra_Compra   FOREIGN KEY (idCompra)   REFERENCES dbo.Compra(idCompra),
    CONSTRAINT FK_DetalleCompra_Repuesto FOREIGN KEY (idRepuesto) REFERENCES dbo.Repuesto(idRepuesto),
    CONSTRAINT CK_DetalleCompra_Cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_DetalleCompra_Costo    CHECK (costoUnitario >= 0)
);
GO

/* =========================================================
   7. REPUESTOS UTILIZADOS Y MOVIMIENTOS DE INVENTARIO
   ========================================================= */
-- N:M Reparacion <-> (Bodega,Repuesto). La FK compuesta a Inventario garantiza R06:
-- el repuesto debe existir EN LA BODEGA seleccionada.
CREATE TABLE dbo.DetalleRepuesto (
    idDetalleRepuesto  INT IDENTITY(1,1) NOT NULL,
    idReparacion       INT           NOT NULL,
    idBodega           INT           NOT NULL,
    idRepuesto         INT           NOT NULL,
    cantidad           INT           NOT NULL,
    precioUnitario     DECIMAL(12,2) NOT NULL,     -- precio de venta HISTÓRICO (congelado)
    costoUnitario      DECIMAL(12,2) NOT NULL,     -- costo de referencia HISTÓRICO
    idUsuario          INT           NOT NULL,
    fechaRegistro      DATETIME2(0)  NOT NULL CONSTRAINT DF_DetalleRepuesto_Fecha DEFAULT (SYSDATETIME()),
    estado             VARCHAR(10)   NOT NULL CONSTRAINT DF_DetalleRepuesto_Estado DEFAULT ('APLICADO'),
    CONSTRAINT PK_DetalleRepuesto PRIMARY KEY (idDetalleRepuesto),
    CONSTRAINT FK_DetalleRepuesto_Reparacion FOREIGN KEY (idReparacion)         REFERENCES dbo.Reparacion(idReparacion),
    CONSTRAINT FK_DetalleRepuesto_Inventario FOREIGN KEY (idBodega, idRepuesto) REFERENCES dbo.Inventario(idBodega, idRepuesto),
    CONSTRAINT FK_DetalleRepuesto_Usuario    FOREIGN KEY (idUsuario)            REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT CK_DetalleRepuesto_Cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_DetalleRepuesto_Precio   CHECK (precioUnitario >= 0 AND costoUnitario >= 0),
    CONSTRAINT CK_DetalleRepuesto_Estado   CHECK (estado IN ('APLICADO','DEVUELTO'))
);
GO

-- Kárdex inmutable: cada fila se verifica a sí misma (anterior +/- cantidad = resultante)
-- y apunta a su documento origen con FK reales (no un texto libre).
CREATE TABLE dbo.MovimientoInventario (
    idMovimiento          BIGINT IDENTITY(1,1) NOT NULL,
    idBodega              INT           NOT NULL,
    idRepuesto            INT           NOT NULL,
    tipo                  VARCHAR(7)    NOT NULL,   -- ENTRADA | SALIDA
    origen                VARCHAR(12)   NOT NULL,   -- COMPRA | REPARACION | DEVOLUCION | AJUSTE
    cantidad              INT           NOT NULL,
    existenciaAnterior    INT           NOT NULL,
    existenciaResultante  INT           NOT NULL,
    costoUnitario         DECIMAL(12,2) NULL,
    fechaMovimiento       DATETIME2(0)  NOT NULL CONSTRAINT DF_Movimiento_Fecha DEFAULT (SYSDATETIME()),
    idUsuario             INT           NOT NULL,
    idCompra              INT           NULL,       -- documento origen si origen = COMPRA
    idDetalleRepuesto     INT           NULL,       -- documento origen si origen = REPARACION / DEVOLUCION
    observacion           NVARCHAR(250) NULL,
    CONSTRAINT PK_MovimientoInventario PRIMARY KEY (idMovimiento),
    CONSTRAINT FK_Movimiento_Inventario      FOREIGN KEY (idBodega, idRepuesto) REFERENCES dbo.Inventario(idBodega, idRepuesto),
    CONSTRAINT FK_Movimiento_Usuario         FOREIGN KEY (idUsuario)            REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT FK_Movimiento_Compra          FOREIGN KEY (idCompra)             REFERENCES dbo.Compra(idCompra),
    CONSTRAINT FK_Movimiento_DetalleRepuesto FOREIGN KEY (idDetalleRepuesto)    REFERENCES dbo.DetalleRepuesto(idDetalleRepuesto),
    CONSTRAINT CK_Movimiento_Tipo     CHECK (tipo IN ('ENTRADA','SALIDA')),
    CONSTRAINT CK_Movimiento_Cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_Movimiento_Existencias CHECK (existenciaAnterior >= 0 AND existenciaResultante >= 0),
    CONSTRAINT CK_Movimiento_Cuadre CHECK (
        existenciaResultante = existenciaAnterior + CASE WHEN tipo = 'ENTRADA' THEN cantidad ELSE -cantidad END),
    CONSTRAINT CK_Movimiento_Origen CHECK (
        (origen = 'COMPRA'     AND tipo = 'ENTRADA' AND idCompra IS NOT NULL AND idDetalleRepuesto IS NULL) OR
        (origen = 'REPARACION' AND tipo = 'SALIDA'  AND idDetalleRepuesto IS NOT NULL AND idCompra IS NULL) OR
        (origen = 'DEVOLUCION' AND tipo = 'ENTRADA' AND idDetalleRepuesto IS NOT NULL AND idCompra IS NULL) OR
        (origen = 'AJUSTE'     AND idCompra IS NULL AND idDetalleRepuesto IS NULL AND observacion IS NOT NULL))
);
GO

/* =========================================================
   8. FACTURACIÓN Y PAGOS
   ========================================================= */
CREATE SEQUENCE dbo.seq_NumeroFactura AS INT START WITH 1 INCREMENT BY 1;
GO

-- R11: UNIQUE(idOrden) => una orden tiene 0 o 1 factura; una factura pertenece a una orden.
-- subtotal/impuesto/total son valores FISCALES congelados al emitir (documento legal, R09).
CREATE TABLE dbo.Factura (
    idFactura             INT IDENTITY(1,1) NOT NULL,
    idOrden               INT           NOT NULL,
    serie                 VARCHAR(5)    NOT NULL CONSTRAINT DF_Factura_Serie  DEFAULT ('A'),
    numero                INT           NOT NULL CONSTRAINT DF_Factura_Numero DEFAULT (NEXT VALUE FOR dbo.seq_NumeroFactura),
    fechaEmision          DATETIME2(0)  NOT NULL CONSTRAINT DF_Factura_Fecha  DEFAULT (SYSDATETIME()),
    nitFacturacion        VARCHAR(15)   NOT NULL,
    nombreFacturacion     NVARCHAR(150) NOT NULL,
    direccionFacturacion  NVARCHAR(250) NULL,
    subtotal              DECIMAL(12,2) NOT NULL,
    tasaImpuesto          DECIMAL(5,4)  NOT NULL CONSTRAINT DF_Factura_Tasa DEFAULT (0.12),   -- IVA 12 %
    impuesto              DECIMAL(12,2) NOT NULL,
    total                 DECIMAL(12,2) NOT NULL,
    estado                VARCHAR(10)   NOT NULL CONSTRAINT DF_Factura_Estado DEFAULT ('EMITIDA'),
    idUsuarioEmite        INT           NOT NULL,
    motivoAnulacion       NVARCHAR(250) NULL,
    CONSTRAINT PK_Factura PRIMARY KEY (idFactura),
    CONSTRAINT UQ_Factura_Orden UNIQUE (idOrden),
    CONSTRAINT UQ_Factura_SerieNumero UNIQUE (serie, numero),
    CONSTRAINT FK_Factura_Orden   FOREIGN KEY (idOrden)        REFERENCES dbo.OrdenServicio(idOrden),
    CONSTRAINT FK_Factura_Usuario FOREIGN KEY (idUsuarioEmite) REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT CK_Factura_Montos  CHECK (subtotal >= 0 AND impuesto >= 0),
    CONSTRAINT CK_Factura_Tasa    CHECK (tasaImpuesto BETWEEN 0 AND 1),
    CONSTRAINT CK_Factura_Total   CHECK (total = subtotal + impuesto),
    CONSTRAINT CK_Factura_Estado  CHECK (estado IN ('EMITIDA','ANULADA')),
    CONSTRAINT CK_Factura_Anulacion CHECK (estado <> 'ANULADA' OR motivoAnulacion IS NOT NULL)
);
GO

-- Entidad débil: líneas de la factura (PK compuesta). Permite separar mano de obra y repuestos (reporte 11).
CREATE TABLE dbo.DetalleFactura (
    idFactura          INT           NOT NULL,
    numeroLinea        SMALLINT      NOT NULL,
    tipoLinea          VARCHAR(10)   NOT NULL,     -- MANO_OBRA | REPUESTO
    descripcion        NVARCHAR(200) NOT NULL,
    cantidad           INT           NOT NULL,
    precioUnitario     DECIMAL(12,2) NOT NULL,
    subtotalLinea      AS (CAST(cantidad * precioUnitario AS DECIMAL(12,2))) PERSISTED,
    idDetalleRepuesto  INT           NULL,         -- trazabilidad: qué repuesto usado se está cobrando
    CONSTRAINT PK_DetalleFactura PRIMARY KEY (idFactura, numeroLinea),
    CONSTRAINT FK_DetalleFactura_Factura         FOREIGN KEY (idFactura)         REFERENCES dbo.Factura(idFactura),
    CONSTRAINT FK_DetalleFactura_DetalleRepuesto FOREIGN KEY (idDetalleRepuesto) REFERENCES dbo.DetalleRepuesto(idDetalleRepuesto),
    CONSTRAINT CK_DetalleFactura_Tipo     CHECK (tipoLinea IN ('MANO_OBRA','REPUESTO')),
    CONSTRAINT CK_DetalleFactura_Cantidad CHECK (cantidad > 0),
    CONSTRAINT CK_DetalleFactura_Precio   CHECK (precioUnitario >= 0),
    CONSTRAINT CK_DetalleFactura_Origen   CHECK (
        (tipoLinea = 'REPUESTO'  AND idDetalleRepuesto IS NOT NULL) OR
        (tipoLinea = 'MANO_OBRA' AND idDetalleRepuesto IS NULL))
);
GO

CREATE TABLE dbo.MetodoPago (
    idMetodoPago        INT IDENTITY(1,1) NOT NULL,
    nombre              VARCHAR(30) NOT NULL,
    requiereReferencia  BIT         NOT NULL CONSTRAINT DF_MetodoPago_Referencia DEFAULT (0),
    estado              VARCHAR(10) NOT NULL CONSTRAINT DF_MetodoPago_Estado DEFAULT ('ACTIVO'),
    CONSTRAINT PK_MetodoPago PRIMARY KEY (idMetodoPago),
    CONSTRAINT UQ_MetodoPago_Nombre UNIQUE (nombre),
    CONSTRAINT CK_MetodoPago_Estado CHECK (estado IN ('ACTIVO','INACTIVO'))
);
GO

-- R12/R13: el saldo NO se guarda; se calcula con dbo.fn_SaldoFactura.
CREATE TABLE dbo.Pago (
    idPago           INT IDENTITY(1,1) NOT NULL,
    idFactura        INT           NOT NULL,
    idMetodoPago     INT           NOT NULL,
    monto            DECIMAL(12,2) NOT NULL,
    fechaPago        DATETIME2(0)  NOT NULL CONSTRAINT DF_Pago_Fecha  DEFAULT (SYSDATETIME()),
    referencia       VARCHAR(60)   NULL,           -- no. de autorización, boleta, cheque
    idUsuarioCaja    INT           NOT NULL,
    estado           VARCHAR(10)   NOT NULL CONSTRAINT DF_Pago_Estado DEFAULT ('APLICADO'),
    motivoAnulacion  NVARCHAR(250) NULL,
    CONSTRAINT PK_Pago PRIMARY KEY (idPago),
    CONSTRAINT FK_Pago_Factura    FOREIGN KEY (idFactura)     REFERENCES dbo.Factura(idFactura),
    CONSTRAINT FK_Pago_MetodoPago FOREIGN KEY (idMetodoPago)  REFERENCES dbo.MetodoPago(idMetodoPago),
    CONSTRAINT FK_Pago_Usuario    FOREIGN KEY (idUsuarioCaja) REFERENCES dbo.Usuario(idUsuario),
    CONSTRAINT CK_Pago_Monto      CHECK (monto > 0),
    CONSTRAINT CK_Pago_Estado     CHECK (estado IN ('APLICADO','ANULADO')),
    CONSTRAINT CK_Pago_Anulacion  CHECK (estado <> 'ANULADO' OR motivoAnulacion IS NOT NULL)
);
GO

/* =========================================================
   9. ENTREGA Y AUDITORÍA
   ========================================================= */
CREATE TABLE dbo.Entrega (
    idEntrega         INT IDENTITY(1,1) NOT NULL,
    idOrden           INT           NOT NULL,
    idUsuarioEntrega  INT           NOT NULL,      -- quién entrega (empleado)
    nombreRecibe      NVARCHAR(120) NOT NULL,      -- quién recibe (cliente o autorizado)
    documentoRecibe   VARCHAR(20)   NULL,          -- DPI de quien recibe
    fechaEntrega      DATETIME2(0)  NOT NULL CONSTRAINT DF_Entrega_Fecha DEFAULT (SYSDATETIME()),
    observaciones     NVARCHAR(300) NULL,
    CONSTRAINT PK_Entrega PRIMARY KEY (idEntrega),
    CONSTRAINT UQ_Entrega_Orden UNIQUE (idOrden),
    CONSTRAINT FK_Entrega_Orden   FOREIGN KEY (idOrden)          REFERENCES dbo.OrdenServicio(idOrden),
    CONSTRAINT FK_Entrega_Usuario FOREIGN KEY (idUsuarioEntrega) REFERENCES dbo.Usuario(idUsuario)
);
GO

-- La llena trg_Repuesto_AuditoriaPrecio (archivo 31, dueño Fullstack/Infra)
CREATE TABLE dbo.AuditoriaPrecioRepuesto (
    idAuditoria           BIGINT IDENTITY(1,1) NOT NULL,
    idRepuesto            INT           NOT NULL,
    precioCompraAnterior  DECIMAL(12,2) NOT NULL,
    precioCompraNuevo     DECIMAL(12,2) NOT NULL,
    precioVentaAnterior   DECIMAL(12,2) NOT NULL,
    precioVentaNuevo      DECIMAL(12,2) NOT NULL,
    fechaCambio           DATETIME2(0)  NOT NULL CONSTRAINT DF_AuditoriaPrecio_Fecha DEFAULT (SYSDATETIME()),
    idUsuario             INT           NULL,
    usuarioBD             NVARCHAR(128) NOT NULL CONSTRAINT DF_AuditoriaPrecio_UsuarioBD DEFAULT (SUSER_SNAME()),
    CONSTRAINT PK_AuditoriaPrecioRepuesto PRIMARY KEY (idAuditoria),
    CONSTRAINT FK_AuditoriaPrecio_Repuesto FOREIGN KEY (idRepuesto) REFERENCES dbo.Repuesto(idRepuesto),
    CONSTRAINT FK_AuditoriaPrecio_Usuario  FOREIGN KEY (idUsuario)  REFERENCES dbo.Usuario(idUsuario)
);
GO

SET NOEXEC OFF;
GO
