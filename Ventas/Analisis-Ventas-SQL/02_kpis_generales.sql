USE superstore;

-- ¿Cuánto vendimos, cuánto ganamos y cuál es el margen total del negocio?
SELECT 
	ROUND(SUM(sales), 2) AS ventas_totales,
	ROUND(SUM(profit), 2) AS ganancia_total,
    SUM(quantity) AS unidades_vendidas,
    COUNT(DISTINCT order_id) AS cantidad_pedidos,
    ROUND(AVG(discount), 2) AS descuento_promedio,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM ventas;