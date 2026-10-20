/* =====================================================================
   04_tipos.sql  |  NÚCLEO  |  Tipos de tabla (Table-Valued Parameters)
   ---------------------------------------------------------------------
   Permiten enviar el detalle completo de una compra en UNA llamada al SP,
   así el encabezado y todas sus líneas se guardan en la misma transacción.
   Desde .NET (Dapper):  dt.AsTableValuedParameter("dbo.TipoDetalleCompra")
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
CREATE TYPE dbo.TipoDetalleCompra AS TABLE (
    idRepuesto     INT           NOT NULL PRIMARY KEY,   -- un repuesto una sola vez por compra
    cantidad       INT           NOT NULL CHECK (cantidad > 0),
    costoUnitario  DECIMAL(12,2) NOT NULL CHECK (costoUnitario >= 0)
);
GO

SET NOEXEC OFF;
GO
