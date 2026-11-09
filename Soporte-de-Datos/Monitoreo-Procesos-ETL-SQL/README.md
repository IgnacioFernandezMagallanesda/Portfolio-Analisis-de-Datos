# Monitoreo de procesos ETL y gestión de tickets (SQL)

Segundo proyecto de soporte de datos en MySQL. Esta vez no miro los datos de una tabla, sino **los procesos que los cargan**: cinco cargas nocturnas que corren todos los días, el registro de cada corrida y los tickets de soporte de octubre 2026. Respondo cinco pedidos como lo haría un analista de soporte: qué procesos fallan, dónde se pierden datos, qué cargas no corrieron, cuáles tardaron de más y cómo se gestionaron los tickets.

> **Nota:** los datos son ficticios. Los creé para practicar monitoreo de procesos, con problemas plantados que imitan casos reales.

## Qué pregunta busca responder

- ¿Qué procesos fallaron más en el mes y desde cuándo?
- ¿Hay cargas que terminaron "bien" pero perdieron filas en el camino?
- ¿Hubo días en que un proceso directamente no corrió?
- ¿Qué corridas tardaron mucho más de lo normal?
- ¿Todos los errores tienen ticket? ¿Se cumplió el SLA?

## El escenario

| Tabla | Qué tiene |
| --- | --- |
| `procesos` | Los 5 procesos programados, con su origen, destino, horario y duración esperada |
| `ejecuciones` | 152 corridas de octubre: inicio, fin, estado (OK / ERROR), filas leídas y filas cargadas |
| `tickets` | 12 tickets de soporte con prioridad, estado, equipo asignado, apertura y cierre |
| `sla` | Tiempo máximo de resolución por prioridad: Alta 4 h, Media 24 h, Baja 72 h |

## Tickets resueltos

| Ticket | Pedido | Hallazgo | Acción |
| --- | --- | --- | --- |
| [TKT-201](02_TKT-201_tasa_exito_procesos.sql) | Qué procesos fallan más | Éxito general 94,1%. carga_pagos: 80,6%, 6 timeouts con la API del proveedor, todos desde el 20/10 | Escalado a Data Engineering y al proveedor |
| [TKT-202](03_TKT-202_reconciliacion_filas.sql) | Faltan pedidos y clientes aunque las cargas dieron OK | 4 corridas OK perdieron filas sin avisar: 47 pedidos y 3 clientes. Solo 2 tenían ticket | Recarga + alerta cuando leídas ≠ cargadas |
| [TKT-203](04_TKT-203_corridas_faltantes.sql) | Datos desactualizados sin ningún error | 3 corridas que nunca arrancaron (clientes 17 y 18/10, productos 25/10) | Revisar el programador + control diario de corridas esperadas |
| [TKT-204](05_TKT-204_duraciones_anomalas.sql) | El dashboard se actualiza tarde | 2 corridas lentas: productos 47 min (9,4 veces lo esperado) y dashboard 85 min (5,7 veces) | Alerta cuando una corrida supere 2 veces su duración esperada |
| [TKT-205](06_TKT-205_seguimiento_tickets_sla.sql) | Revisión mensual de tickets | 2 errores sin ticket. SLA cumplido en 6 de 12 tickets (4 de 7 en Alta). 2 pendientes vencidos | Vincular errores al ticket abierto y seguimiento diario |

## Cómo está armado cada ticket

Igual que en el [proyecto de calidad de datos](../Validacion-Calidad-Datos-SQL): encabezado con el pedido, consultas por punto con su comentario (qué mide, formato y hallazgo), controles que llegan al mismo número por otro camino, y al final el registro del incidente con evidencia, causa probable, impacto, acción y respuesta al solicitante.

## SQL que usé

- Todo lo del proyecto anterior: agregaciones, `GROUP BY`, `HAVING`, `CASE WHEN`, subconsultas, `INNER JOIN` y `LEFT JOIN`
- **CTE recursiva** (`WITH RECURSIVE`) para armar un calendario y encontrar días sin corrida
- `CROSS JOIN` para combinar todos los días con todos los procesos
- Funciones de fecha y hora: `TIMESTAMPDIFF`, `DATE`, `TIME`, `DAYNAME`, `INTERVAL`
- `COALESCE` para medir tickets abiertos hasta la fecha de corte

## Lo que muestran los datos

- **Un proceso con estado OK no garantiza que los datos llegaron.** Las pérdidas de filas solo se ven comparando lo leído contra lo cargado.
- **Lo que no corrió no deja rastro.** Para encontrar corridas faltantes hay que comparar contra lo que debería haber pasado, no contra lo que pasó.
- **Un mismo error repetido apunta a una causa externa.** Los 6 fallos de carga_pagos son idénticos y empiezan el mismo día.
- **La gestión también se mide.** La mitad de los tickets venció el SLA, sobre todo los que dependían de otro equipo o de un proveedor.

## Herramientas

MySQL 8.0 y MySQL Workbench.

## Cómo verlo

1. Descargar los archivos `.sql` de esta carpeta.
2. Ejecutar `01_crear_base_monitoreo_etl.sql` completo en MySQL 8. Crea la base `monitoreo_etl` con las cuatro tablas y sus datos.
3. Abrir cualquiera de los archivos de tickets y ejecutarlo completo. Cada uno empieza con `USE monitoreo_etl;`.
