-- Create table and insert Big-5 encoded test data
-- This simulates a legacy Oracle US7ASCII database storing Big-5 bytes directly

ALTER SESSION SET CONTAINER = XEPDB1;

-- Create test table in CDC user's schema
CREATE TABLE c##dbzuser.big5_test (
    id NUMBER PRIMARY KEY,
    name VARCHAR2(100),
    address VARCHAR2(200),
    description VARCHAR2(500)
);

-- Enable supplemental logging for this table
ALTER TABLE c##dbzuser.big5_test ADD SUPPLEMENTAL LOG DATA (ALL) COLUMNS;

EXIT;
