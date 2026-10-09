USE superstore;

-- ¿Qué período cubren los datos?
SELECT
	MIN(order_date) AS primera_venta,
    MAX(order_date) AS ultima_venta
FROM ventas;

-- Ventas por año
SELECT 
	YEAR(order_date) AS anio,
    COUNT(*) AS pedidos,
    ROUND(SUM(sales), 2) AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM ventas
GROUP BY anio
ORDER BY anio;

-- ¿Por qué mejoro el margen? ¿Será que en 2024 y 2025 se hicieron menos pedidos con descuentos altos?
SELECT
	YEAR(order_date) AS anio,
    COUNT(*) AS pedidos,
    ROUND(SUM(profit), 2) AS ganancia
FROM ventas
WHERE discount >= 0.3
GROUP BY anio
ORDER BY anio;

-- ¿Qué impulsó la mejora de 2025?
SELECT 
	YEAR(order_date) AS anio,
    category,
	ROUND(SUM(sales), 2) AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM ventas
GROUP BY anio, category
ORDER BY category, anio;


-- ¿Hay meses que venden más que otros?
SELECT 
	MONTH(order_date) AS mes,
	COUNT(*) AS pedidos,
    ROUND(SUM(sales), 2) AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM ventas
GROUP BY mes
ORDER BY mes;

-- ¿El bajo margen de julio se repite todos los años?
SELECT 
	YEAR(order_date) AS anio,
	COUNT(*) AS pedidos,
    ROUND(SUM(sales), 2) AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM ventas
WHERE MONTH(order_date) = 7
GROUP BY anio
ORDER BY anio;