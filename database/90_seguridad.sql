/* =====================================================================
   90_seguridad.sql  |  Dueño: FULLSTACK/INFRA  |  Mínimo privilegio (clase 2)
   ---------------------------------------------------------------------
   El backend NO se conecta como sa. Usa techcare_app, que:
     - puede EJECUTAR procedimientos/funciones y LEER (vistas y tablas),
     - puede INSERT/UPDATE solo en tablas de mantenimiento (catálogos),
     - NO puede tocar directamente tablas transaccionales ni borrar nada.
   Los SP sí modifican esas tablas gracias al "ownership chaining"
   (SP y tablas pertenecen a dbo => no se revisan permisos de las tablas).
   Esto demuestra en la defensa que "el stock no se modifica desde una pantalla".
   CAMBIE la contraseña antes de ejecutar y no la suba a git.
   ===================================================================== */
USE master;
GO
IF SUSER_ID(N'techcare_app') IS NULL
    CREATE LOGIN techcare_app WITH PASSWORD = N'Cambiar_Esta_Clave_2026!', CHECK_POLICY = ON;
GO

USE TechCare;
GO
IF USER_ID(N'techcare_app') IS NULL
    CREATE USER techcare_app FOR LOGIN techcare_app;
GO
IF DATABASE_PRINCIPAL_ID(N'rol_app') IS NULL
    CREATE ROLE rol_app;
GO

GRANT EXECUTE ON SCHEMA::dbo TO rol_app;      -- SP y funciones escalares
GRANT SELECT  ON SCHEMA::dbo TO rol_app;      -- vistas, TVF y lecturas
GRANT EXECUTE ON TYPE::dbo.TipoDetalleCompra TO rol_app;

-- Mantenimientos permitidos (6.1)
GRANT INSERT, UPDATE ON dbo.Cliente           TO rol_app;
GRANT INSERT, UPDATE ON dbo.Equipo            TO rol_app;
GRANT INSERT, UPDATE ON dbo.Usuario           TO rol_app;
GRANT INSERT, DELETE ON dbo.UsuarioRol        TO rol_app;   -- quitar un rol es legítimo
GRANT INSERT, UPDATE ON dbo.Repuesto          TO rol_app;
GRANT INSERT, UPDATE ON dbo.CategoriaRepuesto TO rol_app;
GRANT INSERT, UPDATE ON dbo.Proveedor         TO rol_app;
GRANT INSERT, UPDATE ON dbo.Bodega            TO rol_app;
GRANT INSERT, UPDATE ON dbo.TipoEquipo        TO rol_app;
GRANT INSERT, UPDATE ON dbo.Marca             TO rol_app;
GRANT UPDATE (stockMinimo) ON dbo.Inventario  TO rol_app;   -- el mínimo sí se edita; la existencia NO

-- Prohibido escribir directo en lo transaccional (solo vía SP)
DENY INSERT, UPDATE, DELETE ON dbo.OrdenServicio        TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.HistorialEstadoOrden TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Diagnostico          TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Reparacion           TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.DetalleRepuesto      TO rol_app;
DENY INSERT, DELETE         ON dbo.Inventario           TO rol_app;
DENY UPDATE (existencia)    ON dbo.Inventario           TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.MovimientoInventario TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Compra               TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.DetalleCompra        TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Factura              TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.DetalleFactura       TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Pago                 TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Entrega              TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.AuditoriaPrecioRepuesto TO rol_app;
GO

ALTER ROLE rol_app ADD MEMBER techcare_app;
GO

/* Usuarios de desarrollo en la base compartida.
   Los LOGINS dev_front / dev_back / dev_infra se crean UNA vez en el servidor
   (ver guía, sección C · Día 0) y sobreviven a las reconstrucciones; los USUARIOS
   de la base se pierden con el DROP DATABASE, por eso se recrean aquí.
   dev_infra es sysadmin: ya entra como dbo, no necesita usuario. */
IF SUSER_ID(N'dev_front') IS NOT NULL AND USER_ID(N'dev_front') IS NULL
    CREATE USER dev_front FOR LOGIN dev_front;
IF SUSER_ID(N'dev_back') IS NOT NULL AND USER_ID(N'dev_back') IS NULL
    CREATE USER dev_back FOR LOGIN dev_back;
GO
IF USER_ID(N'dev_front') IS NOT NULL ALTER ROLE db_owner ADD MEMBER dev_front;
IF USER_ID(N'dev_back')  IS NOT NULL ALTER ROLE db_owner ADD MEMBER dev_back;
GO
