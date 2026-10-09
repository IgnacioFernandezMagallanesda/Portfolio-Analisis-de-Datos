USE superstore;

-- Pregunta 1: ¿Cómo varía el margen según el nivel de descuento?
SELECT
    discount,
    COUNT(*)                                 AS pedidos,
    ROUND(SUM(sales), 2)                     AS ventas,
    ROUND(SUM(profit), 2)                    AS ganancia,
    ROUND(SUM(profit) / SUM(sales) * 100, 2) AS margen_pct
FROM ventas
GROUP BY discount
ORDER BY discount;

-- Pregunta 2: ¿En qué regiones se concentran los pedidos con descuento >= 30%?
SELECT
    region,
    COUNT(*)              AS pedidos,
    ROUND(SUM(profit), 2) AS ganancia
FROM ventas
WHERE discount >= 0.3
GROUP BY region
ORDER BY ganancia;