WITH customer_cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM orders
    GROUP BY customer_id
),
order_activity AS (
    SELECT
        o.customer_id,
        c.cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM orders o
    JOIN customer_cohorts c ON o.customer_id = c.customer_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),
retention_counts AS (
    SELECT
        cohort_month,
        EXTRACT(YEAR FROM activity_month) * 12 + EXTRACT(MONTH FROM activity_month) -
        (EXTRACT(YEAR FROM cohort_month) * 12 + EXTRACT(MONTH FROM cohort_month)) AS month_index,
        COUNT(DISTINCT customer_id) AS retained_customers
    FROM order_activity
    GROUP BY cohort_month, activity_month
)
SELECT
    r.cohort_month,
    s.cohort_size,
    r.month_index,
    r.retained_customers,
    ROUND((r.retained_customers::DECIMAL / s.cohort_size) * 100, 2) AS retention_rate
FROM retention_counts r
JOIN cohort_sizes s ON r.cohort_month = s.cohort_month
ORDER BY r.cohort_month, r.month_index;

WITH customer_cohorts AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_purchase_timestamp)) AS cohort_month
    FROM orders
    GROUP BY customer_id
),
order_activity AS (
    SELECT
        o.customer_id,
        c.cohort_month,
        DATE_TRUNC('month', o.order_purchase_timestamp) AS activity_month
    FROM orders o
    JOIN customer_cohorts c ON o.customer_id = c.customer_id
),
cohort_sizes AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_id) AS cohort_size
    FROM customer_cohorts
    GROUP BY cohort_month
),
retention_counts AS (
    SELECT
        cohort_month,
        EXTRACT(YEAR FROM activity_month) * 12 + EXTRACT(MONTH FROM activity_month) -
        (EXTRACT(YEAR FROM cohort_month) * 12 + EXTRACT(MONTH FROM cohort_month)) AS month_index,
        COUNT(DISTINCT customer_id) AS retained_customers
    FROM order_activity
    GROUP BY cohort_month, activity_month
)
SELECT
    r.cohort_month,
    s.cohort_size,
    MAX(CASE WHEN r.month_index = 1 THEN ROUND((r.retained_customers::DECIMAL / s.cohort_size) * 100, 2) ELSE 0 END) AS month_1,
    MAX(CASE WHEN r.month_index = 2 THEN ROUND((r.retained_customers::DECIMAL / s.cohort_size) * 100, 2) ELSE 0 END) AS month_2,
    MAX(CASE WHEN r.month_index = 3 THEN ROUND((r.retained_customers::DECIMAL / s.cohort_size) * 100, 2) ELSE 0 END) AS month_3,
    MAX(CASE WHEN r.month_index = 4 THEN ROUND((r.retained_customers::DECIMAL / s.cohort_size) * 100, 2) ELSE 0 END) AS month_4,
    MAX(CASE WHEN r.month_index = 5 THEN ROUND((r.retained_customers::DECIMAL / s.cohort_size) * 100, 2) ELSE 0 END) AS month_5
FROM retention_counts r
JOIN cohort_sizes s ON r.cohort_month = s.cohort_month
GROUP BY r.cohort_month, s.cohort_size
ORDER BY r.cohort_month;