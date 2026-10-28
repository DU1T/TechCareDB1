/* =====================================================================
   85_datos_escenarios.sql  |  Dueño: FULLSTACK/INFRA
   ---------------------------------------------------------------------
   Va al final de todos los datos.
   - Reparte fechas: los datos de 80-84 nacen todos en el mismo segundo. Aquí se les
     da una historia creíble de ~4 meses (ver la guía C4):
       usuarios  hace 150 días
       compras   hace 119 a 103 días (recibidas 2 días después); las PENDIENTES, hace 3 a 1 días
       ajustes   hace 96 días (después de recibir las compras)
       órdenes   hace 89 a 5 días; dentro de cada orden, cada cambio de estado ocurre
                 2 horas después del anterior y todo lo demás (diagnóstico, reparación,
                 repuestos, factura, pagos, entrega) toma la hora del paso al que pertenece
       clientes y equipos, poco antes de su primera orden
     Las fechas se ASIGNAN (no se suman): correrlo dos veces da el mismo resultado.
     Los ids de los movimientos ya van en este mismo orden (compras -> ajustes -> órdenes),
     así el kárdex queda cronológico y encadenado.
   - Verifica que existan todos los escenarios obligatorios del enunciado.
   - Bloque final que cuenta cada tabla contra el mínimo (sección 7) y muestra OK o FALTA.
   - Revisa la coherencia de las fechas. Si algo sale FALTA, el script termina con error
     (la reconstrucción y el CI fallan en vez de dejar datos incompletos sin avisar).
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

SET NOCOUNT ON;
SET XACT_ABORT ON;

DECLARE @hoy DATETIME2(0) = CAST(CAST(SYSDATETIME() AS DATE) AS DATETIME2(0));   -- hoy a las 00:00

/* ---------- 1. Momento de cada paso de cada orden ----------
   Día: de 89 a 5 días atrás según el número de orden. Hora: 08:00, y si dos órdenes
   caen el mismo día, la segunda entra 40 minutos después. Paso k del historial = +2 h * k. */
DECLARE @orden TABLE (idOrden INT PRIMARY KEY, inicio DATETIME2(0) NOT NULL);
INSERT INTO @orden (idOrden, inicio)
SELECT idOrden,
       DATEADD(MINUTE, 480 + 40 * (ROW_NUMBER() OVER (PARTITION BY dias ORDER BY idOrden) - 1),
               DATEADD(DAY, -dias, @hoy))
FROM (SELECT idOrden, 90 - (ROW_NUMBER() OVER (ORDER BY idOrden) * 85) / COUNT(*) OVER () AS dias
      FROM dbo.OrdenServicio) AS x;

DECLARE @paso TABLE (idHistorial BIGINT PRIMARY KEY, idOrden INT NOT NULL, estadoAnterior VARCHAR(25) NULL,
                     estadoNuevo VARCHAR(25) NOT NULL, fecha DATETIME2(0) NOT NULL);
INSERT INTO @paso (idHistorial, idOrden, estadoAnterior, estadoNuevo, fecha)
SELECT h.idHistorial, h.idOrden, h.estadoAnterior, h.estadoNuevo,
       DATEADD(HOUR, 2 * (ROW_NUMBER() OVER (PARTITION BY h.idOrden ORDER BY h.idHistorial) - 1), o.inicio)
FROM dbo.HistorialEstadoOrden h
JOIN @orden o ON o.idOrden = h.idOrden;

-- Compras: las recibidas, una por día en orden de id; las pendientes, en los últimos días
DECLARE @compra TABLE (idCompra INT PRIMARY KEY, fecha DATETIME2(0) NOT NULL);
INSERT INTO @compra (idCompra, fecha)
SELECT idCompra,
       CASE WHEN estado = 'PENDIENTE'
            THEN DATEADD(HOUR, 10, DATEADD(DAY, -(1 + COUNT(*) OVER (PARTITION BY estado)
                                                  - ROW_NUMBER() OVER (PARTITION BY estado ORDER BY idCompra)), @hoy))
            ELSE DATEADD(HOUR, 10, DATEADD(DAY, -(120 - ROW_NUMBER() OVER (PARTITION BY estado ORDER BY idCompra)), @hoy))
       END
FROM dbo.Compra;

BEGIN TRANSACTION;

-- El kárdex es inmutable (R14). Solo este script de datos de prueba lo apaga, dentro de
-- la transacción: si algo falla, el ROLLBACK también lo vuelve a encender.
DISABLE TRIGGER dbo.trg_MovimientoInventario_Inmutable ON dbo.MovimientoInventario;

/* ---------- 2. Órdenes y todo lo que cuelga de ellas ---------- */
UPDATE h SET h.fechaCambio = p.fecha
FROM dbo.HistorialEstadoOrden h JOIN @paso p ON p.idHistorial = h.idHistorial;

UPDATE o SET o.fechaIngreso = x.inicio
FROM dbo.OrdenServicio o JOIN @orden x ON x.idOrden = o.idOrden;

-- Diagnóstico: cuando la orden pasa a ESPERANDO_AUTORIZACION; respuesta: cuando sale de ese estado
UPDATE d SET d.fechaDiagnostico = ISNULL(diag.fecha, o.inicio),
             d.fechaRespuestaCliente = CASE WHEN d.fechaRespuestaCliente IS NULL THEN NULL
                                            ELSE ISNULL(resp.fecha, diag.fecha) END
FROM dbo.Diagnostico d
JOIN @orden o ON o.idOrden = d.idOrden
OUTER APPLY (SELECT MIN(p.fecha) AS fecha FROM @paso p
             WHERE p.idOrden = d.idOrden AND p.estadoNuevo = 'ESPERANDO_AUTORIZACION') diag
OUTER APPLY (SELECT MIN(p.fecha) AS fecha FROM @paso p
             WHERE p.idOrden = d.idOrden AND p.estadoAnterior = 'ESPERANDO_AUTORIZACION') resp;

-- Reparación: inicia al pasar a REPARACION y termina al pasar de REPARACION a LISTO
UPDATE r SET r.fechaInicio = ini.fecha,
             r.fechaFin = CASE WHEN r.fechaFin IS NULL THEN NULL ELSE fin.fecha END
FROM dbo.Reparacion r
JOIN dbo.Diagnostico d ON d.idDiagnostico = r.idDiagnostico
CROSS APPLY (SELECT MIN(p.fecha) AS fecha FROM @paso p
             WHERE p.idOrden = d.idOrden AND p.estadoNuevo = 'REPARACION') ini
OUTER APPLY (SELECT MIN(p.fecha) AS fecha FROM @paso p
             WHERE p.idOrden = d.idOrden AND p.estadoAnterior = 'REPARACION' AND p.estadoNuevo = 'LISTO') fin;

-- Actividades y repuestos: repartidos dentro de los primeros 100 minutos de la reparación
-- (la reparación dura 2 horas, así que siempre quedan entre el inicio y el fin)
UPDATE a SET a.fechaActividad = DATEADD(MINUTE, x.n * 100 / (x.total + 1), r.fechaInicio)
FROM dbo.ActividadReparacion a
JOIN dbo.Reparacion r ON r.idReparacion = a.idReparacion
JOIN (SELECT idReparacion, numeroActividad,
             ROW_NUMBER() OVER (PARTITION BY idReparacion ORDER BY numeroActividad) AS n,
             COUNT(*) OVER (PARTITION BY idReparacion) AS total
      FROM dbo.ActividadReparacion) x
  ON x.idReparacion = a.idReparacion AND x.numeroActividad = a.numeroActividad;

UPDATE dr SET dr.fechaRegistro = DATEADD(MINUTE, x.n * 100 / (x.total + 1), r.fechaInicio)
FROM dbo.DetalleRepuesto dr
JOIN dbo.Reparacion r ON r.idReparacion = dr.idReparacion
JOIN (SELECT idDetalleRepuesto,
             ROW_NUMBER() OVER (PARTITION BY idReparacion ORDER BY idDetalleRepuesto) AS n,
             COUNT(*) OVER (PARTITION BY idReparacion) AS total
      FROM dbo.DetalleRepuesto) x
  ON x.idDetalleRepuesto = dr.idDetalleRepuesto;

UPDATE m SET m.fechaMovimiento = dr.fechaRegistro
FROM dbo.MovimientoInventario m
JOIN dbo.DetalleRepuesto dr ON dr.idDetalleRepuesto = m.idDetalleRepuesto;

-- Factura: 20 minutos después de que la orden queda LISTO; pagos entre la factura y
-- 110 minutos después (antes de la entrega, que es el paso siguiente: +2 h)
UPDATE f SET f.fechaEmision = DATEADD(MINUTE, 20, listo.fecha)
FROM dbo.Factura f
CROSS APPLY (SELECT MIN(p.fecha) AS fecha FROM @paso p
             WHERE p.idOrden = f.idOrden AND p.estadoNuevo = 'LISTO') listo;

UPDATE pg SET pg.fechaPago = DATEADD(MINUTE, x.n * 90 / (x.total + 1), f.fechaEmision)
FROM dbo.Pago pg
JOIN dbo.Factura f ON f.idFactura = pg.idFactura
JOIN (SELECT idPago,
             ROW_NUMBER() OVER (PARTITION BY idFactura ORDER BY idPago) AS n,
             COUNT(*) OVER (PARTITION BY idFactura) AS total
      FROM dbo.Pago) x
  ON x.idPago = pg.idPago;

UPDATE e SET e.fechaEntrega = ent.fecha
FROM dbo.Entrega e
CROSS APPLY (SELECT MIN(p.fecha) AS fecha FROM @paso p
             WHERE p.idOrden = e.idOrden AND p.estadoNuevo = 'ENTREGADO') ent
WHERE ent.fecha IS NOT NULL;

/* ---------- 3. Compras y ajustes ---------- */
UPDATE c SET c.fechaCompra = x.fecha,
             c.fechaRecepcion = CASE WHEN c.fechaRecepcion IS NULL THEN NULL
                                     ELSE DATEADD(HOUR, 5, DATEADD(DAY, 2, x.fecha)) END   -- llega 2 días después, 15:00
FROM dbo.Compra c JOIN @compra x ON x.idCompra = c.idCompra;

UPDATE m SET m.fechaMovimiento = c.fechaRecepcion
FROM dbo.MovimientoInventario m
JOIN dbo.Compra c ON c.idCompra = m.idCompra;

UPDATE dbo.MovimientoInventario
   SET fechaMovimiento = DATEADD(HOUR, 16, DATEADD(DAY, -96, @hoy))
 WHERE origen = 'AJUSTE';

UPDATE i SET i.fechaUltimoMovimiento = m.ultima
FROM dbo.Inventario i
JOIN (SELECT idBodega, idRepuesto, MAX(fechaMovimiento) AS ultima
      FROM dbo.MovimientoInventario GROUP BY idBodega, idRepuesto) m
  ON m.idBodega = i.idBodega AND m.idRepuesto = i.idRepuesto;

ENABLE TRIGGER dbo.trg_MovimientoInventario_Inmutable ON dbo.MovimientoInventario;

/* ---------- 4. Personas: usuarios al inicio; equipos y clientes antes de su primera orden ---------- */
UPDATE dbo.Usuario    SET fechaCreacion   = DATEADD(HOUR, 8, DATEADD(DAY, -150, @hoy));
UPDATE dbo.UsuarioRol SET fechaAsignacion = DATEADD(HOUR, 8, DATEADD(DAY, -150, @hoy));

-- Equipo con órdenes: 15 minutos antes de la primera. Sin órdenes: uno por día hace 140-100 días
UPDATE e SET e.fechaRegistro = ISNULL(DATEADD(MINUTE, -15, pri.fecha),
                                      DATEADD(HOUR, 9, DATEADD(DAY, -(100 + x.n % 40), @hoy)))
FROM dbo.Equipo e
JOIN (SELECT idEquipo, ROW_NUMBER() OVER (ORDER BY idEquipo) AS n FROM dbo.Equipo) x ON x.idEquipo = e.idEquipo
OUTER APPLY (SELECT MIN(o.fechaIngreso) AS fecha FROM dbo.OrdenServicio o WHERE o.idEquipo = e.idEquipo) pri;

-- Cliente: 15 minutos antes de su primer equipo
UPDATE c SET c.fechaRegistro = ISNULL(DATEADD(MINUTE, -15, pri.fecha),
                                      DATEADD(HOUR, 9, DATEADD(DAY, -140, @hoy)))
FROM dbo.Cliente c
OUTER APPLY (SELECT MIN(e.fechaRegistro) AS fecha FROM dbo.Equipo e WHERE e.idCliente = c.idCliente) pri;

COMMIT TRANSACTION;
GO

/* ---------- 5. Escenarios obligatorios del enunciado ---------- */
DECLARE @escenarios TABLE (escenario NVARCHAR(60), ok BIT);
INSERT INTO @escenarios (escenario, ok)
SELECT v.escenario, v.ok
FROM (VALUES
 (N'Cliente sin órdenes', CASE WHEN EXISTS (SELECT 1 FROM dbo.Cliente c WHERE NOT EXISTS (
      SELECT 1 FROM dbo.Equipo e JOIN dbo.OrdenServicio o ON o.idEquipo = e.idEquipo WHERE e.idCliente = c.idCliente)) THEN 1 ELSE 0 END),
 (N'Equipo con 3+ órdenes', CASE WHEN EXISTS (SELECT 1 FROM dbo.OrdenServicio GROUP BY idEquipo HAVING COUNT(*) >= 3) THEN 1 ELSE 0 END),
 (N'Orden sin diagnóstico', CASE WHEN EXISTS (SELECT 1 FROM dbo.OrdenServicio o WHERE NOT EXISTS (SELECT 1 FROM dbo.Diagnostico d WHERE d.idOrden = o.idOrden)) THEN 1 ELSE 0 END),
 (N'Diagnosticada pero no reparada', CASE WHEN EXISTS (SELECT 1 FROM dbo.Diagnostico d WHERE NOT EXISTS (SELECT 1 FROM dbo.Reparacion r WHERE r.idDiagnostico = d.idDiagnostico)) THEN 1 ELSE 0 END),
 (N'Reparación con varios repuestos', CASE WHEN EXISTS (SELECT 1 FROM dbo.DetalleRepuesto GROUP BY idReparacion HAVING COUNT(*) >= 2) THEN 1 ELSE 0 END),
 (N'Repuesto con stock en varias bodegas', CASE WHEN EXISTS (SELECT 1 FROM dbo.Inventario WHERE existencia > 0 GROUP BY idRepuesto HAVING COUNT(*) >= 2) THEN 1 ELSE 0 END),
 (N'Stock en cero', CASE WHEN EXISTS (SELECT 1 FROM dbo.Inventario WHERE existencia = 0) THEN 1 ELSE 0 END),
 (N'Repuesto bajo mínimo', CASE WHEN EXISTS (SELECT 1 FROM dbo.Inventario WHERE existencia > 0 AND existencia <= stockMinimo) THEN 1 ELSE 0 END),
 (N'Factura con varios pagos', CASE WHEN EXISTS (SELECT 1 FROM dbo.Pago WHERE estado = 'APLICADO' GROUP BY idFactura HAVING COUNT(*) >= 2) THEN 1 ELSE 0 END),
 (N'Factura con saldo', CASE WHEN EXISTS (SELECT 1 FROM dbo.Factura f WHERE f.estado = 'EMITIDA' AND dbo.fn_SaldoFactura(f.idFactura) > 0) THEN 1 ELSE 0 END),
 (N'Compra pendiente', CASE WHEN EXISTS (SELECT 1 FROM dbo.Compra WHERE estado = 'PENDIENTE') THEN 1 ELSE 0 END),
 (N'Movimientos de entrada y salida', CASE WHEN EXISTS (SELECT 1 FROM dbo.MovimientoInventario WHERE tipo = 'ENTRADA')
                                        AND EXISTS (SELECT 1 FROM dbo.MovimientoInventario WHERE tipo = 'SALIDA') THEN 1 ELSE 0 END)
) AS v (escenario, ok);

SELECT escenario, CASE WHEN ok = 1 THEN 'OK' ELSE 'FALTA' END AS resultado FROM @escenarios;

/* ---------- 6. Mínimos de la sección 7 ---------- */
DECLARE @minimos TABLE (entidad NVARCHAR(30), total INT, minimo INT);
INSERT INTO @minimos (entidad, total, minimo)
VALUES
    (N'Usuarios',     (SELECT COUNT(*) FROM dbo.Usuario),              10),
    (N'Clientes',     (SELECT COUNT(*) FROM dbo.Cliente),              30),
    (N'Equipos',      (SELECT COUNT(*) FROM dbo.Equipo),               45),
    (N'Órdenes',      (SELECT COUNT(*) FROM dbo.OrdenServicio),        60),
    (N'Diagnósticos', (SELECT COUNT(*) FROM dbo.Diagnostico),          45),
    (N'Reparaciones', (SELECT COUNT(*) FROM dbo.Reparacion),           35),
    (N'Repuestos',    (SELECT COUNT(*) FROM dbo.Repuesto),             30),
    (N'Bodegas',      (SELECT COUNT(*) FROM dbo.Bodega),                3),
    (N'Inventario',   (SELECT COUNT(*) FROM dbo.Inventario),           60),
    (N'Proveedores',  (SELECT COUNT(*) FROM dbo.Proveedor),             8),
    (N'Compras',      (SELECT COUNT(*) FROM dbo.Compra),               20),
    (N'Movimientos',  (SELECT COUNT(*) FROM dbo.MovimientoInventario), 100),
    (N'Facturas',     (SELECT COUNT(*) FROM dbo.Factura),              30),
    (N'Pagos',        (SELECT COUNT(*) FROM dbo.Pago),                 40);

SELECT entidad, total, minimo, CASE WHEN total >= minimo THEN 'OK' ELSE 'FALTA' END AS resultado FROM @minimos;

/* ---------- 7. Coherencia de las fechas ---------- */
DECLARE @ahora DATETIME2(0) = SYSDATETIME();
DECLARE @fechas TABLE (revision NVARCHAR(80), fallas INT);
INSERT INTO @fechas (revision, fallas)
VALUES
 (N'Nada con fecha futura',
    (SELECT COUNT(*) FROM dbo.OrdenServicio WHERE fechaIngreso > @ahora)
  + (SELECT COUNT(*) FROM dbo.HistorialEstadoOrden WHERE fechaCambio > @ahora)
  + (SELECT COUNT(*) FROM dbo.MovimientoInventario WHERE fechaMovimiento > @ahora)
  + (SELECT COUNT(*) FROM dbo.Pago WHERE fechaPago > @ahora)
  + (SELECT COUNT(*) FROM dbo.Entrega WHERE fechaEntrega > @ahora)
  + (SELECT COUNT(*) FROM dbo.Compra WHERE fechaRecepcion > @ahora OR fechaCompra > @ahora)),
 (N'Fechas repartidas (más de 60 días distintos con órdenes)',
    CASE WHEN (SELECT COUNT(DISTINCT CAST(fechaIngreso AS DATE)) FROM dbo.OrdenServicio) > 60 THEN 0 ELSE 1 END),
 (N'Orden: ingreso <= diagnóstico <= respuesta del cliente',
    (SELECT COUNT(*) FROM dbo.Diagnostico d JOIN dbo.OrdenServicio o ON o.idOrden = d.idOrden
      WHERE d.fechaDiagnostico < o.fechaIngreso OR d.fechaRespuestaCliente < d.fechaDiagnostico)),
 (N'Orden: respuesta <= inicio <= repuestos/actividades <= fin de la reparación',
    (SELECT COUNT(*) FROM dbo.Reparacion r JOIN dbo.Diagnostico d ON d.idDiagnostico = r.idDiagnostico
      WHERE r.fechaInicio < d.fechaRespuestaCliente
         OR EXISTS (SELECT 1 FROM dbo.ActividadReparacion a WHERE a.idReparacion = r.idReparacion
                     AND (a.fechaActividad < r.fechaInicio OR a.fechaActividad > r.fechaFin))
         OR EXISTS (SELECT 1 FROM dbo.DetalleRepuesto dr WHERE dr.idReparacion = r.idReparacion
                     AND (dr.fechaRegistro < r.fechaInicio OR dr.fechaRegistro > r.fechaFin)))),
 (N'Orden: fin de la reparación <= factura <= pagos <= entrega',
    (SELECT COUNT(*) FROM dbo.Factura f
      LEFT JOIN dbo.Diagnostico d ON d.idOrden = f.idOrden
      LEFT JOIN dbo.Reparacion r ON r.idDiagnostico = d.idDiagnostico
      LEFT JOIN dbo.Entrega e ON e.idOrden = f.idOrden
      WHERE f.fechaEmision < r.fechaFin
         OR EXISTS (SELECT 1 FROM dbo.Pago p WHERE p.idFactura = f.idFactura
                     AND (p.fechaPago < f.fechaEmision OR p.fechaPago > e.fechaEntrega)))),
 (N'Historial de cada orden en orden cronológico',
    (SELECT COUNT(*) FROM (SELECT fechaCambio, LAG(fechaCambio) OVER (PARTITION BY idOrden ORDER BY idHistorial) AS anterior
                           FROM dbo.HistorialEstadoOrden) x WHERE x.fechaCambio < x.anterior)),
 (N'Compras: compra <= recepción = su movimiento',
    (SELECT COUNT(*) FROM dbo.Compra c WHERE c.fechaRecepcion < c.fechaCompra
        OR EXISTS (SELECT 1 FROM dbo.MovimientoInventario m WHERE m.idCompra = c.idCompra AND m.fechaMovimiento <> c.fechaRecepcion))),
 (N'Kárdex cronológico y encadenado (por fecha)',
    (SELECT COUNT(*) FROM (SELECT existenciaAnterior,
                                  LAG(existenciaResultante) OVER (PARTITION BY idBodega, idRepuesto
                                                                  ORDER BY fechaMovimiento, idMovimiento) AS previa
                           FROM dbo.MovimientoInventario) x
      WHERE x.previa IS NOT NULL AND x.previa <> x.existenciaAnterior)),
 (N'Clientes y equipos registrados antes de su primera orden',
    (SELECT COUNT(*) FROM dbo.OrdenServicio o JOIN dbo.Equipo e ON e.idEquipo = o.idEquipo
      JOIN dbo.Cliente c ON c.idCliente = e.idCliente
      WHERE e.fechaRegistro > o.fechaIngreso OR c.fechaRegistro > e.fechaRegistro));

SELECT revision, CASE WHEN fallas = 0 THEN 'OK' ELSE 'FALTA' END AS resultado FROM @fechas;

IF EXISTS (SELECT 1 FROM @escenarios WHERE ok = 0)
   OR EXISTS (SELECT 1 FROM @minimos WHERE total < minimo)
   OR EXISTS (SELECT 1 FROM @fechas WHERE fallas > 0)
    RAISERROR(N'85: hay escenarios, mínimos o fechas en FALTA (ver las tablas de arriba).', 16, 1);
GO

SET NOEXEC OFF;
GO
