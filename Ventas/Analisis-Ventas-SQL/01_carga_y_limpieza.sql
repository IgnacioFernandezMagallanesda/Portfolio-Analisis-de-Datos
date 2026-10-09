-- =========================================================
-- 01_carga_y_limpieza.sql
-- Creación de la base, importación del CSV y limpieza
-- =========================================================

CREATE DATABASE superstore;
USE superstore;

-- Importación: superstore_base.csv cargado con el
-- Table Data Import Wizard de MySQL Workbench (2500 filas)

-- Renombrar la tabla importada a un nombre corto
RENAME TABLE superstore_base TO ventas;

-- Validación de carga: tiene que dar 2500 (mismas filas que el CSV)
SELECT COUNT(*) AS filas FROM ventas;

-- Renombrar columnas a snake_case (sin espacios ni mayúsculas)
ALTER TABLE ventas
RENAME COLUMN `Order ID`      TO order_id,
RENAME COLUMN `Order Date`    TO order_date,
RENAME COLUMN `Ship Date`     TO ship_date,
RENAME COLUMN `Ship Mode`     TO ship_mode,
RENAME COLUMN `Customer ID`   TO customer_id,
RENAME COLUMN `Customer Name` TO customer_name,
RENAME COLUMN `Segment`       TO segment,
RENAME COLUMN `Region`        TO region,
RENAME COLUMN `State`         TO state,
RENAME COLUMN `City`          TO city,
RENAME COLUMN `Category`      TO category,
RENAME COLUMN `Sub-Category`  TO sub_category,
RENAME COLUMN `Product ID`    TO product_id,
RENAME COLUMN `Product Name`  TO product_name,
RENAME COLUMN `Sales`         TO sales,
RENAME COLUMN `Quantity`      TO quantity,
RENAME COLUMN `Discount`      TO discount,
RENAME COLUMN `Profit`        TO profit;

-- Convertir las fechas de texto a DATE
-- (el formato original ya era AAAA-MM-DD; 0 warnings)
ALTER TABLE ventas
MODIFY COLUMN order_date DATE,
MODIFY COLUMN ship_date  DATE;

-- Verificar la estructura final
DESCRIBE ventas;