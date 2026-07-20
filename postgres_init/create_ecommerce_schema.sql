-- ============================================================
-- DDL: Tạo ecommerce schema và tất cả tables
-- Chạy script này TRƯỚC generate_ecommerce_data.py
-- 
-- CHANGELOG:
--   [2026-06-30] Thêm cột updated_at vào tất cả bảng
--                Thêm trigger tự động cập nhật updated_at khi có UPDATE
--                Mục đích: hỗ trợ Incremental Load ở tầng Bronze
-- ============================================================

CREATE SCHEMA IF NOT EXISTS ecommerce;

CREATE TABLE IF NOT EXISTS ecommerce.categories (
    category_id         INT,
    category_name       VARCHAR(255),
    parent_category_id  INT,
    updated_at          TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.suppliers (
    supplier_id     INT,
    supplier_name   VARCHAR(255),
    contact_email   VARCHAR(255),
    contact_phone   VARCHAR(100),
    country         VARCHAR(100),
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.warehouses (
    warehouse_id    INT,
    warehouse_name  VARCHAR(255),
    location        TEXT,
    capacity        INT,
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.employees (
    employee_id     INT,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    email           VARCHAR(255),
    hire_date       DATE,
    warehouse_id    INT,
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.customers (
    customer_id     INT,
    first_name      VARCHAR(100),
    last_name       VARCHAR(100),
    email           VARCHAR(255),
    phone           VARCHAR(100),
    address         TEXT,
    loyalty_tier    VARCHAR(50),
    valid_from      TIMESTAMP,
    valid_to        TIMESTAMP,
    is_current      BOOLEAN,
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.products (
    product_id      INT,
    product_name    VARCHAR(255),
    category_id     INT,
    supplier_id     INT,
    price           NUMERIC(10,2),
    valid_from      TIMESTAMP,
    valid_to        TIMESTAMP,
    is_current      BOOLEAN,
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.orders (
    order_id        INT,
    customer_id     INT,
    order_date      TIMESTAMP,
    status          VARCHAR(50),
    total_amount    NUMERIC(12,2),
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.order_items (
    order_id        INT,
    product_id      INT,
    quantity        INT,
    unit_price      NUMERIC(10,2),
    subtotal        NUMERIC(12,2),
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.payments (
    payment_id      INT,
    order_id        INT,
    payment_method  VARCHAR(50),
    amount          NUMERIC(12,2),
    payment_date    TIMESTAMP,
    status          VARCHAR(50),
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.shipments (
    shipment_id     INT,
    order_id        INT,
    warehouse_id    INT,
    shipment_date   TIMESTAMP,
    carrier         VARCHAR(50),
    status          VARCHAR(50),
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);

CREATE TABLE IF NOT EXISTS ecommerce.returns (
    return_id       INT,
    order_id        INT,
    customer_id     INT,
    return_date     TIMESTAMP,
    reason          VARCHAR(100),
    status          VARCHAR(50),
    updated_at      TIMESTAMP DEFAULT now()  -- Watermark cho Incremental Load
);
