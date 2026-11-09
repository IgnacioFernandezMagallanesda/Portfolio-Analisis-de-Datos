USE tienda_tech;

/* =====================================================
   TKT-104 - Estados de pedido inconsistentes
   Reclamo: el dashboard muestra el mismo estado repetido
   como si fueran estados distintos.
   ===================================================== */

-- a) Todas las variantes exactas de estado
--    Se compara con COLLATE utf8mb4_0900_bin: distingue mayúsculas y espacios
--    (utf8mb4_bin ignora los espacios al final y junta variantes distintas)
--    FORMATO: una fila por variante, con el texto entre corchetes y su largo
--    CONTROL: la suma de cantidad_pedidos tiene que dar 76
--    Hallazgo: 9 variantes para 3 estados reales
SELECT
    estado COLLATE utf8mb4_0900_bin AS estado_exacto,
    CONCAT('[', estado, ']') AS estado_visible,
    LENGTH(estado) AS estado_largo,
    COUNT(*) AS cantidad_pedidos
FROM stg_pedidos
GROUP BY estado_exacto, estado_visible, estado_largo
ORDER BY estado_exacto;

-- b) Clasificación de los errores (análisis sobre el resultado de a)
--    Estados reales: CANCELADO, ENTREGADO, PENDIENTE
--    Filas mal escritas: 6 de 76
--    - Espacios de más:       ' Cancelado', 'Entregado '
--    - Mayúsculas distintas:  'entregado', 'pendiente', 'ENTREGADO'
--    - Ambos:                 'ENTREGADO '
--    Según el reclamo, el dashboard agrupa sin distinguir mayúsculas pero sí
--    espacios: muestra 5 grupos (Cancelado y Entregado repetidos).
--    Los errores de mayúsculas quedan ocultos en el dashboard, pero existen

-- Control b) Filas con estado fuera del formato correcto ('Cancelado', 'Entregado', 'Pendiente')
--    Comparación exacta con COLLATE utf8mb4_0900_bin
--    Esperado: 6. Sin la collation daría 3: solo detecta los espacios,
--    no las mayúsculas (lo mismo que le pasa al dashboard)
SELECT COUNT(*) AS filas_mal_escritas
FROM stg_pedidos
WHERE estado COLLATE utf8mb4_0900_bin NOT IN ('Cancelado', 'Entregado', 'Pendiente');

-- c) Estados normalizados: una fila por estado real
--    FORMATO: estado en mayúsculas y sin espacios, variantes exactas y pedidos
--    Esperado (según a): variantes 2 + 5 + 2 = 9; pedidos 11 + 53 + 12 = 76
--    CONTROL: variantes = 9 y pedidos = 76
SELECT
    UPPER(TRIM(estado)) AS estado_normalizado,
    COUNT(DISTINCT estado COLLATE utf8mb4_0900_bin) AS variantes_estado,
    COUNT(*) AS cantidad_pedidos
FROM stg_pedidos
GROUP BY estado_normalizado
ORDER BY estado_normalizado;

-- d) Evidencia para la causa: ¿los errores se concentran en alguna corrida?
--    FORMATO: id, estado entre corchetes y fecha de carga, ordenado por fecha de carga
--    CONTROL: 6 filas (igual que el control b)
--    Hallazgo: 6 errores en 6 corridas distintas (04, 08, 11, 21, 24 y 27/10).
--              Sin patrón por corrida: el problema viene del ingreso en el origen
SELECT
    id_pedido,
    CONCAT('[', estado, ']') AS estado_visible,
    fecha_carga
FROM stg_pedidos
WHERE estado COLLATE utf8mb4_0900_bin NOT IN ('Cancelado', 'Entregado', 'Pendiente')
ORDER BY fecha_carga;

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-104
   Problema:        El mismo estado aparece escrito de 9 formas distintas,
                    cuando hay 3 estados reales (Cancelado, Entregado,
                    Pendiente).
   Evidencia:       6 de 76 filas fuera del formato correcto (comparación
                    exacta). Sin distinguir mayúsculas solo se detectan 3.
                    - Espacios de más: ' Cancelado', 'Entregado '
                    - Mayúsculas: 'entregado', 'pendiente', 'ENTREGADO'
                    - Ambos: 'ENTREGADO '
                    Variantes por estado: 2 + 5 + 2 = 9.
                    Las 6 filas están en 6 corridas distintas
                    (04, 08, 11, 21, 24 y 27/10).
   Causa probable:  Error de ingreso de datos en el origen. Los errores
                    están sueltos en corridas distintas, sin patrón de
                    carga. Probablemente el estado se escribe a mano
                    (texto libre) en el sistema de ventas.
   Impacto:         Según el reclamo, el dashboard muestra 5 estados en
                    vez de 3 (Cancelado y Entregado repetidos por los
                    espacios). Los errores de mayúsculas quedan ocultos
                    en el dashboard, pero existen. Cualquier consulta que
                    filtre por estado sin normalizar pierde filas: por
                    ejemplo, estado = 'Cancelado' no incluye ' Cancelado'.
   Acción:          Escalado al responsable del sistema de ventas: que el
                    estado se elija de una lista fija (solución de fondo).
                    Sugerido a Data Engineering: normalizar el estado en
                    la carga (mitigación), previo acuerdo del formato
                    final (ej. 'Entregado'). Seguimiento hasta la
                    corrección.
   Respuesta al
   solicitante:     "Los estados repetidos vienen de errores de escritura
                    en el sistema de ventas: el mismo estado está escrito
                    de 9 formas distintas, con espacios de más y
                    mayúsculas diferentes. Mientras se corrige, pueden
                    normalizarlo en el dashboard (quitar espacios y
                    unificar mayúsculas). Ya lo derivamos para que el
                    estado se elija de una lista fija. Les aviso cuando
                    esté resuelto."
*/
