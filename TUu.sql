-- 1. Tạo bảng sách theo đúng mô tả
CREATE TABLE book (
    book_id SERIAL PRIMARY KEY,
    title VARCHAR(255),
    author VARCHAR(100),
    genre VARCHAR(50),
    price DECIMAL(10,2),
    description TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
-- 2. Sinh 500.000 bản ghi dữ liệu mẫu
INSERT INTO book (title, author, genre, price, description)
SELECT 
    'Sách ' || i,
    -- Giả lập cứ 1000 cuốn thì có 1 cuốn của J.K. Rowling
    CASE WHEN i % 1000 = 0 THEN 'J.K. Rowling' ELSE 'Tác giả ' || (i % 100) END,
    -- Phân bổ đều các thể loại
    CASE WHEN i % 5 = 0 THEN 'Fantasy' 
         WHEN i % 5 = 1 THEN 'Science Fiction'
         WHEN i % 5 = 2 THEN 'Romance'
         WHEN i % 5 = 3 THEN 'Thriller'
         ELSE 'Non-fiction' END,
    (random() * 100 + 10)::numeric(10,2),
    'Đây là mô tả chi tiết phục vụ tìm kiếm cho cuốn sách số ' || i
FROM generate_series(1, 500000) AS i;

-- Kiểm tra truy vấn 1 (Tìm kiếm chuỗi với % ở đầu và cuối)
EXPLAIN ANALYZE 
SELECT * FROM book WHERE author ILIKE '%Rowling%';
-- Kiểm tra truy vấn 2 (Tìm kiếm chính xác)
EXPLAIN ANALYZE 
SELECT * FROM book WHERE genre = 'Fantasy';

-- Yêu cầu 3a: Tạo B-tree Index cho cột genre (Tối ưu cho truy vấn 2)
-- B-tree rất hoàn hảo cho các phép toán so sánh bằng (=, >, <)
CREATE INDEX idx_book_genre ON book(genre);

-- Khởi tạo extension pg_trgm (Hỗ trợ tìm kiếm text LIKE/ILIKE)
CREATE EXTENSION IF NOT EXISTS pg_trgm;

-- Tạo GIN Index cho cột author sử dụng trigram (Tối ưu cho truy vấn 1)
CREATE INDEX idx_book_author_trgm ON book USING gin (author gin_trgm_ops);

-- Yêu cầu 3b: Tạo GIN Index cho cột description phục vụ Full-text Search
-- Thay vì dùng LIKE, Full-text Search trong Postgres sử dụng to_tsvector
CREATE INDEX idx_book_desc_fts ON book USING gin (to_tsvector('simple', description));

-- Truy vấn này giờ đây sẽ sử dụng Bitmap Heap Scan qua idx_book_author_trgm
EXPLAIN ANALYZE 
SELECT * FROM book WHERE author ILIKE '%Rowling%';

-- Truy vấn này sẽ sử dụng Bitmap Heap Scan qua idx_book_genre
EXPLAIN ANALYZE 
SELECT * FROM book WHERE genre = 'Fantasy';

-- Gom cụm dữ liệu vật lý theo Index của cột genre
CLUSTER book USING idx_book_genre;

-- Kiểm tra lại hiệu suất
EXPLAIN ANALYZE 
SELECT * FROM book WHERE genre = 'Fantasy';