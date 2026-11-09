USE tienda_tech;

/* =====================================================
   TKT-101 - Pedidos duplicados en staging
   Reclamo: el reporte de octubre muestra más pedidos
   que los 72 que informa el sistema origen.
   ===================================================== */

-- a) Confirmar el problema: total de filas vs. pedidos distintos
--    FORMATO: una fila con total, distintos y diferencia
--    CONTROL: total - distintos = filas sobrantes. Resultado: 76 - 72 = 4
SELECT
    COUNT(*) AS total_filas,
    COUNT(DISTINCT id_pedido) AS pedidos_distintos,
    COUNT(*) - COUNT(DISTINCT id_pedido) AS filas_sobrantes
FROM stg_pedidos;

-- b) Pedidos cargados más de una vez
--    FORMATO: una fila por pedido duplicado, ordenado por id_pedido
SELECT
    id_pedido,
    COUNT(*) AS veces_cargado
FROM stg_pedidos
GROUP BY id_pedido
HAVING COUNT(*) > 1
ORDER BY id_pedido;

-- Control b) La suma de cargas de más tiene que dar 4 (igual que en a)
SELECT SUM(veces_cargado - 1) AS filas_sobrantes
FROM (
    SELECT
        id_pedido,
        COUNT(*) AS veces_cargado
    FROM stg_pedidos
    GROUP BY id_pedido
    HAVING COUNT(*) > 1
) AS dup;

-- c) Filas completas de los pedidos duplicados, para comparar cada par
--    FORMATO: todas las columnas, ordenado por id_pedido (cada par queda junto)
SELECT *
FROM stg_pedidos
WHERE id_pedido IN (
    SELECT id_pedido
    FROM stg_pedidos
    GROUP BY id_pedido
    HAVING COUNT(*) > 1
)
ORDER BY id_pedido;

-- Control c) Filas únicas (idénticas en todas las columnas)
--    Si da 72, los duplicados son copias exactas
SELECT COUNT(*) AS filas_unicas
FROM (
    SELECT DISTINCT *
    FROM stg_pedidos
) AS unicas;

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-101
   Problema:        stg_pedidos tiene 76 filas y el sistema origen
                    informa 72 pedidos (4 filas de más).
   Evidencia:       4 pedidos cargados 2 veces: 1003, 1018, 1039, 1065.
                    Suma de cargas de más = 4 (explica toda la diferencia).
                    SELECT DISTINCT * = 72: son copias exactas.
   Causa probable:  Cada par tiene la misma fecha_carga: el pedido se
                    insertó dos veces en la misma corrida. Posible
                    re-ejecución del proceso o envío duplicado del origen.
                    La carga no valida id_pedido repetidos.
   Impacto:         El reporte de octubre muestra 76 pedidos en vez de 72.
   Acción:          Escalado a Data Engineering con consultas y evidencia.
                    Seguimiento hasta la corrección.
   Respuesta al
   solicitante:     "La diferencia se debe a 4 pedidos que se cargaron
                    dos veces. El número correcto es 72. Ya lo derivamos
                    al equipo de datos para corregirlo y evitar que se
                    repita. Les aviso cuando esté resuelto."
*/
