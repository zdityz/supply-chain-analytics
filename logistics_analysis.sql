WITH delivery_metrics AS (
    SELECT 
        p.product_category_name,
        o.order_id,
        EXTRACT(EPOCH FROM (o.order_delivered_customer_date - o.order_estimated_delivery_date))/86400 AS delay_days
    FROM 
        orders o
    JOIN 
        order_items oi ON o.order_id = oi.order_id
    JOIN 
        products p ON oi.product_id = p.product_id
    WHERE 
        o.order_status = 'delivered' 
        AND o.order_delivered_customer_date IS NOT NULL
        AND o.order_estimated_delivery_date IS NOT NULL
),
category_aggregation AS (
    SELECT 
        product_category_name,
        COUNT(order_id) AS total_orders,
        SUM(CASE WHEN delay_days > 0 THEN 1 ELSE 0 END) AS late_orders,
        AVG(delay_days) AS avg_delay_days
    FROM 
        delivery_metrics
    GROUP BY 
        product_category_name
    HAVING 
        COUNT(order_id) > 100
)
SELECT 
    product_category_name,
    total_orders,
    late_orders,
    ROUND((late_orders::NUMERIC / total_orders) * 100, 2) AS late_percentage,
    ROUND(avg_delay_days::NUMERIC, 2) AS average_delay,
    RANK() OVER (ORDER BY avg_delay_days DESC) AS worst_delay_rank
FROM 
    category_aggregation
WHERE 
    product_category_name IS NOT NULL
ORDER BY 
    worst_delay_rank
LIMIT 20;