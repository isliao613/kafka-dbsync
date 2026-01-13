# Debezium 2.x vs 3.x Data Type Comparison Results

Generated: 2026-01-13

## Test Environment

- **Oracle**: XE 21c (gvenzl/oracle-xe:21-slim)
- **MariaDB**: 11.x
- **Debezium 2.x**: 2.6.1.Final (Kafka Connect 7.6.1, Java 11)
- **Debezium 3.x**: 3.4.0.Final (Kafka Connect 7.8.0, Java 17)
- **Configuration**: `decimal.handling.mode` not set (using defaults)

## Schema Comparison (SOURCE_ORDERS Table)

### Oracle Source Schema

```sql
CREATE TABLE DEMO.SOURCE_ORDERS (
    ID NUMBER(10) NOT NULL PRIMARY KEY,
    ORDER_NO VARCHAR2(50) NOT NULL,
    CUSTOMER_NAME VARCHAR2(100) NOT NULL,
    AMOUNT NUMBER(15,2) NOT NULL,
    STATUS VARCHAR2(20) DEFAULT 'PENDING' NOT NULL,
    CREATED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    MODIFIED_AT TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL
);
```

### MariaDB Target Schema Comparison

| Oracle Column | Oracle Type | Debezium 2.x (MariaDB) | Debezium 3.x (MariaDB) | Match |
|---------------|-------------|------------------------|------------------------|-------|
| ID | NUMBER(10) | `bigint(20)` | `bigint(20)` | Yes |
| ORDER_NO | VARCHAR2(50) | `text` | `text` | Yes |
| CUSTOMER_NAME | VARCHAR2(100) | `text` | `text` | Yes |
| AMOUNT | NUMBER(15,2) | `decimal(65,2)` | `decimal(65,2)` | Yes |
| STATUS | VARCHAR2(20) | `text` | `text` | Yes |
| CREATED_AT | TIMESTAMP | `bigint(20)` | `bigint(20)` | Yes |
| MODIFIED_AT | TIMESTAMP | `bigint(20)` | `bigint(20)` | Yes |

**Result: Schema is IDENTICAL between Debezium 2.x and 3.x**

## Data Comparison

### Debezium 2.x Output (target_orders)

| ID | ORDER_NO | CUSTOMER_NAME | AMOUNT | STATUS | CREATED_AT | MODIFIED_AT |
|----|----------|---------------|--------|--------|------------|-------------|
| 1 | ORD-001 | Alice | 1500.00 | PENDING | 1768285955277615 | 1768285955277615 |
| 2 | ORD-002 | Bob | 2300.50 | COMPLETED | 1768285955282125 | 1768285955282125 |
| 3 | ORD-003 | Charlie | 890.00 | PENDING | 1768285955283989 | 1768285955283989 |
| 4 | ORD-004 | Diana | 4200.75 | SHIPPED | 1768285955285616 | 1768285955285616 |

### Debezium 3.x Output (target_orders_3x)

| ID | ORDER_NO | CUSTOMER_NAME | AMOUNT | STATUS | CREATED_AT | MODIFIED_AT |
|----|----------|---------------|--------|--------|------------|-------------|
| 1 | ORD-001 | Alice | 1500.00 | PENDING | 1768285955277615 | 1768285955277615 |
| 2 | ORD-002 | Bob | 2300.50 | COMPLETED | 1768285955282125 | 1768285955282125 |
| 3 | ORD-003 | Charlie | 890.00 | PENDING | 1768285955283989 | 1768285955283989 |
| 4 | ORD-004 | Diana | 4200.75 | SHIPPED | 1768285955285616 | 1768285955285616 |

### Row-by-Row Comparison

| ID | ORDER_NO | 2.x AMOUNT | 3.x AMOUNT | Match |
|----|----------|------------|------------|-------|
| 1 | ORD-001 | 1500.00 | 1500.00 | YES |
| 2 | ORD-002 | 2300.50 | 2300.50 | YES |
| 3 | ORD-003 | 890.00 | 890.00 | YES |
| 4 | ORD-004 | 4200.75 | 4200.75 | YES |

**Result: Data is IDENTICAL between Debezium 2.x and 3.x**

## Key Findings

### 1. Schema Compatibility
- Both Debezium 2.x and 3.x produce **identical MariaDB schemas** for standard Oracle data types
- `NUMBER(n)` maps to `bigint(20)` in both versions
- `NUMBER(n,m)` maps to `decimal(65,m)` in both versions
- `VARCHAR2(n)` maps to `text` in both versions
- `TIMESTAMP` maps to `bigint(20)` (microseconds since epoch) in both versions

### 2. Data Integrity
- All values are **identical** between 2.x and 3.x replicated data
- Decimal precision is preserved correctly
- Timestamp precision is preserved (microsecond level)

### 3. Configuration Differences
Both versions use the same default settings for basic data types. The `decimal.handling.mode` configuration affects behavior:

| Mode | Behavior |
|------|----------|
| `precise` (default) | Uses Kafka Connect Decimal schema |
| `double` | Converts to float64 (may lose precision) |
| `string` | Converts to string (safe for all values) |

## Recommendations

1. **Migration Path**: Debezium 2.x to 3.x migration is **safe** for standard Oracle data types
2. **Testing**: Always test with your specific table schemas before production migration
3. **LOB Columns**: Test CLOB/BLOB handling separately (requires `lob.enabled=true`)
4. **Timestamp Zones**: `TIMESTAMP WITH TIME ZONE` behavior should be validated for your timezone requirements

## Test Commands

```bash
# Deploy dual Debezium setup
make all-dual

# Run basic E2E test
make e2e-dual

# Verify data in both tables
make verify-2x
make verify-3x
```

---

*Report generated from kafka-dbsync project*
*Branch: 2x-3x-comparision*
