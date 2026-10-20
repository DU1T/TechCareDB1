/* =====================================================================
   92_auditoria_ddl.sql  |  Dueño: FULLSTACK/INFRA  |  Solo bases de DESARROLLO
   ---------------------------------------------------------------------
   1. PROTEGE el núcleo: un usuario que no es db_owner (dev_front, dev_back,
      dev_infra en Azure) solo puede CREAR/ALTERAR procedimientos, vistas,
      funciones y triggers. Tablas, índices, tipos, secuencias y cualquier
      DROP se rechazan (error 51090): eso solo cambia con una reconstrucción
      que hace C con tcadmin.
   2. REGISTRA cada CREATE / ALTER / DROP permitido: quién, cuándo, desde qué
      máquina y la sentencia completa. Responde "¿quién cambió este SP y cuándo?"
      en la base compartida. No forma parte del script maestro (no se cuenta
   como uno de los triggers del enunciado), pero sí pueden mostrarlo.
   Funciona igual en SQL Server local/VM y en Azure SQL Database.
   Se vuelve a ejecutar después de cada reconstrucción (reconstruir.ps1 lo hace).
   Consultas útiles:
     SELECT TOP (50) fecha, usuarioBD, evento, objeto FROM dbo.AuditoriaDDL ORDER BY idEvento DESC;
     SELECT objeto, MAX(fecha) AS ultimoCambio FROM dbo.AuditoriaDDL GROUP BY objeto ORDER BY ultimoCambio DESC;
   ===================================================================== */
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

IF OBJECT_ID(N'dbo.AuditoriaDDL', N'U') IS NULL
CREATE TABLE dbo.AuditoriaDDL (
    idEvento   BIGINT IDENTITY(1,1) NOT NULL,
    fecha      DATETIME2(0)  NOT NULL CONSTRAINT DF_AuditoriaDDL_Fecha   DEFAULT (SYSDATETIME()),
    usuarioBD  NVARCHAR(128) NOT NULL CONSTRAINT DF_AuditoriaDDL_Usuario DEFAULT (SUSER_SNAME()),
    host       NVARCHAR(128) NULL     CONSTRAINT DF_AuditoriaDDL_Host    DEFAULT (HOST_NAME()),
    evento     NVARCHAR(100) NOT NULL,
    objeto     NVARCHAR(260) NULL,
    sentencia  NVARCHAR(MAX) NULL,
    CONSTRAINT PK_AuditoriaDDL PRIMARY KEY (idEvento)
);
GO

CREATE OR ALTER TRIGGER trg_AuditoriaDDL
ON DATABASE
FOR DDL_DATABASE_LEVEL_EVENTS
AS
BEGIN
    SET NOCOUNT ON;
    DECLARE @e XML = EVENTDATA();
    DECLARE @evento NVARCHAR(100) = @e.value('(/EVENT_INSTANCE/EventType)[1]', 'NVARCHAR(100)');

    -- Protección del núcleo: los desarrolladores solo tocan objetos de lógica
    IF IS_MEMBER('db_owner') = 0
       AND @evento NOT IN (N'CREATE_PROCEDURE', N'ALTER_PROCEDURE',
                           N'CREATE_FUNCTION',  N'ALTER_FUNCTION',
                           N'CREATE_VIEW',      N'ALTER_VIEW',
                           N'CREATE_TRIGGER',   N'ALTER_TRIGGER')
        THROW 51090, 'Cambio de estructura bloqueado: tablas, índices, tipos y DROP solo se cambian con una reconstrucción (protocolo 2.6).', 1;

    INSERT INTO dbo.AuditoriaDDL (evento, objeto, sentencia)
    VALUES (
        @evento,
        CONCAT_WS(N'.', @e.value('(/EVENT_INSTANCE/SchemaName)[1]', 'NVARCHAR(128)'),
                        @e.value('(/EVENT_INSTANCE/ObjectName)[1]', 'NVARCHAR(128)')),
        @e.value('(/EVENT_INSTANCE/TSQLCommand/CommandText)[1]', 'NVARCHAR(MAX)')
    );
END;
GO

SET NOEXEC OFF;
GO
