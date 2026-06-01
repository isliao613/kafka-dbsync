-- Create Source Table in MariaDB
CREATE DATABASE IF NOT EXISTS source_database;
USE source_database;

DROP TABLE IF EXISTS source_orders;
CREATE TABLE source_orders (
    id INT PRIMARY KEY,
    order_no VARCHAR(50) NOT NULL,
    customer_name VARCHAR(100),
    amount DECIMAL(10, 2),
    status VARCHAR(20),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    modified_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
);

-- Insert Initial Data
INSERT INTO source_orders (id, order_no, customer_name, amount, status) VALUES
(1, 'ORD-001', 'Alice', 100.50, 'CREATED'),
(2, 'ORD-002', 'Bob', 250.00, 'PAID'),
(3, 'ORD-003', 'Charlie', 75.25, 'SHIPPED'),
(4, 'ORD-004', 'David', 500.00, 'DELIVERED');
