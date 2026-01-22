#!/bin/bash
# Insert test data that simulates Big-5 encoding corruption from Oracle US7ASCII databases
#
# Background:
# When Oracle JDBC reads VARCHAR2 from a US7ASCII database containing Big-5 bytes,
# it converts bytes >= 0x80 to Unicode halfwidth range (0xFFxx).
# For example: Big-5 測試 (B4 FA B8 D5) becomes ﾴ￺ﾸￕ (U+FFB4 U+FFFA U+FFB8 U+FFD5)
#
# This script inserts data with these halfwidth characters to test the
# LegacyCharsetTransform SMT which decodes them back to proper UTF-8.

set -e

ORACLE_HOST="${ORACLE_HOST:-localhost}"
ORACLE_PORT="${ORACLE_PORT:-1521}"

echo "Waiting for Oracle to be ready..."
until sqlplus -S testuser/testpwd@//${ORACLE_HOST}:${ORACLE_PORT}/FREEPDB1 <<< "SELECT 1 FROM DUAL;" > /dev/null 2>&1; do
    echo "Oracle not ready, waiting..."
    sleep 5
done

echo "Oracle is ready. Inserting Big-5 test data (simulated halfwidth corruption)..."

# Big-5 character to Unicode halfwidth mapping:
# 測 = B4 FA -> U+FFB4 U+FFFA (ﾴ￺)
# 試 = B8 D5 -> U+FFB8 U+FFD5 (ﾸￕ)
# 中 = A4 A4 -> U+FFA4 U+FFA4 (ﾤﾤ)
# 文 = A4 E5 -> U+FFA4 U+FFE5 (ﾤ￥)
# 你 = A7 41 -> U+FFA7 U+0041 (ﾧA)
# 好 = A6 6E -> U+FFA6 U+006E (ﾦn)
# 世 = A5 40 -> U+FFA5 U+0040 (ﾥ@)
# 界 = AC C9 -> U+FFAC U+FFC9 (ﾬ￉)
# 台 = A5 78 -> U+FFA5 U+0078 (ﾥx)
# 北 = A5 5F -> U+FFA5 U+005F (ﾥ_)
# 市 = A5 AB -> U+FFA5 U+FFAB (ﾥﾫ)

sqlplus -S testuser/testpwd@//${ORACLE_HOST}:${ORACLE_PORT}/FREEPDB1 << 'EOF'
SET SERVEROUTPUT ON

-- Clear existing data
DELETE FROM customers;

-- Record 1: name=測試 address=台北市 description=測試中文
-- Using UNISTR to insert halfwidth characters that simulate JDBC corruption
INSERT INTO customers (id, name, address, description) VALUES (
    1,
    UNISTR('\FFB4\FFFA\FFB8\FFD5'),
    UNISTR('\FFA5\0078\FFA5\005F\FFA5\FFAB'),
    UNISTR('\FFB4\FFFA\FFB8\FFD5\FFA4\FFA4\FFA4\FFE5')
);

-- Record 2: name=你好 address=世界 description=你好世界
INSERT INTO customers (id, name, address, description) VALUES (
    2,
    UNISTR('\FFA7\0041\FFA6\006E'),
    UNISTR('\FFA5\0040\FFAC\FFC9'),
    UNISTR('\FFA7\0041\FFA6\006E\FFA5\0040\FFAC\FFC9')
);

-- Record 3: Mixed ASCII and Big-5 (name=Customer-台北 address=台北市-District)
INSERT INTO customers (id, name, address, description) VALUES (
    3,
    'Customer-' || UNISTR('\FFA5\0078\FFA5\005F'),
    UNISTR('\FFA5\0078\FFA5\005F\FFA5\FFAB') || '-District',
    'Mixed content with ' || UNISTR('\FFA4\FFA4\FFA4\FFE5')
);

COMMIT;

-- Show what was inserted
SELECT 'Inserted ' || COUNT(*) || ' records' AS result FROM customers;
SELECT id, name, address FROM customers;
EOF

echo ""
echo "Big-5 test data inserted successfully!"
echo ""
echo "Expected transformations when SMT is enabled:"
echo "  ﾴ￺ﾸￕ -> 測試"
echo "  ﾥxﾥ_ﾥﾫ -> 台北市"
echo "  ﾧAﾦn -> 你好"
echo "  ﾥ@ﾬ￉ -> 世界"
