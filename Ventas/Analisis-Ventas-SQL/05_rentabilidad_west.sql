USE superstore;


-- ¿Cómo se reparte el margen por región y categoría? --
SELECT 
	region, category,
	ROUND(SUM(sales), 2) AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM ventas
GROUP BY region, category
ORDER BY region, ventas DESC; 

-- ¿Qué subcategorías de Technology arrastran el margen de West?
SELECT
	sub_category,
    COUNT(*) AS pedidos,
    ROUND(SUM(sales), 2) AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct,
	ROUND(AVG(discount) * 100, 2) AS descuento_promedio_pct
FROM ventas
WHERE region = 'West'
	AND category = 'Technology'
GROUP BY sub_category
ORDER BY margen_pct;


-- ¿Accessories da pérdida en todas las regiones o solo en West?
SELECT
	region,
    COUNT(*) AS pedidos,
    ROUND(SUM(sales), 2) AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct,
	ROUND(AVG(discount) * 100, 2) AS descuento_promedio_pct
FROM ventas
WHERE sub_category = 'Accessories'
GROUP BY region
ORDER BY margen_pct;
