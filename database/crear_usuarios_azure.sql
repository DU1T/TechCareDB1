/* =====================================================================
   crear_usuarios_azure.sql  |  Dueño: FULLSTACK/INFRA  |  Se ejecuta UNA vez
   ---------------------------------------------------------------------
   Crea los usuarios contenidos de la base compartida en Azure. Las
   contraseñas llegan como variables de sqlcmd: nunca se escriben aquí.
   No lo ejecute a mano: use crear_usuarios_azure.ps1, que las genera,
   las guarda en infra/credenciales_azure.txt (fuera de git) y luego
   aplica 91_seguridad_azure.sql.
   Si un usuario ya existe, no se toca (para cambiar su contraseña:
   ALTER USER dev_front WITH PASSWORD = N'...').
   NO tiene número de prefijo a propósito: el build nunca lo incluye.
   ===================================================================== */
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

IF DATABASE_PRINCIPAL_ID(N'techcare_app') IS NULL CREATE USER techcare_app WITH PASSWORD = N'$(CLAVE_APP)';
IF DATABASE_PRINCIPAL_ID(N'dev_front')    IS NULL CREATE USER dev_front    WITH PASSWORD = N'$(CLAVE_FRONT)';
IF DATABASE_PRINCIPAL_ID(N'dev_back')     IS NULL CREATE USER dev_back     WITH PASSWORD = N'$(CLAVE_BACK)';
IF DATABASE_PRINCIPAL_ID(N'dev_infra')    IS NULL CREATE USER dev_infra    WITH PASSWORD = N'$(CLAVE_INFRA)';
GO

SET NOEXEC OFF;
GO
