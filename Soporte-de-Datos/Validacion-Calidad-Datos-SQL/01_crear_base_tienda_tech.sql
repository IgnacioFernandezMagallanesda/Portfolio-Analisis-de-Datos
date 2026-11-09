-- =====================================================
-- Proyecto 1 - Validación de calidad de datos post-carga
-- Base: tienda_tech (MySQL 8)
-- Escenario: el proceso ETL nocturno carga los pedidos del
-- sistema de ventas en la tabla de staging stg_pedidos.
-- Antes de pasarlos al data warehouse hay que validarlos.
-- =====================================================

DROP DATABASE IF EXISTS tienda_tech;
CREATE DATABASE tienda_tech;
USE tienda_tech;

-- Maestro de clientes
CREATE TABLE clientes (
    id_cliente  INT PRIMARY KEY,
    nombre      VARCHAR(60),
    email       VARCHAR(80),
    ciudad      VARCHAR(40),
    fecha_alta  DATE
);

-- Maestro de productos
CREATE TABLE productos (
    id_producto   INT PRIMARY KEY,
    nombre        VARCHAR(60),
    categoria     VARCHAR(30),
    precio_lista  DECIMAL(10,2)
);

-- Staging: los pedidos tal como llegan del sistema origen.
-- Sin PRIMARY KEY ni FOREIGN KEY a propósito: en staging
-- se carga todo y después se valida.
CREATE TABLE stg_pedidos (
    id_pedido        INT,
    id_cliente       INT,
    id_producto      INT,
    fecha_pedido     DATE,
    cantidad         INT,
    precio_unitario  DECIMAL(10,2),
    estado           VARCHAR(20),
    fecha_carga      DATE
);

INSERT INTO clientes VALUES
(1,'Lucía Gómez','lucia.gomez@mail.com','Mendoza','2025-04-25'),
(2,'Martín Pérez','martin.perez@mail.com','Mar del Plata','2025-10-09'),
(3,'Sofía Díaz','sofia.diaz@mail.com','Buenos Aires','2025-08-17'),
(4,'Juan Romero','juan.romero@mail.com','Buenos Aires','2025-04-15'),
(5,'Valentina Sosa','valentina.sosa@mail.com','Mendoza','2026-07-13'),
(6,'Tomás Álvarez','tomas.alvarez@mail.com','Mar del Plata','2026-03-09'),
(7,'Camila Torres','camila.torres@mail.com','Mar del Plata','2025-01-31'),
(8,'Mateo Ruiz','mateo.ruiz@mail.com','Mar del Plata','2025-08-12'),
(9,'Julieta Castro','julieta.castro@mail.com','Buenos Aires','2026-06-02'),
(10,'Benjamín Ortiz','benjamin.ortiz@mail.com','La Plata','2025-01-28'),
(11,'Florencia Molina','florencia.molina@mail.com','La Plata','2025-07-23'),
(12,'Lautaro Silva','lautaro.silva@mail.com','Mendoza','2026-07-13'),
(13,'Agustina Rojas',NULL,'Rosario','2025-08-14'),
(14,'Nicolás Medina','nicolas.medina@mail.com','Rosario','2025-10-12'),
(15,'Micaela Herrera','micaela.herrera@mail.com','Mar del Plata','2025-06-13'),
(16,'Facundo Aguirre','facundo.aguirre@mail.com','Mendoza','2026-03-09'),
(17,'Paula Benítez','paula.benitez@mail.com','Córdoba','2025-10-12'),
(18,'Santiago Vega','juan.romero@mail.com','Buenos Aires','2025-08-09'),
(19,'Carolina Ríos','carolina.rios@mail.com','Córdoba','2025-04-15'),
(20,'Joaquín Navarro','joaquin.navarro@mail.com','Mar del Plata','2026-01-25'),
(21,'Milagros Acosta','milagros.acosta@mail.com','Mar del Plata','2026-01-03'),
(22,'Federico Luna','julieta.castro@mail.com','Córdoba','2025-09-28'),
(23,'Rocío Cabrera','rocio.cabrera@mail.com','Mar del Plata','2026-04-16'),
(24,'Ignacio Paz','ignacio.paz.mail.com','La Plata','2025-05-08'),
(25,'Antonella Ferreyra','antonella.ferreyra@mail.com','Rosario','2025-03-22');

INSERT INTO productos VALUES
(1,'Mouse inalámbrico','Periféricos',8500),
(2,'Teclado mecánico','Periféricos',32000),
(3,'Auriculares Bluetooth','Audio',27500),
(4,'Parlante portátil','Audio',41000),
(5,'Monitor 24''','Monitores',185000),
(6,'Monitor 27''','Monitores',265000),
(7,'Webcam HD','Periféricos',23000),
(8,'Pendrive 64GB','Almacenamiento',9800),
(9,'Disco SSD 1TB','Almacenamiento',78000),
(10,'Cable HDMI 2m','Accesorios',4500),
(11,'Hub USB-C','Accesorios',19500),
(12,'Silla gamer','Muebles',320000);

INSERT INTO stg_pedidos VALUES
(1028,40,12,'2026-10-01',1,320000,'Entregado','2026-10-01'),
(1065,11,7,'2026-09-30',3,23000,'Entregado','2026-10-01'),
(1065,11,7,'2026-09-30',3,23000,'Entregado','2026-10-01'),
(1042,16,10,'2026-10-02',2,4500,'Entregado','2026-10-02'),
(1068,14,10,'2026-10-02',3,4500,'Entregado','2026-10-02'),
(1070,17,1,'2026-09-29',2,8500,'Entregado','2026-10-02'),
(1003,13,2,'2026-10-02',3,32000,'Pendiente','2026-10-03'),
(1003,13,2,'2026-10-02',3,32000,'Pendiente','2026-10-03'),
(1029,3,6,'2026-10-03',2,265000,'Entregado','2026-10-03'),
(1054,2,5,'2026-09-30',1,185000,'Entregado','2026-10-03'),
(1021,8,5,'2026-10-02',1,185000,'Entregado ','2026-10-04'),
(1058,2,3,'2026-10-02',3,27500,'Entregado','2026-10-05'),
(1024,20,9,'2026-10-04',4,78000,'Entregado','2026-10-06'),
(1039,13,1,'2026-10-03',3,8500,'Pendiente','2026-10-06'),
(1039,13,1,'2026-10-03',3,8500,'Pendiente','2026-10-06'),
(1063,2,7,'2026-10-06',4,23000,'Entregado','2026-10-06'),
(1009,21,4,'2026-10-05',4,41000,'Pendiente','2026-10-07'),
(1041,NULL,4,'2026-10-05',1,41000,'Entregado','2026-10-07'),
(1053,16,9,'2026-10-05',3,78000,'Entregado','2026-10-07'),
(1064,10,6,'2026-10-04',2,265000,'Entregado','2026-10-07'),
(1031,7,7,'2026-10-05',1,23000,'pendiente','2026-10-08'),
(1015,24,15,'2026-10-09',1,19500,'Cancelado','2026-10-09'),
(1046,22,3,'2026-10-06',3,27500,'Pendiente','2026-10-09'),
(1040,24,12,'2026-10-07',4,320000,'Entregado','2026-10-10'),
(1051,9,3,'2026-10-10',1,27500,'Entregado','2026-10-10'),
(1027,18,10,'2026-10-11',2,4500,'Entregado','2026-10-11'),
(1047,15,1,'2026-10-11',1,8500,'Entregado','2026-10-11'),
(1067,9,2,'2026-10-11',2,32000,'ENTREGADO','2026-10-11'),
(1012,17,3,'2026-10-11',4,275000,'Entregado','2026-10-12'),
(1060,24,10,'2026-10-09',2,45000,'Entregado','2026-10-12'),
(1034,8,2,'2026-10-11',-2,32000,'Entregado','2026-10-13'),
(1044,8,10,'2026-10-13',1,4500,'Entregado','2026-10-13'),
(1017,1,8,'2026-10-13',3,9800,'Cancelado','2026-10-14'),
(1038,7,8,'2026-10-11',4,9800,'Entregado','2026-10-14'),
(1045,7,5,'2026-10-23',3,185000,'Entregado','2026-10-14'),
(1069,19,7,'2026-10-14',2,23000,'Entregado','2026-10-14'),
(1071,11,11,'2026-10-14',3,19500,'Entregado','2026-10-14'),
(1026,8,2,'2026-10-12',2,32000,'Entregado','2026-10-15'),
(1036,15,2,'2026-10-14',1,32000,'Entregado','2026-10-15'),
(1050,21,10,'2026-10-13',1,4500,'Cancelado','2026-10-15'),
(1001,20,11,'2026-10-16',3,19500,'Entregado','2026-10-18'),
(1006,NULL,3,'2026-10-17',4,27500,'Entregado','2026-10-18'),
(1035,14,3,'2026-10-15',2,27500,'Entregado','2026-10-18'),
(1048,9,9,'2026-10-17',2,78000,'Entregado','2026-10-18'),
(1056,31,9,'2026-10-15',1,78000,'Entregado','2026-10-18'),
(1014,13,7,'2026-10-20',4,23000,'Cancelado','2026-10-20'),
(1019,NULL,3,'2026-10-19',2,27500,'Cancelado','2026-10-20'),
(1004,12,3,'2026-10-19',3,27500,'entregado','2026-10-21'),
(1037,25,2,'2026-10-21',2,320000,'Entregado','2026-10-21'),
(1005,22,12,'2026-10-20',1,320000,'Entregado','2026-10-22'),
(1030,18,4,'2026-10-19',2,41000,'Pendiente','2026-10-22'),
(1032,14,6,'2026-10-19',4,265000,'Pendiente','2026-10-22'),
(1002,22,1,'2026-10-23',2,8500,'Entregado','2026-10-23'),
(1011,19,12,'2026-10-22',4,320000,'Pendiente','2026-10-24'),
(1052,10,5,'2026-10-23',2,185000,' Cancelado','2026-10-24'),
(1062,22,18,'2026-10-22',2,23000,'Entregado','2026-10-24'),
(1072,10,9,'2026-10-22',4,78000,'Entregado','2026-10-24'),
(1013,5,2,'2026-10-30',2,32000,'Pendiente','2026-10-25'),
(1016,11,11,'2026-10-23',1,19500,'Entregado','2026-10-25'),
(1018,4,9,'2026-10-24',3,78000,'Cancelado','2026-10-25'),
(1018,4,9,'2026-10-24',3,78000,'Cancelado','2026-10-25'),
(1023,22,3,'2026-10-24',0,27500,'Cancelado','2026-10-25'),
(1055,9,11,'2026-10-24',2,19500,'Pendiente','2026-10-25'),
(1008,13,6,'2026-10-27',3,265000,'ENTREGADO ','2026-10-27'),
(1033,21,11,'2026-10-28',1,19500,'Entregado','2026-10-28'),
(1061,14,3,'2026-10-27',1,27500,'Entregado','2026-10-28'),
(1010,31,3,'2026-10-26',2,27500,'Entregado','2026-10-29'),
(1022,24,2,'2026-10-29',4,32000,'Entregado','2026-10-29'),
(1049,12,4,'2026-10-29',-1,41000,'Entregado','2026-10-29'),
(1059,7,6,'2026-10-29',2,265000,'Entregado','2026-10-29'),
(1007,11,11,'2026-10-29',1,19500,'Entregado','2026-10-30'),
(1025,10,12,'2026-10-29',4,320000,'Entregado','2026-10-30'),
(1020,11,10,'2026-10-31',4,4500,'Entregado','2026-10-31'),
(1043,3,3,'2026-10-31',1,27500,'Entregado','2026-10-31'),
(1057,2,9,'2026-10-30',3,78000,'Cancelado','2026-10-31'),
(1066,21,6,'2026-10-29',4,265000,'Cancelado','2026-10-31');
