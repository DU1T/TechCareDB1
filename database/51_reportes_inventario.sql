/* =====================================================================
   51_reportes_inventario.sql  |  Dueño: FULLSTACK/INFRA  |  Reportes 5, 6, 7, 8, 9
   ---------------------------------------------------------------------
   Cada reporte = un SP dbo.sp_Reporte_NN_<Nombre> con parámetros de filtro
   opcionales (@fechaInicio, @fechaFin, @idCliente, @idTecnico, @idBodega...).
   Reglas del enunciado (5.1): sin SELECT *, sin DISTINCT para tapar duplicados,
   alias legibles, LEFT JOIN donde la información es opcional.
   Patrón de filtro opcional:  WHERE (@idTecnico IS NULL OR d.idTecnico = @idTecnico)
   Ver la tabla de reportes en el plan, sección 7.
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

SET NOEXEC OFF;
GO
