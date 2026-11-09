USE monitoreo_etl;

/* =====================================================
   TKT-202 - Filas que se pierden en cargas exitosas
   Reclamo: el reporte de ventas a veces tiene menos
   pedidos que el sistema (ticket 2009) y hubo clientes
   nuevos que no aparecían (ticket 2008), aunque las
   cargas figuran como OK.
   ===================================================== */

-- a) Reconciliación origen - destino: corridas OK con filas perdidas
--    En una corrida correcta, filas_leidas (origen) = filas_cargadas (destino)
--    Se excluyen las corridas con ERROR: ahí no se carga nada a propósito
--    FORMATO: una fila por corrida con diferencia, ordenado por fecha
--    Hallazgo: 4 corridas con estado OK que perdieron filas sin avisar
SELECT
    e.id_ejecucion,
    pr.nombre,
    DATE(e.inicio) AS fecha,
    e.filas_leidas,
    e.filas_cargadas,
    e.filas_leidas - e.filas_cargadas AS filas_perdidas
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
WHERE e.estado = 'OK'
    AND e.filas_leidas <> e.filas_cargadas
ORDER BY e.inicio;

-- Control a) Corridas OK con filas leídas = cargadas: 143 OK - 4 = 139
SELECT COUNT(*) AS corridas_ok_sin_perdida
FROM ejecuciones
WHERE estado = 'OK'
    AND filas_leidas = filas_cargadas;

-- b) Impacto por proceso: filas perdidas en el mes
--    FORMATO: una fila por proceso con pérdida
--    CONTROL: 12 + 5 + 30 = 47 en carga_pedidos; 3 en carga_clientes
SELECT
    pr.nombre,
    SUM(e.filas_leidas) AS filas_leidas_mes,
    SUM(e.filas_leidas - e.filas_cargadas) AS filas_perdidas_mes
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
WHERE e.estado = 'OK'
GROUP BY pr.nombre
HAVING SUM(e.filas_leidas - e.filas_cargadas) > 0
ORDER BY filas_perdidas_mes DESC;

-- c) ¿Los tickets de los usuarios coinciden con las corridas con pérdida?
--    Cruce por fecha: ticket abierto el mismo día que una corrida con pérdida
--    Hallazgo: el ticket 2008 (14/10, clientes que no aparecen) coincide con
--              carga_clientes del 14/10 (3 filas perdidas). El 2009 (19/10,
--              menos pedidos) coincide con carga_pedidos del 19/10 (5 filas).
--              Las pérdidas del 09/10 (12) y del 24/10 (30) no tienen ticket:
--              nadie las detectó
SELECT
    e.id_ejecucion,
    pr.nombre,
    DATE(e.inicio) AS fecha,
    e.filas_leidas - e.filas_cargadas AS filas_perdidas,
    t.id_ticket,
    t.descripcion
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
LEFT JOIN tickets AS t
    ON DATE(t.apertura) = DATE(e.inicio)
    AND t.id_ejecucion IS NULL
WHERE e.estado = 'OK'
    AND e.filas_leidas <> e.filas_cargadas
ORDER BY e.inicio;

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-202
   Problema:        4 corridas terminaron con estado OK pero cargaron
                    menos filas de las que leyeron. El proceso no avisa:
                    la pérdida es silenciosa.
   Evidencia:       carga_pedidos: 09/10 (12 filas), 19/10 (5) y 24/10
                    (30): 47 pedidos perdidos en el mes.
                    carga_clientes: 14/10 (3 filas).
                    Control: 139 corridas OK sin pérdida + 4 = 143.
                    Los tickets 2008 y 2009 coinciden en fecha con dos de
                    estas corridas. Las del 09 y 24/10 no tienen ticket.
   Causa probable:  La carga descarta filas (por ejemplo, por fallar una
                    validación o una conversión) sin registrarlo como
                    error. Sin acceso a los logs no se puede confirmar
                    qué filas ni por qué.
   Impacto:         47 pedidos y 3 clientes que existen en el origen no
                    llegaron a los reportes. Los usuarios solo lo notaron
                    en 2 de las 4 corridas.
   Prioridad:       Alta: es una pérdida de datos que nadie ve.
   Acción:          Escalado a Data Engineering: identificar las filas
                    descartadas en esas 4 corridas y recargarlas.
                    Sugerido: que la carga marque como ERROR (o alerte)
                    toda corrida con filas_leidas <> filas_cargadas.
                    Seguimiento hasta la corrección.
   Respuesta al
   solicitante:     "Encontramos la causa: en algunas cargas nocturnas se
                    perdieron registros aunque el proceso figuraba como
                    exitoso. Ya lo derivamos para recuperar los datos y
                    para que, si vuelve a pasar, el proceso avise. Les
                    aviso cuando estén recargados."
*/
