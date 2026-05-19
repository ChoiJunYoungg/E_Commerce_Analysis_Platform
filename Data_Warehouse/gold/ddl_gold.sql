/* Building Gold Layer
1. Analysing
- Explore & Understand the Business Objects
2. Coding
- Data Integration
  - Build the Business Objects
  - Choose Type Dimension vs Fact
  - Rename to fridnly names
3. Validating
- Data integration Checks
4. Docs & Version (Data m=Model, Data Catalog, Data Flow)
- Documneting Versioning in GIT */

/* Build Gold Layer
Explore the Business Objects */
-- draw.io에 customer, product, sale라는 새로운 관계

/* CREATE Dimension Customers */
-- JOIN은 master table로부터 LEFT JOIN을 함(INNER JOIN x), INNER JOIN을 하면 데이터 손실이 일어날 수 있음

USE E_Commerce;

IF OBJECT_ID('gold.dim_customer', 'U') IS NOT NULL
    DROP TABLE gold.dim_customer;
GO
CREATE TABLE gold.dim_customer (
    customer_sk INT,
    customer_unique_id VARCHAR(50),
    customer_city VARCHAR(100),
    customer_state VARCHAR(10),
    first_order_date DATE,
    last_order_date DATE,
    lifetime_orders INT,
    lifetime_value DECIMAL(18,2),
    avg_order_value DECIMAL(18,2),
    is_repeat_customer INT,
    customer_segment VARCHAR(20),
    dwh_create_date DATETIME DEFAULT GETDATE()
);

-- dim_customer(customer + orders + payments)
SELECT
ROW_NUMBER() OVER (ORDER BY c.customer_id) AS customer_sk,
c.customer_id,
c.customer_unique_id,
c.customer_city,
c.customer_state,
MIN(CAST(o.order_purchase_timestamp AS DATE)) AS first_order_date,
COUNT(o.order_id) AS lifetime_orders,
SUM(p.payment_value) AS lifetime_value
FROM silver.olist_customers AS c LEFT JOIN silver.olist_orders AS o
ON c.customer_id = o.customer_id
LEFT JOIN silver.olist_order_payments AS p
ON o.order_id = p.order_id
GROUP BY
c.customer_id,
c.customer_unique_id,
c.customer_city,
c.customer_state


SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state,
    MIN(CAST(o.order_purchase_timestamp AS DATE)) AS first_order_date,
    MAX(CAST(o.order_purchase_timestamp AS DATE)) AS last_order_date,
    COUNT(DISTINCT o.order_id) AS lifetime_orders,
    COALESCE(SUM(p.payment_value),0) AS lifetime_value,
    COALESCE(AVG(p.payment_value),0) AS avg_order_value,
    AVG(CAST(p.payment_installments AS FLOAT)) AS avg_installments,
    MAX(p.payment_type) AS preferred_payment_type,
    CASE
        WHEN COALESCE(SUM(p.payment_value),0) >= 5000
            THEN 'VIP'
        WHEN COUNT(DISTINCT o.order_id) >= 10
            THEN 'LOYAL'
        WHEN COUNT(DISTINCT o.order_id) >= 3
            THEN 'REGULAR'
        ELSE 'NEW'
    END AS customer_segment,
    CASE
        WHEN COUNT(DISTINCT o.order_id) > 1
            THEN 1
        ELSE 0
    END AS is_repeat_customer
FROM silver.olist_customers AS c LEFT JOIN silver.olist_orders AS o
ON c.customer_id = o.customer_id
LEFT JOIN silver.olist_order_payments AS p
ON o.order_id = p.order_id
GROUP BY
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city,
    c.customer_state

SELECT 
    c.customer_unique_id,
    COUNT(DISTINCT o.order_id) AS order_count
FROM silver.olist_customers c
LEFT JOIN silver.olist_orders o
    ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(DISTINCT o.order_id) > 1
ORDER BY order_count DESC;




SELECT
    COUNT(*) AS total_orders,
    COUNT(c.customer_id) AS matched_customers
FROM silver.olist_orders AS o LEFT JOIN silver.olist_customers AS c
ON o.customer_id = c.customer_id;





SELECT
    COUNT(*) AS repeat_customers
FROM (
    SELECT
        c.customer_unique_id
    FROM silver.olist_customers AS c INNER JOIN silver.olist_orders AS o
    ON c.customer_id = o.customer_id
    GROUP BY c.customer_unique_id
    HAVING COUNT(DISTINCT o.order_id) > 1
) t;


-- dim_customer(customer + orders + payments) 최종 코드
----------------------------------------------------------

WITH payment_agg AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment
    FROM silver.olist_order_payments
    GROUP BY order_id
),

customer_metrics AS (
    SELECT
        c.customer_unique_id,
        -- MIN(c.customer_id) AS customer_id,
        MIN(c.customer_city) AS customer_city,
        MIN(c.customer_state) AS customer_state,
        MIN(CAST(o.order_purchase_timestamp AS DATE)) AS first_order_date,
        MAX(CAST(o.order_purchase_timestamp AS DATE)) AS last_order_date,
        COALESCE(COUNT(DISTINCT o.order_id), 0) AS lifetime_orders,
        COALESCE(SUM(pa.total_payment), 0) AS lifetime_value,
        CASE
            WHEN COALESCE(COUNT(DISTINCT o.order_id), 0) = 0 THEN 0
            ELSE COALESCE(SUM(pa.total_payment), 0) / COALESCE(COUNT(DISTINCT o.order_id), 0)
        END AS avg_order_value,
        CASE
            WHEN COUNT(DISTINCT o.order_id) > 1    THEN 1
            ELSE 0
        END AS is_repeat_customer,
        CASE
        WHEN COUNT(DISTINCT o.order_id) >= 5 AND COALESCE(SUM(pa.total_payment), 0) >= 1000 THEN 'VIP' -- 구매금액과 빈도 모두 고려
        WHEN COUNT(DISTINCT o.order_id) >= 3 THEN 'LOYAL'
        WHEN COUNT(DISTINCT o.order_id) >= 2 THEN 'REGULAR'
        ELSE 'NEW'
        END AS customer_segment
    FROM silver.olist_customers AS c INNER JOIN silver.olist_orders AS o
    ON c.customer_id = o.customer_id
    LEFT JOIN payment_agg AS pa
    ON o.order_id = pa.order_id
    GROUP BY c.customer_unique_id
)

SELECT
    ROW_NUMBER() OVER (ORDER BY customer_unique_id) AS customer_sk,
    -- customer_id,
    customer_unique_id,
    customer_city,
    customer_state
    first_order_date,
    last_order_date,
    lifetime_orders,
    lifetime_value,
    avg_order_value,
    is_repeat_customer,
    customer_segment
FROM customer_metrics



------------------------------------------------------------------------
-- insert
GO
WITH payment_agg AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment
    FROM silver.olist_order_payments
    GROUP BY order_id
),

customer_metrics AS (
    SELECT
        c.customer_unique_id,
        MIN(c.customer_city) AS customer_city,
        MIN(c.customer_state) AS customer_state,
        MIN(CAST(o.order_purchase_timestamp AS DATE)) AS first_order_date,
        MAX(CAST(o.order_purchase_timestamp AS DATE)) AS last_order_date,
        COALESCE(COUNT(DISTINCT o.order_id), 0) AS lifetime_orders,
        COALESCE(SUM(pa.total_payment), 0) AS lifetime_value,
        CASE
            WHEN COALESCE(COUNT(DISTINCT o.order_id), 0) = 0 THEN 0
            ELSE COALESCE(SUM(pa.total_payment), 0) / COALESCE(COUNT(DISTINCT o.order_id), 0)
        END AS avg_order_value,
        CASE
            WHEN COUNT(DISTINCT o.order_id) > 1    THEN 1
            ELSE 0
        END AS is_repeat_customer,
        CASE
        WHEN COUNT(DISTINCT o.order_id) >= 5 AND COALESCE(SUM(pa.total_payment), 0) >= 1000 THEN 'VIP' -- 구매금액과 빈도 모두 고려
        WHEN COUNT(DISTINCT o.order_id) >= 3 THEN 'LOYAL'
        WHEN COUNT(DISTINCT o.order_id) >= 2 THEN 'REGULAR'
        ELSE 'NEW'
        END AS customer_segment
    FROM silver.olist_customers AS c INNER JOIN silver.olist_orders AS o
    ON c.customer_id = o.customer_id
    LEFT JOIN payment_agg AS pa
    ON o.order_id = pa.order_id
    GROUP BY c.customer_unique_id
)

INSERT INTO gold.dim_customer(
    customer_sk,
    customer_unique_id,
    customer_city,
    customer_state,
    first_order_date,
    last_order_date,
    lifetime_orders,
    lifetime_value,
    avg_order_value,
    is_repeat_customer,
    customer_segment
)

SELECT
    ROW_NUMBER() OVER (ORDER BY customer_unique_id) AS customer_sk,
    customer_unique_id,
    customer_city,
    customer_state,
    first_order_date,
    last_order_date,
    lifetime_orders,
    lifetime_value,
    avg_order_value,
    is_repeat_customer,
    customer_segment
FROM customer_metrics

GO

-- 경고: 집계 또는 다른 SET 작업에 의해 Null 값이 제거되었습니다.
--------------------------------------------------------------
SELECT
    *
FROM gold.dim_customer

-- dim_date

IF OBJECT_ID('gold.dim_date', 'U') IS NOT NULL
    DROP TABLE gold.dim_date;

CREATE TABLE gold.dim_date (
    date_sk INT,
    full_date DATE,
    year_num INT,
    quarter_num INT,
    month_num INT,
    month_name VARCHAR(20),
    day_num INT,
    day_name VARCHAR(20),
    week_num INT,
    is_weekend INT,
    dwh_create_date DATETIME DEFAULT GETDATE()
);

----------------------------------------------------------

WITH d AS (
SELECT
    CAST('2016-01-01' AS DATE) AS dt
    UNION ALL
    SELECT
        DATEADD(DAY, 1, dt)
    FROM d
    WHERE dt < '2020-12-31'
)

SELECT
    CAST(FORMAT(dt, 'yyyyMMdd') AS INT) AS date_sk,
    dt AS full_date,
    YEAR(dt) AS year_num,
    DATEPART(QUARTER, dt) AS quarter_num,
    MONTH(dt) AS month_num,
    DATENAME(MONTH, dt) AS month_name,
    DAY(dt) AS day_num,
    DATENAME(WEEKDAY, dt) AS day_name,
    DATEPART(WEEK, dt) AS week_num,
    CASE
        WHEN DATENAME(WEEKDAY, dt) IN ('토요일', '일요일') THEN 1
        ELSE 0
    END AS is_weekend
FROM d

OPTION(MAXRECURSION 0);
----------------------------------------------------------------------------------

---- 최종 insert

WITH d AS (
SELECT
    CAST('2016-01-01' AS DATE) AS dt
    UNION ALL
    SELECT
        DATEADD(DAY, 1, dt)
    FROM d
    WHERE dt < '2020-12-31'
)

INSERT INTO gold.dim_date(
    date_sk,
    full_date,
    year_num,
    quarter_num,
    month_num,
    month_name,
    day_num,
    day_name,
    week_num,
    is_weekend
)

SELECT
    CAST(FORMAT(dt, 'yyyyMMdd') AS INT) AS date_sk,
    dt AS full_date,
    YEAR(dt) AS year_num,
    DATEPART(QUARTER, dt) AS quarter_num,
    MONTH(dt) AS month_num,
    DATENAME(MONTH, dt) AS month_name,
    DAY(dt) AS day_num,
    DATENAME(WEEKDAY, dt) AS day_name,
    DATEPART(WEEK, dt) AS week_num,
    CASE
        WHEN DATENAME(WEEKDAY, dt) IN ('Saturday', 'Sunday') THEN 1
        ELSE 0
    END AS is_weekend
FROM d

OPTION(MAXRECURSION 0);

----------------------------------------------------------------------------------
SELECT
    *
FROM gold.dim_date



------------------------------------------------------------------------------------

-- fact order
IF OBJECT_ID('gold.fact_orders', 'U') IS NOT NULL
    DROP TABLE gold.fact_orders;

CREATE TABLE gold.fact_orders (
    order_sk INT,
    order_id VARCHAR(50),
    customer_sk INT,
    purchase_date_sk INT,
    order_status VARCHAR(30),
    total_items INT,
    total_item_amount DECIMAL(18,2),
    total_freight_amount DECIMAL(18,2),
    total_payment_amount DECIMAL(18,2),
    avg_review_score FLOAT,
    is_delivered INT,
    delivery_days INT,
    estimated_delivery_days INT,
    is_delayed INT,
    delivery_delay_days INT,
    approval_days INT
);





-----------------------------------------------------------------------------------------------
-- fact_orders(orders + order_items + payments + reviews), (dim_customer + dim_date)
-- 1 : N관계에서 단순 join시 중복발생(각각 먼저 aggregation한 후 합치기)

GO
WITH payment_agg AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_amount,
        COUNT(*) AS payment_count,
        AVG(payment_installments * 1.0) AS avg_installments
    FROM silver.olist_order_payments
    GROUP BY order_id
)
, item_agg AS (
    SELECT
        order_id,
        COUNT(*) AS total_items,
        SUM(price) AS total_item_amount,
        SUM(freight_value) AS total_freight_amount
        -- SUM(total_item_value) AS total_order_value
    FROM silver.olist_order_items
    GROUP BY order_id
)
, review_agg AS (
    SELECT
        order_id,
        AVG(CAST(review_score AS FLOAT)) AS avg_review_score
    FROM silver.olist_order_reviews
    GROUP BY order_id
)

SELECT
    ROW_NUMBER() OVER (ORDER BY o.order_id) AS order_sk,
    o.order_id,
    dc.customer_sk,
    dd.date_sk AS purchase_date_sk,
    o.order_status,
    COALESCE(ia.total_items,0) AS total_items,
    COALESCE(ia.total_item_amount, 0) AS total_item_amount,
    COALESCE(ia.total_freight_amount, 0) AS total_freight_amount,
    COALESCE(pa.total_payment_amount,0) AS total_payment_amount,
    COALESCE(ra.avg_review_score,0) AS avg_review_score,
    o.is_delivered,
    o.delivery_days,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_estimated_delivery_date) AS estimated_delivery_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL    THEN 0
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date  THEN 1
        ELSE 0
    END AS is_delayed,
    o.delivery_delay_days,
    CASE 
        WHEN o.order_approved_at IS NOT NULL THEN DATEDIFF(DAY, o.order_purchase_timestamp, o.order_approved_at)
    END AS approval_days
FROM silver.olist_orders AS o INNER JOIN silver.olist_customers AS c
ON o.customer_id = c.customer_id
INNER JOIN gold.dim_customer AS dc
ON c.customer_unique_id = dc.customer_unique_id
INNER JOIN gold.dim_date AS dd
ON CAST(o.order_purchase_timestamp AS DATE) = dd.full_date
LEFT JOIN item_agg AS ia
ON o.order_id = ia.order_id
LEFT JOIN payment_agg AS pa
ON o.order_id = pa.order_id
LEFT JOIN review_agg AS ra
ON o.order_id = ra.order_id
GO

-------------------------------------------------------------------------
-- 최종 insert
WITH payment_agg AS (
    SELECT
        order_id,
        SUM(payment_value) AS total_payment_amount,
        COUNT(*) AS payment_count,
        AVG(payment_installments * 1.0) AS avg_installments
    FROM silver.olist_order_payments
    GROUP BY order_id
)
, item_agg AS (
    SELECT
        order_id,
        COUNT(*) AS total_items,
        SUM(price) AS total_item_amount,
        SUM(freight_value) AS total_freight_amount
        -- SUM(total_item_value) AS total_order_value
    FROM silver.olist_order_items
    GROUP BY order_id
)
, review_agg AS (
    SELECT
        order_id,
        AVG(CAST(review_score AS FLOAT)) AS avg_review_score
    FROM silver.olist_order_reviews
    GROUP BY order_id
)

INSERT INTO gold.fact_orders(
    order_sk,
    order_id,
    customer_sk,
    purchase_date_sk,
    order_status,
    total_items,
    total_item_amount,
    total_freight_amount,
    total_payment_amount,
    avg_review_score,
    is_delivered,
    delivery_days,
    estimated_delivery_days,
    is_delayed,
    delivery_delay_days,
    approval_days
)

SELECT
    ROW_NUMBER() OVER (ORDER BY o.order_id) AS order_sk,
    o.order_id,
    dc.customer_sk,
    dd.date_sk AS purchase_date_sk,
    o.order_status,
    COALESCE(ia.total_items,0) AS total_items,
    COALESCE(ia.total_item_amount, 0) AS total_item_amount,
    COALESCE(ia.total_freight_amount, 0) AS total_freight_amount,
    COALESCE(pa.total_payment_amount,0) AS total_payment_amount,
    COALESCE(ra.avg_review_score,0) AS avg_review_score,
    o.is_delivered,
    o.delivery_days,
    DATEDIFF(DAY, o.order_purchase_timestamp, o.order_estimated_delivery_date) AS estimated_delivery_days,
    CASE
        WHEN o.order_delivered_customer_date IS NULL    THEN 0
        WHEN o.order_delivered_customer_date > o.order_estimated_delivery_date  THEN 1
        ELSE 0
    END AS is_delayed,
    o.delivery_delay_days,
    o.approval_time
FROM silver.olist_orders AS o INNER JOIN silver.olist_customers AS c
ON o.customer_id = c.customer_id
INNER JOIN gold.dim_customer AS dc
ON c.customer_unique_id = dc.customer_unique_id
INNER JOIN gold.dim_date AS dd
ON CAST(o.order_purchase_timestamp AS DATE) = dd.full_date
LEFT JOIN item_agg AS ia
ON o.order_id = ia.order_id
LEFT JOIN payment_agg AS pa
ON o.order_id = pa.order_id
LEFT JOIN review_agg AS ra
ON o.order_id = ra.order_id

-----------------------------------------------------------------------
SELECT
    *
FROM gold.fact_orders

------------------------------------------------------------------------





-- dim products
IF OBJECT_ID('gold.dim_product', 'U') IS NOT NULL
    DROP TABLE gold.dim_product;

CREATE TABLE gold.dim_product (
    product_sk INT,
    product_id VARCHAR(50),
    product_category_name VARCHAR(100),
    product_category_english VARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    product_volume_cm3 INT,
    product_density FLOAT,
    product_size_category VARCHAR(20),
    dwh_create_date DATETIME DEFAULT GETDATE()
);

----------------------------------------------------------
SELECT
    ROW_NUMBER() OVER (ORDER BY p.product_id) AS product_sk,
    p.product_id,
    p.product_category_name,
    t.product_category_name_english AS product_category_english,
    p.product_name_length AS product_name_length,
    p.product_description_length AS product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_volumne,
    p.product_density,
    p.product_size_cateogry
FROM silver.olist_products AS p LEFT JOIN silver.product_category_name_translation AS t
ON p.product_category_name = t.product_category_name;
------------------------------------------------------------------------------------
-- insert

INSERT INTO gold.dim_product(
    product_sk,
    product_id,
    product_category_name,
    product_category_english,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_volume_cm3,
    product_density,
    product_size_category
)

SELECT
    ROW_NUMBER() OVER (ORDER BY p.product_id) AS product_sk,
    p.product_id,
    p.product_category_name,
    t.product_category_name_english AS product_category_english,
    p.product_name_length AS product_name_length,
    p.product_description_length AS product_description_length,
    p.product_photos_qty,
    p.product_weight_g,
    p.product_length_cm,
    p.product_height_cm,
    p.product_width_cm,
    p.product_volumne,
    p.product_density,
    p.product_size_cateogry
FROM silver.olist_products AS p LEFT JOIN silver.product_category_name_translation AS t
ON p.product_category_name = t.product_category_name
------------------------------------------------------------------------------------
SELECT
    *
FROM gold.dim_product
------------------------------------------------------------------------------------





-- dim_seller
IF OBJECT_ID('gold.dim_seller', 'U') IS NOT NULL
    DROP TABLE gold.dim_seller

CREATE TABLE gold.dim_seller (
    seller_sk INT,
    seller_id VARCHAR(50),
    seller_zip_code_prefix INT,
    seller_city VARCHAR(100),
    seller_state VARCHAR(10),
    first_sale_date DATE,
    last_sale_date DATE,
    total_orders INT,
    total_items_sold INT,
    total_sales_amount DECIMAL(18,2),
    avg_item_price DECIMAL(18,2),
    is_top_seller INT,
    dwh_create_date DATETIME DEFAULT GETDATE()
);

---------------------------------------------------------------------------


WITH seller_metrics AS (
    SELECT
        s.seller_id,
        s.seller_zip_code_prefix,
        s.seller_city,
        s.seller_state,
        MIN(o.order_purchase_timestamp) AS first_sale_date,
        MAX(o.order_purchase_timestamp) AS last_sale_date,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(*) AS total_items_sold,
        SUM(oi.price) AS total_sales_amount,
        AVG(oi.price) AS avg_item_price
    FROM silver.olist_sellers AS s LEFT JOIN silver.olist_order_items AS oi
    ON s.seller_id = oi.seller_id
    LEFT JOIN silver.olist_orders AS o
    ON oi.order_id = o.order_id
    GROUP BY s.seller_id, s.seller_zip_code_prefix, s.seller_city, s.seller_state
)

SELECT
    ROW_NUMBER() OVER (ORDER BY seller_id) AS seller_sk,
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    first_sale_date,
    last_sale_date,
    total_orders,
    total_items_sold,
    COALESCE(total_sales_amount, 0) AS total_sales_amount,
    COALESCE(avg_item_price, 0) AS avg_item_price,
    CASE
        WHEN total_sales_amount >= 100000
            THEN 1
        ELSE 0
    END AS is_top_seller
FROM seller_metrics;

--------------------------------------------------------------------------------
-- insert
WITH seller_metrics AS (
    SELECT
        s.seller_id,
        s.seller_zip_code_prefix,
        s.seller_city,
        s.seller_state,
        MIN(o.order_purchase_timestamp) AS first_sale_date,
        MAX(o.order_purchase_timestamp) AS last_sale_date,
        COUNT(DISTINCT oi.order_id) AS total_orders,
        COUNT(*) AS total_items_sold,
        SUM(oi.price) AS total_sales_amount,
        AVG(oi.price) AS avg_item_price
    FROM silver.olist_sellers AS s LEFT JOIN silver.olist_order_items AS oi
    ON s.seller_id = oi.seller_id
    LEFT JOIN silver.olist_orders AS o
    ON oi.order_id = o.order_id
    GROUP BY s.seller_id, s.seller_zip_code_prefix, s.seller_city, s.seller_state
)

INSERT INTO gold.dim_seller(
    seller_sk,
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    first_sale_date,
    last_sale_date,
    total_orders,
    total_items_sold,
    total_sales_amount,
    avg_item_price,
    is_top_seller
)

SELECT
    ROW_NUMBER() OVER (ORDER BY seller_id) AS seller_sk,
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    first_sale_date,
    last_sale_date,
    total_orders,
    total_items_sold,
    COALESCE(total_sales_amount, 0) AS total_sales_amount,
    COALESCE(avg_item_price, 0) AS avg_item_price,
    CASE
        WHEN total_sales_amount >= 100000
            THEN 1
        ELSE 0
    END AS is_top_seller
FROM seller_metrics
-------------------------------------------------------------------
SELECT
    *
FROM gold.dim_seller
-------------------------------------------------------------------






-- fact_order_items
IF OBJECT_ID('gold.fact_order_items', 'U') IS NOT NULL
    DROP TABLE gold.fact_order_items;

CREATE TABLE gold.fact_order_items (
    order_item_sk INT,
    order_id VARCHAR(50),
    order_item_id INT,
    order_sk INT,
    customer_sk INT,
    product_sk INT,
    seller_sk INT,
    purchase_date_sk INT,
    shipping_limit_date_sk INT,
    item_price DECIMAL(18,2),
    freight_value DECIMAL(18,2),
    total_item_value DECIMAL(18,2),
    is_freight_free INT,
    high_value_item_flag INT,
    dwh_create_date DATETIME DEFAULT GETDATE()
);

----------------------------------------------------------------------

SELECT
    ROW_NUMBER() OVER (ORDER BY oi.order_id, oi.order_item_id) AS order_item_sk,
    oi.order_id,
    oi.order_item_id,
    fo.order_sk,
    dc.customer_sk,
    dp.product_sk,
    ds.seller_sk,
    dd_purchase.date_sk AS purchase_date_sk,
    dd_shipping.date_sk AS shipping_limit_date_sk,
    oi.price AS item_price,
    oi.freight_value,
    oi.price + oi.freight_value AS total_item_value,
    CASE
        WHEN oi.freight_value = 0 THEN 1
        ELSE 0
    END AS is_freight_free,
    CASE
        WHEN oi.price >= 500 THEN 1
        ELSE 0
    END AS high_value_item_flag
FROM silver.olist_order_items AS oi INNER JOIN silver.olist_orders AS o
ON oi.order_id = o.order_id
INNER JOIN silver.olist_customers AS c
ON o.customer_id = c.customer_id
INNER JOIN gold.dim_customer AS dc
ON c.customer_unique_id = dc.customer_unique_id
INNER JOIN gold.dim_product AS dp
ON oi.product_id = dp.product_id
INNER JOIN gold.dim_seller AS ds
ON oi.seller_id = ds.seller_id
INNER JOIN gold.fact_orders AS fo
ON oi.order_id = fo.order_id
INNER JOIN gold.dim_date AS dd_purchase
ON CAST(o.order_purchase_timestamp AS DATE) = dd_purchase.full_date
INNER JOIN gold.dim_date AS dd_shipping
ON CAST(oi.shipping_limit_date AS DATE) = dd_shipping.full_date;

---------------------------------------------------------------------

INSERT INTO gold.fact_order_items(
    order_item_sk,
    order_id,
    order_item_id,
    order_sk,
    customer_sk,
    product_sk,
    seller_sk,
    purchase_date_sk,
    shipping_limit_date_sk,
    item_price,
    freight_value,
    total_item_value,
    is_freight_free,
    high_value_item_flag
)

SELECT
    ROW_NUMBER() OVER (ORDER BY oi.order_id, oi.order_item_id) AS order_item_sk,
    oi.order_id,
    oi.order_item_id,
    fo.order_sk,
    dc.customer_sk,
    dp.product_sk,
    ds.seller_sk,
    dd_purchase.date_sk AS purchase_date_sk,
    dd_shipping.date_sk AS shipping_limit_date_sk,
    oi.price AS item_price,
    oi.freight_value,
    oi.price + oi.freight_value AS total_item_value,
    CASE
        WHEN oi.freight_value = 0 THEN 1
        ELSE 0
    END AS is_freight_free,
    CASE
        WHEN oi.price >= 500 THEN 1
        ELSE 0
    END AS high_value_item_flag
FROM silver.olist_order_items AS oi INNER JOIN silver.olist_orders AS o
ON oi.order_id = o.order_id
INNER JOIN silver.olist_customers AS c
ON o.customer_id = c.customer_id
INNER JOIN gold.dim_customer AS dc
ON c.customer_unique_id = dc.customer_unique_id
INNER JOIN gold.dim_product AS dp
ON oi.product_id = dp.product_id
INNER JOIN gold.dim_seller AS ds
ON oi.seller_id = ds.seller_id
INNER JOIN gold.fact_orders AS fo
ON oi.order_id = fo.order_id
INNER JOIN gold.dim_date AS dd_purchase
ON CAST(o.order_purchase_timestamp AS DATE) = dd_purchase.full_date
INNER JOIN gold.dim_date AS dd_shipping
ON CAST(oi.shipping_limit_date AS DATE) = dd_shipping.full_date;

---------------------------------------------------------------------------
SELECT
    *
FROM gold.fact_order_items

SELECT COUNT(*)
FROM gold.fact_order_items

-- 상품매출 top 10
SELECT TOP 10
    dp.product_category_english,
    SUM(foi.total_item_value) AS revenue
FROM gold.fact_order_items AS foi INNER JOIN gold.dim_product AS dp
ON foi.product_sk = dp.product_sk
GROUP BY dp.product_category_english
ORDER BY revenue DESC

-- seller 매출 top 10
SELECT TOP 10
    ds.seller_id,
    SUM(foi.total_item_value) AS revenue
FROM gold.fact_order_items AS foi INNER JOIN gold.dim_seller AS ds
ON foi.seller_sk = ds.seller_sk
GROUP BY ds.seller_id
ORDER BY revenue DESC

---------------------------------------------------------------------------------

-- customer_rfm
-- RFM -> R(Recency) : 최근구매, F(Frequency) : 구매빈도, M(Monetary) : 구매금액 
-- 좋은 고객 : 최근 구매하고 자주 구매하고 많이 구매한 고객 
-- CRM, 마케팅, 재구매 분석, VIP관리 등에 사용
-- Recency(오늘기준 마지막 구매일 후 몇일?) : 오늘 - 가장 최근 구매일 
-- Frequency(총 구매수)
-- Monetary(총 구매금액)

IF OBJECT_ID('gold.customer_rfm', 'U') IS NOT NULL
    DROP TABLE gold.customer_rfm;

CREATE TABLE gold.customer_rfm (
    customer_sk INT,
    recency_days INT,
    frequency_orders INT,
    monetary_value DECIMAL(18,2),
    r_score INT,
    f_score INT,
    m_score INT,
    rfm_score VARCHAR(10),
    rfm_segment VARCHAR(50),
    dwh_create_date DATETIME DEFAULT GETDATE()
);

---------------------------------------------------------
WITH customer_metrics AS (
    SELECT
        customer_sk,
        MAX(purchase_date_sk)AS last_purchase_date_sk,
        COUNT(DISTINCT order_id) AS frequency_orders,
        SUM(total_payment_amount) AS monetary_value
    FROM gold.fact_orders
    GROUP BY customer_sk
),
rfm_base AS (
    SELECT
        cm.customer_sk,
        DATEDIFF(DAY, dd.full_date, GETDATE()) AS recency_days,
        cm.frequency_orders,
        cm.monetary_value
    FROM customer_metrics AS cm INNER JOIN gold.dim_date AS dd
    ON cm.last_purchase_date_sk = dd.date_sk
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_orders ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM rfm_base
)

SELECT
    customer_sk,
    recency_days,
    frequency_orders,
    monetary_value,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'CHAMPIONS'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'LOYAL_CUSTOMERS'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'NEW_CUSTOMERS'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'AT_RISK'
        WHEN r_score = 1 AND f_score = 1 AND m_score = 1 THEN 'LOST_CUSTOMERS'
        ELSE 'REGULAR'
    END AS rfm_segment
FROM rfm_scores;
----------------------------------------------------------------------------------------
-- insert
WITH customer_metrics AS (
    SELECT
        customer_sk,
        MAX(purchase_date_sk)AS last_purchase_date_sk,
        COUNT(DISTINCT order_id) AS frequency_orders,
        SUM(total_payment_amount) AS monetary_value
    FROM gold.fact_orders
    GROUP BY customer_sk
),
rfm_base AS (
    SELECT
        cm.customer_sk,
        DATEDIFF(DAY, dd.full_date, GETDATE()) AS recency_days,
        cm.frequency_orders,
        cm.monetary_value
    FROM customer_metrics AS cm INNER JOIN gold.dim_date AS dd
    ON cm.last_purchase_date_sk = dd.date_sk
),
rfm_scores AS (
    SELECT
        *,
        NTILE(5) OVER (ORDER BY recency_days ASC) AS r_score,
        NTILE(5) OVER (ORDER BY frequency_orders ASC) AS f_score,
        NTILE(5) OVER (ORDER BY monetary_value ASC) AS m_score
    FROM rfm_base
)

INSERT INTO gold.customer_rfm(
    customer_sk,
    recency_days,
    frequency_orders,
    monetary_value,
    r_score,
    f_score,
    m_score,
    rfm_score,
    rfm_segment 
)

SELECT
    customer_sk,
    recency_days,
    frequency_orders,
    monetary_value,
    r_score,
    f_score,
    m_score,
    CONCAT(r_score, f_score, m_score) AS rfm_score,
    CASE
        WHEN r_score >= 4 AND f_score >= 4 AND m_score >= 4 THEN 'CHAMPIONS'
        WHEN r_score >= 3 AND f_score >= 3 AND m_score >= 3 THEN 'LOYAL_CUSTOMERS'
        WHEN r_score >= 4 AND f_score <= 2 THEN 'NEW_CUSTOMERS'
        WHEN r_score <= 2 AND f_score >= 3 THEN 'AT_RISK'
        WHEN r_score = 1 AND f_score = 1 AND m_score = 1 THEN 'LOST_CUSTOMERS'
        ELSE 'REGULAR'
    END AS rfm_segment
FROM rfm_scores;
----------------------------------------------------------------------------------------
SELECT
    *
FROM gold.customer_rfm

-- segment 분포
SELECT
    rfm_segment,
    COUNT(*) AS cnt
FROM gold.customer_rfm
GROUP BY rfm_segment
ORDER BY cnt DESC;

-- VIP 고객
SELECT TOP 20 
    *
FROM gold.customer_rfm
WHERE rfm_segment = 'CHAMPIONS'
ORDER BY monetary_value DESC;

-- 평균 RFM
SELECT
    AVG(recency_days),
    AVG(frequency_orders),
    AVG(monetary_value)
FROM gold.customer_rfm;

---------------------------------------------------------------------------------













-- cohort retention : 고객 유지율
-- 첫 구매한 고객이 그 이후에도 다시 구매하는가?
-- cohort : 같은 시점에 유입된 고객 그룹
-- retention : 고객이 한달 후에 주문 ..%, 2달 후의 주문 ..%, ......
-- 이커머스 핵심 kpi : 재구매율 = 비지니스 건강성



IF OBJECT_ID('gold.cohort_retention', 'U') IS NOT NULL
    DROP TABLE gold.cohort_retention;

CREATE TABLE gold.cohort_retention (
    cohort_month DATE,
    retention_month INT,
    retained_customers INT,
    cohort_size INT,
    retention_rate DECIMAL(10,2),
    dwh_create_date DATETIME DEFAULT GETDATE()
);




-------------------------------------------------------------------------------
WITH customer_first_purchase AS (
    SELECT
        customer_sk,
        MIN(dd.full_date) AS first_purchase_date
    FROM gold.fact_orders AS fo INNER JOIN gold.dim_date AS dd
    ON fo.purchase_date_sk = dd.date_sk
    GROUP BY customer_sk
)
,customer_orders AS (
    SELECT
        fo.customer_sk,
        DATEFROMPARTS(YEAR(cfp.first_purchase_date), MONTH(cfp.first_purchase_date), 1) AS cohort_month,
        DATEFROMPARTS(YEAR(dd.full_date), MONTH(dd.full_date), 1) AS order_month
    FROM gold.fact_orders AS fo INNER JOIN gold.dim_date AS dd
    ON fo.purchase_date_sk = dd.date_sk
    INNER JOIN customer_first_purchase AS cfp
    ON fo.customer_sk = cfp.customer_sk
)
,retention_base AS (
    SELECT
        customer_sk,
        cohort_month,
        order_month,
        DATEDIFF(MONTH, cohort_month, order_month) AS retention_month
    FROM customer_orders
)
,retention_counts AS (
    SELECT
        cohort_month,
        retention_month,
        COUNT(DISTINCT customer_sk) AS retained_customers

    FROM retention_base
    GROUP BY cohort_month, retention_month
)
, 
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_sk) AS cohort_size
    FROM retention_base
    WHERE retention_month = 0
    GROUP BY cohort_month
)

SELECT
    rc.cohort_month,
    rc.retention_month,
    rc.retained_customers,
    cs.cohort_size,
    CAST((rc.retained_customers * 100.0) / COALESCE(cs.cohort_size, 0) AS DECIMAL(10,2)) AS retention_rate
FROM retention_counts AS rc INNER JOIN cohort_size AS cs
ON rc.cohort_month = cs.cohort_month;


------------------------------------------------------------------------
-- insert
WITH customer_first_purchase AS (
    SELECT
        customer_sk,
        MIN(dd.full_date) AS first_purchase_date -- 고객이 처음 주문한 날짜
    FROM gold.fact_orders AS fo INNER JOIN gold.dim_date AS dd
    ON fo.purchase_date_sk = dd.date_sk
    GROUP BY customer_sk
)
,customer_orders AS (
    SELECT
        fo.customer_sk,
        DATEFROMPARTS(YEAR(cfp.first_purchase_date), MONTH(cfp.first_purchase_date), 1) AS cohort_month, -- 고객의 첫 주문 날짜
        DATEFROMPARTS(YEAR(dd.full_date), MONTH(dd.full_date), 1) AS order_month -- 고객의 모든 주문 날짜
    FROM gold.fact_orders AS fo INNER JOIN gold.dim_date AS dd
    ON fo.purchase_date_sk = dd.date_sk
    INNER JOIN customer_first_purchase AS cfp
    ON fo.customer_sk = cfp.customer_sk
)
,retention_base AS (
    SELECT
        customer_sk,
        cohort_month,
        order_month,
        DATEDIFF(MONTH, cohort_month, order_month) AS retention_month
    FROM customer_orders
)
,retention_counts AS (
    SELECT
        cohort_month,
        retention_month,
        COUNT(DISTINCT customer_sk) AS retained_customers
    FROM retention_base
    GROUP BY cohort_month, retention_month
)
, 
cohort_size AS (
    SELECT
        cohort_month,
        COUNT(DISTINCT customer_sk) AS cohort_size
    FROM retention_base
    WHERE retention_month = 0
    GROUP BY cohort_month
)

INSERT INTO gold.cohort_retention(
    cohort_month,
    retention_month,
    retained_customers,
    cohort_size,
    retention_rate
)

SELECT
    rc.cohort_month,
    rc.retention_month,
    rc.retained_customers,
    cs.cohort_size,
    CAST((rc.retained_customers * 100.0) / COALESCE(cs.cohort_size, 0) AS DECIMAL(10,2)) AS retention_rate
FROM retention_counts AS rc INNER JOIN cohort_size AS cs
ON rc.cohort_month = cs.cohort_month;
------------------------------------------------------------------------------------
SELECT
    *
FROM gold.cohort_retention
/*
cohort_month	retention_month	    retained_customers	    cohort_size 	retention_rate(retained_customers / cohort_size)
2017-05-01	           1	              18	                3582	        0.50

-> 해석 : 2017년 5월 처음 구매한 고객 3582명 중 1개월(retention_month) 뒤 다시 구매한 고객은 18명(retained_customers)이고 한달 뒤 재구매율 0.5%(retention_rate)
-- Olist 고객은 첫 구매 이후 재구매율이 매우 낮았다.
   대부분의 cohort에서 1개월 retention이 1% 미만으로 나타났으며,
   이는 고객 충성도보다 단발성 구매 중심의 marketplace 특성을 보여준다
*/

-- cohort_size 확인
SELECT 
    *
FROM gold.cohort_retention
WHERE retention_month = 0;

-- retention 감소 확인
SELECT 
    *
FROM gold.cohort_retention
ORDER BY cohort_month ASC, retention_month ASC;
---------------------------------------------------------------------------------------------










-- seller_performance_mart
IF OBJECT_ID('gold.seller_performance_mart', 'U') IS NOT NULL
    DROP TABLE gold.seller_performance_mart

CREATE TABLE gold.seller_performance_mart (
    seller_sk INT,
    total_orders INT,
    total_items_sold INT,
    total_revenue DECIMAL(18,2),
    avg_order_value DECIMAL(18,2),
    avg_item_price DECIMAL(18,2),
    avg_review_score FLOAT,
    avg_delivery_days FLOAT,
    delay_rate DECIMAL(10,2),
    repeat_customer_rate DECIMAL(10,2),
    seller_segment VARCHAR(50),
    dwh_create_date DATETIME DEFAULT GETDATE()
);

---------------------------------------------------------------------------------------

WITH seller_base AS (
    SELECT
        foi.seller_sk,
        fo.order_id,
        fo.customer_sk,
        foi.order_item_sk,
        foi.item_price,
        foi.total_item_value,
        fo.avg_review_score,
        fo.delivery_days,
        fo.is_delayed,
        dc.is_repeat_customer
    FROM gold.fact_order_items AS foi INNER JOIN gold.fact_orders AS fo
    ON foi.order_sk = fo.order_sk
    INNER JOIN gold.dim_customer AS dc
    ON fo.customer_sk = dc.customer_sk
)
, seller_metrics AS (
    SELECT
        seller_sk,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(order_item_sk) AS total_items_sold,
        ROUND(SUM(total_item_value), 2) AS total_revenue,
        ROUND(AVG(total_item_value), 2) AS avg_order_value,
        ROUND(AVG(item_price), 2) AS avg_item_price,
        ROUND(AVG(avg_review_score), 2) AS avg_review_score,
        ROUND(AVG(CAST(delivery_days AS FLOAT)), 2) AS avg_delivery_days,
        ROUND(AVG(CAST(is_delayed AS FLOAT)) * 100, 2) AS delay_rate,
        ROUND(AVG(CAST(is_repeat_customer AS FLOAT)) * 100, 2) AS repeat_customer_rate
    FROM seller_base
    GROUP BY seller_sk
)

SELECT
    seller_sk,
    total_orders,
    total_items_sold,
    total_revenue,
    CAST(avg_order_value AS DECIMAL(10, 2)) AS avg_order_value,
    CAST(avg_item_price AS DECIMAL(10, 2)) AS avg_item_price,
    avg_review_score,
    avg_delivery_days,
    CAST(delay_rate AS DECIMAL(10,2)) AS delay_rate,
    CAST(repeat_customer_rate AS DECIMAL(10,2)) AS repeat_customer_rate,
    CASE
        WHEN total_revenue >= 100000 AND avg_review_score >= 4 AND delay_rate <= 10 THEN 'TOP_SELLER'
        WHEN total_revenue >= 50000     THEN 'HIGH_PERFORMER'
        WHEN avg_review_score < 3   THEN 'LOW_REVIEW'
        WHEN delay_rate >= 30   THEN 'DELAY_RISK'
        ELSE 'REGULAR'
    END AS seller_segment
FROM seller_metrics;
-----------------------------------------------------------------------------------------------------
-- insert
WITH seller_base AS (
    SELECT
        foi.seller_sk,
        fo.order_id,
        fo.customer_sk,
        foi.order_item_sk,
        foi.item_price,
        foi.total_item_value,
        fo.avg_review_score,
        fo.delivery_days,
        fo.is_delayed,
        dc.is_repeat_customer
    FROM gold.fact_order_items AS foi INNER JOIN gold.fact_orders AS fo
    ON foi.order_sk = fo.order_sk
    INNER JOIN gold.dim_customer AS dc
    ON fo.customer_sk = dc.customer_sk
)
, seller_metrics AS (
    SELECT
        seller_sk,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(order_item_sk) AS total_items_sold,
        ROUND(SUM(total_item_value), 2) AS total_revenue,
        ROUND(AVG(total_item_value), 2) AS avg_order_value,
        ROUND(AVG(item_price), 2) AS avg_item_price,
        ROUND(AVG(avg_review_score), 2) AS avg_review_score,
        ROUND(AVG(CAST(delivery_days AS FLOAT)), 2) AS avg_delivery_days,
        ROUND(AVG(CAST(is_delayed AS FLOAT)) * 100, 2) AS delay_rate,
        ROUND(AVG(CAST(is_repeat_customer AS FLOAT)) * 100, 2) AS repeat_customer_rate
    FROM seller_base
    GROUP BY seller_sk
)

INSERT INTO gold.seller_performance_mart(
    seller_sk,
    total_orders,
    total_items_sold,
    total_revenue,
    avg_order_value,
    avg_item_price,
    avg_review_score,
    avg_delivery_days,
    delay_rate,
    repeat_customer_rate,
    seller_segment
)

SELECT
    seller_sk,
    total_orders,
    total_items_sold,
    total_revenue,
    CAST(avg_order_value AS DECIMAL(10, 2)) AS avg_order_value,
    CAST(avg_item_price AS DECIMAL(10, 2)) AS avg_item_price,
    avg_review_score,
    avg_delivery_days,
    CAST(delay_rate AS DECIMAL(10,2)) AS delay_rate,
    CAST(repeat_customer_rate AS DECIMAL(10,2)) AS repeat_customer_rate,
    CASE
        WHEN total_revenue >= 100000 AND avg_review_score >= 4 AND delay_rate <= 10 THEN 'TOP_SELLER'
        WHEN total_revenue >= 50000     THEN 'HIGH_PERFORMER'
        WHEN avg_review_score < 3   THEN 'LOW_REVIEW'
        WHEN delay_rate >= 30   THEN 'DELAY_RISK'
        ELSE 'REGULAR'
    END AS seller_segment
FROM seller_metrics;
--------------------------------------------------------------------------------------
SELECT
    *
FROM gold.seller_performance_mart

-- seller segment 분포
SELECT
    seller_segment,
    COUNT(*) AS cnt
FROM gold.seller_performance_mart
GROUP BY seller_segment;

-- top seller 확인
SELECT TOP 20 *
FROM gold.seller_performance_mart
ORDER BY total_revenue DESC;

-- delay 높은 seller
SELECT TOP 20 *
FROM gold.seller_performance_mart
ORDER BY delay_rate DESC;

-- review 낮은 seller
SELECT TOP 20 *
FROM gold.seller_performance_mart
ORDER BY avg_review_score ASC;

---------------------------------------------------------------------------------------









-- product_sales_mart

IF OBJECT_ID('gold.product_sales_mart', 'U') IS NOT NULL
    DROP TABLE gold.product_sales_mart;

CREATE TABLE gold.product_sales_mart (
    product_sk INT,
    product_category_name VARCHAR(255),
    total_orders INT,
    total_quantity_sold INT,
    total_revenue DECIMAL(18,2),
    avg_selling_price DECIMAL(18,2),
    avg_freight_value DECIMAL(18,2),
    freight_ratio DECIMAL(10,2),
    avg_review_score FLOAT,
    avg_delivery_days FLOAT,
    delay_rate DECIMAL(10,2),
    product_segment VARCHAR(50),
    dwh_create_date DATETIME DEFAULT GETDATE()
);
-----------------------------------------------------------------------------
WITH product_base AS (
   SELECT
        foi.product_sk,
        dp.product_category_name,
        fo.order_id,
        foi.order_item_sk,
        foi.item_price,
        foi.freight_value,
        foi.total_item_value,
        fo.avg_review_score,
        fo.delivery_days,
        fo.is_delayed
    FROM gold.fact_order_items AS foi INNER JOIN gold.fact_orders AS fo
    ON foi.order_sk = fo.order_sk
    INNER JOIN gold.dim_product AS dp 
    ON foi.product_sk = dp.product_sk
),

product_metrics AS (
    SELECT
        product_sk,
        MAX(product_category_name) AS product_category_name,   
        COUNT(DISTINCT order_id) AS total_orders,
        1 AS total_quantity_sold,
        SUM(total_item_value) AS total_revenue,
        AVG(item_price) AS avg_selling_price,
        AVG(freight_value) AS avg_freight_value,
        (SUM(freight_value) * 100.0) / COALESCE(SUM(item_price),0) AS freight_ratio,
        AVG(avg_review_score) AS avg_review_score,
        AVG(CAST(delivery_days AS FLOAT)) AS avg_delivery_days,
        AVG(CAST(is_delayed AS FLOAT)) * 100 AS delay_rate
    FROM product_base
    GROUP BY product_sk
)

SELECT
    product_sk,
    product_category_name,
    total_orders,
    total_quantity_sold,
    total_revenue,
    CAST(avg_selling_price AS DECIMAL(10,2)) AS avg_selling_price,
    CAST(avg_freight_value AS DECIMAL(10,2)) AS avg_freight_value,
    CAST(freight_ratio AS DECIMAL(10,2)) AS freight_ratio,
    CAST(avg_review_score AS DECIMAL(10,2)) AS avg_review_scre,
    CAST(avg_delivery_days AS DECIMAL(10,2)) AS avg_delivery_days,
    CAST(delay_rate AS DECIMAL(10,2)) AS delay_rate,
    CASE
        WHEN total_revenue >= 100000 AND avg_review_score >= 4 THEN 'BEST_SELLER'
        WHEN total_revenue >= 50000 THEN 'HIGH_REVENUE'
        WHEN avg_review_score < 3 THEN 'LOW_REVIEW'
        WHEN delay_rate >= 30 THEN 'DELIVERY_RISK'
        ELSE 'REGULAR'
    END AS product_segment
FROM product_metrics;

---------------------------------------------------------------------------------------
-- insert
WITH product_base AS (
   SELECT
        foi.product_sk,
        dp.product_category_name,
        fo.order_id,
        foi.order_item_sk,
        foi.item_price,
        foi.freight_value,
        foi.total_item_value,
        fo.avg_review_score,
        fo.delivery_days,
        fo.is_delayed
    FROM gold.fact_order_items AS foi INNER JOIN gold.fact_orders AS fo
    ON foi.order_sk = fo.order_sk
    INNER JOIN gold.dim_product AS dp 
    ON foi.product_sk = dp.product_sk
),

product_metrics AS (
    SELECT
        product_sk,
        MAX(product_category_name) AS product_category_name,   
        COUNT(DISTINCT order_id) AS total_orders,
        1 AS total_quantity_sold,
        SUM(total_item_value) AS total_revenue,
        AVG(item_price) AS avg_selling_price,
        AVG(freight_value) AS avg_freight_value,
        (SUM(freight_value) * 100.0) / COALESCE(SUM(item_price),0) AS freight_ratio,
        AVG(avg_review_score) AS avg_review_score,
        AVG(CAST(delivery_days AS FLOAT)) AS avg_delivery_days,
        AVG(CAST(is_delayed AS FLOAT)) * 100 AS delay_rate
    FROM product_base
    GROUP BY product_sk
)

INSERT INTO gold.product_sales_mart(
    product_sk,
    product_category_name,
    total_orders,
    total_quantity_sold,
    total_revenue,
    avg_selling_price,
    avg_freight_value,
    freight_ratio,
    avg_review_score,
    avg_delivery_days,
    delay_rate,
    product_segment
)

SELECT
    product_sk,
    product_category_name,
    total_orders,
    total_quantity_sold,
    total_revenue,
    CAST(avg_selling_price AS DECIMAL(10,2)) AS avg_selling_price,
    CAST(avg_freight_value AS DECIMAL(10,2)) AS avg_freight_value,
    CAST(freight_ratio AS DECIMAL(10,2)) AS freight_ratio,
    CAST(avg_review_score AS DECIMAL(10,2)) AS avg_review_scre,
    CAST(avg_delivery_days AS DECIMAL(10,2)) AS avg_delivery_days,
    CAST(delay_rate AS DECIMAL(10,2)) AS delay_rate,
    CASE
        WHEN total_revenue >= 100000 AND avg_review_score >= 4 THEN 'BEST_SELLER'
        WHEN total_revenue >= 50000 THEN 'HIGH_REVENUE'
        WHEN avg_review_score < 3 THEN 'LOW_REVIEW'
        WHEN delay_rate >= 30 THEN 'DELIVERY_RISK'
        ELSE 'REGULAR'
    END AS product_segment
FROM product_metrics;

------------------------------------------------------------------------------------------
SELECT
    *
FROM gold.product_sales_mart

-- 매출 top 상품
SELECT TOP 20 *
FROM gold.product_sales_mart
ORDER BY total_revenue DESC;

-- 구매개수 top 상품
SELECT TOP 20 
    product_category_name,
    SUM(total_quantity_sold) AS total_quantity_sold
FROM gold.product_sales_mart
GROUP BY product_category_name
ORDER BY total_quantity_sold DESC;


-- 리뷰 낮은 상품
SELECT TOP 20 *
FROM gold.product_sales_mart
ORDER BY avg_review_score ASC;

-- 배송 지연 높은 상품
SELECT TOP 20 *
FROM gold.product_sales_mart
ORDER BY delay_rate DESC;

-- 카테고리별 매출
SELECT
    product_category_name,
    SUM(total_revenue) AS total_revenue,
    SUM(total_quantity_sold) AS total_quantity_sol
FROM gold.product_sales_mart
GROUP BY product_category_name
ORDER BY total_revenue DESC
------------------------------------------------------------------------------------














-- delivery_performance_mart
IF OBJECT_ID('gold.delivery_performance_mart', 'U') IS NOT NULL
    DROP TABLE gold.delivery_performance_mart;

CREATE TABLE gold.delivery_performance_mart (
    seller_sk INT,
    total_orders INT,
    delivered_orders INT,
    delayed_orders INT,
    avg_delivery_days FLOAT,
    avg_estimated_gap_days FLOAT,
    delay_rate DECIMAL(10,2),
    avg_freight_value DECIMAL(18,2),
    avg_review_score FLOAT,
    delivery_segment VARCHAR(50),
    dwh_create_date DATETIME DEFAULT GETDATE()
);

--------------------------------------------------------------------
WITH delivery_base AS (
    SELECT
        foi.seller_sk,
        fo.order_id,
        fo.order_status,
        fo.delivery_days,
        fo.is_delayed,
        fo.avg_review_score,
        foi.freight_value,
        DATEDIFF(DAY, fo.estimated_delivery_days, fo.delivery_days) AS estimated_gap_days

    FROM gold.fact_order_items AS foi INNER JOIN gold.fact_orders AS fo
    ON foi.order_sk = fo.order_sk
),

delivery_metrics AS (
    SELECT
        seller_sk,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,
        SUM(CASE WHEN is_delayed = 1 THEN 1 ELSE 0 END) AS delayed_orders,
        AVG(CAST(delivery_days AS FLOAT)) AS avg_delivery_days,
        AVG(CAST(estimated_gap_days AS FLOAT)) AS avg_estimated_gap_days,
        AVG(CAST(is_delayed AS FLOAT)) * 100 AS delay_rate,
        AVG(freight_value) AS avg_freight_value,
        AVG(avg_review_score) AS avg_review_score
    FROM delivery_base
    GROUP BY seller_sk
)

SELECT
    seller_sk,
    total_orders,
    delivered_orders,
    delayed_orders,
    CAST(avg_delivery_days AS DECIMAL(10,2)) AS avg_delivery_days,
    CAST(avg_estimated_gap_days AS DECIMAL(10,2)) AS avg_estimated_gap_days,
    CAST(delay_rate AS DECIMAL(10,2)) AS delay_rate,
    CAST(avg_freight_value AS DECIMAL(10,2)) AS avg_freight_value,
    CAST(avg_review_score AS DECIMAL(10,2)) AS avg_review_score,
    CASE
        WHEN delay_rate <= 5 AND avg_review_score >= 4 THEN 'FAST_RELIABLE'
        WHEN delay_rate <= 10 THEN 'GOOD_DELIVERY'
        WHEN delay_rate >= 30 THEN 'DELIVERY_RISK'
        ELSE 'REGULAR'
    END AS delivery_segment
FROM delivery_metrics;
-----------------------------------------------------------------------------------
-- insert
WITH delivery_base AS (
    SELECT
        foi.seller_sk,
        fo.order_id,
        fo.order_status,
        fo.delivery_days,
        fo.is_delayed,
        fo.avg_review_score,
        foi.freight_value,
        DATEDIFF(DAY, fo.estimated_delivery_days, fo.delivery_days) AS estimated_gap_days

    FROM gold.fact_order_items AS foi INNER JOIN gold.fact_orders AS fo
    ON foi.order_sk = fo.order_sk
),

delivery_metrics AS (
    SELECT
        seller_sk,
        COUNT(DISTINCT order_id) AS total_orders,
        SUM(CASE WHEN order_status = 'delivered' THEN 1 ELSE 0 END) AS delivered_orders,
        SUM(CASE WHEN is_delayed = 1 THEN 1 ELSE 0 END) AS delayed_orders,
        AVG(CAST(delivery_days AS FLOAT)) AS avg_delivery_days,
        AVG(CAST(estimated_gap_days AS FLOAT)) AS avg_estimated_gap_days,
        AVG(CAST(is_delayed AS FLOAT)) * 100 AS delay_rate,
        AVG(freight_value) AS avg_freight_value,
        AVG(avg_review_score) AS avg_review_score
    FROM delivery_base
    GROUP BY seller_sk
)

INSERT INTO gold.delivery_performance_mart(
    seller_sk,
    total_orders,
    delivered_orders,
    delayed_orders,
    avg_delivery_days,
    avg_estimated_gap_days,
    delay_rate,
    avg_freight_value,
    avg_review_score,
    delivery_segment
)

SELECT
    seller_sk,
    total_orders,
    delivered_orders,
    delayed_orders,
    CAST(avg_delivery_days AS DECIMAL(10,2)) AS avg_delivery_days,
    CAST(avg_estimated_gap_days AS DECIMAL(10,2)) AS avg_estimated_gap_days,
    CAST(delay_rate AS DECIMAL(10,2)) AS delay_rate,
    CAST(avg_freight_value AS DECIMAL(10,2)) AS avg_freight_value,
    CAST(avg_review_score AS DECIMAL(10,2)) AS avg_review_score,
    CASE
        WHEN delay_rate <= 5 AND avg_review_score >= 4 THEN 'FAST_RELIABLE'
        WHEN delay_rate <= 10 THEN 'GOOD_DELIVERY'
        WHEN delay_rate >= 30 THEN 'DELIVERY_RISK'
        ELSE 'REGULAR'
    END AS delivery_segment
FROM delivery_metrics;
-------------------------------------------------------------------------------------
SELECT
    *
FROM gold.delivery_performance_mart

-- 배송 우수 seller
SELECT TOP 20 *
FROM gold.delivery_performance_mart
ORDER BY delay_rate ASC;

-- 배송 위험 seller
SELECT TOP 20 *
FROM gold.delivery_performance_mart
ORDER BY delay_rate DESC;

-- 리뷰 vs 배송
SELECT TOP 20
    seller_sk,
    avg_review_score,
    delay_rate
FROM gold.delivery_performance_mart
ORDER BY avg_review_score DESC;














-- executive_kpi_mart
IF OBJECT_ID('gold.executive_kpi_mart', 'U') IS NOT NULL
    DROP TABLE gold.executive_kpi_mart;

CREATE TABLE gold.executive_kpi_mart (
    date_sk INT,
    full_date DATE,
    total_orders INT,
    total_customers INT,
    repeat_customers INT,
    total_gmv DECIMAL(18,2),
    avg_order_value DECIMAL(18,2),
    avg_review_score FLOAT,
    delay_rate DECIMAL(10,2),
    dwh_create_date DATETIME DEFAULT GETDATE()
);
-------------------------------------------------------------------------------------
WITH kpi_base AS (
    SELECT
        fo.purchase_date_sk AS date_sk,
        dd.full_date,
        fo.order_id,
        fo.customer_sk,
        fo.total_payment_amount,
        fo.avg_review_score,
        fo.is_delayed,
        dc.is_repeat_customer
    FROM gold.fact_orders AS fo INNER JOIN gold.dim_date AS dd
    ON fo.purchase_date_sk = dd.date_sk
    INNER JOIN gold.dim_customer AS dc
    ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),

daily_kpi AS (
    SELECT
        date_sk,
        MAX(full_date) AS full_date,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT customer_sk) AS total_customers,
        COUNT(DISTINCT CASE WHEN is_repeat_customer = 1 THEN customer_sk END) AS repeat_customers,
        SUM(total_payment_amount) AS total_gmv,
        AVG(total_payment_amount) AS avg_order_value,
        AVG(avg_review_score) AS avg_review_score,
        AVG(CAST(is_delayed AS FLOAT)) * 100 AS delay_rate
    FROM kpi_base
    GROUP BY date_sk
)

SELECT
    date_sk,
    full_date,
    total_orders,
    total_customers,
    repeat_customers,
    total_gmv,
    avg_order_value,
    avg_review_score,
    CAST(delay_rate AS DECIMAL(10,2))
FROM daily_kpi;
----------------------------------------------------------
-- insert

WITH kpi_base AS (
    SELECT
        fo.purchase_date_sk AS date_sk,
        dd.full_date,
        fo.order_id,
        fo.customer_sk,
        fo.total_payment_amount,
        fo.avg_review_score,
        fo.is_delayed,
        dc.is_repeat_customer
    FROM gold.fact_orders AS fo INNER JOIN gold.dim_date AS dd
    ON fo.purchase_date_sk = dd.date_sk
    INNER JOIN gold.dim_customer AS dc
    ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
),

daily_kpi AS (
    SELECT
        date_sk,
        MAX(full_date) AS full_date,
        COUNT(DISTINCT order_id) AS total_orders,
        COUNT(DISTINCT customer_sk) AS total_customers,
        COUNT(DISTINCT CASE WHEN is_repeat_customer = 1 THEN customer_sk END) AS repeat_customers,
        SUM(total_payment_amount) AS total_gmv,
        AVG(total_payment_amount) AS avg_order_value,
        AVG(avg_review_score) AS avg_review_score,
        AVG(CAST(is_delayed AS FLOAT)) * 100 AS delay_rate
    FROM kpi_base
    GROUP BY date_sk
)

INSERT INTO gold.executive_kpi_mart(
    date_sk,
    full_date,
    total_orders,
    total_customers,
    repeat_customers,
    total_gmv,
    avg_order_value,
    avg_review_score,
    delay_rate
)

SELECT
    date_sk,
    full_date,
    total_orders,
    total_customers,
    repeat_customers,
    total_gmv,
    avg_order_value,
    avg_review_score,
    CAST(delay_rate AS DECIMAL(10,2))
FROM daily_kpi;

------------------------------------------------------------------
SELECT
    *
FROM gold.executive_kpi_mart

-- 일별 GMV
SELECT TOP 30
    full_date,
    total_gmv
FROM gold.executive_kpi_mart
ORDER BY full_date;

-- 주문량 높은날
SELECT TOP 20 
    *
FROM gold.executive_kpi_mart
ORDER BY total_orders DESC;

-- 배송지연 높은날
SELECT TOP 20 
    *
FROM gold.executive_kpi_mart
ORDER BY delay_rate DESC;
















--monthly_business_summary
IF OBJECT_ID('gold.monthly_business_summary', 'U') IS NOT NULL
    DROP TABLE gold.monthly_business_summary;

CREATE TABLE gold.monthly_business_summary (
    year_month CHAR(7),
    total_orders INT,
    total_customers INT,
    repeat_customers INT,
    total_gmv DECIMAL(18,2),
    avg_order_value DECIMAL(18,2),
    avg_review_score FLOAT,
    delay_rate DECIMAL(10,2),
    dwh_create_date DATETIME DEFAULT GETDATE()
);
------------------------------------------------------------------
WITH monthly_base AS (
    SELECT
        FORMAT(dd.full_date, 'yyyy-MM') AS year_month,
        fo.order_id,
        fo.customer_sk,
        fo.total_payment_amount,
        fo.avg_review_score,
        fo.is_delayed,
        dc.is_repeat_customer
    FROM gold.fact_orders AS fo INNER JOIN gold.dim_date AS dd
    ON fo.purchase_date_sk = dd.date_sk
    INNER JOIN gold.dim_customer AS dc
    ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
)

SELECT
    year_month,
    COUNT(DISTINCT order_id)  AS total_orders,
    COUNT(DISTINCT customer_sk)  AS total_customers,
    COUNT(DISTINCT CASE WHEN is_repeat_customer = 1 THEN customer_sk END) AS repeat_customers,
    SUM(total_payment_amount) AS total_gmv,
    CAST(AVG(total_payment_amount) AS DECIMAL(10,2)) AS avg_order_value,
    CAST(AVG(avg_review_score) AS DECIMAL(10,2)) AS avg_review_score,
    CAST(AVG(CAST(is_delayed AS FLOAT)) * 100 AS DECIMAL(10,2)) AS delay_rate
FROM monthly_base
GROUP BY year_month;
---------------------------------------------------------------------------------------
-- insert
WITH monthly_base AS (
    SELECT
        FORMAT(dd.full_date, 'yyyy-MM') AS year_month,
        fo.order_id,
        fo.customer_sk,
        fo.total_payment_amount,
        fo.avg_review_score,
        fo.is_delayed,
        dc.is_repeat_customer
    FROM gold.fact_orders AS fo INNER JOIN gold.dim_date AS dd
    ON fo.purchase_date_sk = dd.date_sk
    INNER JOIN gold.dim_customer AS dc
    ON fo.customer_sk = dc.customer_sk
    WHERE fo.order_status = 'delivered'
)
INSERT INTO gold.monthly_business_summary(
    year_month,
    total_orders,
    total_customers,
    repeat_customers,
    total_gmv,
    avg_order_value,
    avg_review_score,
    delay_rate 
)
SELECT
    year_month,
    COUNT(DISTINCT order_id)  AS total_orders,
    COUNT(DISTINCT customer_sk)  AS total_customers,
    COUNT(DISTINCT CASE WHEN is_repeat_customer = 1 THEN customer_sk END) AS repeat_customers,
    SUM(total_payment_amount) AS total_gmv,
    CAST(AVG(total_payment_amount) AS DECIMAL(10,2)) AS avg_order_value,
    CAST(AVG(avg_review_score) AS DECIMAL(10,2)) AS avg_review_score,
    CAST(AVG(CAST(is_delayed AS FLOAT)) * 100 AS DECIMAL(10,2)) AS delay_rate
FROM monthly_base
GROUP BY year_month;
---------------------------------------------------------------------------------------
SELECT
    *
FROM gold.monthly_business_summary















-- category_dashboard_mart
IF OBJECT_ID('gold.category_dashboard_mart', 'U') IS NOT NULL
    DROP TABLE gold.category_dashboard_mart;

CREATE TABLE gold.category_dashboard_mart (
    product_category_name VARCHAR(255),
    total_products INT,
    total_orders INT,
    total_revenue DECIMAL(18,2),
    avg_review_score FLOAT,
    avg_delay_rate DECIMAL(10,2),
    avg_freight_ratio DECIMAL(10,2),
    dwh_create_date DATETIME DEFAULT GETDATE()
);
--------------------------------------------------------------------------

SELECT
    product_category_name AS product_category_name,
    COUNT(*) AS total_products,
    SUM(total_orders) AS total_orders,
    SUM(total_revenue) AS total_revenue,
    CAST(AVG(avg_review_score) AS DECIMAL(10,2)) AS avg_review_score,
    CAST(AVG(delay_rate) AS DECIMAL(10,2)) AS avg_delay_rate,
    CAST(AVG(freight_ratio) AS DECIMAL(10,2)) AS avg_freight_ratio
FROM gold.product_sales_mart
GROUP BY product_category_name;


-------------------------------------------------------------------------------
-- insert
INSERT INTO gold.category_dashboard_mart(
    product_category_name,
    total_products,
    total_orders,
    total_revenue,
    avg_review_score,
    avg_delay_rate,
    avg_freight_ratio
)

SELECT
    product_category_name AS product_category_name,
    COUNT(*) AS total_products,
    SUM(total_orders) AS total_orders,
    SUM(total_revenue) AS total_revenue,
    CAST(AVG(avg_review_score) AS DECIMAL(10,2)) AS avg_review_score,
    CAST(AVG(delay_rate) AS DECIMAL(10,2)) AS avg_delay_rate,
    CAST(AVG(freight_ratio) AS DECIMAL(10,2)) AS avg_freight_ratio
FROM gold.product_sales_mart
GROUP BY product_category_name;
-------------------------------------------------------------------------------
SELECT
    *
FROM gold.category_dashboard_mart














IF OBJECT_ID('gold.customer_360_mart', 'U') IS NOT NULL
    DROP TABLE gold.customer_360_mart;

CREATE TABLE gold.customer_360_mart (
    customer_sk INT,
    lifetime_orders INT,
    lifetime_value DECIMAL(18,2),
    avg_order_value DECIMAL(18,2),
    avg_review_score FLOAT,
    avg_delivery_days FLOAT,
    favorite_category VARCHAR(255),
    rfm_segment VARCHAR(50),
    customer_segment VARCHAR(50),
    created_at DATETIME DEFAULT GETDATE()
);
------------------------------------------------------------
WITH favorite_category AS (
    SELECT 
        *
    FROM (
        SELECT
            fo.customer_sk,
            dp.product_category_name,
            COUNT(*) AS purchase_cnt,
            ROW_NUMBER() OVER (PARTITION BY fo.customer_sk ORDER BY COUNT(*) DESC) AS rn
        FROM gold.fact_order_items AS foi INNER JOIN gold.fact_orders AS fo
        ON foi.order_sk = fo.order_sk
        INNER JOIN gold.dim_product AS dp
        ON foi.product_sk = dp.product_sk
        GROUP BY fo.customer_sk, dp.product_category_name
    ) t
    WHERE rn = 1
)

SELECT
    dc.customer_sk AS customer_sk,
    dc.lifetime_orders AS lifetime_orders,
    dc.lifetime_value AS lifetime_value,
    CAST(CASE
        WHEN dc.lifetime_orders = 0 THEN 0
        ELSE dc.lifetime_value * 1.0 / dc.lifetime_orders
    END AS DECIMAL(10,2)) AS avg_order_value,
    AVG(fo.avg_review_score) AS avg_review_score,
    AVG(CAST(fo.delivery_days AS FLOAT))  AS avg_delivery_days,
    fc.product_category_name AS favorite_category,
    rfm.rfm_segment AS rfm_segment,
    dc.customer_segment AS customer_segment
FROM gold.dim_customer AS dc LEFT JOIN gold.fact_orders AS fo
ON dc.customer_sk = fo.customer_sk
LEFT JOIN gold.customer_rfm AS rfm
ON dc.customer_sk = rfm.customer_sk
LEFT JOIN favorite_category AS fc
ON dc.customer_sk = fc.customer_sk
GROUP BY dc.customer_sk, dc.lifetime_orders, dc.lifetime_value, fc.product_category_name, rfm.rfm_segment, dc.customer_segment;
------------------------------------------------------------
-- insert
WITH favorite_category AS (
    SELECT 
        *
    FROM (
        SELECT
            fo.customer_sk,
            dp.product_category_name,
            COUNT(*) AS purchase_cnt,
            ROW_NUMBER() OVER (PARTITION BY fo.customer_sk ORDER BY COUNT(*) DESC) AS rn
        FROM gold.fact_order_items AS foi INNER JOIN gold.fact_orders AS fo
        ON foi.order_sk = fo.order_sk
        INNER JOIN gold.dim_product AS dp
        ON foi.product_sk = dp.product_sk
        GROUP BY fo.customer_sk, dp.product_category_name
    ) t
    WHERE rn = 1
)

INSERT INTO gold.customer_360_mart(
    customer_sk,
    lifetime_orders,
    lifetime_value,
    avg_order_value,
    avg_review_score,
    avg_delivery_days,
    favorite_category,
    rfm_segment,
    customer_segment
)

SELECT
    dc.customer_sk AS customer_sk,
    dc.lifetime_orders AS lifetime_orders,
    dc.lifetime_value AS lifetime_value,
    CAST(CASE
        WHEN dc.lifetime_orders = 0 THEN 0
        ELSE dc.lifetime_value * 1.0 / dc.lifetime_orders
    END AS DECIMAL(10,2)) AS avg_order_value,
    AVG(fo.avg_review_score) AS avg_review_score,
    AVG(CAST(fo.delivery_days AS FLOAT))  AS avg_delivery_days,
    fc.product_category_name AS favorite_category,
    rfm.rfm_segment AS rfm_segment,
    dc.customer_segment AS customer_segment
FROM gold.dim_customer AS dc LEFT JOIN gold.fact_orders AS fo
ON dc.customer_sk = fo.customer_sk
LEFT JOIN gold.customer_rfm AS rfm
ON dc.customer_sk = rfm.customer_sk
LEFT JOIN favorite_category AS fc
ON dc.customer_sk = fc.customer_sk
GROUP BY dc.customer_sk, dc.lifetime_orders, dc.lifetime_value, fc.product_category_name, rfm.rfm_segment, dc.customer_segment;
-------------------------------------------------------------
SELECT
    *
FROM gold.customer_360_mart
