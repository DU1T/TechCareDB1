/* =====================================================================
   limpiar_base.sql  |  Dueño: FULLSTACK/INFRA  |  Sobre todo para Azure SQL
   ---------------------------------------------------------------------
   Elimina TODOS los objetos de la base a la que está conectado (tablas,
   vistas, SP, funciones, tipos, secuencias y el trigger DDL), dejándola vacía
   para volver a ejecutar el master. En Azure equivale al DROP DATABASE que
   hace 01_base_datos.sql en un servidor local. Conserva usuarios y roles.
   NO tiene número de prefijo a propósito: el build nunca lo incluye.
   ===================================================================== */
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

IF EXISTS (SELECT 1 FROM sys.triggers WHERE parent_class = 0 AND name = N'trg_AuditoriaDDL')
    DROP TRIGGER trg_AuditoriaDDL ON DATABASE;
GO

DECLARE @sql NVARCHAR(MAX);

-- 1. Llaves foráneas (así las tablas se pueden borrar en cualquier orden)
SELECT @sql = STRING_AGG(CAST(N'ALTER TABLE ' + QUOTENAME(OBJECT_SCHEMA_NAME(fk.parent_object_id)) + N'.'
            + QUOTENAME(OBJECT_NAME(fk.parent_object_id)) + N' DROP CONSTRAINT ' + QUOTENAME(fk.name) + N';'
            AS NVARCHAR(MAX)), NCHAR(10))
FROM sys.foreign_keys fk;
IF @sql IS NOT NULL EXEC sys.sp_executesql @sql;

-- 2. Vistas, procedimientos, funciones y tablas (los triggers DML caen con su tabla)
SELECT @sql = STRING_AGG(CAST(N'DROP '
            + CASE o.type WHEN 'V' THEN N'VIEW' WHEN 'P' THEN N'PROCEDURE' WHEN 'U' THEN N'TABLE' ELSE N'FUNCTION' END
            + N' ' + QUOTENAME(SCHEMA_NAME(o.schema_id)) + N'.' + QUOTENAME(o.name) + N';' AS NVARCHAR(MAX)), NCHAR(10))
       WITHIN GROUP (ORDER BY CASE o.type WHEN 'V' THEN 1 WHEN 'P' THEN 2 WHEN 'U' THEN 4 ELSE 3 END)
FROM sys.objects o
WHERE o.type IN ('V', 'P', 'FN', 'IF', 'TF', 'U')
  AND o.is_ms_shipped = 0;
IF @sql IS NOT NULL EXEC sys.sp_executesql @sql;

-- 3. Tipos de tabla y secuencias
SELECT @sql = STRING_AGG(CAST(N'DROP TYPE ' + QUOTENAME(SCHEMA_NAME(t.schema_id)) + N'.' + QUOTENAME(t.name) + N';'
            AS NVARCHAR(MAX)), NCHAR(10))
FROM sys.types t
WHERE t.is_user_defined = 1;
IF @sql IS NOT NULL EXEC sys.sp_executesql @sql;

SELECT @sql = STRING_AGG(CAST(N'DROP SEQUENCE ' + QUOTENAME(SCHEMA_NAME(s.schema_id)) + N'.' + QUOTENAME(s.name) + N';'
            AS NVARCHAR(MAX)), NCHAR(10))
FROM sys.sequences s;
IF @sql IS NOT NULL EXEC sys.sp_executesql @sql;

SELECT COUNT(*) AS objetosRestantes
FROM sys.objects
WHERE is_ms_shipped = 0 AND type IN ('U', 'V', 'P', 'FN', 'IF', 'TF', 'SO');
GO

SET NOEXEC OFF;
GO
