# Análisis de ventas en SQL

Este es mi primer proyecto en SQL. Usé el mismo dataset de ventas tipo Superstore del [informe en Power BI](../Analisis-Ventas-USA): 2.500 pedidos de una cadena minorista de EE. UU., desde enero de 2023 hasta diciembre de 2025. La idea fue responder preguntas de negocio directamente con consultas, sin usar herramientas de visualización, y seguir cada hallazgo hasta encontrar su causa.

> Los datos son de práctica y no corresponden a una empresa real.

## Qué pregunta busca responder

- ¿Cuánto vende y cuánto gana el negocio, y con qué margen?
- ¿Qué regiones y categorías son más rentables?
- ¿Cómo afectan los descuentos a la ganancia?
- ¿Por qué la región West tiene el peor margen?
- ¿Cómo evolucionaron las ventas y la ganancia entre 2023 y 2025? ¿Hay meses mejores que otros?

## Estructura del proyecto

Cada script empieza con `USE superstore;` y cada consulta lleva un comentario con la pregunta que responde.

| Script | Contenido |
|---|---|
| [`01_carga_y_limpieza.sql`](01_carga_y_limpieza.sql) | Creación de la base, importación del CSV, validación de la carga y limpieza |
| [`02_kpis_generales.sql`](02_kpis_generales.sql) | Ventas, ganancia, unidades, pedidos, descuento promedio y margen totales |
| [`03_region_categoria.sql`](03_region_categoria.sql) | Ventas, ganancia y margen por región y por categoría |
| [`04_descuentos.sql`](04_descuentos.sql) | Margen según el nivel de descuento y pedidos vendidos a pérdida |
| [`05_rentabilidad_west.sql`](05_rentabilidad_west.sql) | Investigación del bajo margen de la región West |
| [`06_evolucion_temporal.sql`](06_evolucion_temporal.sql) | Evolución por año, por año y categoría, y estacionalidad mensual |

## Cómo está armado

**Carga y limpieza.** Importé el CSV con el Table Data Import Wizard de MySQL Workbench en una tabla llamada `ventas`. Después:

- Validé la carga: el `COUNT(*)` dio 2.500 filas, igual que el CSV.
- Renombré todas las columnas a `snake_case` (por ejemplo, `Order Date` → `order_date`), para no tener que usar comillas invertidas en cada consulta.
- Convertí las fechas de texto a `DATE`, sin errores ni advertencias, para poder trabajar por año y por mes.
- Comprobé que en este dataset cada pedido tiene una sola fila (2.500 filas = 2.500 pedidos únicos).

**Consultas.** Usé `SELECT`, `WHERE` (con `AND`), `GROUP BY` (por una y por dos columnas), `ORDER BY`, funciones de agregación (`SUM`, `COUNT`, `AVG`, `MIN`, `MAX`), `ROUND`, `DISTINCT` y funciones de fecha (`YEAR`, `MONTH`). El margen lo calculo siempre como `SUM(profit) / SUM(sales) * 100`.

**Validaciones.** Cada vez que agrupé, verifiqué que los subtotales sumaran el total: por ejemplo, que los pedidos de cada nivel de descuento sumaran 2.500, o que las subcategorías de Technology en West sumaran las ventas de esa categoría en esa región.

## Lo que muestran los datos

**Se vende mucho, pero el margen es bajo.** El negocio facturó 5,81 millones y ganó 254.875 en los 3 años: un margen del 4,39 %, con un descuento promedio del 13 %.

| Categoría | % de las ventas | % de la ganancia | Margen |
|---|---|---|---|
| Technology | 60 % | 51 % | 3,71 % |
| Furniture | 32 % | 29 % | 3,85 % |
| Office Supplies | 7,5 % | 21 % | 12,08 % |

Office Supplies vende poco, pero con un margen tres veces más alto que el resto.

**Desde el 30 % de descuento se vende a pérdida.** El margen baja en cada nivel de descuento, sin excepción:

| Descuento | Pedidos | Ganancia | Margen |
|---|---|---|---|
| 0 % | 846 | 222.816 | 10,81 % |
| 10 % | 473 | 54.637 | 5,07 % |
| 15 % | 405 | 28.615 | 3,26 % |
| 20 % | 402 | 6.682 | 0,72 % |
| 30 % | 241 | −20.213 | −3,89 % |
| 40 % | 133 | −37.663 | −10,98 % |

374 pedidos (el 15 %) se vendieron con descuentos del 30 % o más y restaron 57.876 de ganancia. Esos pedidos están repartidos de forma pareja entre las 4 regiones, así que es un tema de política comercial de toda la empresa. Las ventas sin descuento generan el 87 % de toda la ganancia.

**El problema de West está en Accessories.** West es la segunda región en ventas, pero tiene el peor margen (3,04 %) y la menor ganancia. Para encontrar la causa fui descartando hipótesis:

1. **Descuento promedio:** descartado. Es parecido en las 4 regiones (entre 12,2 % y 13 %).
2. **Mezcla de productos:** descartada. West es la región que menos depende de Technology, la categoría de menor margen.
3. **Technology en West:** confirmado. Vende lo mismo que en las otras regiones (unos 850.000), pero con un margen del 1,90 %, contra un 4,3 % en el resto.
4. **Accessories:** dentro de Technology, es la subcategoría que más vende en West, y lo hace a pérdida (−0,68 %). En las otras regiones gana: 5,25 % en South, 3,51 % en Central y 1,53 % en East. El problema es regional, no del producto.

Si Technology en West tuviera el margen del resto de las regiones, ganaría unos 20.000 más. El dataset no tiene costos ni precios de lista, así que no puedo explicar el porqué de fondo; sí puedo señalar dónde está el problema. Además, son entre 39 y 52 pedidos por subcategoría, una muestra chica que conviene confirmar con más datos.

**Se vende menos, pero se gana más.** Los 3 años están completos, así que la comparación es válida:

| Año | Ventas | Ganancia | Margen |
|---|---|---|---|
| 2023 | 2.113.058 | 79.900 | 3,78 % |
| 2024 | 1.763.561 | 83.639 | 4,74 % |
| 2025 | 1.934.668 | 91.335 | 4,72 % |

Entre 2023 y 2025 las ventas bajaron un 8 %, pero la ganancia subió un 14 %. Primero pensé que se debía a menos pedidos con descuentos altos, pero los datos lo descartaron: esos pedidos aumentaron todos los años (118, 122 y 134). El motor de la mejora fue Technology, que pasó de un margen del 2,63 % al 4,53 %. En cambio, Furniture baja su margen todos los años (4,09 % → 3,99 % → 3,52 %).

**Julio tiene un margen bajo todos los años.** Las ventas son bastante estables a lo largo del año, pero la ganancia no: octubre ganó 39.358 y julio, 8.452, aunque julio vende más que el promedio mensual. Verifiqué que no fuera un caso aislado: el margen de julio quedó por debajo del margen anual en los 3 años (0,18 %, 2,96 % y 2,26 %).

### Recomendaciones

1. Limitar los descuentos al 20 %, porque desde el 30 % cada venta da pérdida.
2. Revisar precios, costos y condiciones comerciales de Accessories en West.
3. Seguir de cerca el margen de Furniture, que viene cayendo.
4. Investigar qué pasa en julio con los pedidos de menor margen.

## Herramientas

- MySQL 8.0
- MySQL Workbench

## Cómo verlo

1. Descargá los scripts de esta carpeta y el CSV del dataset (`superstore_base.csv`).
2. En MySQL Workbench, ejecutá las dos primeras líneas de `01_carga_y_limpieza.sql` (`CREATE DATABASE` y `USE`).
3. Importá el CSV con el Table Data Import Wizard (clic derecho sobre la base `superstore` → Table Data Import Wizard), en una tabla nueva llamada `superstore_base`.
4. Ejecutá el resto de `01_carga_y_limpieza.sql` y después los demás scripts, en orden.
