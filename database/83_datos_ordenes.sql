/* =====================================================================
   83_datos_ordenes.sql  |  Dueño: BACKEND
   ---------------------------------------------------------------------
   Requiere 80-82 (usuarios e inventario con existencias).
   - 60+ órdenes con sp_RegistrarOrdenServicio, en todos los estados (una CANCELADA con motivo).
   - 45+ diagnósticos; dejar órdenes SIN diagnóstico; autorizaciones, algunas rechazadas.
   - 35+ reparaciones con y sin repuestos; una con 3+ repuestos (sp_UtilizarRepuesto);
     una orden diagnosticada pero no reparada.
   - Un equipo con 3+ órdenes: la anterior debe quedar ENTREGADA/CANCELADA antes de
     abrir la siguiente (sp_RegistrarOrdenServicio no permite dos abiertas).
   Recuperar ids: SELECT @idOrden = MAX(idOrden) FROM dbo.OrdenServicio WHERE idEquipo = @idEquipo;
   ---------------------------------------------------------------------
   Los datos de prueba se reparten en 6 archivos, uno por dueño; el build los
   une EN ESTE ORDEN en TechCare_DatosPrueba.sql (entregable 03):
     80_datos_usuarios.sql     B  10+ usuarios con hash real y sus roles (los genera el backend)
     81_datos_maestros.sql     C  clientes, equipos, repuestos, inventario (stockMinimo), proveedores
     82_datos_compras.sql      C  20+ compras vía SP (17 recibidas, 3+ PENDIENTES)
     83_datos_ordenes.sql      B  60+ órdenes, 45+ diagnósticos, 35+ reparaciones, repuestos usados
     84_datos_facturacion.sql  A  30+ facturas, 40+ pagos, entregas
     85_datos_escenarios.sql   C  fechas repartidas, escenarios de la defensa y verificación de mínimos
   REGLA DE ORO: todo lo transaccional se crea LLAMANDO A LOS SP. Si un SP falla
   al generar datos, encontraron un bug antes que el profesor.
   Para recuperar el id que crea un SP, búsquelo después por su llave de negocio
   (no use INSERT ... EXEC con SP que tienen transacción: falla con el error 3915).
   ===================================================================== */
-- Se ejecuta sobre la base a la que esté conectado: TechCare, TechCare_<nombre> o Azure.
-- Si está en otra base (p. ej. master) se detiene sin crear nada.
IF DB_NAME() NOT LIKE N'TechCare%'
BEGIN
    RAISERROR(N'Conéctese primero a una base TechCare o TechCare_<nombre>. Script detenido.', 16, 1);
    SET NOEXEC ON;
END
GO

-- ============================================================
-- PASO 103: Validaciones previas a la carga de órdenes
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @idRecepcion1 INT;
DECLARE @idRecepcion2 INT;
DECLARE @idTecnico1 INT;
DECLARE @idTecnico2 INT;

-- Recuperar usuarios por username, sin depender de IDs fijos
SELECT @idRecepcion1 = idUsuario
FROM dbo.Usuario
WHERE username = 'recepcion1'
  AND estado = 'ACTIVO';

SELECT @idRecepcion2 = idUsuario
FROM dbo.Usuario
WHERE username = 'recepcion2'
  AND estado = 'ACTIVO';

SELECT @idTecnico1 = idUsuario
FROM dbo.Usuario
WHERE username = 'tecnico1'
  AND estado = 'ACTIVO';

SELECT @idTecnico2 = idUsuario
FROM dbo.Usuario
WHERE username = 'tecnico2'
  AND estado = 'ACTIVO';

-- Verificar los usuarios requeridos
IF @idRecepcion1 IS NULL
   OR @idRecepcion2 IS NULL
   OR @idTecnico1 IS NULL
   OR @idTecnico2 IS NULL
BEGIN
    THROW 52001,
        'Faltan usuarios activos necesarios para generar los datos de ordenes.',
        1;
END;

-- Verificar datos maestros y compras
IF (SELECT COUNT(*) FROM dbo.Equipo) < 60
   OR (SELECT COUNT(*) FROM dbo.Cliente) < 30
   OR (SELECT COUNT(*) FROM dbo.Compra) < 20
   OR (SELECT COUNT(*) FROM dbo.Repuesto) < 30
BEGIN
    THROW 52002,
        'Faltan datos maestros o compras. Ejecute primero los scripts 80, 81 y 82.',
        1;
END;

-- Evitar ejecutar accidentalmente el generador dos veces
IF EXISTS (SELECT 1 FROM dbo.OrdenServicio)
BEGIN
    THROW 52003,
        'Ya existen ordenes. Use una base de prueba recien reconstruida.',
        1;
END;

PRINT 'PASO 103 OK: usuarios y datos maestros validados.';

SELECT
    @idRecepcion1 AS idRecepcion1,
    @idRecepcion2 AS idRecepcion2,
    @idTecnico1 AS idTecnico1,
    @idTecnico2 AS idTecnico2;
GO

-- ============================================================
-- PASO 104: Crear 62 ordenes de servicio
-- 60 ordenes principales y 2 cancelaciones previas
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @recepcion1 INT;
DECLARE @recepcion2 INT;
DECLARE @idRecepcion INT;
DECLARE @idEquipo INT;
DECLARE @idOrden INT;
DECLARE @numeroSerie VARCHAR(60);
DECLARE @prioridad VARCHAR(10);
DECLARE @i INT;

SELECT @recepcion1 = idUsuario
FROM dbo.Usuario
WHERE username = 'recepcion1';

SELECT @recepcion2 = idUsuario
FROM dbo.Usuario
WHERE username = 'recepcion2';

IF @recepcion1 IS NULL OR @recepcion2 IS NULL
    THROW 52010, 'No se encontraron los usuarios de recepcion.', 1;

IF EXISTS (SELECT 1 FROM dbo.OrdenServicio)
    THROW 52011, 'Ya existen ordenes. No repetir esta carga.', 1;

-- 1. Crear dos visitas anteriores canceladas
SELECT @idEquipo = idEquipo
FROM dbo.Equipo
WHERE numeroSerie = 'SN-00001';

IF @idEquipo IS NULL
    THROW 52012, 'No existe el equipo SN-00001.', 1;

SET @i = 1;

WHILE @i <= 2
BEGIN
    EXEC dbo.sp_RegistrarOrdenServicio
        @idEquipo = @idEquipo,
        @idUsuarioRecepcion = @recepcion1,
        @problemaReportado =
            N'Falla intermitente reportada por el cliente.',
        @prioridad = 'BAJA',
        @observaciones =
            N'Visita anterior cancelada por solicitud del cliente.';

    SELECT @idOrden = MAX(idOrden)
    FROM dbo.OrdenServicio
    WHERE idEquipo = @idEquipo;

    EXEC dbo.sp_CambiarEstadoOrden
        @idOrden = @idOrden,
        @estadoNuevo = 'CANCELADO',
        @idUsuario = @recepcion1,
        @observacion =
            N'El cliente solicito cancelar el servicio.';

    SET @i += 1;
END;

-- 2. Crear 60 ordenes principales
SET @i = 1;

WHILE @i <= 60
BEGIN
    SET @numeroSerie =
        CONCAT('SN-', RIGHT(CONCAT('00000', @i), 5));

    SET @idEquipo = NULL;

    SELECT @idEquipo = idEquipo
    FROM dbo.Equipo
    WHERE numeroSerie = @numeroSerie;

    IF @idEquipo IS NULL
        THROW 52013, 'No se encontro uno de los equipos.', 1;

    SET @idRecepcion =
        CASE WHEN @i % 2 = 0
             THEN @recepcion2
             ELSE @recepcion1
        END;

    SET @prioridad =
        CASE @i % 4
            WHEN 0 THEN 'URGENTE'
            WHEN 1 THEN 'BAJA'
            WHEN 2 THEN 'MEDIA'
            ELSE 'ALTA'
        END;

    EXEC dbo.sp_RegistrarOrdenServicio
        @idEquipo = @idEquipo,
        @idUsuarioRecepcion = @idRecepcion,
        @problemaReportado =
            N'Equipo presenta fallas de funcionamiento, rendimiento o encendido.',
        @prioridad = @prioridad,
        @observaciones =
            N'Orden generada para pruebas integrales TechCare.';

    SET @i += 1;
END;

PRINT 'PASO 104: Ordenes generadas.';

-- 3. Verificar cantidades
SELECT COUNT(*) AS totalOrdenes
FROM dbo.OrdenServicio;

SELECT
    estado,
    COUNT(*) AS cantidad
FROM dbo.OrdenServicio
GROUP BY estado
ORDER BY estado;

-- 4. Equipo con tres visitas
SELECT
    e.numeroSerie,
    o.numeroOrden,
    o.estado
FROM dbo.OrdenServicio AS o
INNER JOIN dbo.Equipo AS e
    ON e.idEquipo = o.idEquipo
WHERE e.numeroSerie = 'SN-00001'
ORDER BY o.idOrden;

-- 5. Verificar historial de cambios
SELECT COUNT(*) AS registrosHistorial
FROM dbo.HistorialEstadoOrden;
GO

-- ============================================================
-- PASO 105: Registrar 48 diagnosticos
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @idOrdenDiagnostico INT;
DECLARE @idTecnico INT;
DECLARE @tecnico1 INT;
DECLARE @tecnico2 INT;
DECLARE @contador INT = 1;

SELECT @tecnico1 = idUsuario
FROM dbo.Usuario
WHERE username = 'tecnico1';

SELECT @tecnico2 = idUsuario
FROM dbo.Usuario
WHERE username = 'tecnico2';

IF @tecnico1 IS NULL OR @tecnico2 IS NULL
BEGIN
    ;THROW 52020,
        'No se encontraron los tecnicos de prueba.',
        1;
END;

IF (SELECT COUNT(*) FROM dbo.OrdenServicio) <> 62
   OR EXISTS (SELECT 1 FROM dbo.Diagnostico)
BEGIN
    ;THROW 52021,
        'El paso 105 requiere 62 ordenes y ningun diagnostico previo.',
        1;
END;

-- Seleccionar las primeras 48 ordenes RECIBIDO
DECLARE cursorDiagnosticos CURSOR LOCAL FAST_FORWARD FOR
SELECT TOP (48) idOrden
FROM dbo.OrdenServicio
WHERE estado = 'RECIBIDO'
ORDER BY idOrden;

OPEN cursorDiagnosticos;

FETCH NEXT FROM cursorDiagnosticos
INTO @idOrdenDiagnostico;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @idTecnico =
        CASE
            WHEN @contador % 2 = 0 THEN @tecnico2
            ELSE @tecnico1
        END;

    EXEC dbo.sp_RegistrarDiagnostico
        @idOrden = @idOrdenDiagnostico,
        @idTecnico = @idTecnico,
        @descripcion =
            N'Se realizaron pruebas de funcionamiento y revision de componentes. Se recomienda mantenimiento o reparacion tecnica.',
        @costoManoObraEstimado = 150.00;

    SET @contador += 1;

    FETCH NEXT FROM cursorDiagnosticos
    INTO @idOrdenDiagnostico;
END;

CLOSE cursorDiagnosticos;
DEALLOCATE cursorDiagnosticos;

PRINT 'PASO 105: Diagnosticos registrados.';

-- Verificar diagnosticos
SELECT COUNT(*) AS totalDiagnosticos
FROM dbo.Diagnostico;

-- Verificar estados actuales
SELECT
    estado,
    COUNT(*) AS cantidad
FROM dbo.OrdenServicio
GROUP BY estado
ORDER BY estado;

-- Verificar asignacion de tecnicos
SELECT
    u.username AS tecnico,
    COUNT(*) AS diagnosticosRealizados
FROM dbo.Diagnostico AS d
INNER JOIN dbo.Usuario AS u
    ON u.idUsuario = d.idTecnico
GROUP BY u.username
ORDER BY u.username;
GO

-- ============================================================
-- PASO 106: Autorizaciones del cliente
-- 38 aprobadas, 5 rechazadas y 5 pendientes
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @idOrdenAutorizacion INT;
DECLARE @idUsuarioRecepcion INT;
DECLARE @contadorAutorizacion INT = 1;
DECLARE @autorizado BIT;

-- Verificar que el paso anterior este completo
IF (SELECT COUNT(*) FROM dbo.Diagnostico) <> 48
BEGIN
    ;THROW 52030,
        'Se requieren 48 diagnosticos para ejecutar el paso 106.',
        1;
END;

-- Evitar registrar nuevamente las autorizaciones
IF EXISTS (
    SELECT 1
    FROM dbo.Diagnostico
    WHERE autorizado IS NOT NULL
)
BEGIN
    ;THROW 52031,
        'Ya existen autorizaciones registradas.',
        1;
END;

-- Procesar solo los primeros 43 diagnosticos.
-- Los ultimos 5 quedan pendientes de respuesta.
DECLARE cursorAutorizaciones CURSOR LOCAL FAST_FORWARD FOR
SELECT TOP (43)
    d.idOrden,
    o.idUsuarioRecepcion
FROM dbo.Diagnostico AS d
INNER JOIN dbo.OrdenServicio AS o
    ON o.idOrden = d.idOrden
ORDER BY d.idOrden;

OPEN cursorAutorizaciones;

FETCH NEXT FROM cursorAutorizaciones
INTO @idOrdenAutorizacion, @idUsuarioRecepcion;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @autorizado =
        CASE
            WHEN @contadorAutorizacion <= 38 THEN 1
            ELSE 0
        END;

    EXEC dbo.sp_RegistrarAutorizacionCliente
        @idOrden = @idOrdenAutorizacion,
        @autorizado = @autorizado,
        @idUsuario = @idUsuarioRecepcion;

    SET @contadorAutorizacion += 1;

    FETCH NEXT FROM cursorAutorizaciones
    INTO @idOrdenAutorizacion, @idUsuarioRecepcion;
END;

CLOSE cursorAutorizaciones;
DEALLOCATE cursorAutorizaciones;

PRINT 'PASO 106: Autorizaciones registradas.';

-- 1. Resumen de respuestas
SELECT
    CASE
        WHEN autorizado = 1 THEN 'AUTORIZADA'
        WHEN autorizado = 0 THEN 'RECHAZADA'
        ELSE 'PENDIENTE'
    END AS respuestaCliente,
    COUNT(*) AS cantidad
FROM dbo.Diagnostico
GROUP BY autorizado
ORDER BY respuestaCliente;

-- 2. Estados actuales de las ordenes
SELECT
    estado,
    COUNT(*) AS cantidad
FROM dbo.OrdenServicio
GROUP BY estado
ORDER BY estado;

-- 3. Validar que las respuestas tengan fecha
SELECT COUNT(*) AS respuestasSinFecha
FROM dbo.Diagnostico
WHERE autorizado IS NOT NULL
  AND fechaRespuestaCliente IS NULL;
GO

-- ============================================================
-- PASO 107: Iniciar las 38 reparaciones autorizadas
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @idOrdenReparacion INT;
DECLARE @idTecnicoReparacion INT;
DECLARE @totalIniciadas INT = 0;

-- Validar las condiciones previas
IF (SELECT COUNT(*)
    FROM dbo.Diagnostico
    WHERE autorizado = 1) <> 38
BEGIN
    ;THROW 52040,
        'Se requieren exactamente 38 diagnosticos autorizados.',
        1;
END;

IF EXISTS (SELECT 1 FROM dbo.Reparacion)
BEGIN
    ;THROW 52041,
        'Ya existen reparaciones. No ejecutar este bloque nuevamente.',
        1;
END;

-- Recorrer solo las ordenes autorizadas
DECLARE cursorReparaciones CURSOR LOCAL FAST_FORWARD FOR
SELECT
    d.idOrden,
    d.idTecnico
FROM dbo.Diagnostico AS d
INNER JOIN dbo.OrdenServicio AS o
    ON o.idOrden = d.idOrden
WHERE d.autorizado = 1
  AND o.estado = 'ESPERANDO_AUTORIZACION'
ORDER BY d.idOrden;

OPEN cursorReparaciones;

FETCH NEXT FROM cursorReparaciones
INTO @idOrdenReparacion, @idTecnicoReparacion;

WHILE @@FETCH_STATUS = 0
BEGIN
    EXEC dbo.sp_IniciarReparacion
        @idOrden = @idOrdenReparacion,
        @idTecnico = @idTecnicoReparacion;

    SET @totalIniciadas += 1;

    FETCH NEXT FROM cursorReparaciones
    INTO @idOrdenReparacion, @idTecnicoReparacion;
END;

CLOSE cursorReparaciones;
DEALLOCATE cursorReparaciones;

PRINT 'PASO 107: Reparaciones iniciadas correctamente.';

-- Verificar reparaciones
SELECT
    @totalIniciadas AS reparacionesIniciadas,
    COUNT(*) AS reparacionesRegistradas
FROM dbo.Reparacion;

-- Verificar estados de las ordenes
SELECT
    estado,
    COUNT(*) AS cantidad
FROM dbo.OrdenServicio
GROUP BY estado
ORDER BY estado;

-- Verificar distribucion de tecnicos
SELECT
    u.username AS tecnico,
    COUNT(*) AS reparacionesAsignadas
FROM dbo.Reparacion AS r
INNER JOIN dbo.Usuario AS u
    ON u.idUsuario = r.idTecnico
GROUP BY u.username
ORDER BY u.username;

-- Verificar que no existan reparaciones sin autorizacion
SELECT COUNT(*) AS reparacionesSinAutorizacion
FROM dbo.Reparacion AS r
INNER JOIN dbo.Diagnostico AS d
    ON d.idDiagnostico = r.idDiagnostico
WHERE d.autorizado IS NULL
   OR d.autorizado = 0;
GO

-- ============================================================
-- PASO 108: Registrar actividades de reparacion
-- 34 reparaciones con 2 actividades
-- 4 reparaciones con 1 actividad
-- Total esperado: 72 actividades
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @idReparacionActividad INT;
DECLARE @idTecnicoActividad INT;
DECLARE @contadorActividad INT = 1;

-- Validar que existan las 38 reparaciones
IF (SELECT COUNT(*) FROM dbo.Reparacion) <> 38
BEGIN
    ;THROW 52050,
        'Se requieren 38 reparaciones antes de registrar actividades.',
        1;
END;

-- Evitar duplicar actividades
IF EXISTS (SELECT 1 FROM dbo.ActividadReparacion)
BEGIN
    ;THROW 52051,
        'Ya existen actividades registradas. No repetir este bloque.',
        1;
END;

-- Procesar las reparaciones en orden de creacion
DECLARE cursorActividades CURSOR LOCAL FAST_FORWARD FOR
SELECT
    idReparacion,
    idTecnico
FROM dbo.Reparacion
WHERE estado = 'EN_PROCESO'
ORDER BY idReparacion;

OPEN cursorActividades;

FETCH NEXT FROM cursorActividades
INTO @idReparacionActividad, @idTecnicoActividad;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Primera actividad para todas las reparaciones
    EXEC dbo.sp_RegistrarActividad
        @idReparacion = @idReparacionActividad,
        @idTecnico = @idTecnicoActividad,
        @descripcion =
            N'Revision tecnica, diagnostico de componentes y correccion de fallas.',
        @horas = 1.25;

    -- Segunda actividad solo en las primeras 34 reparaciones
    IF @contadorActividad <= 34
    BEGIN
        EXEC dbo.sp_RegistrarActividad
            @idReparacion = @idReparacionActividad,
            @idTecnico = @idTecnicoActividad,
            @descripcion =
                N'Pruebas de funcionamiento, estabilidad y verificacion de calidad.',
            @horas = 0.75;
    END;

    SET @contadorActividad += 1;

    FETCH NEXT FROM cursorActividades
    INTO @idReparacionActividad, @idTecnicoActividad;
END;

CLOSE cursorActividades;
DEALLOCATE cursorActividades;

PRINT 'PASO 108: Actividades registradas correctamente.';

-- 1. Cantidad total
SELECT COUNT(*) AS totalActividades
FROM dbo.ActividadReparacion;

-- 2. Distribucion por cantidad de actividades
SELECT
    cantidadActividades,
    COUNT(*) AS reparaciones
FROM (
    SELECT
        idReparacion,
        COUNT(*) AS cantidadActividades
    FROM dbo.ActividadReparacion
    GROUP BY idReparacion
) AS resumen
GROUP BY cantidadActividades
ORDER BY cantidadActividades;

-- 3. Total de horas registradas
SELECT
    SUM(horas) AS totalHoras
FROM dbo.ActividadReparacion;

-- 4. Comprobar numeracion consecutiva
SELECT COUNT(*) AS reparacionesConNumeracionIncorrecta
FROM (
    SELECT
        idReparacion,
        COUNT(*) AS total,
        MAX(numeroActividad) AS ultimoNumero
    FROM dbo.ActividadReparacion
    GROUP BY idReparacion
) AS resumen
WHERE total <> ultimoNumero;
GO

-- ============================================================
-- PASO 109: Consumo de repuestos en reparaciones
-- 12 reparaciones con repuestos, 14 consumos en total
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @idReparacionConsumo INT;
DECLARE @idBodegaConsumo INT;
DECLARE @idRepuestoConsumo INT;
DECLARE @idTecnicoConsumo INT;

DECLARE @numeroReparacion INT;
DECLARE @numeroPieza INT;
DECLARE @codigoRepuesto VARCHAR(30);

-- Validaciones previas
IF (SELECT COUNT(*) FROM dbo.Reparacion) <> 38
BEGIN
    ;THROW 52060,
        'Se requieren 38 reparaciones para registrar los consumos.',
        1;
END;

IF EXISTS (SELECT 1 FROM dbo.DetalleRepuesto)
BEGIN
    ;THROW 52061,
        'Ya existen consumos de repuestos. No repetir este bloque.',
        1;
END;

-- Utilizaremos la bodega central
SELECT @idBodegaConsumo = idBodega
FROM dbo.Bodega
WHERE codigo = 'BOD-CEN';

IF @idBodegaConsumo IS NULL
BEGIN
    ;THROW 52062,
        'No existe la bodega central BOD-CEN.',
        1;
END;

-- Tabla temporal con los 14 consumos previstos
DECLARE @consumos TABLE
(
    numeroReparacion INT,
    numeroPieza INT,
    codigoRepuesto VARCHAR(30)
);

INSERT INTO @consumos
    (numeroReparacion, numeroPieza, codigoRepuesto)
VALUES
    (1, 1, 'ALM-003'),
    (1, 2, 'BAT-003'),
    (1, 3, 'TEC-003'),
    (2, 1, 'ALM-001'),
    (3, 1, 'BAT-001'),
    (4, 1, 'BAT-002'),
    (5, 1, 'FUE-001'),
    (6, 1, 'FUE-003'),
    (7, 1, 'PAN-001'),
    (8, 1, 'PAN-002'),
    (9, 1, 'PAN-003'),
    (10, 1, 'RAM-001'),
    (11, 1, 'RAM-003'),
    (12, 1, 'RED-001');

-- Recorrer los consumos configurados
DECLARE cursorConsumos CURSOR LOCAL FAST_FORWARD FOR
SELECT
    numeroReparacion,
    numeroPieza,
    codigoRepuesto
FROM @consumos
ORDER BY numeroReparacion, numeroPieza;

OPEN cursorConsumos;

FETCH NEXT FROM cursorConsumos
INTO @numeroReparacion, @numeroPieza, @codigoRepuesto;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Buscar la reparacion por posicion, no por ID fijo
    SET @idReparacionConsumo = NULL;
    SET @idTecnicoConsumo = NULL;
    SET @idRepuestoConsumo = NULL;

    SELECT
        @idReparacionConsumo = r.idReparacion,
        @idTecnicoConsumo = r.idTecnico
    FROM
    (
        SELECT
            idReparacion,
            idTecnico,
            ROW_NUMBER() OVER (
                ORDER BY idReparacion
            ) AS numero
        FROM dbo.Reparacion
    ) AS r
    WHERE r.numero = @numeroReparacion;

    SELECT @idRepuestoConsumo = idRepuesto
    FROM dbo.Repuesto
    WHERE codigo = @codigoRepuesto;

    IF @idReparacionConsumo IS NULL
       OR @idTecnicoConsumo IS NULL
       OR @idRepuestoConsumo IS NULL
    BEGIN
        CLOSE cursorConsumos;
        DEALLOCATE cursorConsumos;

        ;THROW 52063,
            'No se encontro la reparacion, el tecnico o el repuesto.',
            1;
    END;

    EXEC dbo.sp_UtilizarRepuesto
        @idReparacion = @idReparacionConsumo,
        @idBodega = @idBodegaConsumo,
        @idRepuesto = @idRepuestoConsumo,
        @cantidad = 1,
        @idUsuario = @idTecnicoConsumo;

    FETCH NEXT FROM cursorConsumos
    INTO @numeroReparacion, @numeroPieza, @codigoRepuesto;
END;

CLOSE cursorConsumos;
DEALLOCATE cursorConsumos;

PRINT 'PASO 109: Consumos de repuestos registrados.';

-- 1. Total de consumos
SELECT COUNT(*) AS totalConsumos
FROM dbo.DetalleRepuesto;

-- 2. Reparaciones que utilizaron repuestos
SELECT COUNT(DISTINCT idReparacion)
    AS reparacionesConRepuestos
FROM dbo.DetalleRepuesto;

-- 3. Reparaciones con 3 o mas repuestos
SELECT
    idReparacion,
    COUNT(*) AS repuestosUtilizados
FROM dbo.DetalleRepuesto
GROUP BY idReparacion
HAVING COUNT(DISTINCT idRepuesto) >= 3;

-- 4. Verificar movimientos de inventario
SELECT
    COUNT(*) AS movimientosSalidaReparacion
FROM dbo.MovimientoInventario
WHERE tipo = 'SALIDA'
  AND origen = 'REPARACION';

-- 5. Verificar que no existan existencias negativas
SELECT COUNT(*) AS inventariosNegativos
FROM dbo.Inventario
WHERE existencia < 0;
GO

-- ============================================================
-- PASO 110: Finalizar 34 reparaciones
-- Dejar 4 reparaciones en proceso
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @idReparacionFinalizar INT;
DECLARE @idTecnicoFinalizar INT;
DECLARE @contadorFinalizar INT = 0;
DECLARE @costoFinal DECIMAL(12,2);

-- Validar estado previo de las reparaciones
IF (SELECT COUNT(*) FROM dbo.Reparacion) <> 38
BEGIN
    ;THROW 52070,
        'Se requieren 38 reparaciones para ejecutar el paso 110.',
        1;
END;

IF EXISTS (
    SELECT 1
    FROM dbo.Reparacion
    WHERE estado <> 'EN_PROCESO'
)
BEGIN
    ;THROW 52071,
        'Ya hay reparaciones finalizadas o canceladas. No repetir este paso.',
        1;
END;

-- Procesar las primeras 34 reparaciones
DECLARE cursorFinalizaciones CURSOR LOCAL FAST_FORWARD FOR
SELECT TOP (34)
    idReparacion,
    idTecnico
FROM dbo.Reparacion
WHERE estado = 'EN_PROCESO'
ORDER BY idReparacion;

OPEN cursorFinalizaciones;

FETCH NEXT FROM cursorFinalizaciones
INTO @idReparacionFinalizar, @idTecnicoFinalizar;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @contadorFinalizar += 1;

    -- Costos variados para facturacion y reportes
    SET @costoFinal =
        150.00 + (@contadorFinalizar * 10.00);

    EXEC dbo.sp_FinalizarReparacion
        @idReparacion = @idReparacionFinalizar,
        @idTecnico = @idTecnicoFinalizar,
        @descripcionTrabajo =
            N'Se realizaron reparaciones, mantenimiento correctivo y pruebas de funcionamiento satisfactorias.',
        @costoManoObra = @costoFinal;

    FETCH NEXT FROM cursorFinalizaciones
    INTO @idReparacionFinalizar, @idTecnicoFinalizar;
END;

CLOSE cursorFinalizaciones;
DEALLOCATE cursorFinalizaciones;

PRINT 'PASO 110: Reparaciones finalizadas correctamente.';

-- 1. Resumen de reparaciones
SELECT
    estado,
    COUNT(*) AS cantidad
FROM dbo.Reparacion
GROUP BY estado
ORDER BY estado;

-- 2. Estados finales de las ordenes
SELECT
    estado,
    COUNT(*) AS cantidad
FROM dbo.OrdenServicio
GROUP BY estado
ORDER BY estado;

-- 3. Verificar reparaciones finalizadas
SELECT
    COUNT(*) AS finalizadas,
    SUM(costoManoObra) AS totalManoObra,
    MIN(costoManoObra) AS costoMinimo,
    MAX(costoManoObra) AS costoMaximo
FROM dbo.Reparacion
WHERE estado = 'FINALIZADA';

-- 4. Verificar fechas de finalizacion
SELECT COUNT(*) AS finalizadasSinFecha
FROM dbo.Reparacion
WHERE estado = 'FINALIZADA'
  AND fechaFin IS NULL;

-- 5. Verificar coherencia con las ordenes
SELECT COUNT(*) AS reparacionesFinalizadasConOrdenIncorrecta
FROM dbo.Reparacion AS r
INNER JOIN dbo.Diagnostico AS d
    ON d.idDiagnostico = r.idDiagnostico
INNER JOIN dbo.OrdenServicio AS o
    ON o.idOrden = d.idOrden
WHERE r.estado = 'FINALIZADA'
  AND o.estado <> 'LISTO';
GO

-- ============================================================
-- PASO 111: Dejar una orden en DIAGNOSTICO
-- ============================================================

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @idOrdenPendiente INT;
DECLARE @idRecepcionDiagnostico INT;

SELECT @idRecepcionDiagnostico = idUsuario
FROM dbo.Usuario
WHERE username = 'recepcion1'
  AND estado = 'ACTIVO';

IF @idRecepcionDiagnostico IS NULL
BEGIN
    ;THROW 52080,
        'No existe el usuario de recepcion requerido.',
        1;
END;

-- Seleccionar una orden que aun este RECIBIDO
-- y que no tenga diagnostico registrado.
SELECT TOP (1)
    @idOrdenPendiente = o.idOrden
FROM dbo.OrdenServicio AS o
WHERE o.estado = 'RECIBIDO'
  AND NOT EXISTS (
      SELECT 1
      FROM dbo.Diagnostico AS d
      WHERE d.idOrden = o.idOrden
  )
ORDER BY o.idOrden DESC;

IF @idOrdenPendiente IS NULL
BEGIN
    ;THROW 52081,
        'No existe una orden RECIBIDO disponible.',
        1;
END;

EXEC dbo.sp_CambiarEstadoOrden
    @idOrden = @idOrdenPendiente,
    @estadoNuevo = 'DIAGNOSTICO',
    @idUsuario = @idRecepcionDiagnostico,
    @observacion =
        N'Equipo en evaluacion tecnica; diagnostico pendiente.';

PRINT 'PASO 111: Orden en diagnostico creada correctamente.';

-- Verificacion
SELECT
    idOrden,
    numeroOrden,
    estado
FROM dbo.OrdenServicio
WHERE idOrden = @idOrdenPendiente;

SELECT
    estado,
    COUNT(*) AS cantidad
FROM dbo.OrdenServicio
GROUP BY estado
ORDER BY estado;
GO

-- ============================================================
-- PASO 112: Validacion integral de datos de prueba
-- ============================================================

SET NOCOUNT ON;

-- 1. Validar cantidades principales
SELECT
    (SELECT COUNT(*) FROM dbo.OrdenServicio)
        AS totalOrdenes,

    (SELECT COUNT(*) FROM dbo.Diagnostico)
        AS totalDiagnosticos,

    (SELECT COUNT(*) FROM dbo.Reparacion)
        AS totalReparaciones,

    (SELECT COUNT(*) FROM dbo.ActividadReparacion)
        AS totalActividades,

    (SELECT COUNT(*) FROM dbo.DetalleRepuesto)
        AS totalConsumos,

    (SELECT COUNT(*) FROM dbo.Reparacion
     WHERE estado = 'FINALIZADA')
        AS reparacionesFinalizadas;

-- 2. Validar respuestas de los clientes
SELECT
    SUM(CASE WHEN autorizado = 1 THEN 1 ELSE 0 END)
        AS autorizadas,

    SUM(CASE WHEN autorizado = 0 THEN 1 ELSE 0 END)
        AS rechazadas,

    SUM(CASE WHEN autorizado IS NULL THEN 1 ELSE 0 END)
        AS pendientes
FROM dbo.Diagnostico;

-- 3. Verificar reparaciones con y sin repuestos
SELECT
    COUNT(DISTINCT dr.idReparacion)
        AS reparacionesConRepuestos,

    (SELECT COUNT(*) FROM dbo.Reparacion)
      - COUNT(DISTINCT dr.idReparacion)
        AS reparacionesSinRepuestos
FROM dbo.DetalleRepuesto AS dr;

-- 4. Verificar una reparacion con 3+ repuestos diferentes
SELECT
    idReparacion,
    COUNT(DISTINCT idRepuesto) AS repuestosDiferentes
FROM dbo.DetalleRepuesto
GROUP BY idReparacion
HAVING COUNT(DISTINCT idRepuesto) >= 3;

-- 5. Verificar las tres visitas del mismo equipo
SELECT
    e.numeroSerie,
    COUNT(*) AS totalOrdenes,
    SUM(CASE WHEN o.estado = 'CANCELADO'
             THEN 1 ELSE 0 END) AS canceladas
FROM dbo.OrdenServicio AS o
INNER JOIN dbo.Equipo AS e
    ON e.idEquipo = o.idEquipo
WHERE e.numeroSerie = 'SN-00001'
GROUP BY e.numeroSerie;

-- 6. Validar integridad de reparaciones
SELECT
    COUNT(*) AS reparacionesSinAutorizacion
FROM dbo.Reparacion AS r
INNER JOIN dbo.Diagnostico AS d
    ON d.idDiagnostico = r.idDiagnostico
WHERE d.autorizado IS NULL
   OR d.autorizado = 0;

-- 7. Validar historial y movimientos de inventario
SELECT
    (SELECT COUNT(*)
     FROM dbo.HistorialEstadoOrden)
        AS registrosHistorial,

    (SELECT COUNT(*)
     FROM dbo.MovimientoInventario
     WHERE tipo = 'SALIDA'
       AND origen = 'REPARACION')
        AS movimientosReparacion;

-- 8. Verificar distribucion final de estados
SELECT
    estado,
    COUNT(*) AS cantidad
FROM dbo.OrdenServicio
GROUP BY estado
ORDER BY estado;
GO

SET NOEXEC OFF;
GO