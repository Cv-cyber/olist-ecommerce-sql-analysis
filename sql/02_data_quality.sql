-- Olist E-commerce SQL Analysis
-- File 02: Data quality checks

USE olist;

-- 1. Order status distribution
SELECT order_status, COUNT(*) AS orders FROM orders GROUP BY order_status;
-- Result: delivered 96,455 | canceled 6


-- 2. Order items whose order did not load
SELECT COUNT(*) AS orphan_items
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;
-- Result: 2,470 items. Joins through orders exclude them automatically.

-- 3. Duplicate orders
SELECT order_id, COUNT(*) FROM orders GROUP BY order_id HAVING COUNT(*) > 1;
-- Result: no rows, so there are no duplicate order IDs.

-- 4. Orders with no items
SELECT COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi ON o.order_id = oi.order_id
WHERE oi.order_id IS NULL;
-- Result: 0. Every loaded order has at least one item.

-- 5. Products with no category
SELECT COUNT(*) AS no_category FROM products WHERE product_category_name IS NULL;
-- Result: [write your number here]

-- 6. Delivered orders missing a delivery date
SELECT COUNT(*) AS delivered_missing_date
FROM orders
WHERE order_status = 'delivered' AND order_delivered_customer_date IS NULL;
-- Result: [write your number here]


-- 7. Date range of the data
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM orders;
-- Result: 2016-09-15 to 2018-08-29

