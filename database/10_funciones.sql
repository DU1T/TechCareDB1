/* =====================================================================
   10_funciones.sql  |  NÚCLEO  |  Funciones (cálculo, sin efectos secundarios)
   ---------------------------------------------------------------------
   FUNCTION = "dame una respuesta". No inserta, no actualiza, no usa transacciones.
   Defensa: fn_SaldoFactura / fn_TotalPagado -> Frontend (dominio facturación)
            fn_TotalOrden                     -> Frontend (dominio facturación)
            fn_UsuarioTieneRol                -> Backend  (dominio órdenes, R03)
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
-- Suma de pagos APLICADOS de una factura. 0 si no hay pagos (laboratorio clase 2).
CREATE OR ALTER FUNCTION dbo.fn_TotalPagado (@idFactura INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @pagado DECIMAL(12,2);

    SELECT @pagado = SUM(p.monto)
    FROM dbo.Pago p
    WHERE p.idFactura = @idFactura
      AND p.estado = 'APLICADO';

    RETURN ISNULL(@pagado, 0);
END;
GO

-- R13: saldo calculado, nunca guardado. Factura anulada o inexistente => 0.
CREATE OR ALTER FUNCTION dbo.fn_SaldoFactura (@idFactura INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @total DECIMAL(12,2);

    SELECT @total = f.total
    FROM dbo.Factura f
    WHERE f.idFactura = @idFactura
      AND f.estado = 'EMITIDA';

    IF @total IS NULL
        RETURN 0;

    RETURN @total - dbo.fn_TotalPagado(@idFactura);
END;
GO

-- Subtotal de una orden (ANTES de impuestos): mano de obra de la reparación
-- + repuestos aplicados a precio HISTÓRICO (DetalleRepuesto.precioUnitario, no Repuesto.precioVenta).
-- Lo usa sp_FacturarOrden y los reportes.
CREATE OR ALTER FUNCTION dbo.fn_TotalOrden (@idOrden INT)
RETURNS DECIMAL(12,2)
AS
BEGIN
    DECLARE @manoObra  DECIMAL(12,2) = 0;
    DECLARE @repuestos DECIMAL(12,2) = 0;

    SELECT @manoObra = r.costoManoObra
    FROM dbo.Diagnostico d
    INNER JOIN dbo.Reparacion r ON r.idDiagnostico = d.idDiagnostico
    WHERE d.idOrden = @idOrden
      AND r.estado <> 'CANCELADA';

    SELECT @repuestos = ISNULL(SUM(dr.cantidad * dr.precioUnitario), 0)
    FROM dbo.Diagnostico d
    INNER JOIN dbo.Reparacion r       ON r.idDiagnostico = d.idDiagnostico
    INNER JOIN dbo.DetalleRepuesto dr ON dr.idReparacion = r.idReparacion
    WHERE d.idOrden = @idOrden
      AND dr.estado = 'APLICADO';

    RETURN ISNULL(@manoObra, 0) + @repuestos;
END;
GO

-- R03: ¿el usuario está activo y tiene el rol (o es ADMINISTRADOR)? 1 = sí, 0 = no.
CREATE OR ALTER FUNCTION dbo.fn_UsuarioTieneRol (@idUsuario INT, @rol VARCHAR(30))
RETURNS BIT
AS
BEGIN
    IF EXISTS (
        SELECT 1
        FROM dbo.Usuario u
        INNER JOIN dbo.UsuarioRol ur ON ur.idUsuario = u.idUsuario
        INNER JOIN dbo.Rol r         ON r.idRol = ur.idRol
        WHERE u.idUsuario = @idUsuario
          AND u.estado = 'ACTIVO'
          AND r.nombre IN (@rol, 'ADMINISTRADOR'))
        RETURN 1;

    RETURN 0;
END;
GO

SET NOEXEC OFF;
GO
