/* ============================================================
   TECHCARE SOLUTIONS
   T11 - Historial tecnico de un equipo

   Responsable: B - Backend y Base de Datos

   Objetivo:
   Verificar que el reporte 03 devuelve las tres ordenes
   historicas de un equipo, incluyendo ordenes sin
   diagnostico, reparacion o factura.

   Requisitos:
   - Datos 80, 81, 82 y 83 cargados.
   - fn_HistorialEquipo implementada.
   - sp_Reporte_03_HistorialEquipo implementado.

   Datos de entrada:
   Numero de serie: SN-00001

   Resultado esperado:
   - 3 ordenes.
   - 2 CANCELADO.
   - 1 LISTO con reparacion FINALIZADA.
   - Se conservan las ordenes sin factura.

   Este script no modifica registros.
   ============================================================ */

SET NOCOUNT ON;

DECLARE @numeroSerie VARCHAR(60) = 'SN-00001';

-- 1. Ejecutar el reporte obligatorio
EXEC dbo.sp_Reporte_03_HistorialEquipo
    @numeroSerie = @numeroSerie;

-- 2. Verificar cantidades
SELECT
    COUNT(*) AS totalOrdenes,
    SUM(CASE WHEN estado = 'CANCELADO'
             THEN 1 ELSE 0 END) AS canceladas,
    SUM(CASE WHEN estado = 'LISTO'
             THEN 1 ELSE 0 END) AS listas,
    SUM(CASE WHEN estadoReparacion = 'FINALIZADA'
             THEN 1 ELSE 0 END) AS reparacionesFinalizadas,
    SUM(CASE WHEN totalFacturado IS NULL
             THEN 1 ELSE 0 END) AS ordenesSinFactura
FROM dbo.fn_HistorialEquipo(@numeroSerie);

-- 3. Verificacion automatica
DECLARE @total INT;
DECLARE @canceladas INT;
DECLARE @finalizadas INT;

SELECT
    @total = COUNT(*),
    @canceladas = SUM(
        CASE WHEN estado = 'CANCELADO' THEN 1 ELSE 0 END),
    @finalizadas = SUM(
        CASE WHEN estadoReparacion = 'FINALIZADA'
             THEN 1 ELSE 0 END)
FROM dbo.fn_HistorialEquipo(@numeroSerie);

IF @total <> 3
   OR @canceladas <> 2
   OR @finalizadas <> 1
BEGIN
    ;THROW 52090,
        'T11 FALLIDA: El historial no coincide con los datos esperados.',
        1;
END;

PRINT 'T11 OK: Historial tecnico validado correctamente.';
GO