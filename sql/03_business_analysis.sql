-- Olist E-commerce SQL Analysis
-- File 03: Business analysis (Q1-Q11)
-- Currency: Brazilian reais (R$). Revenue = item price, delivered orders only.

USE olist;

-- Q1: What are the overall headline numbers?
SELECT COUNT(DISTINCT o.order_id) AS orders,
       COUNT(DISTINCT c.customer_unique_id) AS customers,
       ROUND(SUM(oi.price),2) AS revenue,
       ROUND(SUM(oi.price)/COUNT(DISTINCT o.order_id),2) AS avg_order_value
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered';
-- Finding: 96,455 delivered orders from 93,336 unique customers generated
-- R$13.22M in revenue; average order value R$137.04. Orders are only ~3% higher
-- than customers, which hints at very few repeat buyers (see Q5).


-- Q2: How does monthly revenue trend (Jan 2017 - Aug 2018)?
WITH monthly AS (
  SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS ym,
         SUM(oi.price) AS revenue
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp <  '2018-09-01'
  GROUP BY ym
)
SELECT ym,
       ROUND(revenue,2) AS revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY ym))
             / LAG(revenue) OVER (ORDER BY ym) * 100, 1) AS mom_growth_pct
FROM monthly
ORDER BY ym;
-- Finding: Revenue grew from R$112K (Jan 2017) to a peak of R$988K in Nov 2017
-- (+52% vs Oct, Black Friday). It dropped 26.5% in Dec, then plateaued at about
-- R$830K-R$980K per month through 2018 (Aug 2018: R$839K), so growth stalled in 2018.
-- The Feb 2017 jump (+108%) comes from a very small base.


-- Q3: Which product categories drive revenue? (Pareto)
WITH cat AS (
  SELECT t.product_category_name_english AS category,
         SUM(oi.price) AS revenue
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  JOIN products p ON oi.product_id = p.product_id
  JOIN category_translation t ON p.product_category_name = t.product_category_name
  WHERE o.order_status = 'delivered'
  GROUP BY category
)
SELECT category,
       ROUND(revenue,2) AS revenue,
       ROUND(100 * revenue / SUM(revenue) OVER (), 1) AS share_pct,
       ROUND(100 * SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER (), 1) AS cumulative_pct
FROM cat
ORDER BY revenue DESC;
-- Finding: Revenue is spread across many categories rather than a strict 80/20 pattern.
-- The top 5 (health_beauty, watches_gifts, bed_bath_table, sports_leisure,
-- computers_accessories) generate 40.4% of category revenue; the top 10 generate 63.3%.
-- About 14 categories are needed to reach 80%. health_beauty leads with R$1.23M (9.5%).
-- Many categories contribute under 1% each (long tail).


-- Q4: Which states bring the most revenue?
SELECT c.customer_state,
       COUNT(DISTINCT o.order_id) AS orders,
       ROUND(SUM(oi.price),2) AS revenue
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY c.customer_state
ORDER BY revenue DESC
LIMIT 10;
-- Finding: Sao Paulo (SP) dominates with R$5.07M (38.3% of revenue) and 40,488 orders
-- (42.0% of orders). SP, RJ, and MG together bring R$8.38M, about 63% of total revenue.


-- Q5: How many customers come back? (repeat purchase rate)
SELECT order_count, COUNT(*) AS customers
FROM (
  SELECT c.customer_unique_id, COUNT(DISTINCT o.order_id) AS order_count
  FROM orders o
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
) t
GROUP BY order_count
ORDER BY order_count;
-- Finding: Only 2,800 of 93,336 customers (3.0%) ordered more than once;
-- 97.0% bought exactly once (90,536 customers). Retention is the biggest weakness.


-- Q6: How concentrated is spending across customers?
WITH spend AS (
  SELECT c.customer_unique_id, SUM(oi.price) AS total_spend
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  JOIN customers c ON o.customer_id = c.customer_id
  WHERE o.order_status = 'delivered'
  GROUP BY c.customer_unique_id
)
SELECT quartile,
       COUNT(*) AS customers,
       ROUND(SUM(total_spend),2) AS revenue,
       ROUND(AVG(total_spend),2) AS avg_spend
FROM (SELECT total_spend, NTILE(4) OVER (ORDER BY total_spend DESC) AS quartile FROM spend) t
GROUP BY quartile
ORDER BY quartile;
-- Finding: The top 25% of customers (avg spend R$354) generate R$8.27M, 62.5% of revenue;
-- the top 50% generate 83.3%. The bottom quartile averages R$29 and contributes 5.1%.


-- Q7: How fast is delivery, and how often is it late?
SELECT COUNT(*) AS delivered_orders,
       ROUND(AVG(DATEDIFF(order_delivered_customer_date, order_purchase_timestamp)),1) AS avg_delivery_days,
       ROUND(100 * SUM(order_delivered_customer_date > order_estimated_delivery_date) / COUNT(*),1) AS pct_late
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NOT NULL;
-- Finding: Average delivery takes 12.5 days and 8.1% of orders arrive after
-- the estimated date.


-- Q8: How does delivery performance vary by state?
SELECT c.customer_state,
       COUNT(*) AS delivered_orders,
       ROUND(AVG(DATEDIFF(o.order_delivered_customer_date, o.order_purchase_timestamp)),1) AS avg_delivery_days,
       ROUND(100 * SUM(o.order_delivered_customer_date > o.order_estimated_delivery_date) / COUNT(*),1) AS pct_late
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
  AND o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
HAVING COUNT(*) >= 100
ORDER BY pct_late DESC;
-- Finding: Alagoas (AL) has the highest late rate (23.9%) and the second-slowest delivery
-- (24.5 days), followed by Maranhao (MA, 19.7%) and Piaui (PI, 16.0%). Sao Paulo is the
-- fastest and most reliable (8.7 days, 5.9% late). RJ has 12,348 orders with a 13.5% late
-- rate, the biggest late-delivery impact among large markets. Amazonas (AM) is slowest
-- (26.4 days) but only 4.1% late, because its estimated dates are longer.


-- Q9: How do customers pay?
SELECT p.payment_type,
       COUNT(DISTINCT p.order_id) AS orders,
       ROUND(SUM(p.payment_value),2) AS total_value,
       ROUND(AVG(p.payment_installments),1) AS avg_installments
FROM order_payments p
JOIN orders o ON p.order_id = o.order_id
WHERE o.order_status = 'delivered'
GROUP BY p.payment_type
ORDER BY total_value DESC;
-- Finding: Credit card dominates with 74,296 orders (77% of delivered orders) and R$12.10M
-- (78.5% of payment value), 3.5 installments on average. Boleto is second (19,177 orders,
-- R$2.77M). Voucher and debit card are minor. Order counts exceed 96,455 because some
-- orders use more than one payment type, and payment value includes freight.


-- Q10: Top 3 sellers in each state by revenue
WITH seller_rev AS (
  SELECT s.seller_id, s.seller_state, SUM(oi.price) AS revenue
  FROM order_items oi
  JOIN orders o ON oi.order_id = o.order_id
  JOIN sellers s ON oi.seller_id = s.seller_id
  WHERE o.order_status = 'delivered'
  GROUP BY s.seller_id, s.seller_state
)
SELECT *
FROM (
  SELECT seller_id, seller_state, ROUND(revenue,2) AS revenue,
         RANK() OVER (PARTITION BY seller_state ORDER BY revenue DESC) AS rnk
  FROM seller_rev
) t
WHERE rnk <= 3
ORDER BY seller_state, rnk;
-- Finding: Seller revenue is concentrated in a few large sellers. The top Sao Paulo seller
-- earned R$227K and the top 3 SP sellers each earned over R$190K. A Bahia seller earned
-- R$218K despite BA being a small buyer market, suggesting nationwide selling. Other state
-- leaders: RJ R$123K, MG R$99K, PR R$73K, SC R$59K. In many smaller states the best seller
-- earned under R$5K. seller_state is the seller's location, not the customer's.


-- Q11: Running total of revenue (Jan 2017 - Aug 2018)
WITH monthly AS (
  SELECT DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m') AS ym,
         SUM(oi.price) AS revenue
  FROM orders o
  JOIN order_items oi ON o.order_id = oi.order_id
  WHERE o.order_status = 'delivered'
    AND o.order_purchase_timestamp >= '2017-01-01'
    AND o.order_purchase_timestamp <  '2018-09-01'
  GROUP BY ym
)
SELECT ym,
       ROUND(revenue,2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY ym),2) AS cumulative_revenue
FROM monthly;
-- Finding: Cumulative revenue reached R$13.18M by Aug 2018. The first 8 months of 2018
-- (R$7.22M) exceeded all of 2017 (R$5.96M) by about 21%.
-- Validation: the Q1 total (R$13.22M) minus this total leaves about R$40K, which is the
-- revenue from the excluded 2016 period.
