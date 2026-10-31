/* Verifica la sección 5.1 del enunciado sobre los 12 reportes (sp_Reporte_NN_*). Solo lee el catálogo; no modifica nada.
     - tablas reales que alcanza cada reporte (directo o por las vistas/funciones que usa)  -> al menos 4 reportes con 6 o más
     - LEFT JOIN usados por cada reporte (en su SP y en las vistas/funciones que usa)       -> al menos 3 reportes
     - SELECT * y DISTINCT en el código (se ignoran los comentarios `--`)                   -> debe ser 0
   Se ejecuta en cualquier base TechCare_*. */
SET NOCOUNT ON;

CREATE TABLE #Alcanza (raiz INT, actual INT, PRIMARY KEY (raiz, actual));
;WITH Grafo AS (
    SELECT p.object_id AS raiz, p.object_id AS actual, 0 AS nivel FROM sys.procedures p WHERE p.name LIKE 'sp_Reporte[_]%'
    UNION ALL
    SELECT g.raiz, d.referenced_id, g.nivel + 1
    FROM Grafo g JOIN sys.sql_expression_dependencies d ON d.referencing_id = g.actual AND d.referenced_id IS NOT NULL
    WHERE g.nivel < 6)
INSERT #Alcanza SELECT DISTINCT raiz, actual FROM Grafo;

-- líneas de código (sin la parte comentada con --) de cada reporte y de lo que usa
CREATE TABLE #Codigo (raiz INT, linea NVARCHAR(MAX));
INSERT #Codigo
SELECT a.raiz, UPPER(LEFT(l.value, CHARINDEX('--', l.value + '--') - 1))
FROM #Alcanza a
JOIN sys.sql_modules m ON m.object_id = a.actual
CROSS APPLY STRING_SPLIT(REPLACE(m.definition, CHAR(13), ''), CHAR(10)) l;

SELECT p.name AS reporte,
    (SELECT COUNT(*) FROM #Alcanza a JOIN sys.tables t ON t.object_id = a.actual WHERE a.raiz = p.object_id) AS tablas_reales,
    (SELECT COUNT(*) FROM #Alcanza a JOIN sys.views v ON v.object_id = a.actual WHERE a.raiz = p.object_id) AS vistas,
    (SELECT COUNT(*) FROM #Alcanza a JOIN sys.objects o ON o.object_id = a.actual AND o.type IN ('IF','TF','FN') WHERE a.raiz = p.object_id) AS funciones,
    (SELECT COUNT(*) FROM #Codigo c WHERE c.raiz = p.object_id AND c.linea LIKE '%LEFT%JOIN%') AS left_join,
    (SELECT COUNT(*) FROM #Codigo c WHERE c.raiz = p.object_id AND c.linea LIKE '%SELECT *%')  AS select_estrella,
    (SELECT COUNT(*) FROM #Codigo c WHERE c.raiz = p.object_id AND c.linea LIKE '%DISTINCT%')  AS distinct_usado
FROM sys.procedures p WHERE p.name LIKE 'sp_Reporte[_]%' ORDER BY p.name;

PRINT '';
PRINT 'Tablas reales alcanzadas por cada reporte:';
SELECT p.name AS reporte, STRING_AGG(t.name, ', ') WITHIN GROUP (ORDER BY t.name) AS tablas
FROM sys.procedures p
JOIN #Alcanza a ON a.raiz = p.object_id
JOIN sys.tables t ON t.object_id = a.actual
WHERE p.name LIKE 'sp_Reporte[_]%'
GROUP BY p.name ORDER BY p.name;

PRINT '';
PRINT 'Resumen §5.1:';
;WITH R AS (
    SELECT p.object_id,
        (SELECT COUNT(*) FROM #Alcanza a JOIN sys.tables t ON t.object_id = a.actual WHERE a.raiz = p.object_id) AS tablas,
        (SELECT COUNT(*) FROM #Codigo c WHERE c.raiz = p.object_id AND c.linea LIKE '%LEFT%JOIN%') AS lj,
        (SELECT COUNT(*) FROM #Codigo c WHERE c.raiz = p.object_id AND (c.linea LIKE '%SELECT *%' OR c.linea LIKE '%DISTINCT%')) AS mal
    FROM sys.procedures p WHERE p.name LIKE 'sp_Reporte[_]%')
SELECT COUNT(*) AS reportes,
    SUM(CASE WHEN tablas >= 6 THEN 1 ELSE 0 END) AS con_6_o_mas_tablas,
    SUM(CASE WHEN lj >= 1 THEN 1 ELSE 0 END)     AS con_left_join,
    SUM(CASE WHEN mal > 0 THEN 1 ELSE 0 END)     AS con_select_estrella_o_distinct,
    CASE WHEN SUM(CASE WHEN tablas >= 6 THEN 1 ELSE 0 END) >= 4 AND SUM(CASE WHEN lj >= 1 THEN 1 ELSE 0 END) >= 3
              AND SUM(CASE WHEN mal > 0 THEN 1 ELSE 0 END) = 0 THEN 'CUMPLE' ELSE 'REVISAR' END AS resultado
FROM R;
DROP TABLE #Codigo; DROP TABLE #Alcanza;
