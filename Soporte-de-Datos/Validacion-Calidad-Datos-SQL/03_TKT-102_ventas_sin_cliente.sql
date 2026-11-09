USE tienda_tech;

/* =====================================================
   TKT-102 - Ventas sin cliente asignado
   Reclamo: el reporte de ventas por cliente suma menos
   que el total de ventas de octubre.
   ===================================================== */

-- a) Perfil de nulos: cantidad de NULL por columna
--    FORMATO: una fila, una columna por campo de stg_pedidos
--    CONTROL: nulos_id_cliente tiene que coincidir con el conteo directo por IS NULL
SELECT
    COUNT(*) AS total_filas,
    COUNT(*) - COUNT(id_pedido) AS nulos_id_pedido,
    COUNT(*) - COUNT(id_cliente) AS nulos_id_cliente,
    COUNT(*) - COUNT(id_producto) AS nulos_id_producto,
    COUNT(*) - COUNT(fecha_pedido) AS nulos_fecha_pedido,
    COUNT(*) - COUNT(cantidad) AS nulos_cantidad,
    COUNT(*) - COUNT(precio_unitario) AS nulos_precio_unitario,
    COUNT(*) - COUNT(estado) AS nulos_estado,
    COUNT(*) - COUNT(fecha_carga) AS nulos_fecha_carga
FROM stg_pedidos;

-- Control a) Contar directo las filas sin cliente: tiene que dar 3
SELECT COUNT(*) AS filas_sin_cliente
FROM stg_pedidos
WHERE id_cliente IS NULL;

-- b) Pedidos sin cliente asignado
--    FORMATO: todas las columnas, ordenado por id_pedido
--    CONTROL: tiene que devolver 3 filas (igual que nulos_id_cliente del punto a)
SELECT *
FROM stg_pedidos
WHERE id_cliente IS NULL
ORDER BY id_pedido;

-- c) Impacto en plata de los pedidos sin cliente
--    FORMATO: una fila; monto total, monto sin cliente y % redondeado a 2 decimales
--    CONTROL: 110.000 + 55.000 + 41.000 = 206.000
--             Estimación previa: 1% de 16,1 M ≈ 161 mil → cerca de 1,3%. Resultado: 1,28%
SELECT
    SUM(precio_unitario * cantidad) AS monto_total,
    SUM(CASE WHEN id_cliente IS NULL THEN precio_unitario * cantidad ELSE 0 END) AS monto_sin_cliente,
    ROUND(SUM(CASE WHEN id_cliente IS NULL THEN precio_unitario * cantidad ELSE 0 END) / SUM(precio_unitario * cantidad) * 100, 2) AS pct_sin_cliente
FROM stg_pedidos;

-- c2) Valores distintos de estado, antes de filtrar por él
--     Motivo: los pedidos cancelados no son ventas y hay que excluirlos del monto
--     CONTROL: la suma de cantidad_pedidos tiene que dar 76
--     Hallazgo: "Cancelado" y "Entregado" aparecen con espacios extra.
--               Se normaliza con UPPER(TRIM()) antes de filtrar (detalle en TKT-104)
SELECT
    estado,
    COUNT(*) AS cantidad_pedidos
FROM stg_pedidos
GROUP BY estado
ORDER BY estado;

-- c3) Impacto en plata excluyendo pedidos cancelados (ventas reales)
--     FORMATO: igual que c), con el filtro de estado normalizado
--     CONTROL: monto_sin_cliente = 206.000 - 55.000 (pedido 1019 cancelado) = 151.000
--              El % tiene que bajar: la parte cae ~27% y el total ~14%. Resultado: 1,09%
SELECT
    SUM(precio_unitario * cantidad) AS monto_total,
    SUM(CASE WHEN id_cliente IS NULL THEN precio_unitario * cantidad ELSE 0 END) AS monto_sin_cliente,
    ROUND(SUM(CASE WHEN id_cliente IS NULL THEN precio_unitario * cantidad ELSE 0 END) / SUM(precio_unitario * cantidad) * 100, 2) AS pct_sin_cliente
FROM stg_pedidos
WHERE UPPER(TRIM(estado)) <> 'CANCELADO';

-- Control c3) Filas que pasan el filtro: tiene que dar 65 (76 - 11 cancelados)
SELECT COUNT(*) AS filas_sin_cancelados
FROM stg_pedidos
WHERE UPPER(TRIM(estado)) <> 'CANCELADO';

/* REGISTRO DEL INCIDENTE
   Ticket:          TKT-102
   Problema:        3 pedidos de stg_pedidos no tienen cliente asignado,
                    por eso el reporte por cliente suma menos que el total.
   Evidencia:       Perfil de nulos: id_cliente es la única columna con
                    NULL (3 de 76 filas). Resto de columnas completas.
                    Pedidos afectados: 1006, 1019 (cancelado), 1041.
                    Monto sin cliente: $206.000 (1,28%). Excluyendo
                    cancelados: $151.000 (1,09%), calculado como ventas reales.
                    Control: 110.000 + 41.000 = 151.000.
   Causa probable:  Error de ingreso de datos en el origen. Las 3 filas
                    tienen fecha_carga distinta (07, 18 y 20/10) y en esas
                    mismas corridas el resto de los pedidos llegó con
                    cliente: no es un patrón del proceso de carga.
   Impacto:         $151.000 en ventas (1,09%) no se asignan a ningún
                    cliente en el reporte. Monto preliminar: incluye los
                    duplicados pendientes del TKT-101.
   Acción:          Escalado al responsable del sistema de ventas para
                    identificar los clientes y evaluar hacer obligatorio
                    el campo. Sugerido a Data Engineering: validación en la
                    carga que alerte pedidos sin cliente. Seguimiento
                    hasta la corrección.
   Respuesta al
   solicitante:     "Encontramos 3 ventas que se registraron sin cliente:
                    pedidos 1006, 1019 y 1041. ¿Pueden confirmarnos a qué
                    cliente corresponde cada una? Mientras tanto, lo
                    derivamos para que no se vuelva a repetir. Les aviso
                    cuando esté resuelto."
*/
