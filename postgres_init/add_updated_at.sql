-- ============================================================
-- SCRIPT: Thêm updated_at Watermark vào ecommerce schema
-- MỤC ĐÍCH : Cho phép Bronze layer làm Incremental Load
-- CHẠY    : 1 lần duy nhất trên PostgreSQL container đang chạy
-- ============================================================

-- ──────────────────────────────────────────────────────────
-- BƯỚC 1: THÊM CỘT updated_at VÀO TẤT CẢ BẢNG
-- DEFAULT now() → backfill toàn bộ rows hiện có = thời điểm chạy script
-- ──────────────────────────────────────────────────────────
ALTER TABLE ecommerce.categories   ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.suppliers    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.warehouses   ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.employees    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.customers    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.products     ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.orders       ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.order_items  ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.payments     ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.shipments    ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();
ALTER TABLE ecommerce.returns      ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT now();


-- ──────────────────────────────────────────────────────────
-- BƯỚC 2: TẠO TRIGGER FUNCTION (viết 1 lần, dùng cho tất cả)
-- Mỗi khi bất kỳ row nào bị UPDATE → updated_at tự động = now()
-- ──────────────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION ecommerce.set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;


-- ──────────────────────────────────────────────────────────
-- BƯỚC 3: GẮN TRIGGER VÀO TỪNG BẢNG
-- BEFORE UPDATE → cập nhật updated_at TRƯỚC khi ghi row
-- ──────────────────────────────────────────────────────────

-- Reference tables (ít thay đổi)
CREATE OR REPLACE TRIGGER trg_categories_updated_at
    BEFORE UPDATE ON ecommerce.categories
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

CREATE OR REPLACE TRIGGER trg_suppliers_updated_at
    BEFORE UPDATE ON ecommerce.suppliers
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

CREATE OR REPLACE TRIGGER trg_warehouses_updated_at
    BEFORE UPDATE ON ecommerce.warehouses
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

CREATE OR REPLACE TRIGGER trg_employees_updated_at
    BEFORE UPDATE ON ecommerce.employees
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

-- Dimension tables (SCD1, có thể UPDATE)
CREATE OR REPLACE TRIGGER trg_customers_updated_at
    BEFORE UPDATE ON ecommerce.customers
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

CREATE OR REPLACE TRIGGER trg_products_updated_at
    BEFORE UPDATE ON ecommerce.products
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

-- Transaction tables (thường xuyên UPDATE status)
CREATE OR REPLACE TRIGGER trg_orders_updated_at
    BEFORE UPDATE ON ecommerce.orders
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

CREATE OR REPLACE TRIGGER trg_order_items_updated_at
    BEFORE UPDATE ON ecommerce.order_items
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

CREATE OR REPLACE TRIGGER trg_payments_updated_at
    BEFORE UPDATE ON ecommerce.payments
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

CREATE OR REPLACE TRIGGER trg_shipments_updated_at
    BEFORE UPDATE ON ecommerce.shipments
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();

CREATE OR REPLACE TRIGGER trg_returns_updated_at
    BEFORE UPDATE ON ecommerce.returns
    FOR EACH ROW EXECUTE FUNCTION ecommerce.set_updated_at();


-- ──────────────────────────────────────────────────────────
-- BƯỚC 4: VERIFY — Kiểm tra trigger đã hoạt động đúng chưa
-- ──────────────────────────────────────────────────────────

-- Xem updated_at hiện tại của 1 customer
SELECT customer_id, loyalty_tier, updated_at 
FROM ecommerce.customers 
WHERE customer_id = 1;

-- Thực hiện UPDATE thử
UPDATE ecommerce.customers 
SET loyalty_tier = 'Gold' 
WHERE customer_id = 1;

-- Kiểm tra: updated_at phải thay đổi thành timestamp hiện tại
SELECT customer_id, loyalty_tier, updated_at 
FROM ecommerce.customers 
WHERE customer_id = 1;

-- Khôi phục lại
UPDATE ecommerce.customers 
SET loyalty_tier = 'Bronze' 
WHERE customer_id = 1;


-- ──────────────────────────────────────────────────────────
-- BƯỚC 5: Kiểm tra tất cả trigger đã tồn tại
-- ──────────────────────────────────────────────────────────
SELECT 
    trigger_name,
    event_object_table  AS table_name,
    action_timing,
    event_manipulation
FROM information_schema.triggers
WHERE trigger_schema = 'ecommerce'
ORDER BY event_object_table, trigger_name;
