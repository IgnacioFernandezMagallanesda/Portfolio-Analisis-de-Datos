USE monitoreo_etl;

/* =====================================================
   TKT-204 - Cargas que tardan más de lo normal
   Reclamo: algunos días el dashboard se actualiza tarde
   (ticket 2010: carga de productos demorada).
   ===================================================== */

-- a) Duración real contra duración esperada por proceso
--    TIMESTAMPDIFF(MINUTE, inicio, fin) da los minutos de cada corrida
--    FORMATO: una fila por proceso con la duración esperada, el promedio
--             y el máximo del mes (solo corridas OK)
--    Hallazgo: en carga_productos (47 min) y actualizacion_dashboard (85 min)
--              el máximo se dispara. Su promedio (7,2 y 18,2 min) queda por
--              encima de lo esperado por esa sola corrida; el resto de los
--              procesos está cerca de lo esperado
SELECT
    pr.nombre,
    pr.duracion_esperada_min,
    ROUND(AVG(TIMESTAMPDIFF(MINUTE, e.inicio, e.fin)), 1) AS duracion_promedio_min,
    MAX(TIMESTAMPDIFF(MINUTE, e.inicio, e.fin)) AS duracion_maxima_min
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
WHERE e.estado = 'OK'
GROUP BY pr.id_proceso, pr.nombre, pr.duracion_esperada_min
ORDER BY pr.nombre;

-- b) Corridas que tardaron más del doble de lo esperado
--    Criterio: más de 2 veces la duración esperada del proceso
--    FORMATO: una fila por corrida lenta, con cuántas veces se pasó
--    CONTROL: 2 corridas (las mismas que marcan el máximo en a)
--    Hallazgo: carga_productos el 28/10 (47 min, 9,4 veces lo esperado) y
--              actualizacion_dashboard el 30/10 (85 min, 5,7 veces)
SELECT
    e.id_ejecucion,
    pr.nombre,
    DATE(e.inicio) AS fecha,
    TIMESTAMPDIFF(MINUTE, e.inicio, e.fin) AS duracion_min,
    pr.duracion_esperada_min,
    ROUND(TIMESTAMPDIFF(MINUTE, e.inicio, e.fin) / pr.duracion_esperada_min, 1) AS veces_esperado,
    TIME(e.fin) AS hora_fin
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
WHERE e.estado = 'OK'
    AND TIMESTAMPDIFF(MINUTE, e.inicio, e.fin) > 2 * pr.duracion_esperada_min
ORDER BY e.inicio;

-- c) ¿Hay ticket para cada corrida lenta?
--    Hallazgo: la demora del 28/10 tiene ticket (2010, en curso). La del
--              30/10 en actualizacion_dashboard no tiene ticket
SELECT
    DATE(e.inicio) AS fecha,
    pr.nombre,
    t.id_ticket,
    t.estado AS estado_ticket
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
LEFT JOIN tickets AS t
    ON DATE(t.apertura) = DATE(e.inicio)
    AND t.descripcion LIKE '%demorada%'
WHERE e.estado = 'OK'
    AND TIMESTAMPDIFF(MINUTE, e.inicio, e.fin) > 2 * pr.duracion_esperada_min
ORDER BY e.inicio;

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-204
   Problema:        2 corridas terminaron OK pero tardaron mucho más de
                    lo normal, y retrasaron la actualización de los datos.
   Evidencia:       carga_productos 28/10: 47 min (esperado 5, 9,4 veces).
                    actualizacion_dashboard 30/10: 85 min (esperado 15,
                    5,7 veces), terminó pasadas las 7:25 en vez de las 6:15.
                    El resto de las corridas está cerca de lo esperado.
                    La del 28/10 tiene ticket (2010); la del 30/10, no.
   Causa probable:  Casos aislados (un día cada uno), sin patrón. Puede ser
                    un volumen mayor, un bloqueo en la base o un problema
                    de recursos del servidor. Hace falta revisar los logs
                    de esas corridas.
   Impacto:         El 30/10 el dashboard de ventas estuvo desactualizado
                    más de una hora al inicio de la jornada.
   Acción:          Sumado al ticket 2010 (Data Engineering) con la
                    evidencia de ambas corridas. Sugerido: alerta cuando
                    una corrida supere 2 veces su duración esperada.
                    Seguimiento hasta la corrección.
   Respuesta al
   solicitante:     "La demora del 28/10 en productos y la del 30/10 en
                    el dashboard fueron casos puntuales: las cargas
                    terminaron bien, pero tardaron mucho más de lo normal.
                    Lo sumamos al ticket abierto para revisar la causa y
                    para que haya una alerta si se repite."
*/
