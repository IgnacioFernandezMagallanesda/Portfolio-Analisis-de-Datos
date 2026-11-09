USE monitoreo_etl;

/* =====================================================
   TKT-201 - Procesos con más fallas en octubre
   Pedido: el líder de Data Engineering quiere saber qué
   procesos fallaron más en el mes para priorizar arreglos.
   ===================================================== */

-- a) Tasa de éxito general del mes
--    FORMATO: una fila con corridas, errores y % de éxito
--    CONTROL: corridas OK + corridas con error = total (143 + 9 = 152)
SELECT
    COUNT(*) AS corridas,
    SUM(CASE WHEN estado = 'ERROR' THEN 1 ELSE 0 END) AS corridas_error,
    ROUND(SUM(CASE WHEN estado = 'OK' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_exito
FROM ejecuciones;

-- b) Tasa de éxito por proceso
--    FORMATO: una fila por proceso, ordenado de peor a mejor
--    CONTROL: la suma de corridas da 152 y la de errores, 9
--    Hallazgo: carga_pagos tiene 80,6% de éxito (6 errores de 31 corridas),
--              muy por debajo del resto. carga_clientes y carga_productos
--              tienen 100%, pero corrieron menos de 31 veces (ver TKT-203)
SELECT
    pr.nombre,
    COUNT(*) AS corridas,
    SUM(CASE WHEN e.estado = 'ERROR' THEN 1 ELSE 0 END) AS corridas_error,
    ROUND(SUM(CASE WHEN e.estado = 'OK' THEN 1 ELSE 0 END) / COUNT(*) * 100, 1) AS pct_exito
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
GROUP BY pr.id_proceso, pr.nombre
ORDER BY pct_exito, pr.nombre;

-- c) Detalle de los errores de carga_pagos
--    FORMATO: fecha y mensaje de cada corrida con error, en orden de fecha
--    Hallazgo: los 6 errores son el mismo (timeout con la API de pagos) y
--              empiezan el 20/10: hasta el 19/10 el proceso no había fallado.
--              Patrón de un cambio o problema del lado del proveedor
SELECT
    e.id_ejecucion,
    DATE(e.inicio) AS fecha,
    e.mensaje_error
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
WHERE pr.nombre = 'carga_pagos'
    AND e.estado = 'ERROR'
ORDER BY e.inicio;

-- Control c) Primera y última falla de carga_pagos, y corridas OK antes del 20/10
--    Tiene que dar: primera 20/10, última 29/10, y 19 corridas OK previas (01 al 19/10)
SELECT
    MIN(CASE WHEN e.estado = 'ERROR' THEN DATE(e.inicio) END) AS primera_falla,
    MAX(CASE WHEN e.estado = 'ERROR' THEN DATE(e.inicio) END) AS ultima_falla,
    SUM(CASE WHEN e.estado = 'OK' AND DATE(e.inicio) < '2026-10-20' THEN 1 ELSE 0 END) AS ok_antes_del_20
FROM ejecuciones AS e
INNER JOIN procesos AS pr
    ON e.id_proceso = pr.id_proceso
WHERE pr.nombre = 'carga_pagos';

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-201
   Problema:        Pedido de diagnóstico: qué procesos fallaron más en
                    octubre.
   Evidencia:       Éxito general: 94,1% (143 de 152 corridas).
                    carga_pagos: 80,6% (6 errores en 31 corridas), todos
                    "Timeout al conectar con la API de pagos", entre el
                    20 y el 29/10. Antes del 20/10: 19 corridas OK seguidas.
                    carga_pedidos: 93,5% (2 errores con causas distintas).
                    actualizacion_dashboard: 96,8% (1 error).
   Causa probable:  carga_pagos: cambio o problema en la API del proveedor
                    a partir del 20/10 (mismo error, aparece de golpe y se
                    repite). Los errores de los otros procesos son aislados.
   Impacto:         6 días sin datos de pagos cargados en octubre.
   Prioridad:       Alta para carga_pagos.
   Acción:          Escalado a Data Engineering con la evidencia, para
                    coordinar con el proveedor de pagos (ya existe el
                    ticket 2007, escalado al proveedor y abierto).
                    Seguimiento hasta la corrección.
   Respuesta al
   solicitante:     "El proceso con más fallas es carga_pagos: 6 errores
                    en el mes, todos por timeout con la API del proveedor
                    y todos desde el 20/10. Hasta ese día no había fallado.
                    El resto de los procesos tiene errores aislados.
                    Recomiendo priorizar carga_pagos."
*/
