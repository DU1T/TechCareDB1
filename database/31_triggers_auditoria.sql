/* =====================================================================
   31_triggers_auditoria.sql  |  Dueño: FULLSTACK/INFRA   (códigos 51010-51099)
   ---------------------------------------------------------------------
   dbo.trg_Repuesto_AuditoriaPrecio   AFTER UPDATE ON dbo.Repuesto   (4.2, T14)
     set-based: INSERT INTO AuditoriaPrecioRepuesto ... FROM inserted i JOIN deleted d
     WHERE i.precioVenta <> d.precioVenta OR i.precioCompraRef <> d.precioCompraRef
     idUsuario = TRY_CAST(SESSION_CONTEXT(N'idUsuario') AS INT)

   dbo.trg_MovimientoInventario_Inmutable  INSTEAD OF UPDATE, DELETE   (R14)
     THROW 51010, 'Los movimientos de inventario no se modifican ni eliminan; registre un ajuste.', 1;

   dbo.trg_Pago_NoExcedeTotal  AFTER INSERT, UPDATE ON dbo.Pago   (R12, R16)
     THROW 51011 si en una factura afectada fn_TotalPagado > total (pago directo en SQL)

   (Opcional) trg_Pago_NoEliminar / trg_Factura_NoEliminar  INSTEAD OF DELETE   (R14)
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

-- T14: un cambio de precio queda auditado; las facturas y detalles viejos no cambian (precios históricos)
CREATE OR ALTER TRIGGER dbo.trg_Repuesto_AuditoriaPrecio
ON dbo.Repuesto
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(precioVenta) OR UPDATE(precioCompraRef)) RETURN;

    -- Set-based: un UPDATE de 20 repuestos deja 20 filas
    INSERT INTO dbo.AuditoriaPrecioRepuesto
        (idRepuesto, precioCompraAnterior, precioCompraNuevo, precioVentaAnterior, precioVentaNuevo, idUsuario)
    SELECT i.idRepuesto, d.precioCompraRef, i.precioCompraRef, d.precioVenta, i.precioVenta,
           TRY_CAST(SESSION_CONTEXT(N'idUsuario') AS INT)
    FROM inserted i
    INNER JOIN deleted d ON d.idRepuesto = i.idRepuesto
    WHERE i.precioVenta <> d.precioVenta
       OR i.precioCompraRef <> d.precioCompraRef;
END;
GO

-- R14: el kárdex no se edita ni se borra; se corrige con un ajuste
CREATE OR ALTER TRIGGER dbo.trg_MovimientoInventario_Inmutable
ON dbo.MovimientoInventario
INSTEAD OF UPDATE, DELETE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT EXISTS (SELECT 1 FROM deleted) RETURN;
    THROW 51010, 'Los movimientos de inventario no se modifican ni eliminan; registre un ajuste.', 1;
END;
GO

-- R12/R16: la suma de pagos aplicados nunca supera el total de la factura, aunque el pago se
-- inserte o modifique directo en SQL (sp_RegistrarPago ya lo valida; esto cubre todo lo demás)
CREATE OR ALTER TRIGGER dbo.trg_Pago_NoExcedeTotal
ON dbo.Pago
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;
    IF NOT (UPDATE(monto) OR UPDATE(estado) OR UPDATE(idFactura)) RETURN;   -- p. ej. solo cambia la fecha

    -- Set-based: revisa cada factura afectada por las filas insertadas o modificadas
    IF EXISTS (
        SELECT 1
        FROM dbo.Factura f
        WHERE f.idFactura IN (SELECT i.idFactura FROM inserted i)
          AND dbo.fn_TotalPagado(f.idFactura) > f.total)
        THROW 51011, 'La suma de los pagos aplicados no puede exceder el total de la factura (R12).', 1;
END;
GO

SET NOEXEC OFF;
GO
