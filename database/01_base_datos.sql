/* =====================================================================
   TechCare Solutions - Sistema Integral de Servicio Técnico
   01_base_datos.sql  |  Dueño: Fullstack/Infra  |  NÚCLEO (no modificar sin acuerdo)
   ---------------------------------------------------------------------
   Crea la base de datos desde cero.
   ¡CUIDADO! Elimina la base si ya existe. En el servidor compartido solo
   lo ejecuta el responsable de infraestructura y avisa al equipo antes.
   Para una base personal NO edite este archivo: genere el master con
     ./build_master.sh --db TechCare_<nombre>     (Windows: pwsh ./build_master.ps1 -Db TechCare_<nombre>)
   En Azure SQL Database este archivo se omite (la base se crea en el portal):
     ./build_master.sh --azure
   ===================================================================== */
USE master;
GO

IF DB_ID(N'TechCare') IS NOT NULL
BEGIN
    ALTER DATABASE TechCare SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE TechCare;
END
GO

CREATE DATABASE TechCare COLLATE Modern_Spanish_CI_AS;
GO

USE TechCare;
GO
