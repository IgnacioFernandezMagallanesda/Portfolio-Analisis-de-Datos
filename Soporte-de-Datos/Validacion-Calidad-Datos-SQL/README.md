# Validación de calidad de datos post-carga (SQL)

Proyecto de soporte de datos en MySQL: investigo los incidentes que aparecen después de que un proceso ETL carga los pedidos de octubre de una tienda de tecnología en una tabla de staging. Cada problema llega como un ticket de un área del negocio, y lo resuelvo como lo haría un analista de soporte de primer nivel: confirmo el problema, encuentro las filas afectadas, mido el impacto, propongo una causa probable y decido si se resuelve o se escala, y a quién.

> **Nota:** los datos son ficticios. Los creé para practicar validación de datos, con errores plantados que imitan problemas reales de carga y de ingreso de datos.

## Qué pregunta busca responder

- ¿Los datos que llegaron a staging coinciden con lo que informa el sistema origen?
- ¿Qué registros tienen errores (duplicados, nulos, valores imposibles, formatos inconsistentes, códigos inexistentes)?
- ¿Cuánto afecta cada error a los reportes, en filas y en plata?
- ¿El error viene del ingreso de datos en el origen o del proceso de carga? ¿A qué equipo hay que escalarlo?

## El escenario

| Tabla | Qué tiene |
| --- | --- |
| `stg_pedidos` | Staging: 76 filas de pedidos tal como llegan del sistema de ventas, sin claves ni restricciones |
| `clientes` | Maestro de 25 clientes |
| `productos` | Maestro de 12 productos con su precio de lista |

El recorrido de los datos es: **sistema de ventas → proceso ETL → staging → data warehouse → reportes**. Ubicar en qué paso aparece cada error es lo que define a quién se escala.

## Tickets resueltos

| Ticket | Reclamo | Hallazgo | Causa probable | Impacto | Acción |
| --- | --- | --- | --- | --- | --- |
| [TKT-101](02_TKT-101_pedidos_duplicados.sql) | El reporte muestra más pedidos que los 72 del origen | 4 pedidos cargados 2 veces, copias exactas | Inserción doble en la misma corrida de carga | 76 pedidos en vez de 72 | Escalado a Data Engineering |
| [TKT-102](03_TKT-102_ventas_sin_cliente.sql) | El reporte por cliente suma menos que el total | 3 pedidos sin cliente asignado | Error de ingreso en el origen | $151.000 en ventas sin asignar (1,09%) | Escalado al responsable del sistema de ventas |
| [TKT-103](04_TKT-103_valores_fuera_de_rango.sql) | Pedidos con monto negativo y fechas imposibles | 3 cantidades menores a 1 y 2 pedidos cargados antes de hacerse | Error de ingreso en el origen (una posible devolución sin confirmar) | Ventas subestimadas en al menos $105.000 | Escalado al responsable del sistema de ventas |
| [TKT-104](05_TKT-104_estados_inconsistentes.sql) | El dashboard muestra estados repetidos | 9 formas de escribir 3 estados (espacios y mayúsculas) | Estado escrito a mano en el origen | Dashboard con 5 estados en vez de 3; filtros que pierden filas | Lista fija en el origen + normalización en la carga |
| [TKT-105](06_TKT-105_cruce_con_maestros.sql) | Se pierden pedidos al cruzar con los maestros y hay precios distintos a la lista | 5 pedidos huérfanos y 3 precios 10 veces más altos | Una corrida completa con precios mal (posible error de carga) | Ventas sobreestimadas en $1.647.000 | Escalado con prioridad alta |

## Cómo está armado cada ticket

Cada archivo `.sql` sigue el mismo orden, para que se pueda leer de arriba hacia abajo como una investigación:

1. **Encabezado** con el reclamo del solicitante.
2. **Consultas por punto** (a, b, c…), cada una con un comentario que explica qué mide, el formato esperado y el hallazgo.
3. **Controles**: una consulta distinta que tiene que llegar al mismo número por otro camino. Por ejemplo, filas válidas + filas inválidas = total, o una suma hecha a mano contra la suma de la consulta.
4. **Registro del incidente**: problema, evidencia, causa probable, impacto, acción y respuesta al solicitante en lenguaje no técnico.

## SQL que usé

- Agregaciones y agrupamiento: `COUNT`, `COUNT(DISTINCT)`, `SUM`, `MIN`, `MAX`, `GROUP BY`, `HAVING`
- Lógica condicional: `CASE WHEN` dentro de `SUM` para medir una parte sin filtrar el total
- Subconsultas en el `FROM` y en el `WHERE`
- `INNER JOIN` y `LEFT JOIN` para encontrar registros huérfanos y validar precios contra el maestro
- Funciones de texto y fecha: `TRIM`, `UPPER`, `CONCAT`, `LENGTH`, `DATEDIFF`, `ROUND`
- `COLLATE utf8mb4_0900_bin` para comparar textos de forma exacta (mayúsculas y espacios)

## Lo que aprendí

- **Un número no se da por bueno sin un control.** Varios errores los encontré porque el resultado no coincidía con lo que esperaba, no porque la consulta tirara error.
- **Una consulta puede ejecutarse bien y devolver algo equivocado.** Por ejemplo, promediar porcentajes en vez de dividir sumas, o comparar textos sin distinguir mayúsculas y esconder errores.
- **El patrón por corrida orienta la causa.** Errores sueltos en corridas distintas suelen venir del ingreso en el origen; errores concentrados en una corrida apuntan al proceso de carga.
- **La palabra correcta manda el ticket al equipo correcto.** No es lo mismo un error de carga que un error de ingreso de datos.

## Herramientas

MySQL 8.0 y MySQL Workbench.

## Cómo verlo

1. Descargar los archivos `.sql` de esta carpeta.
2. Ejecutar `01_crear_base_tienda_tech.sql` completo en MySQL 8. Crea la base `tienda_tech` con las tres tablas y sus datos.
3. Abrir cualquiera de los archivos de tickets y ejecutarlo completo. Cada uno empieza con `USE tienda_tech;`.
