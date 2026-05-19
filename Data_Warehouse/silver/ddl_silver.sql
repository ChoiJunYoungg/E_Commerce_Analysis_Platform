/* Sliver Layer
1. Analysing : Explore & Understand the Data
2. Coding : Data cleansing
- Check Quality of Bronze
- Write Data Transformations
- Insert into Silver
3. Validating : Data Correctness Check
4. Docs & Version
- Data Documenting Versioning in GIT
- Data Flow, Data Integration */

/* Build Silver Layer
Explore & Understand The Data */

USE E_Commerce;

/* Build Sliver Layer
Create DDL for Tables */

IF OBJECT_ID('silver.olist_customers', 'U') IS NOT NULL
	DROP TABLE silver.olist_customers;  
CREATE TABLE silver.olist_customers(
	customer_id CHAR(32),
    customer_unique_id CHAR(32),
    customer_zip_code_prefix CHAR(8),
    customer_city NVARCHAR(100),
    customer_state CHAR(2),
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- 메타 데이터 컬럼(데이터 흐름추정, 최신성 보장, 데이터 품질 및 감사, 증분 적재관리 등을 위해 추가)
);

/* Build Silver Layer
Clean & Load (olist_customers) */
-- 테이블의 컬럼을 하나씩 보면서 다른테이블과 연결한것이 있거나 그 자체로 cleansing해야할것이 있다면 하면됨

-- Chcek For Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT
	*
FROM bronze.olist_customers;

SELECT
	customer_id,
	COUNT(*) AS cn
FROM bronze.olist_customers
GROUP BY customer_id
HAVING COUNT(*) >= 2   -- 중복되는 customer_id(주문번호, 시스템 내 recordID)가 없음

SELECT
	customer_unique_id,
	COUNT(*) AS cn
FROM bronze.olist_customers
GROUP BY customer_unique_id
HAVING COUNT(*) >= 2 

SELECT
	COUNT(*) -- 99441
FROM bronze.olist_customers

SELECT
	COUNT(DISTINCT customer_id) -- 99441, 시스템 내 recordID
FROM bronze.olist_customers

SELECT
	COUNT(DISTINCT customer_unique_id)
FROM bronze.olist_customers -- 96096, 실제 고객의 ID, 중복되는 고객이 있다는 의미

SELECT
	*
FROM bronze.olist_customers -- 결과 값이 없음 : null인 값이 없음
WHERE customer_id IS NULL OR customer_unique_id IS NULL OR customer_zip_code_prefix IS NULL OR customer_city IS NULL OR customer_state IS NULL

-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	customer_id
FROM bronze.olist_customers
WHERE customer_id != TRIM(customer_id); -- 결과없음

SELECT
	customer_unique_id
FROM bronze.olist_customers
WHERE customer_unique_id != TRIM(customer_unique_id); -- 결과없음

SELECT
	customer_zip_code_prefix
FROM bronze.olist_customers
WHERE customer_zip_code_prefix != TRIM(customer_zip_code_prefix); -- 결과없음

SELECT
	customer_city
FROM bronze.olist_customers
WHERE customer_city != TRIM(customer_city); -- 결과없음

SELECT
	customer_state
FROM bronze.olist_customers
WHERE customer_state != TRIM(customer_state); -- 결과없음

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
	DISTINCT customer_city -- 모두 소문자로 되어있음
FROM bronze.olist_customers


SELECT
	DISTINCT customer_state -- 모두 대문자로 되어있음
FROM bronze.olist_customers

SELECT
	customer_zip_code_prefix
FROM bronze.olist_customers
WHERE customer_zip_code_prefix NOT BETWEEN '01000' AND '99990' -- 브라질 우편번호 앞자리의 범위에 있는지 확인, 아무결과 없음 모두 정상범위


-- 최종적으로 cleansing된 테이블의 데이터를 다시 테이블에 insert
-- null값도 없고 범위를 벗어나는것도 없음, 형식만 맞춰서 silver layer에 insert

INSERT INTO silver.olist_customers(
	customer_id,
	customer_unique_id,
	customer_zip_code_prefix,
	customer_city,
	customer_state
	)

SELECT
	TRIM(customer_id),
	TRIM(customer_unique_id),
	customer_zip_code_prefix,
	LOWER(TRIM(customer_city)) AS customer_city,
	UPPER(TRIM(customer_state)) AS customer_state
FROM bronze.olist_customers

-- Insert 한 후 처음했던 Quality Check해보기
-- Re-run the quality chekc querires from the bronze layer to verify the quality of data in silver layer

-- Check For NULLs or Duplicates in Primary Key
-- Expectation: No Result

SELECT
	*
FROM silver.olist_customers

SELECT
	customer_id,
	COUNT(*) AS cn
FROM silver.olist_customers
GROUP BY customer_id
HAVING COUNT(*) >= 2　-- 결과값 없음

SELECT
	*
FROM silver.olist_customers -- 결과 값이 없음 : null인 값이 없음
WHERE customer_id IS NULL OR customer_unique_id IS NULL OR customer_zip_code_prefix IS NULL OR customer_city IS NULL OR customer_state IS NULL










/* Create DDL for Tables(silver.olist_geolocation) */
IF OBJECT_ID('silver.olist_geolocation', 'U') IS NOT NULL
	DROP TABLE silver.olist_geolocation;  
CREATE TABLE silver.olist_geolocation(
	geolocation_zip_code_prefix CHAR(8),
    geolocation_lat FLOAT,
    geolocation_lng FLOAT,
    geolocation_city NVARCHAR(100),
    geolocation_state CHAR(4),
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- 메타 데이터 컬럼(데이터 흐름추정, 최신성 보장, 데이터 품질 및 감사, 증분 적재관리 등을 위해 추가)
);

/* Build Silver Layer
Clean & Load (olist_geolocation) */
-- 테이블의 컬럼을 하나씩 보면서 다른테이블과 연결한것이 있거나 그 자체로 cleansing해야할것이 있다면 하면됨

-- Chcek For Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT
	*
FROM bronze.olist_geolocation

-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	geolocation_city
FROM bronze.olist_geolocation
WHERE  geolocation_city!= TRIM(geolocation_city)　-- 결과없음

SELECT
	geolocation_city
FROM bronze.olist_geolocation
WHERE  geolocation_state!= TRIM(geolocation_state)　-- 결과없음

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
	DISTINCT geolocation_city -- 모두 소문자로 되어있음, 같은 의미이지만 글자위에 찍힌 점들에따라 다른값으로 나옴, 이값을 통일할 필요가 있어보임
FROM bronze.olist_geolocation

-- 통일 해야하는것(소문자 뿐만 아니라 대문자도) 				
-- á : a, ã : a, â : a, à : a
-- é : e, ê : e
-- ô : o, õ : o, ô : o
-- i : í,
-- ç : c,

--- 악센트에 따라 중복되는 도시이름 제거
SELECT DISTINCT
    LOWER(
        TRANSLATE(
            geolocation_city,
            N'áàâãäéèêëíìîïóòôõöúùûüçñ',
            N'aaaaaeeeeiiiiooooouuuucn'
        )
    ) AS city_standard
FROM bronze.olist_geolocation


SELECT
	DISTINCT geolocation_state -- 모두 대문자로 되어있음
FROM bronze.olist_geolocation

SELECT
	*
FROM bronze.olist_geolocation
WHERE geolocation_lat NOT BETWEEN -90 AND 90                
	OR geolocation_lng NOT BETWEEN -180 AND 180 -- 결과값 없음, 범위를 벗어나는 이상값 없음

SELECT
	COUNT(*)
FROM bronze.olist_geolocation
WHERE geolocation_lat BETWEEN -90 AND 90                
	AND geolocation_lng BETWEEN -180 AND 180　-- 모든 행의 개수가 다 나옴

-- 브라질의 우편번호 앞자리는 같지만 geolocation_lat, geolocation_lng의 값을 상당히 다양함 -> 값이 너무 많아질 수 있음
-- group by를 통해 각 우편번호별 평균 geolocation_lat, geolocation_lng 값을 사용
-- 우편번호 단위의 중심 위치를 대표 → 지리 분석, 매핑, 시각화에 적합, 극단값(동일 우편번호내 약간 벗어난 좌표) 영향을 최소화, downstream에서 1:1 매칭 + 집계 분석 시 안전
SELECT
	COUNT(*) -- 1000163개
FROM bronze.olist_geolocation

SELECT
	geolocation_zip_code_prefix,
	TRIM(city_standard) AS city_standard,
	TRIM(geolocation_state) AS geolocation_state,
	AVG(geolocation_lat) AS lat_avg,
	AVG(geolocation_lng) AS lng_avg
FROM (
	SELECT 
	geolocation_zip_code_prefix,
	LOWER(
        TRANSLATE(
            geolocation_city,
            N'áàâãäéèêëíìîïóòôõöúùûüçñ',
            N'aaaaaeeeeiiiiooooouuuucn'
        )
    ) AS city_standard,
	geolocation_state,
	geolocation_lat,
	geolocation_lng
FROM bronze.olist_geolocation
)t
WHERE geolocation_zip_code_prefix BETWEEN '01000' AND '99990'  
	AND geolocation_lat BETWEEN -90 AND 90                
	AND geolocation_lng BETWEEN -180 AND 180
GROUP BY geolocation_zip_code_prefix, city_standard, geolocation_state  -- 19617개로 줄어듦


-- 같은 geolocation_zip_code_prefix에 중복되는 도시가 존재하는지 확인, 중복되는 값이 존재, rank 함수를 통해 제거
SELECT
    geolocation_zip_code_prefix,
    COUNT(DISTINCT geolocation_state) AS city_cnt,
    COUNT(DISTINCT geolocation_state) AS state_cnt
FROM bronze.olist_geolocation
GROUP BY geolocation_zip_code_prefix
HAVING COUNT(DISTINCT geolocation_state) > 1
    OR COUNT(DISTINCT geolocation_state) > 1; 

-- 19617개 -> 19015개로 줄어듦
GO
WITH geo AS (
    SELECT
        geolocation_zip_code_prefix,
        LOWER(
            TRANSLATE(
                geolocation_city,
                N'áàâãäéèêëíìîïóòôõöúùûüçñ',
                N'aaaaaeeeeiiiiooooouuuucn'
            )
        ) AS city_standard,
        geolocation_state,
        AVG(geolocation_lat) AS lat_avg,
        AVG(geolocation_lng) AS lng_avg,
        COUNT(*) AS cnt
    FROM bronze.olist_geolocation
    GROUP BY
        geolocation_zip_code_prefix,
        LOWER(
            TRANSLATE(
                geolocation_city,
                N'áàâãäéèêëíìîïóòôõöúùûüçñ',
                N'aaaaaeeeeiiiiooooouuuucn'
            )
        ),
        geolocation_state
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY geolocation_zip_code_prefix
            ORDER BY cnt DESC
        ) AS rn
    FROM geo
)

SELECT *
FROM ranked
WHERE rn = 1
GO

-- 최종적으로 cleansing된 테이블의 데이터를 다시 테이블에 insert

WITH geo AS (
    SELECT
        geolocation_zip_code_prefix,
        LOWER(
            TRANSLATE(
                geolocation_city,
                N'áàâãäéèêëíìîïóòôõöúùûüçñ',
                N'aaaaaeeeeiiiiooooouuuucn'
            )
        ) AS city_standard,
        geolocation_state,
        AVG(geolocation_lat) AS lat_avg,
        AVG(geolocation_lng) AS lng_avg,
        COUNT(*) AS cnt
    FROM bronze.olist_geolocation
    GROUP BY
        geolocation_zip_code_prefix,
        LOWER(
            TRANSLATE(
                geolocation_city,
                N'áàâãäéèêëíìîïóòôõöúùûüçñ',
                N'aaaaaeeeeiiiiooooouuuucn'
            )
        ),
        geolocation_state
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY geolocation_zip_code_prefix
            ORDER BY cnt DESC
        ) AS rn
    FROM geo
)

INSERT INTO silver.olist_geolocation(
    geolocation_zip_code_prefix,
    geolocation_lat,
    geolocation_lng,
    geolocation_city,
    geolocation_state
)

SELECT
    geolocation_zip_code_prefix,
    lat_avg,
    lng_avg,
    city_standard,
    geolocation_state
FROM ranked
WHERE rn = 1

-- Insert 한 후 처음했던 Quality Check해보기
-- Re-run the quality chekc querires from the bronze layer to verify the quality of data in silver layer

SELECT
    *
FROM silver.olist_geolocation


/* Create DDL for Tables(silver.olist_geolocation) */
IF OBJECT_ID('silver.olist_order_items', 'U') IS NOT NULL
	DROP TABLE silver.olist_order_items;  
CREATE TABLE silver.olist_order_items(
	order_id CHAR(32),
    order_item_id INT,
    product_id CHAR(32),
    seller_id CHAR(32),
    shipping_limit_date DATETIME2(0),
    PRICE FLOAT,
    freight_value FLOAT,
    total_item_value FLOAT,
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- 메타 데이터 컬럼(데이터 흐름추정, 최신성 보장, 데이터 품질 및 감사, 증분 적재관리 등을 위해 추가)
);

/* Build Silver Layer
Clean & Load (olist_geolocation) */
-- 테이블의 컬럼을 하나씩 보면서 다른테이블과 연결한것이 있거나 그 자체로 cleansing해야할것이 있다면 하면됨

-- Chcek For Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT
    *
FROM bronze.olist_order_items

SELECT
    *
FROM bronze.olist_order_items -- NULL인 값이 없음
WHERE order_id IS NULL OR order_item_id IS NULL OR product_id IS NULL OR seller_id IS NULL OR shipping_limit_date IS NULL OR PRICE IS NULL OR freight_value IS NULL

SELECT
    *
FROM(
    SELECT 
        *,
        ROW_NUMBER() OVER (
                PARTITION BY order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value
                ORDER BY order_id
            ) AS rn
    FROM bronze.olist_order_items
)t
WHERE rn >= 2  -- 중복되는 값 없음

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
    *
FROM bronze.olist_order_items
WHERE price < 0 OR freight_value < 0 -- 범위를 벗어나는 값이 없음


------------------------------------------------------
WITH CTE_t1 AS (
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value AS freight_value
    FROM bronze.olist_order_items
    WHERE price >= 0
      AND freight_value >= 0
      AND order_id IS NOT NULL
      AND order_item_id IS NOT NULL
      AND product_id IS NOT NULL
      AND seller_id IS NOT NULL
)
, CTE_t2 AS(
     SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value
            ORDER BY order_id
        ) AS rn -- 중복제거
    FROM CTE_t1
)

SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    (price + freight_value) AS total_item_value -- 주문 금액 계산,  item 기준으로 합해야 실제 주문 금액 계산 가능
FROM CTE_t2
WHERE rn = 1



-- 최종적으로 cleansing된 테이블의 데이터를 다시 테이블에 insert

WITH CTE_t1 AS (
    SELECT
        order_id,
        order_item_id,
        product_id,
        seller_id,
        shipping_limit_date,
        price,
        freight_value AS freight_value
    FROM bronze.olist_order_items
    WHERE price >= 0
      AND freight_value >= 0
      AND order_id IS NOT NULL
      AND order_item_id IS NOT NULL
      AND product_id IS NOT NULL
      AND seller_id IS NOT NULL
)
, CTE_t2 AS(
     SELECT 
        *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value
            ORDER BY order_id
        ) AS rn -- 중복제거
    FROM CTE_t1
)

INSERT INTO silver.olist_order_items(
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    total_item_value
)

SELECT
    order_id,
    order_item_id,
    product_id,
    seller_id,
    shipping_limit_date,
    price,
    freight_value,
    (price + freight_value) AS total_item_value -- 주문 금액 계산,  item 기준으로 합해야 실제 주문 금액 계산 가능
FROM CTE_t2
WHERE rn = 1


-- Insert 한 후 처음했던 Quality Check해보기
-- Re-run the quality chekc querires from the bronze layer to verify the quality of data in silver layer

SELECT
    *
FROM silver.olist_order_items

SELECT
    *
FROM silver.olist_order_items
WHERE order_id IS NULL OR order_item_id IS NULL OR product_id IS NULL OR seller_id IS NULL OR shipping_limit_date IS NULL OR PRICE IS NULL OR freight_value IS NULL

SELECT
    *
FROM silver.olist_order_items
WHERE price < 0 OR freight_value < 0 OR total_item_value < 0









/* Create DDL for Tables(silver.olist_order_payments) */
IF OBJECT_ID('silver.olist_order_payments', 'U') IS NOT NULL
	DROP TABLE silver.olist_order_payments;  
CREATE TABLE silver.olist_order_payments(
	order_id CHAR(32),
    payment_sequential INT,
    payment_type NVARCHAR(50),
    payment_installments INT,
    payment_value FLOAT,
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- 메타 데이터 컬럼(데이터 흐름추정, 최신성 보장, 데이터 품질 및 감사, 증분 적재관리 등을 위해 추가)
);

/* Build Silver Layer
Clean & Load (olist_order_payments) */
-- 테이블의 컬럼을 하나씩 보면서 다른테이블과 연결한것이 있거나 그 자체로 cleansing해야할것이 있다면 하면됨

-- Chcek For Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT
    *
FROM bronze.olist_order_payments

SELECT
    *
FROM bronze.olist_order_payments
WHERE order_id IS NULL OR payment_sequential IS NULL OR payment_type IS NULL OR payment_installments IS NULL OR payment_value IS NULL -- null인 값 없음

SELECT
    *
FROM(
    SELECT 
        *,
        ROW_NUMBER() OVER (
                PARTITION BY order_id, payment_sequential, payment_type, payment_installments, payment_value
                ORDER BY order_id
        ) AS rn
    FROM bronze.olist_order_payments
)t
WHERE rn >= 2 -- 중복되는 값 없음

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
    *
FROM bronze.olist_order_payments
WHERE payment_value < 0  OR payment_sequential < 0 OR payment_sequential < 0 -- 값의 범위를 벗어나는 값 없음


--------------------------------------------------------------------------------
WITH CTE_t1 AS (
    SELECT
        order_id,
        payment_sequential,
        LOWER(TRIM(payment_type)) AS payment_type,
        payment_installments,
        payment_value
    FROM bronze.olist_order_payments
    WHERE order_id IS NOT NULL
      AND payment_type IS NOT NULL
      AND payment_sequential >= 0
      AND payment_installments >= 0
      AND payment_value >= 0
)

,CTE_t2 AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, payment_sequential, payment_type, payment_installments, payment_value
            ORDER BY order_id
        ) AS rn
    FROM CTE_t1
)

SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM CTE_t2
WHERE rn = 1

-------------------------------------------------------------------------------------------

-- 최종적으로 cleansing된 테이블의 데이터를 다시 테이블에 insert
WITH CTE_t1 AS (
    SELECT
        order_id,
        payment_sequential,
        LOWER(TRIM(payment_type)) AS payment_type,
        payment_installments,
        payment_value
    FROM bronze.olist_order_payments
    WHERE order_id IS NOT NULL
      AND payment_type IS NOT NULL
      AND payment_sequential >= 0
      AND payment_installments >= 0
      AND payment_value >= 0
)

,CTE_t2 AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY order_id, payment_sequential, payment_type, payment_installments, payment_value
            ORDER BY order_id
        ) AS rn
    FROM CTE_t1
)

INSERT INTO silver.olist_order_payments(
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
)

SELECT
    order_id,
    payment_sequential,
    payment_type,
    payment_installments,
    payment_value
FROM CTE_t2
WHERE rn = 1

-- Insert 한 후 처음했던 Quality Check해보기
-- Re-run the quality chekc querires from the bronze layer to verify the quality of data in silver layer

SELECT
    *
FROM silver.olist_order_payments

SELECT
    *
FROM silver.olist_order_payments
WHERE order_id IS NULL OR payment_sequential IS NULL OR payment_type IS NULL OR payment_installments IS NULL OR payment_value IS NULL -- null인 값 없음

SELECT
    *
FROM(
    SELECT 
        *,
        ROW_NUMBER() OVER (
                PARTITION BY order_id, payment_sequential, payment_type, payment_installments, payment_value
                ORDER BY order_id
        ) AS rn
    FROM silver.olist_order_payments
)t
WHERE rn >= 2 -- 중복되는 값 없음

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
    *
FROM bronze.olist_order_payments
WHERE payment_value < 0  OR payment_sequential < 0 OR payment_sequential < 0 -- 값의 범위를 벗어나는 값 없음











/* Create DDL for Tables(silver.olist_order_payments) */
IF OBJECT_ID('silver.olist_order_reviews', 'U') IS NOT NULL
	DROP TABLE silver.olist_order_reviews;  
CREATE TABLE silver.olist_order_reviews(
	review_id CHAR(32),
    order_id CHAR(32),
    review_score FLOAT,
    review_comment_title NVARCHAR(500),
    review_comment_message NVARCHAR(500),
    review_comment_message_length NVARCHAR(500),
    review_creation_date DATETIME2(0),
    review_answer_timestamp DATETIME2(0),
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- 메타 데이터 컬럼(데이터 흐름추정, 최신성 보장, 데이터 품질 및 감사, 증분 적재관리 등을 위해 추가)
);

/* Build Silver Layer
Clean & Load (olist_order_reviews) */
-- 테이블의 컬럼을 하나씩 보면서 다른테이블과 연결한것이 있거나 그 자체로 cleansing해야할것이 있다면 하면됨

-- Chcek For Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT
    *
FROM bronze.olist_order_reviews

SELECT
    *
FROM bronze.olist_order_reviews
WHERE review_id IS NULL OR order_id IS NULL OR review_score IS NULL OR review_creation_date IS NULL OR review_answer_timestamp IS NULL -- NULL인 값 없음

SELECT
    *
FROM(
    SELECT 
        *,
        ROW_NUMBER() OVER (
                PARTITION BY review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp
                ORDER BY review_id
            ) AS rn
    FROM bronze.olist_order_reviews
)t
WHERE rn >= 2 -- 중복되는 값 없음

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
    *
FROM bronze.olist_order_reviews
WHERE review_score < 0 OR review_score > 6 -- 값의 범위를 벗어나는 값 없음

SELECT
    *
FROM bronze.olist_order_reviews
WHERE review_creation_date > review_answer_timestamp -- 시간 범위를 벗어나는 값 없음

SELECT
    *
FROM bronze.olist_order_reviews
WHERE review_creation_date > '2030-01-01' OR review_creation_date < '2000-01-01' -- 시간 범위를 벗어나는 값 없음

SELECT
    *
FROM bronze.olist_order_reviews
WHERE review_answer_timestamp > '2030-01-01' OR review_answer_timestamp < '2000-01-01' -- 시간 범위를 벗어나는 값 없음

----------------------------------------------------------------
WITH CTE_t1 AS (
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp
    FROM bronze.olist_order_reviews
    WHERE review_id IS NOT NULL
      AND order_id IS NOT NULL
      AND review_score BETWEEN 1 AND 5
      AND review_creation_date <= review_answer_timestamp
)

,CTE_t2 AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp
            ORDER BY review_id
        ) AS rn
    FROM CTE_t1
)

SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    LEN(review_comment_message) AS review_comment_message_length,
    review_creation_date,
    review_answer_timestamp
FROM CTE_t2
WHERE rn = 1

-------------------------------------------------------------------------------------------

-- 최종적으로 cleansing된 테이블의 데이터를 다시 테이블에 insert

WITH CTE_t1 AS (
    SELECT
        review_id,
        order_id,
        review_score,
        review_comment_title,
        review_comment_message,
        review_creation_date,
        review_answer_timestamp
    FROM bronze.olist_order_reviews
    WHERE review_id IS NOT NULL
      AND order_id IS NOT NULL
      AND review_score BETWEEN 1 AND 5
      AND review_creation_date <= review_answer_timestamp
)

,CTE_t2 AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp
            ORDER BY review_id
        ) AS rn
    FROM CTE_t1
)

INSERT INTO silver.olist_order_reviews(
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    review_comment_message_length,
    review_creation_date,
    review_answer_timestamp
)

SELECT
    review_id,
    order_id,
    review_score,
    review_comment_title,
    review_comment_message,
    LEN(review_comment_message) AS review_comment_message_length,
    review_creation_date,
    review_answer_timestamp
FROM CTE_t2
WHERE rn = 1

-- Insert 한 후 처음했던 Quality Check해보기
-- Re-run the quality chekc querires from the bronze layer to verify the quality of data in silver layer

SELECT
    *
FROM silver.olist_order_reviews

SELECT
    *
FROM silver.olist_order_reviews
WHERE review_id IS NULL OR order_id IS NULL OR review_score IS NULL OR review_creation_date IS NULL OR review_answer_timestamp IS NULL -- NULL인 값 없음

SELECT
    *
FROM(
    SELECT 
        *,
        ROW_NUMBER() OVER (
                PARTITION BY review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp
                ORDER BY review_id
            ) AS rn
    FROM silver.olist_order_reviews
)t
WHERE rn >= 2 -- 중복되는 값 없음

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
    *
FROM silver.olist_order_reviews
WHERE review_score < 0 OR review_score > 6 -- 값의 범위를 벗어나는 값 없음

SELECT
    *
FROM silver.olist_order_reviews
WHERE review_creation_date > review_answer_timestamp -- 시간 범위를 벗어나는 값 없음

SELECT
    *
FROM silver.olist_order_reviews
WHERE review_creation_date > '2030-01-01' OR review_creation_date < '2000-01-01' -- 시간 범위를 벗어나는 값 없음

SELECT
    *
FROM silver.olist_order_reviews
WHERE review_answer_timestamp > '2030-01-01' OR review_answer_timestamp < '2000-01-01' -- 시간 범위를 벗어나는 값 없음













/* Create DDL for Tables(silver.olist_orders) */
IF OBJECT_ID('silver.olist_orders', 'U') IS NOT NULL
	DROP TABLE silver.olist_orders;  
CREATE TABLE silver.olist_orders(
	order_id CHAR(32),
    customer_id CHAR(32),
    order_status NVARCHAR(50),
    order_purchase_timestamp DATETIME2(0),
    order_approved_at DATETIME2(0),
    order_delivered_carrier_date DATETIME2(0),
    order_delivered_customer_date DATETIME2(0),
    order_estimated_delivery_date DATETIME2(0),
    is_delivered INT,
    approval_time INT,
    delivery_days INT,
    delivery_delay_days INT,
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- 메타 데이터 컬럼(데이터 흐름추정, 최신성 보장, 데이터 품질 및 감사, 증분 적재관리 등을 위해 추가)
);

/* Build Silver Layer
Clean & Load (olist_orders) */
-- 테이블의 컬럼을 하나씩 보면서 다른테이블과 연결한것이 있거나 그 자체로 cleansing해야할것이 있다면 하면됨

-- Chcek For Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT
    *
FROM bronze.olist_orders

SELECT
    *
FROM bronze.olist_orders
WHERE order_id IS NOT NULL
      AND customer_id IS NOT NULL
      AND order_status IS NOT NULL
      AND order_purchase_timestamp IS NOT NULL -- NULL값이 아니어야하는 값들은 모두 null인 값이 없음

SELECT
    *
FROM bronze.olist_orders
WHERE order_id IS NULL
      OR customer_id IS  NULL
      OR order_status IS  NULL
      OR order_purchase_timestamp IS NULL -- not null이여야하는 값들은 모두 not null임

SELECT
    *
FROM bronze.olist_orders
WHERE order_delivered_carrier_date IS NULL OR order_delivered_customer_date IS NULL

SELECT
    DISTINCT order_status -- apporved, canceled, created, shipped, unavailable, processing, invoiced, delivered의 결과값이 나옴
FROM bronze.olist_orders 
WHERE order_delivered_carrier_date IS NULL OR order_delivered_customer_date IS NULL 

SELECT
    *
FROM(
SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_id) AS rn
FROM bronze.olist_orders
)t
WHERE rn >= 2 -- 중복되는 값 없음

-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	order_status
FROM bronze.olist_orders
WHERE order_status != TRIM(order_status); -- 결과없음

SELECT
	DISTINCT order_status
FROM bronze.olist_orders


-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
    *
FROM bronze.olist_orders
WHERE order_purchase_timestamp > order_approved_at OR order_purchase_timestamp > order_delivered_customer_date
    OR order_purchase_timestamp > order_estimated_delivery_date -- 0건

SELECT
    *
FROM bronze.olist_orders
WHERE order_purchase_timestamp > order_delivered_carrier_date -- 166건(제거해야함)



SELECT
    *
FROM bronze.olist_orders
WHERE order_approved_at > order_delivered_carrier_date -- 1359건

SELECT
    *
FROM bronze.olist_orders
WHERE order_approved_at > order_delivered_customer_date -- 61건

SELECT
    *
FROM bronze.olist_orders
WHERE order_approved_at > order_estimated_delivery_date -- 12건




SELECT
    *
FROM bronze.olist_orders
WHERE order_delivered_carrier_date > order_delivered_customer_date -- 23건

SELECT
    *
FROM bronze.olist_orders
WHERE order_delivered_carrier_date > order_estimated_delivery_date -- 473건(배송지연된 가능성, 제거할필요는 없을것같음)




SELECT
    *
FROM bronze.olist_orders
WHERE order_delivered_customer_date > order_estimated_delivery_date -- 7827건(배송이 지연된 경우)

--------------------------------------------------------------------------------------------------

WITH CTE_t1 AS(
    SELECT
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date
    FROM bronze.olist_orders
    WHERE order_id IS NULL
      OR customer_id IS  NULL
      OR order_status IS  NULL
      OR order_purchase_timestamp IS NULL
)
,CTE_t2 AS(
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_id) AS rn
    FROM bronze.olist_orders
)
,CTE_t3 AS(
    SELECT
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        CASE 
            WHEN order_status IN ('canceled', 'unavailable') THEN NULL
            WHEN order_status = 'created'   THEN order_purchase_timestamp
            WHEN order_status IN ('approved', 'processing', 'invoiced', 'shipped') AND order_delivered_carrier_date IS NULL THEN order_approved_at
            ELSE order_delivered_carrier_date
        END AS order_delivered_carrier_date, -- 배송 시작일 처리
        CASE 
            WHEN order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL THEN order_delivered_customer_date
            ELSE NULL
        END AS order_delivered_customer_date, -- 고객 도착일 처리
        CASE
            WHEN order_status = 'delivered' AND order_estimated_delivery_date IS NOT NULL THEN order_estimated_delivery_date
            ELSE NULL
        END AS order_estimated_delivery_date, -- 예상 배송일 처리
         CASE 
            WHEN order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL THEN 1 -- 배송 완료 여부
            ELSE 0
        END AS is_delivered,
        DATEDIFF(MINUTE, order_purchase_timestamp, order_approved_at) AS approval_time, -- 승인까지 걸린 시간
        CASE 
            WHEN order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL THEN
                DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)
            ELSE NULL
        END AS delivery_days, -- 배송 기간
        CASE 
            WHEN order_status = 'delivered' 
                 AND order_delivered_customer_date IS NOT NULL 
                 AND order_estimated_delivery_date IS NOT NULL THEN
                DATEDIFF(DAY, order_estimated_delivery_date, order_delivered_customer_date)
            ELSE NULL
        END AS delivery_delay_days -- 배송 지연/조기 배송(-값이면 조기배송된것이고 + 값이면 배송 지연된것임)
    FROM CTE_t2
    WHERE rn = 1
    AND (
          order_status IN ('approved', 'canceled', 'created', 'shipped','unavailable', 'processing','invoiced')
          OR (
              order_status = 'delivered' -- 배송 완료 주문만 날짜 이상치 필터 적용
              AND order_purchase_timestamp <= order_approved_at
              AND order_approved_at <= order_delivered_carrier_date
              AND order_approved_at <= order_delivered_customer_date
              AND order_delivered_carrier_date <= order_delivered_customer_date
          )
      )
)

SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    is_delivered,
    approval_time,
    delivery_days,
    delivery_delay_days
FROM CTE_t3 -- 99441개 -> 98045개

-------------------------------------------------------------------------------------------

-- 최종적으로 cleansing된 테이블의 데이터를 다시 테이블에 insert

GO
WITH CTE_t1 AS(
    SELECT
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        order_delivered_carrier_date,
        order_delivered_customer_date,
        order_estimated_delivery_date
    FROM bronze.olist_orders
    WHERE order_id IS NULL
      OR customer_id IS  NULL
      OR order_status IS  NULL
      OR order_purchase_timestamp IS NULL
)
,CTE_t2 AS(
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_id) AS rn
    FROM bronze.olist_orders
)
,CTE_t3 AS(
    SELECT
        order_id,
        customer_id,
        order_status,
        order_purchase_timestamp,
        order_approved_at,
        CASE 
            WHEN order_status IN ('canceled', 'unavailable') THEN NULL
            WHEN order_status = 'created'   THEN order_purchase_timestamp
            WHEN order_status IN ('approved', 'processing', 'invoiced', 'shipped') AND order_delivered_carrier_date IS NULL THEN order_approved_at
            ELSE order_delivered_carrier_date
        END AS order_delivered_carrier_date, -- 배송 시작일 처리
        CASE 
            WHEN order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL THEN order_delivered_customer_date
            ELSE NULL
        END AS order_delivered_customer_date, -- 고객 도착일 처리
        CASE
            WHEN order_status = 'delivered' AND order_estimated_delivery_date IS NOT NULL THEN order_estimated_delivery_date
            ELSE NULL
        END AS order_estimated_delivery_date, -- 예상 배송일 처리
         CASE 
            WHEN order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL THEN 1 -- 배송 완료 여부
            ELSE 0
        END AS is_delivered,
        DATEDIFF(MINUTE, order_purchase_timestamp, order_approved_at) AS approval_time, -- 승인까지 걸린 시간
        CASE 
            WHEN order_status = 'delivered' AND order_delivered_customer_date IS NOT NULL THEN
                DATEDIFF(DAY, order_purchase_timestamp, order_delivered_customer_date)
            ELSE NULL
        END AS delivery_days, -- 배송 기간
        CASE 
            WHEN order_status = 'delivered' 
                 AND order_delivered_customer_date IS NOT NULL 
                 AND order_estimated_delivery_date IS NOT NULL THEN
                DATEDIFF(DAY, order_estimated_delivery_date, order_delivered_customer_date)
            ELSE NULL
        END AS delivery_delay_days -- 배송 지연/조기 배송(-값이면 조기배송된것이고, + 값이면 배송 지연된것임, 0이면 제때 배송된것임)
    FROM CTE_t2
    WHERE rn = 1
    AND (
          order_status IN ('approved', 'canceled', 'created', 'shipped','unavailable', 'processing','invoiced')
          OR (
              order_status = 'delivered' -- 배송 완료 주문만 날짜 이상치 필터 적용
              AND order_purchase_timestamp <= order_approved_at
              AND order_approved_at <= order_delivered_carrier_date
              AND order_approved_at <= order_delivered_customer_date
              AND order_delivered_carrier_date <= order_delivered_customer_date
          )
      )
       AND (
            order_delivered_carrier_date IS NULL
            OR order_purchase_timestamp <= order_delivered_carrier_date
          )

     
      AND (
            order_delivered_carrier_date IS NULL
            OR order_approved_at <= order_delivered_carrier_date
          )

    
      AND (
            order_delivered_customer_date IS NULL
            OR order_delivered_carrier_date <= order_delivered_customer_date
          )
)

INSERT INTO silver.olist_orders(
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    is_delivered,
    approval_time,
    delivery_days,
    delivery_delay_days
)
SELECT
    order_id,
    customer_id,
    order_status,
    order_purchase_timestamp,
    order_approved_at,
    order_delivered_carrier_date,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    is_delivered,
    approval_time,
    delivery_days,
    delivery_delay_days
FROM CTE_t3

GO

-- Insert 한 후 처음했던 Quality Check해보기
-- Re-run the quality chekc querires from the bronze layer to verify the quality of data in silver layer

SELECT
    *
FROM silver.olist_orders -- 98036개

SELECT
    *
FROM silver.olist_orders
WHERE order_id IS NOT NULL
      AND customer_id IS NOT NULL
      AND order_status IS NOT NULL
      AND order_purchase_timestamp IS NOT NULL -- NULL값이 아니어야하는 값들은 모두 null인 값이 없음(98036개)

SELECT
    *
FROM(
    SELECT 
        *,
        ROW_NUMBER() OVER (PARTITION BY order_id ORDER BY order_id) AS rn
    FROM silver.olist_orders
)t
WHERE rn >= 2 -- 결과 값이 없음(중복되는 값이 없음)

-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	order_status
FROM silver.olist_orders
WHERE order_status != TRIM(order_status); -- 결과없음

SELECT
	DISTINCT order_status
FROM bronze.olist_orders


-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
    *
FROM silver.olist_orders
WHERE order_purchase_timestamp > order_approved_at OR order_purchase_timestamp > order_delivered_customer_date
    OR order_purchase_timestamp > order_estimated_delivery_date -- 0건

SELECT
    *
FROM silver.olist_orders
WHERE order_purchase_timestamp > order_delivered_carrier_date -- 0건


SELECT
    *
FROM silver.olist_orders
WHERE order_approved_at > order_delivered_carrier_date -- 0건

SELECT
    *
FROM silver.olist_orders
WHERE order_approved_at > order_delivered_customer_date -- 0건

SELECT
    *
FROM silver.olist_orders
WHERE order_approved_at > order_estimated_delivery_date -- 1건




SELECT
    *
FROM silver.olist_orders
WHERE order_delivered_carrier_date > order_delivered_customer_date -- 0건

SELECT
    *
FROM silver.olist_orders
WHERE order_delivered_carrier_date > order_estimated_delivery_date -- 464건(배송지연된 가능성, 제거할필요는 없을것같음)


SELECT
    *
FROM silver.olist_orders
WHERE order_delivered_customer_date > order_estimated_delivery_date -- 7792건(배송이 지연된 경우)










/* Create DDL for Tables(silver.olist_products) */
IF OBJECT_ID('silver.olist_products', 'U') IS NOT NULL
	DROP TABLE silver.olist_products;  
CREATE TABLE silver.olist_products(
	product_id CHAR(32),
    product_category_name NVARCHAR(100),
    product_name_length INT,
    product_description_length INT,
    product_photos_qty INT,
    product_weight_g INT,
    product_length_cm INT,
    product_height_cm INT,
    product_width_cm INT,
    product_volumne INT,
    product_density FLOAT,
    product_size_cateogry NVARCHAR(10),
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- 메타 데이터 컬럼(데이터 흐름추정, 최신성 보장, 데이터 품질 및 감사, 증분 적재관리 등을 위해 추가)
);

/* Build Silver Layer
Clean & Load (olist_products) */
-- 테이블의 컬럼을 하나씩 보면서 다른테이블과 연결한것이 있거나 그 자체로 cleansing해야할것이 있다면 하면됨

-- Chcek For Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT
    *
FROM bronze.olist_products -- (32951개)

SELECT
    *
FROM(
        SELECT 
            *,
            ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS rn
        FROM bronze.olist_products
)t
WHERE rn >= 2 -- 결과 값이 없음(중복되는 값이 없음)

-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	product_category_name
FROM bronze.olist_products
WHERE product_category_name != TRIM(product_category_name); -- 결과없음

SELECT
	DISTINCT product_category_name
FROM bronze.olist_products -- NULL 값이 존재

SELECT
	*
FROM bronze.olist_products
WHERE product_category_name IS NULL -- name_length, description_length, photos_qty 값들이 다 이상값들임 (610개)

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
	*
FROM bronze.olist_products
WHERE product_name_lenght > 999 OR product_description_lenght > 9999 OR product_name_lenght < 0 OR product_description_lenght < 0 -- 610건(위에서 name_length, description_length, photos_qty 값들이 다 이상값들)

SELECT
	*
FROM bronze.olist_products
WHERE product_photos_qty > 99 OR product_photos_qty < 0 -- 610건(위에서 name_length, description_length, photos_qty 값들이 다 이상값들)

SELECT
	*
FROM bronze.olist_products
WHERE product_weight_g < 0 OR product_weight_g > 99999 -- 2건

SELECT
	*
FROM bronze.olist_products
WHERE product_length_cm < 0 OR product_length_cm > 99999 -- 2건

SELECT
	*
FROM bronze.olist_products
WHERE product_height_cm < 0 OR product_height_cm > 99999 -- 2건

SELECT
	*
FROM bronze.olist_products
WHERE product_width_cm < 0 OR product_width_cm > 99999 -- 2건


-----------------------------------------------------------------------
WITH CTE_t1 AS(
    SELECT
        product_id,
        LOWER(TRIM(product_category_name)) AS product_category_name,
        product_name_lenght,
        product_description_lenght,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
    FROM bronze.olist_products
    WHERE product_id IS NOT NULL
)
, CTE_t2 AS(
    SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS rn
    FROM CTE_t1
)
, CTE_t3 AS(
    SELECT
    product_id,
    COALESCE(product_category_name, 'unknown') AS product_category_name,       
    CASE
        WHEN product_name_lenght >= 0 THEN product_name_lenght
        ELSE NULL
    END AS product_name_length, -- 음수 제거
    CASE
        WHEN product_description_lenght >= 0 THEN product_description_lenght
        ELSE NULL
    END AS product_description_length, -- 음수 제거
    CASE
        WHEN product_photos_qty >= 0 THEN product_photos_qty
        ELSE NULL
    END AS product_photos_qty, -- 음수 제거
    CASE
        WHEN product_weight_g >= 0  THEN product_weight_g
        ELSE NULL
    END AS product_weight_g,
    CASE
        WHEN product_length_cm > 0  THEN product_length_cm
        ELSE NULL
    END AS product_length_cm,
    CASE
        WHEN product_height_cm > 0  THEN product_height_cm
        ELSE NULL
    END AS product_height_cm,
    CASE
        WHEN product_width_cm > 0   THEN product_width_cm
        ELSE NULL
    END AS product_width_cm,               
    CASE
        WHEN product_length_cm > 0 AND product_height_cm > 0 AND product_width_cm > 0   THEN (product_length_cm * product_height_cm * product_width_cm)
        ELSE NULL
    END AS product_volume, -- 상품 부피        
    CASE
        WHEN product_weight_g > 0 AND product_length_cm > 0 AND product_height_cm > 0 AND product_width_cm > 0  THEN product_weight_g / (product_length_cm * product_height_cm * product_width_cm)
        ELSE NULL
    END AS product_density, -- 상품 밀도
    CASE
        WHEN (product_length_cm * product_height_cm * product_width_cm) < 1000 THEN 'small'
        WHEN (product_length_cm * product_height_cm * product_width_cm) < 10000 THEN 'medium'
        ELSE 'large'
    END AS size_category -- 크기 분류
    FROM CTE_t2
    WHERE rn = 1
)

SELECT
    *
FROM CTE_t3

-- expression을(를) 데이터 형식 bigint(으)로 변환하는 중 산술 오버플로 오류가 발생했습니다. 오류발생
UPDATE bronze.olist_products
SET product_name_lenght = NULL
WHERE product_name_lenght = -9223372036854775808

UPDATE bronze.olist_products
SET product_description_lenght = NULL
WHERE product_description_lenght = -9223372036854775808

UPDATE bronze.olist_products
SET product_photos_qty = NULL
WHERE product_photos_qty = -9223372036854775808

UPDATE bronze.olist_products
SET product_weight_g = NULL
WHERE product_weight_g = -9223372036854775808

UPDATE bronze.olist_products
SET product_length_cm = NULL
WHERE product_length_cm = -9223372036854775808

UPDATE bronze.olist_products
SET product_height_cm = NULL
WHERE product_height_cm = -9223372036854775808

UPDATE bronze.olist_products
SET product_width_cm = NULL
WHERE product_width_cm = -9223372036854775808

----------------------------------------------------------------------------
WITH CTE_t1 AS(
    SELECT
        product_id,
        LOWER(TRIM(product_category_name)) AS product_category_name,
        product_name_lenght,
        product_description_lenght,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
    FROM bronze.olist_products
    WHERE product_id IS NOT NULL
)
, CTE_t2 AS(
    SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS rn
    FROM CTE_t1
)
, CTE_t3 AS(
    SELECT
    product_id,
    COALESCE(product_category_name, 'unknown') AS product_category_name,       
    CASE
        WHEN product_name_lenght >= 0 THEN product_name_lenght
        ELSE NULL
    END AS product_name_length, -- 음수 제거
    CASE
        WHEN product_description_lenght >= 0 THEN product_description_lenght
        ELSE NULL
    END AS product_description_length, -- 음수 제거
    CASE
        WHEN product_photos_qty >= 0 THEN product_photos_qty
        ELSE NULL
    END AS product_photos_qty, -- 음수 제거
    CASE
        WHEN product_weight_g >= 0  THEN product_weight_g
        ELSE NULL
    END AS product_weight_g,
    CASE
        WHEN product_length_cm > 0  THEN product_length_cm
        ELSE NULL
    END AS product_length_cm,
    CASE
        WHEN product_height_cm > 0  THEN product_height_cm
        ELSE NULL
    END AS product_height_cm,
    CASE
        WHEN product_width_cm > 0   THEN product_width_cm
        ELSE NULL
    END AS product_width_cm,               
    CASE
        WHEN product_length_cm > 0 AND product_height_cm > 0 AND product_width_cm > 0   THEN (product_length_cm * product_height_cm * product_width_cm)
        ELSE NULL
    END AS product_volume, -- 상품 부피        
    CASE
        WHEN product_weight_g > 0 AND product_length_cm > 0 AND product_height_cm > 0 AND product_width_cm > 0  
            THEN ROUND(CAST(product_weight_g AS FLOAT) / (product_length_cm * product_height_cm * product_width_cm), 2)
        ELSE NULL
    END AS product_density, -- 상품 밀도
    CASE
        WHEN (product_length_cm * product_height_cm * product_width_cm) < 1000 THEN 'small'
        WHEN (product_length_cm * product_height_cm * product_width_cm) < 10000 THEN 'medium'
        ELSE 'large'
    END AS product_size_category -- 크기 분류
    FROM CTE_t2
    WHERE rn = 1
)

SELECT
    *
FROM CTE_t3

-------------------------------------------------------------------------------------------

-- 최종적으로 cleansing된 테이블의 데이터를 다시 테이블에 insert
GO
WITH CTE_t1 AS(
    SELECT
        product_id,
        LOWER(TRIM(product_category_name)) AS product_category_name,
        product_name_lenght,
        product_description_lenght,
        product_photos_qty,
        product_weight_g,
        product_length_cm,
        product_height_cm,
        product_width_cm
    FROM bronze.olist_products
    WHERE product_id IS NOT NULL
)
, CTE_t2 AS(
    SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS rn
    FROM CTE_t1
)
, CTE_t3 AS(
    SELECT
    product_id,
    COALESCE(product_category_name, 'unknown') AS product_category_name,       
    CASE
        WHEN product_name_lenght >= 0 THEN product_name_lenght
        ELSE NULL
    END AS product_name_length, -- 음수 제거
    CASE
        WHEN product_description_lenght >= 0 THEN product_description_lenght
        ELSE NULL
    END AS product_description_length, -- 음수 제거
    CASE
        WHEN product_photos_qty >= 0 THEN product_photos_qty
        ELSE NULL
    END AS product_photos_qty, -- 음수 제거
    CASE
        WHEN product_weight_g >= 0  THEN product_weight_g
        ELSE NULL
    END AS product_weight_g,
    CASE
        WHEN product_length_cm > 0  THEN product_length_cm
        ELSE NULL
    END AS product_length_cm,
    CASE
        WHEN product_height_cm > 0  THEN product_height_cm
        ELSE NULL
    END AS product_height_cm,
    CASE
        WHEN product_width_cm > 0   THEN product_width_cm
        ELSE NULL
    END AS product_width_cm,               
    CASE
        WHEN product_length_cm > 0 AND product_height_cm > 0 AND product_width_cm > 0   THEN (product_length_cm * product_height_cm * product_width_cm)
        ELSE NULL
    END AS product_volume, -- 상품 부피        
    CASE
        WHEN product_weight_g > 0 AND product_length_cm > 0 AND product_height_cm > 0 AND product_width_cm > 0  
            THEN ROUND(CAST(product_weight_g AS FLOAT) / (product_length_cm * product_height_cm * product_width_cm), 2)
        ELSE NULL
    END AS product_density, -- 상품 밀도
    CASE
        WHEN (product_length_cm * product_height_cm * product_width_cm) < 1000 THEN 'small'
        WHEN (product_length_cm * product_height_cm * product_width_cm) < 10000 THEN 'medium'
        ELSE 'large'
    END AS product_size_category -- 크기 분류
    FROM CTE_t2
    WHERE rn = 1
)

INSERT INTO silver.olist_products(
    product_id,
    product_category_name,
    product_name_length,
    product_description_length,
    product_photos_qty,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_volumne,
    product_density,
    product_size_cateogry
)
SELECT
    *
FROM CTE_t3
GO


-- Insert 한 후 처음했던 Quality Check해보기
-- Re-run the quality chekc querires from the bronze layer to verify the quality of data in silver layer

SELECT
    *
FROM silver.olist_products

SELECT
    *
FROM(
        SELECT 
            *,
            ROW_NUMBER() OVER (PARTITION BY product_id ORDER BY product_id) AS rn
        FROM silver.olist_products
)t
WHERE rn >= 2 -- 결과 값이 없음(중복되는 값이 없음)

-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	product_category_name
FROM silver.olist_products
WHERE product_category_name != TRIM(product_category_name); -- 결과없음

SELECT
	*
FROM silver.olist_products
WHERE product_category_name IS NULL -- 결과없음(NULL -> unknown으로 바뀜)

SELECT
    *
FROM silver.olist_products
WHERE product_name_length IS NULL -- 610개의 값(product_name_legth, product_description_length, product_photos_qty값이 -9223372036854775808 -> NULL로 바뀜)

SELECT
    *
FROM silver.olist_products
WHERE product_weight_g IS NULL -- 2개의 값(product_weight_g, product_length_cm, product_height_cm, product_width_cm값이 -9223372036854775808 -> NULL로 바뀜)

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
	*
FROM silver.olist_products
WHERE product_name_length > 999 OR product_description_length > 9999 OR product_name_length < 0 OR product_description_length < 0 -- 결과값 없음

SELECT
	*
FROM silver.olist_products
WHERE product_photos_qty > 99 OR product_photos_qty < 0 -- 결과값 없음

SELECT
	*
FROM silver.olist_products
WHERE product_weight_g < 0 OR product_weight_g > 99999 -- 결과값 없음

SELECT
	*
FROM silver.olist_products
WHERE product_length_cm < 0 OR product_length_cm > 99999 -- 결과값 없음

SELECT
	*
FROM silver.olist_products
WHERE product_height_cm < 0 OR product_height_cm > 99999 -- 결과값 없음

SELECT
	*
FROM silver.olist_products
WHERE product_width_cm < 0 OR product_width_cm > 99999 -- 결과값 없음

SELECT
    *
FROM silver.olist_products
WHERE product_size_cateogry NOT IN ('small', 'medium', 'large') -- 결과값 없음





/* Create DDL for Tables(silver.olist_sellers) */
IF OBJECT_ID('silver.olist_sellers', 'U') IS NOT NULL
	DROP TABLE silver.olist_sellers;  
CREATE TABLE silver.olist_sellers(
	seller_id CHAR(32),
    seller_zip_code_prefix char(8),
    seller_city NVARCHAR(50),
    seller_state NVARCHAR(10),
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- 메타 데이터 컬럼(데이터 흐름추정, 최신성 보장, 데이터 품질 및 감사, 증분 적재관리 등을 위해 추가)
);

/* Build Silver Layer
Clean & Load (olist_sellers) */
-- 테이블의 컬럼을 하나씩 보면서 다른테이블과 연결한것이 있거나 그 자체로 cleansing해야할것이 있다면 하면됨

-- Chcek For Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT
    *
FROM bronze.olist_sellers

SELECT
    *
FROM(
    SELECT
        *,
        ROW_NUMBER() OVER(PARTITION BY seller_id ORDER BY seller_id) AS rn
    FROM bronze.olist_sellers
)t
WHERE rn >= 2 -- 중복되는 값 없음


-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	seller_city
FROM bronze.olist_sellers
WHERE seller_city != TRIM(seller_city); -- 결과없음

SELECT
	DISTINCT seller_city
FROM bronze.olist_sellers

WHERE seller_city != TRIM(seller_city); -- 결과없음

SELECT
	seller_state
FROM bronze.olist_sellers
WHERE seller_state != TRIM(seller_state); -- 결과없음

SELECT
    DISTINCT seller_state
FROM bronze.olist_sellers;

-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
    *
FROM bronze.olist_sellers
WHERE seller_zip_code_prefix NOT BETWEEN '1000' AND '99999'; -- 결과값 없음

--------------------------------------------------------------------------------
WITH CTE_t1 AS(
SELECT
    seller_id,
    seller_zip_code_prefix,
    LOWER(TRIM(seller_city)) AS seller_city,
    UPPER(TRIM(seller_state)) AS seller_state
FROM bronze.olist_sellers
WHERE seller_zip_code_prefix BETWEEN '1000' AND '99999'
)
, CTE_t2 AS(
SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY seller_id) AS rn
FROM CTE_t1
)
, CTE_t3 AS(
SELECT
    seller_id,
    seller_zip_code_prefix,
    LOWER(TRANSLATE(seller_city, N'áàâãäéèêëíìîïóòôõöúùûüçñ', N'aaaaaeeeeiiiiooooouuuucn')) AS seller_city, -- accent 제거, 특수문자 정규화
    seller_state
FROM CTE_t2
WHERE rn = 1
)

SELECT
    *
FROM CTE_t3

-------------------------------------------------------------------------------------------

-- 최종적으로 cleansing된 테이블의 데이터를 다시 테이블에 insert
GO
WITH CTE_t1 AS(
SELECT
    seller_id,
    seller_zip_code_prefix,
    LOWER(TRIM(seller_city)) AS seller_city,
    UPPER(TRIM(seller_state)) AS seller_state
FROM bronze.olist_sellers
WHERE seller_zip_code_prefix BETWEEN '1000' AND '99999'
)
, CTE_t2 AS(
SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY seller_id ORDER BY seller_id) AS rn
FROM CTE_t1
)
, CTE_t3 AS(
SELECT
    seller_id,
    seller_zip_code_prefix,
    LOWER(TRANSLATE(seller_city, N'áàâãäéèêëíìîïóòôõöúùûüçñ', N'aaaaaeeeeiiiiooooouuuucn')) AS seller_city, -- accent 제거, 특수문자 정규화
    seller_state
FROM CTE_t2
WHERE rn = 1
)

INSERT INTO silver.olist_sellers(
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state
)
SELECT
    *
FROM CTE_t3
GO

-- Insert 한 후 처음했던 Quality Check해보기
-- Re-run the quality chekc querires from the bronze layer to verify the quality of data in silver layer

SELECT
    *
FROM silver.olist_sellers

SELECT
    *
FROM(
    SELECT
        *,
        ROW_NUMBER() OVER(PARTITION BY seller_id ORDER BY seller_id) AS rn
    FROM silver.olist_sellers
)t
WHERE rn >= 2 -- 중복되는 값 없음

-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	seller_city
FROM silver.olist_sellers
WHERE seller_city != TRIM(seller_city); -- 결과값 없음

SELECT
	seller_state
FROM silver.olist_sellers
WHERE seller_state != TRIM(seller_state); -- 결과값 없음


-- Quality Check
-- Check the consistency of values in low cardinality columns 
-- Data Standardization & Consistency

SELECT
    *
FROM silver.olist_sellers
WHERE seller_zip_code_prefix NOT BETWEEN '1000' AND '99999' -- 결과값 없음













/* Create DDL for Tables(silver.product_category_name_translation) */
IF OBJECT_ID('silver.product_category_name_translation', 'U') IS NOT NULL
	DROP TABLE silver.product_category_name_translation;  
CREATE TABLE silver.product_category_name_translation(
	product_category_name NVARCHAR(50),
    product_category_name_english NVARCHAR(50),
	dwh_create_date DATETIME2 DEFAULT GETDATE() -- 메타 데이터 컬럼(데이터 흐름추정, 최신성 보장, 데이터 품질 및 감사, 증분 적재관리 등을 위해 추가)
);

/* Build Silver Layer
Clean & Load (product_category_name_translation) */
-- 테이블의 컬럼을 하나씩 보면서 다른테이블과 연결한것이 있거나 그 자체로 cleansing해야할것이 있다면 하면됨

-- Chcek For Nulls or Duplicates in Primary Key
-- Expectation: No Result

SELECT
    *
FROM bronze.product_category_name_translation

SELECT
    *
FROM(
SELECT
    *,
    ROW_NUMBER() OVER(PARTITION BY product_category_name ORDER BY product_category_name) AS rn
FROM bronze.product_category_name_translation
)t
WHERE rn >= 2 -- 중복되는 값 없음

-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	product_category_name
FROM bronze.product_category_name_translation
WHERE product_category_name != TRIM(product_category_name);

SELECT
    DISTINCT product_category_name
FROM bronze.product_category_name_translation

SELECT
	product_category_name_english
FROM bronze.product_category_name_translation
WHERE product_category_name_english != TRIM(product_category_name_english);

SELECT
    DISTINCT product_category_name_english
FROM bronze.product_category_name_translation;

---------------------------------------------------
WITH CTE_t1 AS(
SELECT
    LOWER(TRIM(product_category_name)) AS product_category_name,
    LOWER(TRIM(product_category_name_english)) AS product_category_name_english
FROM bronze.product_category_name_translation
WHERE product_category_name IS NOT NULL
)
, CTE_t2 AS(
SELECT
    *,
    ROW_NUMBER() OVER(PARTITION BY product_category_name ORDER BY product_category_name) AS rn
FROM CTE_t1   
)
, CTE_t3 AS(
SELECT
    LOWER(TRANSLATE(product_category_name, N'áàâãäéèêëíìîïóòôõöúùûüçñ', N'aaaaaeeeeiiiiooooouuuucn')) AS product_category_name, -- accent 제거, 특수문자 정규화
    CASE
        WHEN product_category_name_english IS NOT NULL THEN product_category_name_english
        ELSE 'unknown'
    END AS product_category_name_english
FROM CTE_t2
WHERE rn = 1
)
SELECT
    *
FROM CTE_t3

-------------------------------------------------------------------------------------------

-- 최종적으로 cleansing된 테이블의 데이터를 다시 테이블에 insert
GO
WITH CTE_t1 AS(
SELECT
    LOWER(TRIM(product_category_name)) AS product_category_name,
    LOWER(TRIM(product_category_name_english)) AS product_category_name_english
FROM bronze.product_category_name_translation
WHERE product_category_name IS NOT NULL
)
, CTE_t2 AS(
SELECT
    *,
    ROW_NUMBER() OVER(PARTITION BY product_category_name ORDER BY product_category_name) AS rn
FROM CTE_t1   
)
, CTE_t3 AS(
SELECT
    LOWER(TRANSLATE(product_category_name, N'áàâãäéèêëíìîïóòôõöúùûüçñ', N'aaaaaeeeeiiiiooooouuuucn')) AS product_category_name, -- accent 제거, 특수문자 정규화
    CASE
        WHEN product_category_name_english IS NOT NULL THEN product_category_name_english
        ELSE 'unknown'
    END AS product_category_name_english
FROM CTE_t2
WHERE rn = 1
)

INSERT INTO silver.product_category_name_translation(
product_category_name,
product_category_name_english
)
SELECT
    *
FROM CTE_t3
GO

-- Insert 한 후 처음했던 Quality Check해보기
-- Re-run the quality chekc querires from the bronze layer to verify the quality of data in silver layer

SELECT
    *
FROM silver.product_category_name_translation

SELECT
    *
FROM(
SELECT
    *,
    ROW_NUMBER() OVER(PARTITION BY product_category_name ORDER BY product_category_name) AS rn
FROM silver.product_category_name_translation
)t
WHERE rn >= 2

-- Quality Check
-- Check for unwanted spaces in string values
-- Chekc for unwanted Spaces
-- Expectation: No Results

SELECT
	product_category_name
FROM silver.product_category_name_translation
WHERE product_category_name != TRIM(product_category_name)

SELECT
    DISTINCT product_category_name
FROM silver.product_category_name_translation

SELECT
	product_category_name_english
FROM silver.product_category_name_translation
WHERE product_category_name_english != TRIM(product_category_name_english)

SELECT
    DISTINCT product_category_name_english
FROM silver.product_category_name_translation
