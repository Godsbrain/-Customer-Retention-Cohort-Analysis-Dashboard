CREATE TABLE transactions (
    invoice VARCHAR(20),
    stockcode VARCHAR(20),
    description TEXT,
    quantity INT,
    invoice_date DATETIME,
    price DECIMAL(10,2),
    customer_id INT,
    country VARCHAR(50)
);
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/Uploads/online_retail.csv' 
INTO TABLE transactions 
CHARACTER SET latin1
FIELDS TERMINATED BY ',' 
ENCLOSED BY '"' 
LINES TERMINATED BY '\n' 
IGNORE 1 ROWS 
(invoice, stockcode, description, quantity, invoice_date, price, @v_customer_id, country) 
SET customer_id = NULLIF(@v_customer_id, '');

CREATE TABLE transactions_clean AS
SELECT *
FROM transactions
WHERE customer_id IS NOT NULL
  AND quantity > 0
  AND price > 0
  AND invoice NOT LIKE 'C%';
  
  SELECT COUNT(*) FROM transactions_clean;
  SELECT COUNT(*) FROM transactions;
  CREATE TABLE customer_cohort AS
SELECT customer_id,
       MIN(DATE_FORMAT(invoice_date, '%Y-%m')) AS cohort_month
FROM transactions_clean
GROUP BY customer_id;

CREATE TABLE customer_activity AS
SELECT customer_id,
       DATE_FORMAT(invoice_date, '%Y-%m') AS activity_month
FROM transactions_clean;

CREATE TABLE cohort_data AS
SELECT c.customer_id,
       c.cohort_month,
       a.activity_month
FROM customer_cohort c
JOIN customer_activity a
  ON c.customer_id = a.customer_id;
  
CREATE TABLE cohort_index AS
SELECT customer_id,
       cohort_month,
       activity_month,
       PERIOD_DIFF(
           REPLACE(activity_month, '-', ''),
           REPLACE(cohort_month, '-', '')
       ) AS month_index
FROM cohort_data;

SELECT cohort_month, month_index, COUNT(DISTINCT customer_id)
FROM cohort_index
GROUP BY cohort_month, month_index
ORDER BY cohort_month, month_index;

WITH cohort_counts AS (
    SELECT cohort_month,
           month_index,
           COUNT(DISTINCT customer_id) AS users
    FROM cohort_index
    GROUP BY cohort_month, month_index
),
cohort_sizes AS (
    SELECT cohort_month,
           COUNT(DISTINCT customer_id) AS size
    FROM cohort_index
    WHERE month_index = 0
    GROUP BY cohort_month
)

SELECT c.cohort_month,
       c.month_index,
       c.users,
       ROUND(c.users / s.size * 100, 2) AS retention_rate
FROM cohort_counts c
JOIN cohort_sizes s
  ON c.cohort_month = s.cohort_month
ORDER BY c.cohort_month, c.month_index;
SELECT DISTINCT cohort_month FROM cohort_index;

SELECT MAX(month_index) FROM cohort_index;
 