USE monitoreo_etl;

/* =====================================================
   TKT-203 - Días en que un proceso no corrió
   Reclamo: BI detectó días en que el dashboard mostraba
   clientes y productos desactualizados, sin que ningún
   proceso figurara con error.
   ===================================================== */

-- a) Corridas por proceso en el mes
--    Todos los procesos corren una vez por día: en octubre deberían ser 31
--    FORMATO: una fila por proceso con sus corridas y las que faltan
--    Hallazgo: carga_clientes tiene 29 y carga_productos 30. Faltan 3 corridas
SELECT
    pr.nombre,
    COUNT(e.id_ejecucion) AS corridas,
    31 - COUNT(e.id_ejecucion) AS corridas_faltantes
FROM procesos AS pr
LEFT JOIN ejecuciones AS e
    ON e.id_proceso = pr.id_proceso
GROUP BY pr.id_proceso, pr.nombre
ORDER BY corridas_faltantes DESC, pr.nombre;

-- b) Qué días faltan
--    Un día sin corrida no deja ninguna fila en ejecuciones, así que no se
--    puede encontrar filtrando esa tabla. Hay que armar primero el
--    calendario completo (todos los días x todos los procesos) y buscar
--    con LEFT JOIN las combinaciones que no tienen corrida.
--    El calendario se arma con una CTE recursiva: arranca en el 01/10 y
--    suma un día por vuelta hasta el 31/10
--    FORMATO: una fila por día y proceso sin corrida
--    CONTROL: 3 filas (2 + 1, igual que el punto a)
--    Hallazgo: carga_clientes no corrió el sábado 17 ni el domingo 18/10;
--              carga_productos no corrió el domingo 25/10
WITH RECURSIVE calendario AS (
    SELECT DATE('2026-10-01') AS dia
    UNION ALL
    SELECT dia + INTERVAL 1 DAY
    FROM calendario
    WHERE dia < '2026-10-31'
)
SELECT
    c.dia,
    DAYNAME(c.dia) AS dia_semana,
    pr.nombre
FROM calendario AS c
CROSS JOIN procesos AS pr
LEFT JOIN ejecuciones AS e
    ON e.id_proceso = pr.id_proceso
    AND DATE(e.inicio) = c.dia
WHERE e.id_ejecucion IS NULL
ORDER BY c.dia, pr.nombre;

-- Control b) El calendario tiene que tener 31 días x 5 procesos = 155 combinaciones,
--    y 155 - 152 corridas registradas = 3 faltantes
WITH RECURSIVE calendario AS (
    SELECT DATE('2026-10-01') AS dia
    UNION ALL
    SELECT dia + INTERVAL 1 DAY
    FROM calendario
    WHERE dia < '2026-10-31'
)
SELECT
    COUNT(*) AS combinaciones_dia_proceso,
    COUNT(*) - (SELECT COUNT(*) FROM ejecuciones) AS corridas_faltantes
FROM calendario
CROSS JOIN procesos;

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-203
   Problema:        3 corridas programadas no se ejecutaron y no quedó
                    ningún registro: ni OK ni ERROR.
   Evidencia:       carga_clientes: 29 corridas de 31. Faltan sábado 17
                    y domingo 18/10. carga_productos: 30 de 31. Falta
                    domingo 25/10. Control: 155 combinaciones día-proceso
                    - 152 corridas = 3.
   Causa probable:  El programador de tareas no lanzó el proceso esos días
                    (por ejemplo, una pausa o mantenimiento de fin de
                    semana). Las 3 faltas caen en fin de semana, pero no
                    todos los fines de semana: no es una regla fija.
   Impacto:         Esos días el dashboard mostró clientes y productos del
                    día anterior. Como no hay registro de la corrida,
                    ningún control basado en errores lo detecta.
   Acción:          Escalado a Data Engineering: revisar la
                    configuración del programador para esas fechas.
                    Sugerido: un control diario que compare las corridas
                    esperadas contra las registradas (esta misma
                    consulta) y alerte las faltantes.
                    Seguimiento hasta la corrección.
   Respuesta al
   solicitante:     "Los días con datos desactualizados coinciden con 3
                    cargas que no se ejecutaron: clientes el 17 y 18/10, y
                    productos el 25/10. No dieron error porque nunca
                    arrancaron. Ya lo derivamos para revisar por qué no
                    corrieron y para sumar un control que avise."
*/
