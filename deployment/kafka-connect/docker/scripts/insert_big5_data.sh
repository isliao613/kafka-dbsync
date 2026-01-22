#!/bin/bash
# Insert test data using raw Big-5 byte values
#
# Background:
# Legacy Oracle US7ASCII databases stored Big-5 bytes directly in VARCHAR2 columns.
# When JDBC reads these, it converts bytes >= 0x80 to Unicode halfwidth (U+FFxx).
# For example: Big-5 測試 (0xB4 0xFA 0xB8 0xD5) -> ﾴ￺ﾸￕ (U+FFB4 U+FFFA U+FFB8 U+FFD5)
#
# This script uses CHR() with raw Big-5 byte values to simulate this data.
# The LegacyCharsetTransform SMT decodes these back to proper UTF-8.

set -e

ORACLE_HOST="${ORACLE_HOST:-localhost}"
ORACLE_PORT="${ORACLE_PORT:-1521}"

echo "Waiting for Oracle to be ready..."
until sqlplus -S c##dbzuser/dbz@//${ORACLE_HOST}:${ORACLE_PORT}/XEPDB1 <<< "SELECT 1 FROM DUAL;" > /dev/null 2>&1; do
    echo "Oracle not ready, waiting..."
    sleep 5
done

echo "Oracle is ready. Inserting Big-5 test data using both CHR() and CONVERT()..."

# Two approaches to insert raw Big-5 bytes:
# 1. CHR() with decimal values: CHR(180)||CHR(250) = 0xB4 0xFA
# 2. CONVERT(): CONVERT('測試', 'ZHT16MSWIN950', 'AL32UTF8')
#
# Big-5 byte mappings:
# 測 = 0xB4 0xFA = CHR(180)||CHR(250)
# 試 = 0xB8 0xD5 = CHR(184)||CHR(213)
# 台 = 0xA5 0x78 = CHR(165)||CHR(120)
# 北 = 0xA5 0x5F = CHR(165)||CHR(95)
# 市 = 0xA5 0xAB = CHR(165)||CHR(171)
# 你 = 0xA7 0x41 = CHR(167)||CHR(65)
# 好 = 0xA6 0x6E = CHR(166)||CHR(110)
# 世 = 0xA5 0x40 = CHR(165)||CHR(64)
# 界 = 0xAC 0xC9 = CHR(172)||CHR(201)
# 中 = 0xA4 0xA4 = CHR(164)||CHR(164)
# 文 = 0xA4 0xE5 = CHR(164)||CHR(229)

sqlplus -S c##dbzuser/dbz@//${ORACLE_HOST}:${ORACLE_PORT}/XEPDB1 << 'EOF'
SET SERVEROUTPUT ON

-- Clear existing data
DELETE FROM big5_test;

-- Record 1: name=測試 address=台北市 description=測試中文
-- Using CHR() with raw Big-5 byte values (decimal)
INSERT INTO big5_test (id, name, address, description) VALUES (
    1,
    CHR(180)||CHR(250)||CHR(184)||CHR(213),
    CHR(165)||CHR(120)||CHR(165)||CHR(95)||CHR(165)||CHR(171),
    CHR(180)||CHR(250)||CHR(184)||CHR(213)||CHR(164)||CHR(164)||CHR(164)||CHR(229)
);

-- Record 2: name=你好 address=世界 description=你好世界
-- Using CONVERT() to convert UTF-8 to Big-5 bytes
INSERT INTO big5_test (id, name, address, description) VALUES (
    2,
    CONVERT('你好', 'ZHT16MSWIN950', 'AL32UTF8'),
    CONVERT('世界', 'ZHT16MSWIN950', 'AL32UTF8'),
    CONVERT('你好世界', 'ZHT16MSWIN950', 'AL32UTF8')
);

-- Record 3: Mixed ASCII and Big-5 (name=Customer-台北 address=台北市-District)
-- Using both approaches: ASCII strings + CHR() for Big-5 + CONVERT()
INSERT INTO big5_test (id, name, address, description) VALUES (
    3,
    'Customer-' || CHR(165)||CHR(120)||CHR(165)||CHR(95),
    CONVERT('台北市', 'ZHT16MSWIN950', 'AL32UTF8') || '-District',
    'Mixed content with ' || CHR(164)||CHR(164)||CHR(164)||CHR(229)
);

COMMIT;

-- Show what was inserted
SELECT 'Inserted ' || COUNT(*) || ' records' AS result FROM big5_test;
SELECT id, name, address FROM big5_test;
EOF

echo ""
echo "Big-5 test data inserted successfully!"
echo ""
echo "Insertion methods used:"
echo "  Record 1: CHR() with Big-5 byte values (decimal)"
echo "  Record 2: CONVERT() function (UTF-8 to Big-5)"
echo "  Record 3: Mixed (ASCII + CHR() + CONVERT())"
echo ""
echo "Expected Big-5 bytes:"
echo "  測試 -> 0xB4 0xFA 0xB8 0xD5"
echo "  台北市 -> 0xA5 0x78 0xA5 0x5F 0xA5 0xAB"
echo "  你好 -> 0xA7 0x41 0xA6 0x6E"
echo "  世界 -> 0xA5 0x40 0xAC 0xC9"
echo ""
echo "The LegacyCharsetTransform SMT will decode Big-5 bytes back to UTF-8."
