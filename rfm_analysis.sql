WITH max_date AS (
    SELECT MAX(order_purchase_timestamp) AS max_ts FROM orders
),
customer_rfm_raw AS (
    SELECT
        o.customer_id,
        EXTRACT(DAY FROM (m.max_ts - MAX(o.order_purchase_timestamp))) AS recency_days,
        COUNT(DISTINCT o.order_id) AS frequency,
        SUM(oi.price + oi.freight_value) AS monetary
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    CROSS JOIN max_date m
    GROUP BY o.customer_id, m.max_ts
),
rfm_scores AS (
    SELECT
        customer_id,
        recency_days,
        frequency,
        monetary,
        NTILE(5) OVER (ORDER BY recency_days DESC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary ASC) AS m_score
    FROM customer_rfm_raw
)
SELECT
    customer_id,
    recency_days,
    frequency,
    ROUND(monetary::DECIMAL, 2) AS monetary,
    r_score,
    f_score,
    m_score,
    (r_score + f_score + m_score) AS combined_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'VIP / Champions'
        WHEN r_score >= 3 AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'Recent Buyers'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'At-Risk'
        WHEN r_score <= 2 AND f_score <= 2 THEN 'Lost / Hibernating'
        ELSE 'Potential / Average'
    END AS customer_segment
FROM rfm_scores
ORDER BY combined_score DESC;