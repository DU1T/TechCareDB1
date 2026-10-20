/* =====================================================================
   30_triggers_ordenes.sql  |  NÚCLEO (defiende: BACKEND)
   ---------------------------------------------------------------------
   trg_OrdenServicio_Estado  (AFTER INSERT, UPDATE, set-based)
     1. INSERT: la orden debe nacer en un estado inicial (RECIBIDO).
     2. UPDATE: la transición debe existir en TransicionEstado.
     3. ENTREGADO: exige registro de Entrega, factura sin saldo, y factura
        si hubo reparación finalizada (R16: aplica aunque se haga UPDATE desde SSMS).
     4. Registra el historial (R05) con el usuario de la aplicación.

   ¿Cómo sabe el trigger QUÉ usuario de la app hizo el cambio?
     El SP llama a dbo.sp_EstablecerContexto @idUsuario, @observacion, que guarda
     los valores en SESSION_CONTEXT. El trigger los lee. Si alguien actualiza
     directo desde SSMS, idUsuario queda NULL pero usuarioBD guarda el login SQL.
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO
CREATE OR ALTER TRIGGER dbo.trg_OrdenServicio_Estado
ON dbo.OrdenServicio
AFTER INSERT, UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF NOT EXISTS (SELECT 1 FROM inserted)
        RETURN;

    -- En un UPDATE que no toca la columna estado no hay nada que validar ni auditar
    IF EXISTS (SELECT 1 FROM deleted) AND NOT UPDATE(estado)
        RETURN;

    DECLARE @idUsuario   INT           = TRY_CAST(SESSION_CONTEXT(N'idUsuario')   AS INT);
    DECLARE @observacion NVARCHAR(300) = TRY_CAST(SESSION_CONTEXT(N'observacion') AS NVARCHAR(300));

    -- 1) INSERT: estado inicial obligatorio
    IF NOT EXISTS (SELECT 1 FROM deleted)
       AND EXISTS (SELECT 1
                   FROM inserted i
                   INNER JOIN dbo.EstadoOrden eo ON eo.codigo = i.estado
                   WHERE eo.esInicial = 0)
        THROW 51001, 'Una orden nueva debe iniciar en estado RECIBIDO.', 1;

    -- 2) UPDATE: transición permitida
    IF EXISTS (SELECT 1
               FROM inserted i
               INNER JOIN deleted d ON d.idOrden = i.idOrden
               WHERE i.estado <> d.estado
                 AND NOT EXISTS (SELECT 1
                                 FROM dbo.TransicionEstado t
                                 WHERE t.estadoOrigen = d.estado
                                   AND t.estadoDestino = i.estado))
        THROW 51002, 'Transición de estado no permitida para la orden.', 1;

    -- 3) ENTREGADO: reglas de cierre (R16)
    IF EXISTS (
        SELECT 1
        FROM inserted i
        INNER JOIN deleted d ON d.idOrden = i.idOrden
        WHERE i.estado = 'ENTREGADO'
          AND d.estado <> 'ENTREGADO'
          AND (
                -- falta el registro de entrega
                NOT EXISTS (SELECT 1 FROM dbo.Entrega en WHERE en.idOrden = i.idOrden)
                -- factura vigente con saldo pendiente
             OR EXISTS (SELECT 1 FROM dbo.Factura f
                        WHERE f.idOrden = i.idOrden
                          AND f.estado = 'EMITIDA'
                          AND dbo.fn_SaldoFactura(f.idFactura) > 0)
                -- hubo reparación finalizada pero no hay factura vigente
             OR (EXISTS (SELECT 1 FROM dbo.Diagnostico dg
                         INNER JOIN dbo.Reparacion r ON r.idDiagnostico = dg.idDiagnostico
                         WHERE dg.idOrden = i.idOrden AND r.estado = 'FINALIZADA')
                 AND NOT EXISTS (SELECT 1 FROM dbo.Factura f
                                 WHERE f.idOrden = i.idOrden AND f.estado = 'EMITIDA'))
          ))
        THROW 51003, 'No se puede entregar: falta el registro de entrega, la factura o existe saldo pendiente.', 1;

    -- 4) Historial set-based: funciona igual con 1 o con 10,000 filas
    INSERT INTO dbo.HistorialEstadoOrden (idOrden, estadoAnterior, estadoNuevo, idUsuario, observacion)
    SELECT i.idOrden, d.estado, i.estado, @idUsuario, @observacion
    FROM inserted i
    LEFT JOIN deleted d ON d.idOrden = i.idOrden
    WHERE d.idOrden IS NULL          -- INSERT
       OR i.estado <> d.estado;      -- UPDATE con cambio real
END;
GO

SET NOEXEC OFF;
GO
