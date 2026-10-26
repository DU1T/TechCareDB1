
/*
TECHCARE SOLUTIONS
T03 - Verificacion del flujo de orden, diagnostico y reparacion

Objetivo:
Comprobar que una orden de prueba termino correctamente
y que conserva su historial y actividades.

Pruebas funcionales realizadas previamente desde Swagger:
1. Crear orden.
2. Registrar diagnostico.
3. Autorizar reparacion.
4. Iniciar reparacion.
5. Registrar dos actividades.
6. Finalizar reparacion.
7. Rechazar actividades y finalizaciones posteriores (HTTP 409).

Base de prueba: TechCare_Back.
Orden de referencia: OS-000001.

Este script es de solo lectura.
Requiere que la orden de referencia conserve los datos
generados durante las pruebas.
*/

USE TechCare_Back;
GO

DECLARE @idOrden INT = 1;
DECLARE @idReparacion INT;

SELECT @idReparacion = r.idReparacion
FROM dbo.Reparacion AS r
INNER JOIN dbo.Diagnostico AS d
    ON d.idDiagnostico = r.idDiagnostico
WHERE d.idOrden = @idOrden;

-- Estado final y costo de mano de obra
SELECT
    o.numeroOrden,
    o.estado AS estadoOrden,
    r.estado AS estadoReparacion,
    r.fechaInicio,
    r.fechaFin,
    r.costoManoObra
FROM dbo.OrdenServicio AS o
INNER JOIN dbo.Diagnostico AS d
    ON d.idOrden = o.idOrden
INNER JOIN dbo.Reparacion AS r
    ON r.idDiagnostico = d.idDiagnostico
WHERE o.idOrden = @idOrden;

-- Historial de estados
SELECT
    estadoAnterior,
    estadoNuevo,
    fechaCambio
FROM dbo.HistorialEstadoOrden
WHERE idOrden = @idOrden
ORDER BY fechaCambio;

-- Actividades de la reparacion
SELECT
    numeroActividad,
    descripcion,
    horas
FROM dbo.ActividadReparacion
WHERE idReparacion = @idReparacion
ORDER BY numeroActividad;

-- Resumen de verificaciones
SELECT
    CASE WHEN o.estado = 'LISTO'
        THEN 'OK' ELSE 'ERROR' END AS ordenLista,
    CASE WHEN r.estado = 'FINALIZADA' AND r.fechaFin IS NOT NULL
        THEN 'OK' ELSE 'ERROR' END AS reparacionFinalizada,
    CASE WHEN r.costoManoObra = 250.00
        THEN 'OK' ELSE 'ERROR' END AS costoCorrecto,
    CASE WHEN (
        SELECT COUNT(*)
        FROM dbo.ActividadReparacion
        WHERE idReparacion = r.idReparacion
    ) = 2 THEN 'OK' ELSE 'ERROR' END AS actividadesCorrectas,
    CASE WHEN (
        SELECT COUNT(*)
        FROM dbo.HistorialEstadoOrden
        WHERE idOrden = o.idOrden
    ) = 5 THEN 'OK' ELSE 'ERROR' END AS historialCorrecto
FROM dbo.OrdenServicio AS o
INNER JOIN dbo.Diagnostico AS d
    ON d.idOrden = o.idOrden
INNER JOIN dbo.Reparacion AS r
    ON r.idDiagnostico = d.idDiagnostico
WHERE o.idOrden = @idOrden;
GO
