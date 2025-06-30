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

### 1. Total Gross Revenue

SELECT SUM(quantity * unit_price) AS total_gross_revenue
FROM fact_transaction;

###2. Total Net Revenue (after discount)
SELECT SUM(quantity * unit_price * (1 - discount_perc / 100)) AS total_net_revenue
FROM fact_transaction;

###3. Total Profit
SELECT SUM(
  (quantity * unit_price * (1 - discount_perc / 100)) -
  (quantity * unit_manufacturing_cost + quantity * unit_shipping_cost)
) AS total_profit
FROM fact_transaction;

### 4. Orders by Customer Segment
SELECT customer_segment, COUNT(DISTINCT order_id) AS total_orders
FROM fact_transaction
GROUP BY customer_segment;

###  5. Top 5 Best-Selling Products by Quantity
SELECT product_id, SUM(quantity) AS total_quantity
FROM fact_transaction
GROUP BY product_id
ORDER BY total_quantity DESC
LIMIT 5;

### 6. Monthly Gross Revenue Trend for 2015
SELECT DATE_FORMAT(order_date, '%Y-%m') AS month, SUM(quantity * unit_price) AS gross_revenue
FROM fact_transaction
WHERE YEAR(order_date) = 2015
GROUP BY month
ORDER BY month;

### 7. Sub-Category with Highest Profit Margin
SELECT sub_category,
       SUM((unit_price * (1 - discount_perc / 100)) - unit_manufacturing_cost - unit_shipping_cost) /
       SUM(unit_price * (1 - discount_perc / 100)) AS profit_margin
FROM fact_transaction
GROUP BY sub_category
ORDER BY profit_margin DESC
LIMIT 1;

### 8. Continents with Most Product Returns (as % of total sold)
SELECT dl.continent,
       COUNT(DISTINCT r.`Order ID`) / COUNT(DISTINCT f.order_id) * 100 AS return_rate_pct
FROM fact_transaction f
JOIN dim_location dl ON f.city = dl.city
LEFT JOIN return_table r ON f.order_id = r.`Order ID`
GROUP BY dl.continent
ORDER BY return_rate_pct DESC;



### 9. Products with Negative Profit
SELECT product_id,
       SUM(
         (quantity * unit_price * (1 - discount_perc / 100)) -
         (quantity * unit_manufacturing_cost + quantity * unit_shipping_cost)
       ) AS total_profit
FROM fact_transaction
GROUP BY product_id
HAVING total_profit < 0;

### 10. Correlation Between Discount and Order Volume

SELECT
  discount_perc,
  ROUND(AVG(unit_price), 2) AS avg_unit_price,
  SUM(quantity) AS order_volume
FROM fact_transaction
GROUP BY discount_perc
ORDER BY discount_perc;







### 11. Return Rate by Product Category
SELECT category,
       COUNT(DISTINCT r.`Order ID`) / COUNT(DISTINCT f.order_id) * 100 AS return_rate_pct
FROM fact_transaction f
LEFT JOIN return_table r ON f.order_id = r.`Order ID`
GROUP BY category;

### 12. Most Profitable Shipping Mode
SELECT ship_mode,
       SUM(
         (quantity * unit_price * (1 - discount_perc / 100)) -
         (quantity * unit_manufacturing_cost + quantity * unit_shipping_cost)
       ) AS total_profit
FROM fact_transaction
GROUP BY ship_mode
ORDER BY total_profit DESC
LIMIT 1;

### 13. % of High Priority Orders

SELECT 
  ROUND(
    (SUM(CASE 
           WHEN LOWER(TRIM(REPLACE(REPLACE(order_priority, '\r', ''), '\n', ''))) = 'high' THEN 1 
           ELSE 0 
         END) / COUNT(*)) * 100, 2
  ) AS high_priority_pct
FROM fact_transaction;





### 14. Highest Revenue per Order by City
SELECT city,
       SUM(quantity * unit_price) / COUNT(DISTINCT order_id) AS revenue_per_order
FROM fact_transaction
GROUP BY city
ORDER BY revenue_per_order DESC
LIMIT 1;

### 15. Average Profit per Customer Segment
SELECT customer_segment,
       AVG(
         (quantity * unit_price * (1 - discount_perc / 100)) -
         (quantity * unit_manufacturing_cost + quantity * unit_shipping_cost)
       ) AS avg_profit
FROM fact_transaction
GROUP BY customer_segment;

### 16. YoY Revenue Growth by Category
SELECT category,
       YEAR(order_date) AS year,
       SUM(quantity * unit_price * (1 - discount_perc / 100)) AS revenue
FROM fact_transaction
GROUP BY category, year
ORDER BY category, year;

### 17. Products Frequently Purchased Together


SELECT a.product_id AS product_a, b.product_id AS product_b, COUNT(*) AS times_bought_together
FROM (
    SELECT DISTINCT order_id, product_id
    FROM fact_transaction
) a
JOIN (
    SELECT DISTINCT order_id, product_id
    FROM fact_transaction
) b
  ON a.order_id = b.order_id AND a.product_id < b.product_id
GROUP BY product_a, product_b
ORDER BY times_bought_together DESC;






### 18. % of Orders with Multiple Products

SELECT 
  ROUND(
    (COUNT(CASE WHEN product_count > 1 THEN 1 END) / COUNT(*)) * 100, 2
  ) AS multi_product_order_pct
FROM (
  SELECT order_id, COUNT(DISTINCT product_id) AS product_count
  FROM fact_transaction
  GROUP BY order_id
) t;


### 19. Orders with Abnormally High Shipping Costs

SELECT order_id,
       SUM(unit_shipping_cost * quantity) AS total_shipping_cost
FROM fact_transaction
GROUP BY order_id
HAVING total_shipping_cost > (
  SELECT AVG(unit_shipping_cost * quantity) + 2 * STDDEV(unit_shipping_cost * quantity)
  FROM fact_transaction
);

### 20. Orders by Value Segment (Low / Medium / High)

SELECT order_id,
       CASE
         WHEN total_value < 100 THEN 'Low'
         WHEN total_value < 500 THEN 'Medium'
         ELSE 'High'
       END AS value_segment
FROM (
  SELECT order_id, SUM(quantity * unit_price * (1 - discount_perc / 100)) AS total_value
  FROM fact_transaction
  GROUP BY order_id
) t;
























