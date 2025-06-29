create database Faul;
use  faul;
CREATE TABLE sales (
    Row_ID INT,
    Order_ID VARCHAR(100),
    Order_Date DATE,
    Ship_Date DATE,
    Ship_Mode VARCHAR(100),
    Customer_Segment VARCHAR(150),
    City VARCHAR(100),
    State VARCHAR(100),
    Country VARCHAR(100),
    Continent VARCHAR(150),
    Product_ID VARCHAR(150),
    Category VARCHAR(100),
    Sub_Category VARCHAR(100),
    Product_Name VARCHAR(255),
    Quantity INT,
    Unit_Price DECIMAL(10,2),
    Discount_Perc DECIMAL(5,2),
    Unit_Manufacturing_Cost DECIMAL(10,2),
    Unit_Shipping_Cost DECIMAL(10,2),
    Order_Priority VARCHAR(50)
);


#Show table

Select * from sales;

#Load CSV file using INFilE method

LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/sales.csv'
INTO TABLE sales
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n'
IGNORE 1 LINES
(@Row_ID, @Order_ID, @Order_Date, @Ship_Date, @Ship_Mode, @Customer_Segment, @City, @State, @Country, @Continent,
 @Product_ID, @Category, @Sub_Category, @Product_Name, @Quantity, @Unit_Price, @Discount_Perc, @Unit_Manufacturing_Cost,
 @Unit_Shipping_Cost, @Order_Priority)
SET 
Row_ID = @Row_ID,
Order_ID = @Order_ID,
Order_Date = STR_TO_DATE(@Order_Date, '%m/%d/%Y'),
Ship_Date = STR_TO_DATE(@Ship_Date, '%m/%d/%Y'),
Ship_Mode = @Ship_Mode,
Customer_Segment = @Customer_Segment,
City = @City,
State = @State,
Country = @Country,
Continent = @Continent,
Product_ID = @Product_ID,
Category = @Category,
Sub_Category = @Sub_Category,
Product_Name = @Product_Name,
Quantity = @Quantity,
Unit_Price = @Unit_Price,
Discount_Perc = @Discount_Perc,
Unit_Manufacturing_Cost = @Unit_Manufacturing_Cost,
Unit_Shipping_Cost = @Unit_Shipping_Cost,
Order_Priority = @Order_Priority;

#Show sales table

Select * from sales;
select * from return_table;

SHOW COLUMNS FROM sales;

CREATE TABLE dim_location (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    continent VARCHAR(100),
    UNIQUE(city, state, country, continent)  -- prevent exact duplicates
);


INSERT INTO dim_location (city, state, country, continent)
SELECT DISTINCT City, State, Country, Continent FROM sales;


select * from dim_location;

CREATE TABLE dim_product (
    product_id VARCHAR(50) PRIMARY KEY,
    product_name VARCHAR(255)
);

INSERT INTO dim_product
SELECT DISTINCT Product_ID, Product_Name FROM sales;

select * from dim_product;


CREATE TABLE dim_category (
    category VARCHAR(100) PRIMARY KEY
);

INSERT INTO dim_category
SELECT DISTINCT Category FROM sales;

CREATE TABLE dim_sub_category (
    sub_category VARCHAR(100) PRIMARY KEY,
    category VARCHAR(100),
    FOREIGN KEY (category) REFERENCES dim_category(category)
);

INSERT INTO dim_sub_category (sub_category, category)
SELECT DISTINCT Sub_Category, Category FROM sales;

select * from dim_sub_category;

CREATE TABLE dim_location (
    city VARCHAR(100) PRIMARY KEY,
    state VARCHAR(100),
    country VARCHAR(100),
    continent VARCHAR(100)
);

INSERT INTO dim_location (city, state, country, continent)
SELECT 
    City,
    MAX(State) AS State,
    MAX(Country) AS Country,
    MAX(Continent) AS Continent
FROM sales
GROUP BY City;

select * from dim_location;


### Creating fact_transaction table

CREATE TABLE fact_transaction (
    row_id INT PRIMARY KEY,
    order_id VARCHAR(50),
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(50),
    customer_segment VARCHAR(100),
    city VARCHAR(100),
    product_id VARCHAR(50),
    category VARCHAR(100),
    sub_category VARCHAR(100),
    quantity INT,
    unit_price DECIMAL(10,2),
    discount_perc DECIMAL(5,2),
    unit_manufacturing_cost DECIMAL(10,2),
    unit_shipping_cost DECIMAL(10,2),
    order_priority VARCHAR(50),
    FOREIGN KEY (city) REFERENCES dim_location(city),
    FOREIGN KEY (product_id) REFERENCES dim_product(product_id),
    FOREIGN KEY (category) REFERENCES dim_category(category),
    FOREIGN KEY (sub_category) REFERENCES dim_sub_category(sub_category)
);

select * from fact_transaction;


DELIMITER $$

CREATE PROCEDURE populate_fact_transaction()
BEGIN
  INSERT INTO fact_transaction (
    row_id, order_id, order_date, ship_date,
    ship_mode, customer_segment, city,
    product_id, category, sub_category,
    quantity, unit_price, discount_perc,
    unit_manufacturing_cost, unit_shipping_cost, order_priority
  )
  SELECT
    s.Row_ID, s.Order_ID, s.Order_Date, s.Ship_Date,
    s.Ship_Mode, s.Customer_Segment, s.City,
    s.Product_ID, s.Category, s.Sub_Category,
    s.Quantity, s.Unit_Price, s.Discount_Perc,
    s.Unit_Manufacturing_Cost, s.Unit_Shipping_Cost, s.Order_Priority
  FROM sales s
  JOIN dim_location dl ON s.City = dl.city
  JOIN dim_product dp ON s.Product_ID = dp.product_id
  JOIN dim_category dc ON s.Category = dc.category
  JOIN dim_sub_category dsc ON s.Sub_Category = dsc.sub_category
  WHERE dsc.category = dc.category;  -- optional if you need strict join integrity
END$$

DELIMITER ;

CALL populate_fact_transaction();

select * from fact_transaction;







