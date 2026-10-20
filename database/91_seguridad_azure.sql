/* =====================================================================
   91_seguridad_azure.sql  |  Dueño: FULLSTACK/INFRA  |  Solo Azure SQL Database
   ---------------------------------------------------------------------
   Roles y permisos de la base compartida. NO contiene contraseñas:
   los usuarios se crean UNA vez con crear_usuarios_azure.ps1.
   Se re-ejecuta en cada reconstrucción (reconstruir.ps1 -Azure lo hace),
   porque al borrar y recrear las tablas se pierden sus GRANT/DENY.

   Modelo de mínimo privilegio:
     tcadmin            administrador del servidor (dbo). Solo C, solo para
                        reconstruir, firewall y emergencias.
     dev_front/back/infra  rol_desarrollador: leer, escribir datos de prueba,
                        ejecutar, y CREAR/ALTERAR procedimientos, vistas,
                        funciones y triggers. Las tablas, índices, tipos y
                        cualquier DROP los bloquea trg_AuditoriaDDL (92):
                        el núcleo solo cambia con una reconstrucción.
     techcare_app       rol_app: el backend. Ejecuta SP y lee; escribe solo
                        en catálogos; nunca en tablas transaccionales.
   ===================================================================== */
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

/* ---------- Roles ---------- */
IF DATABASE_PRINCIPAL_ID(N'rol_app') IS NULL
    CREATE ROLE rol_app;
IF DATABASE_PRINCIPAL_ID(N'rol_desarrollador') IS NULL
    CREATE ROLE rol_desarrollador;
GO

/* ---------- rol_desarrollador ---------- */
ALTER ROLE db_ddladmin   ADD MEMBER rol_desarrollador;   -- CREATE/ALTER de objetos (filtrado por el trigger DDL)
ALTER ROLE db_datareader ADD MEMBER rol_desarrollador;
ALTER ROLE db_datawriter ADD MEMBER rol_desarrollador;   -- pruebas y demostraciones (R16)
GRANT EXECUTE             ON SCHEMA::dbo TO rol_desarrollador;
GRANT VIEW DEFINITION     ON SCHEMA::dbo TO rol_desarrollador;
GRANT VIEW DATABASE STATE TO rol_desarrollador;           -- diagnosticar bloqueos
GRANT SHOWPLAN            TO rol_desarrollador;           -- planes de ejecución (defensa de índices)
GO

/* ---------- rol_app (backend) ---------- */
GRANT EXECUTE ON SCHEMA::dbo TO rol_app;      -- SP y funciones escalares
GRANT SELECT  ON SCHEMA::dbo TO rol_app;      -- vistas, TVF y lecturas
GRANT EXECUTE ON TYPE::dbo.TipoDetalleCompra TO rol_app;

-- Mantenimientos permitidos (6.1 del enunciado)
GRANT INSERT, UPDATE ON dbo.Cliente           TO rol_app;
GRANT INSERT, UPDATE ON dbo.Equipo            TO rol_app;
GRANT INSERT, UPDATE ON dbo.Usuario           TO rol_app;
GRANT INSERT, DELETE ON dbo.UsuarioRol        TO rol_app;
GRANT INSERT, UPDATE ON dbo.Repuesto          TO rol_app;
GRANT INSERT, UPDATE ON dbo.CategoriaRepuesto TO rol_app;
GRANT INSERT, UPDATE ON dbo.Proveedor         TO rol_app;
GRANT INSERT, UPDATE ON dbo.Bodega            TO rol_app;
GRANT INSERT, UPDATE ON dbo.TipoEquipo        TO rol_app;
GRANT INSERT, UPDATE ON dbo.Marca             TO rol_app;
GRANT UPDATE (stockMinimo) ON dbo.Inventario  TO rol_app;

-- Prohibido escribir directo en lo transaccional (solo vía SP, por ownership chaining)
DENY INSERT, UPDATE, DELETE ON dbo.OrdenServicio           TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.HistorialEstadoOrden    TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Diagnostico             TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Reparacion              TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.DetalleRepuesto         TO rol_app;
DENY INSERT, DELETE         ON dbo.Inventario              TO rol_app;
DENY UPDATE (existencia)    ON dbo.Inventario              TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.MovimientoInventario    TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Compra                  TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.DetalleCompra           TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Factura                 TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.DetalleFactura          TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Pago                    TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.Entrega                 TO rol_app;
DENY INSERT, UPDATE, DELETE ON dbo.AuditoriaPrecioRepuesto TO rol_app;
GO

/* ---------- Membresías (solo si los usuarios ya existen) ---------- */
IF USER_ID(N'techcare_app') IS NOT NULL ALTER ROLE rol_app           ADD MEMBER techcare_app;
IF USER_ID(N'dev_front')    IS NOT NULL ALTER ROLE rol_desarrollador ADD MEMBER dev_front;
IF USER_ID(N'dev_back')     IS NOT NULL ALTER ROLE rol_desarrollador ADD MEMBER dev_back;
IF USER_ID(N'dev_infra')    IS NOT NULL ALTER ROLE rol_desarrollador ADD MEMBER dev_infra;
GO

-- Resumen: quién está en qué rol
SELECT r.name AS rol, m.name AS miembro
FROM sys.database_role_members drm
JOIN sys.database_principals r ON r.principal_id = drm.role_principal_id
JOIN sys.database_principals m ON m.principal_id = drm.member_principal_id
WHERE r.name IN (N'rol_app', N'rol_desarrollador', N'db_ddladmin', N'db_datareader', N'db_datawriter')
ORDER BY r.name, m.name;
GO

SET NOEXEC OFF;
GO
