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
    city VARCHAR(100) PRIMARY KEY,  -- referenced by 'sales.city'
    state VARCHAR(100) NOT NULL,
    country VARCHAR(100) NOT NULL,
    continent VARCHAR(150) NOT NULL
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



# Task2

#1. Total Gross Revenue
#Gross revenue = Quantity × Unit Price
SELECT SUM(ft.quantity * dp.unit_price) AS total_gross_revenue
FROM fact_transaction as ft
JOIN dim_product as dp ON ft.product_id = dp.product_id;

#2. Total Net Revenue
#Net Revenue = Gross Revenue – Discount
SELECT SUM(ft.quantity * dp.unit_price * (1 - ft.discount_perc / 100)) AS total_net_revenue
FROM fact_transaction as ft
JOIN dim_product as dp ON ft.product_id = dp.product_id;

#3. Total Profit
#Profit = Net Revenue – Manufacturing Cost – Shipping Cost

SELECT SUM(
    (ft.quantity * dp.unit_price * (1 - ft.discount_perc / 100)) -
    (ft.quantity * dp.unit_manufacturing_cost) -
    (ft.quantity * ft.unit_shipping_cost)
) AS total_profit
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id;

#4. Orders per Customer Segment
SELECT customer_segment, COUNT(DISTINCT order_id) AS total_orders
FROM fact_transaction
GROUP BY customer_segment;

#5. Top 5 Best-Selling Products by Quantity
SELECT dp.product_name, SUM(ft.quantity) AS total_sold
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id
GROUP BY dp.product_name
ORDER BY total_sold DESC
LIMIT 5;


#6. Monthly Gross Revenue Trend for 2015
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month,
       SUM(ft.quantity * dp.unit_price) AS gross_revenue
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id
WHERE YEAR(order_date) = 2015
GROUP BY month
ORDER BY month;

#7. Sub-category with Highest Profit Margin
SELECT dsc.sub_category,
       SUM((dp.unit_price - dp.unit_manufacturing_cost) * ft.quantity) / SUM(ft.quantity * dp.unit_price) AS profit_margin
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id
JOIN dim_sub_category dsc ON dp.sub_category_id = dsc.sub_category_id
GROUP BY dsc.sub_category
ORDER BY profit_margin DESC
LIMIT 1;

#8. Continents with Most Returns (as % of total sales)

SELECT dr.continent,
       COUNT(DISTINCT rt.order_id) / COUNT(DISTINCT ft.order_id) * 100 AS return_rate_percentage
FROM fact_transaction ft
JOIN dim_location dr ON ft.location_id = dr.location_id
LEFT JOIN return_table rt ON ft.order_id = rt.order_id AND rt.Returned = 'Yes'
GROUP BY dr.continent;

#9. Products with Negative Profit


SELECT 
    dp.product_name,
    SUM(
        (dp.unit_price * ft.quantity * (1 - ft.discount_perc / 100)) -
        (dp.unit_manufacturing_cost * ft.quantity) -
        (ft.unit_shipping_cost * ft.quantity)
    ) AS total_profit
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id
GROUP BY dp.product_name
HAVING total_profit < 0
ORDER BY total_profit ASC;

#10. Discount vs. Order Volume Correlation
SELECT ROUND(discount_perc, 2) AS discount, SUM(quantity) AS total_order_volume
FROM fact_transaction
GROUP BY discount
ORDER BY discount;

#11. Return Rate by Product Category
SELECT dc.category,
       COUNT(DISTINCT rt.order_id) / COUNT(DISTINCT ft.order_id) * 100 AS return_rate
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id
JOIN dim_sub_category dsc ON dp.sub_category_id = dsc.sub_category_id
JOIN dim_category dc ON dsc.category_id = dc.category_id
LEFT JOIN return_table rt ON ft.order_id = rt.order_id AND rt.Returned = 'Yes'
GROUP BY dc.category;

#12. Most Profitable Shipping Mode
SELECT ship_mode,
       SUM((dp.unit_price * ft.quantity * (1 - ft.discount_perc / 100)) -
           (dp.unit_manufacturing_cost * ft.quantity) -
           (ft.unit_shipping_cost * ft.quantity)) AS profit
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id
GROUP BY ship_mode
ORDER BY profit DESC
LIMIT 1;

#13. Percentage of Orders That Are High Priority
SELECT 
  CONCAT(
    ROUND(SUM(LOWER(REPLACE(TRIM(order_priority), '\r', '')) = 'high') * 100.0 / COUNT(*), 2),
    '%'
  ) AS high_priority_percent
FROM fact_transaction;

#14.City with Highest Revenue per Order
#####LOCATION_ID FIX KORTE HOBE




#15. Average Profit per Customer Segment
SELECT customer_segment,
       AVG(
         (dp.unit_price * ft.quantity * (1 - ft.discount_perc / 100)) -
         (dp.unit_manufacturing_cost * ft.quantity) -
         (ft.unit_shipping_cost * ft.quantity)
       ) AS avg_profit
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id
GROUP BY customer_segment;

#16. YoY Revenue Growth by Category

SELECT 
  dc.category,
  YEAR(ft.order_date) AS year,
  SUM(ft.quantity * dp.unit_price * (1 - ft.discount_perc / 100)) AS revenue
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id
JOIN dim_sub_category dsc ON dp.sub_category_id = dsc.sub_category_id
JOIN dim_category dc ON dsc.category_id = dc.category_id
GROUP BY dc.category, year
ORDER BY dc.category, year;

#17. NEED STUDY

#18. % Orders with Multiple Products
SELECT 
    (SELECT COUNT(*) FROM (
        SELECT order_id FROM fact_transaction GROUP BY order_id HAVING COUNT(DISTINCT product_id) > 1
    ) AS multi) * 100.0 / COUNT(DISTINCT order_id) AS multi_product_percent
FROM fact_transaction;

#19.Orders with Abnormally High Shipping Costs

SELECT order_id, quantity, unit_shipping_cost
FROM fact_transaction
WHERE unit_shipping_cost > (
    SELECT AVG(unit_shipping_cost) * 3 FROM fact_transaction
);
# (Assuming threshold: shipping cost > 3× average)

#20.Order Value Segments (Low / Medium / High)
 SELECT order_id,SUM(dp.unit_price * ft.quantity) AS order_value,
       CASE 
         WHEN SUM(dp.unit_price * ft.quantity) < 100 THEN 'Low'
         WHEN SUM(dp.unit_price * ft.quantity) BETWEEN 100 AND 500 THEN 'Medium'
         ELSE 'High'
       END AS value_segment
FROM fact_transaction ft
JOIN dim_product dp ON ft.product_id = dp.product_id
GROUP BY order_id;































