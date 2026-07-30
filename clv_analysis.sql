WITH customer_revenue AS (
    SELECT
        o.customer_id,
        COUNT(DISTINCT o.order_id) AS total_orders,
        MIN(o.order_purchase_timestamp) AS first_purchase,
        MAX(o.order_purchase_timestamp) AS last_purchase,
        SUM(oi.price + oi.freight_value) AS total_revenue
    FROM orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    GROUP BY o.customer_id
)
SELECT
    customer_id,
    total_orders,
    ROUND(total_revenue::DECIMAL, 2) AS total_revenue,
    ROUND((total_revenue::DECIMAL / total_orders), 2) AS avg_order_value,
    EXTRACT(DAY FROM (last_purchase - first_purchase)) AS customer_lifespan_days
FROM customer_revenue
ORDER BY total_revenue DESC;