# IIDR CDC Sink Connector

A Kafka Connect Sink Connector for processing IBM InfoSphere Data Replication (IIDR) CDC events.

## Features

- **A_ENTTYP Mapping**: Maps IBM Journal Entry Type codes to database operations
- **Idempotent Replay**: All INSERT/UPDATE operations use UPSERT for safe replay
- **Multi-Connector Filtering**: Multiple connectors can read the same topic, each processing only matching tables
- **Configurable Error Handling**: Fail, log, or skip corrupt events
- **Auto DDL**: Optionally create tables and evolve schemas automatically
- **Type-Aware Parameter Binding**: Automatically converts string values to the correct JDBC type for date/time columns

## Quick Start

```json
{
    "name": "iidr_sink",
    "config": {
        "connector.class": "com.example.kafka.connect.iidr.IidrCdcSinkConnector",
        "tasks.max": "1",
        "topics": "iidr.CDC.ORDERS",
        "connection.url": "jdbc:mariadb://localhost:3306/target_db",
        "connection.user": "root",
        "connection.password": "password",
        "table.name.format": "${TableName}",
        "pk.mode": "record_key",
        "pk.fields": "ID",
        "auto.create": "true",
        "key.converter": "org.apache.kafka.connect.json.JsonConverter",
        "key.converter.schemas.enable": "false",
        "value.converter": "org.apache.kafka.connect.json.JsonConverter",
        "value.converter.schemas.enable": "false"
    }
}
```

## Event Structure

| Component | Format | Required | Description |
|-----------|--------|----------|-------------|
| Key | JSON | DELETE only | Primary key columns |
| Value | JSON | INSERT/UPDATE | Full row image |
| Headers | Metadata | Always | CDC metadata (TableName, A_ENTTYP, A_TIMSTAMP) |

### Required Headers

| Header | Description |
|--------|-------------|
| `TableName` | Source table name (case-sensitive) |
| `A_ENTTYP` | IIDR Journal Entry Type code |
| `A_TIMSTAMP` | Source timestamp (`yyyy-MM-dd HH:mm:ss.SSSSSS`) |

### A_ENTTYP Operation Mapping

| Operation | Codes | Description |
|-----------|-------|-------------|
| UPSERT | PT, RR, PX, UR | Insert (mapped to UPSERT) |
| UPSERT | UP, FI, FP | Update (mapped to UPSERT) |
| DELETE | DL, DR | Delete |

## Configuration

### Required

| Property | Description |
|----------|-------------|
| `connection.url` | JDBC connection URL |
| `connection.user` | Database username |
| `connection.password` | Database password |

### Table Mapping

| Property | Default | Description |
|----------|---------|-------------|
| `table.name.format` | `${TableName}` | Target table. Supports `${TableName}` and `${topic}` placeholders |
| `pk.mode` | `record_key` | PK source: `record_key`, `record_value`, `none` |
| `pk.fields` | - | Comma-separated PK field names |

### Error Handling

| Property | Default | Description |
|----------|---------|-------------|
| `iidr.errors.tolerance` | `log` | `none` (fail), `log` (warn+skip), `all` (silent skip) |
| `corrupt.events.table` | - | Table for corrupt events (empty=disabled) |

### DDL & Performance

| Property | Default | Description |
|----------|---------|-------------|
| `auto.create` | `false` | Auto-create tables |
| `auto.evolve` | `false` | Auto-add columns |
| `default.timezone` | `UTC` | Timezone for A_TIMSTAMP |
| `batch.size` | `3000` | JDBC batch size |

## Multi-Connector Table Filtering

When `table.name.format` is a **literal value** (no `${TableName}`), the connector only processes records where the `TableName` header matches.

| Format | Behavior |
|--------|----------|
| `${TableName}` | Process all records |
| `ORDERS` | Only process records with `TableName=ORDERS` |
| `PREFIX_${TableName}` | Process all, target = PREFIX_ + TableName |

**Example**: Two connectors reading the same topic, each filtering different tables:

```json
// Connector 1: processes only ORDERS
{ "table.name.format": "ORDERS", "topics": "iidr.CDC.ALL" }

// Connector 2: processes only PRODUCTS
{ "table.name.format": "PRODUCTS", "topics": "iidr.CDC.ALL" }
```

## Event Examples

**INSERT/UPDATE** (A_ENTTYP: PT, UP, etc.):
```json
{
  "key": { "ID": 1 },
  "value": { "ID": 1, "NAME": "Order-001", "AMOUNT": 100.50 },
  "headers": { "TableName": "ORDERS", "A_ENTTYP": "PT", "A_TIMSTAMP": "2026-01-15 10:00:00.000000" }
}
```

**DELETE** (A_ENTTYP: DL, DR):
```json
{
  "key": { "ID": 1 },
  "value": null,
  "headers": { "TableName": "ORDERS", "A_ENTTYP": "DL", "A_TIMSTAMP": "2026-01-15 10:00:00.000000" }
}
```

## Type-Aware Parameter Binding

When record values arrive as JSON strings (schemaless mode), some JDBC drivers (notably PostgreSQL) will reject `setObject(idx, stringValue)` for typed columns like `TIMESTAMP` — they won't implicitly cast `VARCHAR → TIMESTAMP`.

The connector resolves this by querying `DatabaseMetaData.getColumns()` to discover the SQL type of each target column, then using the appropriate typed setter:

| Column SQL Type | JDBC Setter | String Format | Notes |
|---|---|---|---|
| `TIMESTAMP`, `TIMESTAMP WITH TIME ZONE` | `setTimestamp()` | `yyyy-MM-dd HH:mm:ss` or `yyyy-MM-ddTHH:mm:ss` | ISO-8601 `T` separator is normalized to space |
| `DATE` | `setDate()` | `yyyy-MM-dd` | Full datetime strings are truncated to first 10 chars |
| `TIME`, `TIME WITH TIME ZONE` | `setTime()` | `HH:mm:ss` | |

Column type metadata is cached per table and invalidated when `auto.evolve` alters the table. If parsing fails for any value, the connector falls back to `setObject()` (the default JDBC behavior).

### Supported Database Types

| Type Category | MariaDB/MySQL | PostgreSQL |
|---|---|---|
| Timestamp | `DATETIME`, `TIMESTAMP` | `TIMESTAMP`, `TIMESTAMPTZ` |
| Date | `DATE` | `DATE` |
| Time | `TIME` | `TIME`, `TIMETZ` |

## Corrupt Events

Events are corrupt if:
- Missing `TableName` or `A_ENTTYP` header
- Unrecognized `A_ENTTYP` code
- DELETE without key, or INSERT/UPDATE without value

When `corrupt.events.table` is set, corrupt events are logged to:

```sql
CREATE TABLE streaming_corrupt_events (
    id BIGINT AUTO_INCREMENT PRIMARY KEY,
    topic VARCHAR(255) NOT NULL,
    kafka_partition INT NOT NULL,
    kafka_offset BIGINT NOT NULL,
    record_key TEXT,
    record_value LONGTEXT,
    headers TEXT,
    error_reason VARCHAR(1000) NOT NULL,
    table_name VARCHAR(255),
    entry_type VARCHAR(10),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
```

## Building & Testing

```bash
make build-v2    # Build with Debezium 2.x
make build-v3    # Build with Debezium 3.x
make iidr-all-v2 # Run E2E test with 2.x
make iidr-all-v3 # Run E2E test with 3.x
```

## Compatibility

- **Java**: 11 (Debezium 2.x) / 17 (Debezium 3.x)
- **Databases**: MySQL, MariaDB, PostgreSQL, SQL Server, Oracle

## References

- [IBM IIDR Journal Codes](https://www.ibm.com/docs/en/idr/11.4?topic=tables-journal-control-field-header-format)
- [IBM Adding Headers to Kafka Records](https://www.ibm.com/support/pages/node/6252611)
