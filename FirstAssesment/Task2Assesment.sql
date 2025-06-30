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
ORDER BY discount_perc
LIMIT 25;







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

SELECT 
  ship_mode,
  FORMAT(
    SUM(
      (quantity * unit_price * (1 - discount_perc / 100)) -
      (quantity * unit_manufacturing_cost + quantity * unit_shipping_cost)
    ), 2
  ) AS total_profit
FROM fact_transaction
GROUP BY ship_mode
ORDER BY 
  SUM(
    (quantity * unit_price * (1 - discount_perc / 100)) -
    (quantity * unit_manufacturing_cost + quantity * unit_shipping_cost)
  ) DESC
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

SELECT 
  CONCAT(
    ROUND(
      (SUM(CASE 
             WHEN LOWER(TRIM(REPLACE(REPLACE(order_priority, '\r', ''), '\n', ''))) = 'high' THEN 1 
             ELSE 0 
           END) / COUNT(*)) * 100, 2
    ),
    '%'
  ) AS high_priority_pct
FROM fact_transaction;

#14.
SELECT 
  city,
  FORMAT(
    SUM(quantity * unit_price) / COUNT(DISTINCT order_id), 2
  ) AS revenue_per_order
FROM fact_transaction
GROUP BY city
ORDER BY 
  SUM(quantity * unit_price) / COUNT(DISTINCT order_id) DESC
LIMIT 1;

### 15. Average Profit per Customer Segment
SELECT customer_segment,
       AVG(
         (quantity * unit_price * (1 - discount_perc / 100)) -
         (quantity * unit_manufacturing_cost + quantity * unit_shipping_cost)
       ) AS avg_profit
FROM fact_transaction
GROUP BY customer_segment;

#16. 
SELECT 
  category,
  YEAR(order_date) AS year,
  FORMAT(
    SUM(quantity * unit_price * (1 - discount_perc / 100)), 2
  ) AS revenue
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


#18.
SELECT 
  CONCAT(
    ROUND(
      (COUNT(CASE WHEN product_count > 1 THEN 1 END) / COUNT(*)) * 100, 2
    ),
    '%'
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

#20.
SELECT 
  value_segment,
  COUNT(*) AS order_count,
  ROUND( COUNT(*) / (SELECT COUNT(DISTINCT order_id) FROM fact_transaction) * 100, 2) AS percentage_of_orders
FROM (
  SELECT order_id,
         SUM(quantity * unit_price * (1 - discount_perc / 100)) AS total_value,
         CASE
           WHEN SUM(quantity * unit_price * (1 - discount_perc / 100)) < 100 THEN 'Low'
           WHEN SUM(quantity * unit_price * (1 - discount_perc / 100)) < 500 THEN 'Medium'
           ELSE 'High'
         END AS value_segment
  FROM fact_transaction
  GROUP BY order_id
) t
GROUP BY value_segment
ORDER BY FIELD(value_segment, 'Low', 'Medium', 'High');











