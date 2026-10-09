USE superstore;

-- ¿Qué regiones venden más y cuáles son más rentables?
SELECT
	region,
    ROUND(SUM(sales), 2) AS ventas,
    ROUND(SUM(profit), 2) AS ganancia,
    ROUND(SUM(profit) /	SUM(sales) * 100, 2) AS margen_pct,
    ROUND(AVG(discount) * 100, 2) AS descuento_promedio_pct
FROM ventas
GROUP BY region
ORDER BY ventas DESC;

-- ¿Qué categorías venden más y cuáles son más rentables?
SELECT
    category,
    ROUND(SUM(sales), 2)                     AS ventas,
    ROUND(SUM(profit), 2)                    AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM ventas
GROUP BY category
ORDER BY ventas DESC;
