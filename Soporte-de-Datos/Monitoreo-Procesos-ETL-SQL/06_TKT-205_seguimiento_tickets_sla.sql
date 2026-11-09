USE monitoreo_etl;

/* =====================================================
   TKT-205 - Revisión mensual de tickets
   Pedido: la coordinación de soporte pide el cierre de
   octubre: errores sin ticket, cumplimiento del SLA y
   tickets pendientes.
   Fecha de corte: 31/10/2026 23:59.
   ===================================================== */

-- a) Corridas con error que no tienen ticket
--    LEFT JOIN de ejecuciones con tickets: un error sin ticket queda con
--    las columnas de tickets en NULL
--    FORMATO: una fila por corrida con error sin ticket
--    CONTROL: 9 errores en el mes - 7 con ticket = 2
--    Hallazgo: los timeouts de carga_pagos del 27 y del 29/10 no tienen ticket
SELECT
    e.id_ejecucion,
    pr.nombre,
    DATE(e.inicio) AS fecha,
    e.mensaje_error
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
LEFT JOIN tickets AS t
    ON t.id_ejecucion = e.id_ejecucion
WHERE e.estado = 'ERROR'
    AND t.id_ticket IS NULL
ORDER BY e.inicio;

-- b) Cumplimiento del SLA por ticket
--    Horas de resolución = desde la apertura hasta el cierre. Si el ticket
--    sigue abierto, se cuenta hasta la fecha de corte (COALESCE)
--    Se compara en minutos para no perder precisión (TIMESTAMPDIFF en horas
--    trunca: 3 h 25 min daría 3)
--    FORMATO: una fila por ticket, ordenado por id
SELECT
    t.id_ticket,
    t.prioridad,
    t.estado,
    s.horas_resolucion AS sla_horas,
    ROUND(TIMESTAMPDIFF(MINUTE, t.apertura, COALESCE(t.cierre, '2026-10-31 23:59:00')) / 60, 1) AS horas_resolucion,
    CASE
        WHEN TIMESTAMPDIFF(MINUTE, t.apertura, COALESCE(t.cierre, '2026-10-31 23:59:00')) <= s.horas_resolucion * 60
            THEN 'Cumple'
        ELSE 'Vencido'
    END AS estado_sla
FROM tickets AS t
INNER JOIN sla AS s
    ON t.prioridad = s.prioridad
ORDER BY t.id_ticket;

-- c) Cumplimiento del SLA por prioridad
--    FORMATO: una fila por prioridad con tickets, vencidos y % de cumplimiento
--    CONTROL: tickets 7 + 3 + 2 = 12; vencidos 3 + 2 + 1 = 6
--    Hallazgo: 50% de cumplimiento general. En prioridad Alta se cumple
--              en 4 de 7 (57,1%)
SELECT
    t.prioridad,
    COUNT(*) AS tickets,
    SUM(CASE WHEN TIMESTAMPDIFF(MINUTE, t.apertura, COALESCE(t.cierre, '2026-10-31 23:59:00')) > s.horas_resolucion * 60
             THEN 1 ELSE 0 END) AS vencidos,
    ROUND(SUM(CASE WHEN TIMESTAMPDIFF(MINUTE, t.apertura, COALESCE(t.cierre, '2026-10-31 23:59:00')) <= s.horas_resolucion * 60
                   THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_cumplimiento
FROM tickets AS t
INNER JOIN sla AS s
    ON t.prioridad = s.prioridad
GROUP BY t.prioridad, s.horas_resolucion
ORDER BY s.horas_resolucion;

-- d) Tickets pendientes al cierre del mes
--    FORMATO: una fila por ticket sin fecha de cierre, con días abierto
--    Hallazgo: 2 pendientes, los dos con el SLA vencido: 2007 (carga_pagos,
--              escalado al proveedor) y 2010 (carga de productos demorada)
SELECT
    t.id_ticket,
    t.prioridad,
    t.estado,
    t.equipo_asignado,
    t.descripcion,
    TIMESTAMPDIFF(DAY, t.apertura, '2026-10-31 23:59:00') AS dias_abierto
FROM tickets AS t
WHERE t.cierre IS NULL
ORDER BY t.apertura;

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-205
   Problema:        Revisión mensual de tickets de octubre.
   Evidencia:       2 errores sin ticket: carga_pagos 27 y 29/10 (timeout).
                    SLA: se cumplió en 6 de 12 tickets (50%). Prioridad
                    Alta: 4 de 7. Vencidos con más demora: 2007 (abierto,
                    más de 5 días) y 2012 (115 h contra un SLA de 72 h).
                    Pendientes al corte: 2007 (Alta, escalado al
                    proveedor) y 2010 (Media, en curso).
   Causa probable:  Los errores sin ticket son repeticiones del mismo
                    problema de carga_pagos: se trataron como parte del
                    ticket 2007 sin vincularlos. Los vencimientos en Alta
                    coinciden con casos que dependían de otro equipo o de
                    un proveedor.
   Impacto:         Sin ticket por corrida, no queda registro de cuántas
                    veces falló un proceso. Los vencimientos de SLA afectan
                    a los usuarios que esperan los datos.
   Acción:          Vincular los errores del 27 y 29/10 al ticket 2007.
                    Seguimiento diario de 2007 y 2010 hasta su cierre.
                    Sugerido: crear el ticket automáticamente con cada
                    corrida en ERROR.
   Respuesta al
   solicitante:     "En octubre se cumplió el SLA en 6 de 12 tickets (4 de
                    7 en prioridad Alta). Quedan 2 pendientes, los dos
                    vencidos y con seguimiento: el de pagos depende del
                    proveedor. Además, 2 fallas de pagos no tenían ticket;
                    ya las vinculamos al ticket abierto."
*/
