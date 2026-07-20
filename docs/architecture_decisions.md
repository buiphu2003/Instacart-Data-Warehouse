# Data Architecture & Modeling Decisions

Tài liệu này lưu trữ các quyết định kiến trúc quan trọng cho dự án Instacart Sales Data Warehouse. Các Agent/Developer ở các phiên làm việc sau vui lòng đọc kỹ tài liệu này trước khi lập trình.

## 1. Phương pháp Thiết kế Tầng Silver (Star Schema vs Galaxy Schema)
- **Quyết định:** Sử dụng **Transaction Fact Tables** nguyên thủy tại tầng Silver, không join sẵn các bảng Dimensions vào Fact nếu không có sẵn ở nguồn tại thời điểm diễn ra sự kiện. 
- **Lý do:** Đảm bảo tính Immutable (Append-only) cực kỳ thân thiện với hệ thống ClickHouse (tránh lệnh UPDATE đắt đỏ), và duy trì tính nguyên bản của dữ liệu gốc để dễ dàng tái sử dụng.
- **Trạng thái:** Đã triển khai xong cho các luồng `orders`, `order_items`, `shipments`, `payments`, `returns`.

## 2. Lưu vết lịch sử thay đổi trạng thái (SCD Type 2 cho Facts)
- **Vấn đề:** Hệ thống nguồn Postgres thực hiện "Ghi đè" (In-place update / Upsert) các trạng thái của đơn hàng, vận chuyển, v.v., làm mất lịch sử sự kiện.
- **Giải pháp:** Sử dụng **dbt Snapshots** (với `strategy='check'`, `check_cols=['status']`) để tự động bắt các thay đổi dữ liệu từ Postgres.
- **Cấu trúc triển khai:**
  - **Snapshots:** Các file nằm trong thư mục `snapshots/` (vd: `ecommerce_orders_snapshot.sql`).
  - **Bronze Layer (`base_models`):** Trích xuất dữ liệu từ các snapshot này để lấy các trường metadata quý giá (`dbt_valid_from`, `dbt_valid_to`, `dbt_scd_id`).
  - **Silver Current Facts (`fact_orders`, `fact_shipments`...):** Luôn có điều kiện `WHERE dbt_valid_to IS NULL` để đảm bảo bảng Fact này đóng vai trò là "Snapshot hiện tại", không bị phình to làm sai lệch số liệu báo cáo.
  - **Silver History Facts (`fact_orders_history`, `fact_returns_history`...):** Đây là các bảng Event Log (Lịch sử sự kiện). Chúng lưu toàn bộ dữ liệu từ snapshot để phục vụ phân tích Time-series (ví dụ: thời gian từ lúc pending đến lúc shipped).

## 3. Kế hoạch Tầng Gold (Data Marts)
- **Quyết định:** Khi cần query báo cáo, sẽ sử dụng kiến trúc **OBT (One Big Table)** hoặc **Accumulating Snapshot Fact**. 
- **Lý do:** Bù đắp lại việc tầng Silver phải JOIN nhiều bảng Fact. Việc JOIN dồn lại sẽ được dbt thực hiện tự động vào ban đêm để tạo ra một bảng OBT phẳng duy nhất. Columnar Database như ClickHouse query các bảng OBT này với tốc độ ánh sáng (sub-second query).
- **Trạng thái:** Chuẩn bị thiết kế.

## 4. Cách Mô phỏng Môi trường Test
Để test dbt snapshots với dữ liệu gen tĩnh, cần thực hiện Update thủ công trong Postgres để mô phỏng Backend App:
1. Chạy `dbt snapshot` & `dbt run` lần 1.
2. Chạy SQL UPDATE trực tiếp trên Postgres (vd: `UPDATE orders SET status = 'paid' WHERE order_id = 1;`).
3. Chạy lại `dbt snapshot` & `dbt run` lần 2 và kiểm tra bảng `..._history` trong ClickHouse.
