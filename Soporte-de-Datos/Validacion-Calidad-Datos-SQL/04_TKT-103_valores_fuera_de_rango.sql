USE tienda_tech;

/* =====================================================
   TKT-103 - Valores fuera de rango en stg_pedidos
   Reclamo: hay pedidos con monto negativo y pedidos
   con fecha de carga anterior a la fecha del pedido.
   ===================================================== */

-- a) Perfil de rangos: mínimo y máximo de columnas numéricas y de fecha
--    FORMATO: una fila, MIN y MAX por columna
--    Esperado: cantidad >= 1; fecha_carga en octubre; fecha_pedido puede
--              tener fines de septiembre (se cargan con atraso)
--    Hallazgo: cantidad_min = -2 (imposible). Fechas dentro de lo esperado,
--              pero el perfil no compara fecha_pedido contra fecha_carga
SELECT
    MIN(cantidad) AS cantidad_min,
    MAX(cantidad) AS cantidad_max,
    MIN(precio_unitario) AS precio_unitario_min,
    MAX(precio_unitario) AS precio_unitario_max,
    MIN(fecha_pedido) AS fecha_pedido_min,
    MAX(fecha_pedido) AS fecha_pedido_max,
    MIN(fecha_carga) AS fecha_carga_min,
    MAX(fecha_carga) AS fecha_carga_max
FROM stg_pedidos;

-- b) Pedidos con cantidad inválida (un pedido real tiene al menos 1 unidad)
--    FORMATO: todas las columnas, ordenado por id_pedido
--    Hallazgo: 3 pedidos: 1023 (0), 1034 (-2), 1049 (-1)
SELECT *
FROM stg_pedidos
WHERE cantidad < 1
ORDER BY id_pedido;

-- Control b) Filas con cantidad válida: 73. Inválidas + válidas = 3 + 73 = 76
--    Válido porque cantidad no tiene NULL (perfil de nulos, TKT-102)
SELECT COUNT(*) AS filas_cantidad_valida
FROM stg_pedidos
WHERE cantidad >= 1;

-- c) Pedidos con fecha de carga anterior a la fecha del pedido (imposible)
--    FORMATO: id, ambas fechas y días de carga - pedido, ordenado por la diferencia
--    Esperado: en un pedido normal la diferencia es >= 0; en un error, negativa
--    Hallazgo: 2 pedidos: 1045 (-9 días) y 1013 (-5 días)
SELECT
    id_pedido,
    fecha_pedido,
    fecha_carga,
    DATEDIFF(fecha_carga, fecha_pedido) AS dias_carga_vs_pedido
FROM stg_pedidos
WHERE fecha_pedido > fecha_carga
ORDER BY dias_carga_vs_pedido;

-- Control c) Filas con fechas coherentes: 74. Coherentes + imposibles = 74 + 2 = 76
--    Válido porque ninguna de las dos fechas tiene NULL (perfil de nulos, TKT-102)
SELECT COUNT(*) AS filas_fechas_validas
FROM stg_pedidos
WHERE fecha_pedido <= fecha_carga;

-- d) Impacto en plata de los pedidos con cantidad inválida
--    FORMATO: una fila; cantidad de pedidos y monto que suman
--    CONTROL: (0 × 27.500) + (-2 × 32.000) + (-1 × 41.000) = 0 - 64.000 - 41.000 = -105.000
--    Hallazgo: estos pedidos restan $105.000 del total (el total está subestimado).
--              El monto real es desconocido: las cantidades correctas las tiene que confirmar el origen
SELECT
    COUNT(*) AS pedidos_cantidad_invalida,
    SUM(cantidad * precio_unitario) AS monto_cantidad_invalida
FROM stg_pedidos
WHERE cantidad < 1;

-- e) Hipótesis de devolución: ¿el cliente compró antes ese producto?
--    Pedidos con el mismo cliente y producto que los 3 inválidos
--    FORMATO: todas las columnas, ordenado por cliente y fecha de pedido
--    Hallazgo: 1034 (-2): el cliente 8 compró 2 unidades el 12/10 (pedido 1026),
--              pero la "devolución" tiene fecha anterior (11/10). No se confirma:
--              la compra original pudo ser previa a octubre, o la fecha está mal ingresada.
--              1049 (-1): no hay compra previa del producto. Probable error de ingreso.
--              1023 (0): el cliente compró el producto el 06/10 (pedido 1046).
SELECT *
FROM stg_pedidos
WHERE (id_cliente = 8  AND id_producto = 2)
   OR (id_cliente = 12 AND id_producto = 4)
   OR (id_cliente = 22 AND id_producto = 3)
ORDER BY id_cliente, fecha_pedido;

-- f) Hipótesis de cancelación: ¿cancelar pone la cantidad en 0?
--    FORMATO: una fila por cantidad, con los pedidos cancelados de cada una
--    CONTROL: 1 + 2 + 2 + 4 + 2 = 11 cancelados
--    Hallazgo: solo 1 de 11 cancelados tiene cantidad 0. No es una regla del
--              sistema: el 0 del pedido 1023 es un caso aislado
SELECT
    cantidad,
    COUNT(*) AS pedidos_cancelados
FROM stg_pedidos
WHERE UPPER(TRIM(estado)) = 'CANCELADO'
GROUP BY cantidad
ORDER BY cantidad;

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-103
   Problema:        (1) 3 pedidos con cantidad menor a 1, que generan
                    montos negativos. (2) 2 pedidos con fecha de pedido
                    posterior a su fecha de carga.
   Evidencia:       (1) Perfil de rangos: cantidad mínima = -2.
                    Pedidos 1023 (0), 1034 (-2) y 1049 (-1).
                    Control: 3 inválidas + 73 válidas = 76.
                    (2) Pedidos 1045 (carga 9 días antes del pedido) y
                    1013 (5 días antes). Control: 2 + 74 coherentes = 76.
                    Solo 1 de 11 cancelados tiene cantidad 0: cancelar
                    no pone la cantidad en 0.
   Causa probable:  Error de ingreso de datos en el origen. Las 5 filas
                    son casos aislados en corridas distintas.
                    - 1034: posible devolución (el cliente compró 2 unidades
                      del producto el 12/10, pedido 1026), pero su fecha es
                      anterior a esa compra. No se puede confirmar con datos
                      de octubre.
                    - 1049 y 1023: sin compra previa que explique una
                      devolución ni regla de cancelación. Probable error
                      de ingreso.
                    - 1045: probable error de tipeo (13/10 → 23/10); con la
                      fecha corregida tendría 1 día de atraso, lo habitual.
                    - 1013: posible error de tipeo, sin confirmar.
   Impacto:         (1) El total de ventas está subestimado en al menos
                    $105.000. El monto real de esos pedidos es desconocido
                    hasta confirmar las cantidades.
                    (2) Las métricas de días entre pedido y carga quedan
                    distorsionadas: los valores negativos bajan el promedio.
   Acción:          Escalado al responsable del sistema de ventas para
                    confirmar cantidades y fechas reales, y si el 1034 es
                    una devolución. Si las devoluciones se registran como
                    pedidos negativos, hace falta una forma de distinguirlas.
                    Sugerido a Data Engineering: validaciones en la carga
                    que alerten cantidad < 1 y fecha_pedido > fecha_carga.
                    Seguimiento hasta la corrección.
   Respuesta al
   solicitante:     "Los montos negativos vienen de 3 pedidos con
                    cantidades mal registradas (1023, 1034 y 1049), que
                    restan $105.000 del total de octubre. ¿Pueden confirmar
                    si alguno corresponde a una devolución? Además, los
                    pedidos 1045 y 1013 tienen fechas mal registradas; ya
                    lo derivamos para corregirlo. Les aviso cuando esté
                    resuelto."
*/
