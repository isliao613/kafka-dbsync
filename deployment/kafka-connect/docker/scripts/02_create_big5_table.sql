-- Create table and insert Big-5 encoded test data
-- This simulates a legacy Oracle US7ASCII database storing Big-5 bytes directly

ALTER SESSION SET CONTAINER = FREEPDB1;

-- Create test table
CREATE TABLE testuser.customers (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    address VARCHAR2(200),
    description VARCHAR2(500)
);

-- Enable supplemental logging for this table
ALTER TABLE testuser.customers ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

-- Grant permissions to CDC user
GRANT SELECT ON testuser.customers TO c##dbzuser;

EXIT;
