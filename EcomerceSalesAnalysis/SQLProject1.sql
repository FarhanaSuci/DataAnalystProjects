create database DataSolution;
use DataSolution;
CREATE TABLE raw_sales (
    row_id INT,
    order_id VARCHAR(50),
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(100),
    customer_segment VARCHAR(100),
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    continent VARCHAR(100),
    product_id VARCHAR(50),
    category VARCHAR(100),
    sub_category VARCHAR(100),
    product_name VARCHAR(255),
    quantity INT,
    unit_price DECIMAL(10,2),
    discount_pct DECIMAL(5,2),
    unit_manufacturing_cost DECIMAL(10,2),
    unit_shipping_cost DECIMAL(10,2),
    order_priority VARCHAR(50)
);
SHOW VARIABLES LIKE 'secure_file_priv';
LOAD DATA INFILE "C:\Program Files\MySQL\MySQL Server 8.0\Uploads\sales.csv"
INTO TABLE raw_sales
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS;

CREATE TABLE dim_product (
    product_id INT AUTO_INCREMENT PRIMARY KEY,
    product_name VARCHAR(255) UNIQUE
);

CREATE TABLE dim_category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category_name VARCHAR(100) UNIQUE
);

CREATE TABLE dim_sub_category (
    sub_category_id INT AUTO_INCREMENT PRIMARY KEY,
    sub_category_name VARCHAR(100) UNIQUE
);

CREATE TABLE dim_region (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    continent VARCHAR(100),
    UNIQUE(city, state, country)
);

CREATE TABLE fact_transaction (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(50),
    order_date DATE,
    ship_date DATE,
    shipping_mode VARCHAR(100),
    segment VARCHAR(100),
    product_fk INT,
    category_fk INT,
    sub_category_fk INT,
    location_fk INT,
    product_id_original VARCHAR(50),
    order_priority VARCHAR(50),
    quantity INT,
    unit_price DECIMAL(10,2),
    discount_pct DECIMAL(5,2),
    unit_manufacturing_cost DECIMAL(10,2),
    unit_shipping_cost DECIMAL(10,2),
    profit DECIMAL(12,2) GENERATED ALWAYS AS ((unit_price * quantity * (1 - discount_pct)) - (unit_manufacturing_cost * quantity + unit_shipping_cost * quantity)) STORED,

    FOREIGN KEY (product_fk) REFERENCES dim_product(product_id),
    FOREIGN KEY (category_fk) REFERENCES dim_category(category_id),
    FOREIGN KEY (sub_category_fk) REFERENCES dim_sub_category(sub_category_id),
    FOREIGN KEY (location_fk) REFERENCES dim_location(location_id)
);
DELIMITER $$

CREATE PROCEDURE normalize_and_populate()
BEGIN
    -- Step 1: Insert unique regions
    INSERT INTO dim_region (city, state, country, continent)
    SELECT DISTINCT city, state, country, continent
    FROM raw_sales;

    -- Step 2: Insert unique products
    INSERT INTO dim_product (product_id, product_name, sub_category)
    SELECT DISTINCT product_id, product_name, sub_category
    FROM raw_sales;

    -- Step 3: Insert unique sub-categories
    INSERT INTO dim_sub_category (sub_category, category)
    SELECT DISTINCT sub_category, category
    FROM raw_sales;

    -- Step 4: Insert into fact_sales table (normalized)
    INSERT INTO fact_sales (order_id, order_date, product_id, city, quantity, unit_price, unit_cost, shipping_cost, customer_segment)
    SELECT 
        order_id,
        order_date,
        product_id,
        city,
        quantity,
        unit_price,
        unit_cost,
        shipping_cost,
        customer_segment
    FROM raw_sales;
END$$

DELIMITER ;


CALL normalize_and_populate();


