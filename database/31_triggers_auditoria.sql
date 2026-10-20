/* =====================================================================
   31_triggers_auditoria.sql  |  Dueño: FULLSTACK/INFRA   (códigos 51010-51099)
   ---------------------------------------------------------------------
   TODO dbo.trg_Repuesto_AuditoriaPrecio   AFTER UPDATE ON dbo.Repuesto   (4.2, T14)
     set-based: INSERT INTO AuditoriaPrecioRepuesto ... FROM inserted i JOIN deleted d
     WHERE i.precioVenta <> d.precioVenta OR i.precioCompraRef <> d.precioCompraRef
     idUsuario = TRY_CAST(SESSION_CONTEXT(N'idUsuario') AS INT)

   TODO dbo.trg_MovimientoInventario_Inmutable  INSTEAD OF UPDATE, DELETE   (R14)
     THROW 51010, 'Los movimientos de inventario no se modifican ni eliminan; registre un ajuste.', 1;

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

SET NOEXEC OFF;
GO
