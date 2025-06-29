#Create Database

create database DataSolution;

#Use Database

use DataSolution;

#Create Table

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

-- Dim Location Table
CREATE TABLE dim_location (
    location_id INT AUTO_INCREMENT PRIMARY KEY,
    city VARCHAR(100),
    state VARCHAR(100),
    country VARCHAR(100),
    continent VARCHAR(150),
    UNIQUE(city, state, country, continent)
);

-- Dim Category Table
CREATE TABLE dim_category (
    category_id INT AUTO_INCREMENT PRIMARY KEY,
    category VARCHAR(100),
    UNIQUE(category)
);

-- Dim Sub-Category Table
CREATE TABLE dim_sub_category (
    sub_category_id INT AUTO_INCREMENT PRIMARY KEY,
    sub_category VARCHAR(100),
    category_id INT,
    FOREIGN KEY (category_id) REFERENCES dim_category(category_id),
    UNIQUE(sub_category, category_id)
);

-- Dim Product Table
CREATE TABLE dim_product (
    product_id VARCHAR(150) PRIMARY KEY,
    product_name VARCHAR(255),
    sub_category_id INT,
    unit_price DECIMAL(10,2),
    unit_manufacturing_cost DECIMAL(10,2),
    FOREIGN KEY (sub_category_id) REFERENCES dim_sub_category(sub_category_id)
);

CREATE TABLE fact_transaction (
    transaction_id INT AUTO_INCREMENT PRIMARY KEY,
    order_id VARCHAR(100),
    order_date DATE,
    ship_date DATE,
    ship_mode VARCHAR(100),
    order_priority VARCHAR(50),
    customer_segment VARCHAR(150),
    location_id INT,
    product_id VARCHAR(150),
    quantity INT,
    discount_perc DECIMAL(5,2),
    unit_shipping_cost DECIMAL(10,2),
    FOREIGN KEY (location_id) REFERENCES dim_location(location_id),
    FOREIGN KEY (product_id) REFERENCES dim_product(product_id)
);

# Normalize and Populate in mySQL


DELIMITER //
CREATE PROCEDURE normalize_and_populate()
BEGIN
    -- Insert locations
    INSERT IGNORE INTO dim_location (city, state, country, continent)
    SELECT DISTINCT City, State, Country, Continent FROM sales;

    -- Insert categories
    INSERT IGNORE INTO dim_category (category)
    SELECT DISTINCT Category FROM sales;

    -- Insert sub-categories
    INSERT IGNORE INTO dim_sub_category (sub_category, category_id)
    SELECT DISTINCT s.Sub_Category, dc.category_id
    FROM sales s
    JOIN dim_category dc ON s.Category = dc.category;

    -- Insert products
    INSERT IGNORE INTO dim_product (product_id, product_name, sub_category_id, unit_price, unit_manufacturing_cost)
    SELECT DISTINCT s.Product_ID, s.Product_Name, dsc.sub_category_id, s.Unit_Price, s.Unit_Manufacturing_Cost
    FROM sales s
    JOIN dim_category dc ON s.Category = dc.category
    JOIN dim_sub_category dsc ON s.Sub_Category = dsc.sub_category AND dsc.category_id = dc.category_id;

    -- Insert fact transactions
    INSERT INTO fact_transaction (
        order_id, order_date, ship_date, ship_mode, order_priority,
        customer_segment, location_id, product_id, quantity,
        discount_perc, unit_shipping_cost
    )
    SELECT
        s.Order_ID, s.Order_Date, s.Ship_Date, s.Ship_Mode, s.Order_Priority,
        s.Customer_Segment, dl.location_id, s.Product_ID, s.Quantity,
        s.Discount_Perc, s.Unit_Shipping_Cost
    FROM sales s
    JOIN dim_location dl ON s.City = dl.city AND s.State = dl.state AND s.Country = dl.country AND s.Continent = dl.continent;
END //
DELIMITER ;


CALL normalize_and_populate();

select * from dim_sub_category;
select * from dim_product;
select * from dim_location;
select * from dim_category;
select * from fact_transaction;

#Count the records 
SELECT COUNT(*) FROM sales;

#Checking null records
SELECT COUNT(*) FROM sales WHERE Product_ID IS NULL;

CREATE TABLE return_table (
    Order_ID VARCHAR(100),
    Returned VARCHAR(10)
);


#Create table for returned.csv
CREATE TABLE return_table (
    returned VARCHAR(10),
    order_id VARCHAR(100)
);

select * from return_table;






