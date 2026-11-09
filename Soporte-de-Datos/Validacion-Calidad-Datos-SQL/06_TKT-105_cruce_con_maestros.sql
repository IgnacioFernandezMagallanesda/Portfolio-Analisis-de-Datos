USE tienda_tech;

/* =====================================================
   TKT-105 - Pedidos que no cruzan con los maestros
   Reclamo: al cruzar pedidos con clientes y productos se
   pierden pedidos, y algunos precios no coinciden con la
   lista de precios.
   ===================================================== */

-- a) Pedidos que cruzan con el maestro de clientes (INNER JOIN)
--    INNER JOIN solo devuelve los pedidos que encuentran su cliente
--    Esperado: 73 (76 - 3 pedidos sin cliente del TKT-102)
--    Hallazgo: 70. Faltan 3 pedidos que no se explican por los nulos
SELECT
    COUNT(*) AS pedidos_con_cliente
FROM stg_pedidos AS p
INNER JOIN clientes AS c
    ON p.id_cliente = c.id_cliente;

-- Control a) Pedidos que pierde el INNER JOIN: 76 - 70 = 6
--    3 sin cliente (TKT-102: 1006, 1019, 1041) + 3 huérfanos (1010, 1028, 1056)
SELECT
    p.id_pedido,
    p.id_cliente,
    p.fecha_carga
FROM stg_pedidos AS p
LEFT JOIN clientes AS c
    ON p.id_cliente = c.id_cliente
WHERE c.id_cliente IS NULL
ORDER BY p.id_pedido;

-- b) Pedidos huérfanos: id_cliente cargado pero inexistente en clientes
--    LEFT JOIN devuelve todos los pedidos; los que no encuentran cliente
--    quedan con las columnas de clientes en NULL
--    Se excluyen los pedidos sin cliente (p.id_cliente NULL, ya vistos en TKT-102)
--    CONTROL: 73 - 70 = 3
--    Hallazgo: 1010 y 1056 (cliente 31), 1028 (cliente 40), en 3 corridas distintas
SELECT
    p.id_pedido,
    p.id_cliente,
    p.fecha_carga
FROM stg_pedidos AS p
LEFT JOIN clientes AS c
    ON p.id_cliente = c.id_cliente
WHERE c.id_cliente IS NULL
    AND p.id_cliente IS NOT NULL
ORDER BY p.id_pedido;

-- c) Pedidos que cruzan con el maestro de productos (INNER JOIN)
--    Esperado sin problemas: 76. id_producto no tiene NULL (perfil, TKT-102)
--    Hallazgo: 74. Faltan 2 pedidos
SELECT
    COUNT(*) AS pedidos_con_producto
FROM stg_pedidos AS p
INNER JOIN productos AS pr
    ON p.id_producto = pr.id_producto;

-- Control c) Pedidos huérfanos de producto: id_producto inexistente en productos
--    No hace falta excluir NULL: id_producto no tiene nulos
--    CONTROL: 74 con producto + 2 huérfanos = 76
--    Hallazgo: 1015 (producto 15) y 1062 (producto 18), en corridas distintas
SELECT
    p.id_pedido,
    p.id_producto,
    p.fecha_carga
FROM stg_pedidos AS p
LEFT JOIN productos AS pr
    ON p.id_producto = pr.id_producto
WHERE pr.id_producto IS NULL
ORDER BY p.id_pedido;

-- d) Pedidos con precio distinto al precio de lista del producto
--    INNER JOIN: solo se comparan pedidos que tienen producto en el maestro
--    relacion_precio = precio cargado / precio de lista
--    Esperado: 1 si el precio es correcto; 10 si se cargó con un cero de más
--    Hallazgo: 3 pedidos con relación 10: 1012, 1037 y 1060.
--              El 1037 (teclado a $320.000) no se detectaba en el perfil de
--              rangos del TKT-103: coincide con el precio de la silla gamer
SELECT
    p.id_pedido,
    p.id_producto,
    p.precio_unitario,
    pr.precio_lista,
    ROUND(p.precio_unitario / pr.precio_lista, 2) AS relacion_precio
FROM stg_pedidos AS p
INNER JOIN productos AS pr
    ON p.id_producto = pr.id_producto
WHERE p.precio_unitario <> pr.precio_lista
ORDER BY p.id_pedido;

-- Control d) Pedidos con precio igual al de lista: 74 con producto - 3 = 71
SELECT COUNT(*) AS filas_precio_correcto
FROM stg_pedidos AS p
INNER JOIN productos AS pr
    ON p.id_producto = pr.id_producto
WHERE p.precio_unitario = pr.precio_lista;

-- e) Impacto en plata: monto facturado de más por los precios incorrectos
--    De más por pedido = (precio cargado - precio de lista) × cantidad
--    CONTROL: 1012: 247.500 × 4 = 990.000
--             1037: 288.000 × 2 = 576.000
--             1060:  40.500 × 2 =  81.000
--             Total: 1.647.000
SELECT
    SUM((p.precio_unitario - pr.precio_lista) * p.cantidad) AS monto_inflado
FROM stg_pedidos AS p
INNER JOIN productos AS pr
    ON p.id_producto = pr.id_producto
WHERE p.precio_unitario <> pr.precio_lista;

-- f) Evidencia para la causa: errores de precio por corrida
--    FORMATO: una fila por fecha de carga con algún precio incorrecto
--    CONTROL: la suma de pedidos_precio_mal tiene que dar 3
--    Hallazgo: corrida 12/10: 2 de 2 pedidos con precio mal (el 100%).
--              Corrida 21/10: 1 de 2. La corrida del 12/10 apunta a un
--              error de la carga (por ejemplo, lectura del separador de
--              miles); el 21/10 puede ser un error de ingreso
SELECT
    p.fecha_carga,
    COUNT(*) AS pedidos_corrida,
    SUM(CASE WHEN p.precio_unitario <> pr.precio_lista THEN 1 ELSE 0 END) AS pedidos_precio_mal
FROM stg_pedidos AS p
INNER JOIN productos AS pr
    ON p.id_producto = pr.id_producto
GROUP BY p.fecha_carga
HAVING SUM(CASE WHEN p.precio_unitario <> pr.precio_lista THEN 1 ELSE 0 END) > 0
ORDER BY p.fecha_carga;

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-105
   Problema:        (1) 5 pedidos apuntan a clientes o productos que no
                    existen en los maestros y desaparecen al cruzarlos.
                    (2) 3 pedidos tienen un precio 10 veces mayor al de
                    la lista de precios.
   Evidencia:       (1) INNER JOIN con clientes: 70 de 76. Faltan 3 sin
                    cliente (TKT-102) y 3 huérfanos: 1010 y 1056
                    (cliente 31), 1028 (cliente 40).
                    INNER JOIN con productos: 74 de 76. Huérfanos:
                    1015 (producto 15) y 1062 (producto 18).
                    (2) Pedidos 1012, 1037 y 1060 con relación precio
                    cargado / precio de lista = 10. Control: 71 + 3 = 74.
                    Por corrida: 12/10 con 2 de 2 pedidos mal;
                    21/10 con 1 de 2.
   Causa probable:  (1) Error de ingreso en el origen, o maestros de
                    clientes y productos desactualizados (altas nuevas
                    que todavía no se cargaron). Huérfanos en corridas
                    distintas, sin patrón de carga.
                    (2) Corrida del 12/10: todos sus pedidos tienen el
                    precio mal; apunta a un error de la carga (posible
                    lectura errónea del separador de miles). Pedido 1037:
                    posible error de ingreso. Se confirma comparando el
                    precio de estos pedidos en el sistema de ventas.
   Impacto:         (1) 5 pedidos desaparecen del reporte de BI sin aviso.
                    (2) Ventas sobreestimadas en $1.647.000. Los 3 pedidos
                    están entregados: si se facturaron con ese precio,
                    a los clientes se les cobró 10 veces más.
   Prioridad:       Alta para (2): impacto económico y posible cobro
                    incorrecto a clientes. Media para (1).
   Acción:          (2) Escalado con prioridad alta al responsable del
                    sistema de ventas (verificar el precio en origen y si
                    se facturó) y a Data Engineering (revisar la corrida
                    del 12/10).
                    (1) Escalado a los responsables de los maestros:
                    confirmar si los clientes 31 y 40 y los productos 15
                    y 18 existen y faltan en el maestro, o si son errores
                    de ingreso. Sugerido a Data Engineering: validación
                    en la carga que alerte códigos inexistentes.
                    Seguimiento hasta la corrección.
   Respuesta al
   solicitante:     "Los pedidos que se pierden en el cruce son 5 que
                    apuntan a clientes o productos que no existen en las
                    tablas de referencia (1010, 1028, 1056, 1015 y 1062),
                    más los 3 sin cliente ya informados. Los precios
                    distintos son 3 pedidos (1012, 1037 y 1060) cargados
                    10 veces más caros: suman $1.647.000 de más. Lo
                    escalamos con prioridad alta. Les aviso cuando esté
                    resuelto."
*/
