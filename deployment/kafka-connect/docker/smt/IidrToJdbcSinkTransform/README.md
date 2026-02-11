# IidrToJdbcSinkTransform SMT

A Kafka Connect SMT that translates IIDR CDC events for use with the Confluent JDBC Sink Connector.

## Background

The custom `IidrCdcSinkConnector` re-implements much of what the Confluent JDBC Sink Connector already provides (dialect-specific UPSERT, auto-create/evolve, type-aware binding). The only IIDR-specific logic is header parsing and operation mapping.

**This SMT** extracts that IIDR-specific logic into a lightweight transform, letting the battle-tested JDBC Sink Connector handle all database operations.

**Pipeline:**
```
IIDR Topic → IidrToJdbcSinkTransform → Confluent JDBC Sink Connector → Target DB
```

## Features

- **Header-Based Routing**: Extracts `TableName` header to route records to the correct target table
- **Operation Mapping**: Maps `A_ENTTYP` codes to UPSERT (pass-through) or DELETE (tombstone)
- **Schema Inference**: Converts schemaless JSON (Maps) to Connect Structs with proper schemas
- **Type Coercion**: Converts string values to typed values (timestamp, date, time) with multi-format fallback
- **Case Conversion**: Configurable table name and field name case conversion (for PostgreSQL compatibility)
- **Table Filtering**: Per-connector table filtering for one-connector-per-table deployments

## Event Structure

IIDR CDC events carry routing info in Kafka headers:

| Component | Format | Description |
|-----------|--------|-------------|
| Key | JSON | Primary key columns (e.g., `{"ID": 1}`) |
| Value | JSON | Full row image (null for DELETE) |
| Headers | Metadata | `TableName`, `A_ENTTYP`, `A_TIMSTAMP` |

### A_ENTTYP Operation Mapping

| Operation | Codes | SMT Action |
|-----------|-------|------------|
| UPSERT | PT, RR, PX, UP, FI, FP, UR | Pass record with schema |
| DELETE | DL, DR | Return tombstone (null value) |

## Configuration

| Property | Type | Default | Description |
|----------|------|---------|-------------|
| `table.header` | String | `TableName` | Header name containing the target table name |
| `entry.type.header` | String | `A_ENTTYP` | Header name containing the IIDR entry type code |
| `table.name.case` | String | `none` | Convert table name case: `lower`, `upper`, or `none` |
| `field.name.case` | String | `none` | Convert field/column name case: `lower`, `upper`, or `none` |
| `table.name.filter` | String | _(empty)_ | Only process records matching this table name. Empty means process all |
| `field.type.overrides` | String | _(empty)_ | Comma-separated `field:type` pairs. Supported types: `timestamp`, `date`, `time` |

## Usage Examples

### Basic (MariaDB)

MariaDB is case-insensitive and handles implicit string-to-date conversion, so minimal config is needed:

```json
{
    "name": "iidr_jdbc_sink_mariadb",
    "config": {
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "topics": "iidr.CDC.TEST_ORDERS",
        "connection.url": "jdbc:mariadb://mariadb:3306/target_database",
        "connection.user": "root",
        "connection.password": "password",
        "table.name.format": "${topic}",
        "insert.mode": "upsert",
        "delete.enabled": "true",
        "pk.mode": "record_key",
        "pk.fields": "ID",
        "auto.create": "false",
        "errors.tolerance": "all",
        "errors.deadletterqueue.topic.name": "dlq-iidr-jdbc-sink",
        "errors.deadletterqueue.topic.replication.factor": "1",
        "transforms": "iidrToJdbc",
        "transforms.iidrToJdbc.type": "com.example.debezium.smt.IidrToJdbcSinkTransform",
        "key.converter": "org.apache.kafka.connect.json.JsonConverter",
        "key.converter.schemas.enable": "false",
        "value.converter": "org.apache.kafka.connect.json.JsonConverter",
        "value.converter.schemas.enable": "false"
    }
}
```

### PostgreSQL (with case conversion and type coercion)

PostgreSQL requires lowercase identifiers and strict type matching:

```json
{
    "name": "iidr_jdbc_sink_postgres",
    "config": {
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "topics": "iidr.CDC.TEST_ORDERS",
        "connection.url": "jdbc:postgresql://postgres:5432/target_database",
        "connection.user": "postgres",
        "connection.password": "password",
        "table.name.format": "${topic}",
        "insert.mode": "upsert",
        "delete.enabled": "true",
        "pk.mode": "record_key",
        "pk.fields": "id",
        "auto.create": "false",
        "errors.tolerance": "all",
        "errors.deadletterqueue.topic.name": "dlq-iidr-jdbc-sink-pg",
        "errors.deadletterqueue.topic.replication.factor": "1",
        "transforms": "iidrToJdbc",
        "transforms.iidrToJdbc.type": "com.example.debezium.smt.IidrToJdbcSinkTransform",
        "transforms.iidrToJdbc.table.name.case": "lower",
        "transforms.iidrToJdbc.field.name.case": "lower",
        "transforms.iidrToJdbc.field.type.overrides": "created_at:timestamp,updated_at:timestamp,order_date:date,order_time:time",
        "key.converter": "org.apache.kafka.connect.json.JsonConverter",
        "key.converter.schemas.enable": "false",
        "value.converter": "org.apache.kafka.connect.json.JsonConverter",
        "value.converter.schemas.enable": "false"
    }
}
```

### Per-Table Connector (with table filter)

For production deployments with one connector per table:

```json
{
    "name": "iidr_jdbc_sink_orders",
    "config": {
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "topics": "iidr.CDC.ALL_TABLES",
        "connection.url": "jdbc:mariadb://mariadb:3306/target_database",
        "connection.user": "root",
        "connection.password": "password",
        "table.name.format": "ORDERS",
        "insert.mode": "upsert",
        "delete.enabled": "true",
        "pk.mode": "record_key",
        "pk.fields": "ID",
        "transforms": "iidrToJdbc",
        "transforms.iidrToJdbc.type": "com.example.debezium.smt.IidrToJdbcSinkTransform",
        "transforms.iidrToJdbc.table.name.filter": "ORDERS",
        "key.converter": "org.apache.kafka.connect.json.JsonConverter",
        "key.converter.schemas.enable": "false",
        "value.converter": "org.apache.kafka.connect.json.JsonConverter",
        "value.converter.schemas.enable": "false"
    }
}
```

## Type Coercion

The `field.type.overrides` config converts string values to proper Connect logical types. This is needed for databases like PostgreSQL that reject implicit string-to-timestamp casts.

```
"field.type.overrides": "created_at:timestamp,updated_at:timestamp,order_date:date,order_time:time"
```

### Supported Types and Formats

| Type | Connect Schema | Accepted Formats |
|------|---------------|-----------------|
| `timestamp` | `org.apache.kafka.connect.data.Timestamp` | `yyyy-MM-dd'T'HH:mm:ss.SSS`, `yyyy-MM-dd'T'HH:mm:ss`, `yyyy-MM-dd HH:mm:ss.SSS`, `yyyy-MM-dd HH:mm:ss` |
| `date` | `org.apache.kafka.connect.data.Date` | `yyyy-MM-dd` |
| `time` | `org.apache.kafka.connect.data.Time` | `HH:mm:ss.SSS`, `HH:mm:ss` |

Multiple formats are tried in order, so mixed formats in source data (e.g., both `T` and space separators) are handled automatically.

## How It Works

1. Extract `TableName` header → apply case conversion → filter if configured
2. Extract `A_ENTTYP` header → determine operation (UPSERT or DELETE)
3. Convert schemaless key/value Maps to Connect Structs with inferred schemas
4. Apply `field.type.overrides` — parse string values into typed `java.util.Date` values
5. For DELETE: return record with null value (tombstone) → JDBC Sink deletes by PK
6. For UPSERT: return record with typed value → JDBC Sink upserts

## Error Handling

- **Missing/empty `TableName` or `A_ENTTYP` header**: throws `DataException`
- **Unrecognized `A_ENTTYP` code**: throws `DataException`
- **Unparseable date/time value**: throws `DataException`

All `DataException`s are handled by Kafka Connect's error tolerance. With `errors.tolerance=all`, failed records go to the dead letter queue (DLQ) topic.

## Building

The JAR is automatically built as part of the kafka-connect Docker image build process.

To build standalone:

```bash
cd deployment/kafka-connect/docker/smt/IidrToJdbcSinkTransform
mvn clean package -DskipTests
```

Output: `target/iidr-to-jdbc-sink-smt-1.0.0.jar`

## Testing

```bash
make build-v3                   # Build Docker image
make iidr-setup                 # Create test databases and topics
make iidr-register-jdbc-v3      # Register MariaDB JDBC sink
make iidr-register-jdbc-pg-v3   # Register PostgreSQL JDBC sink
make iidr-run                   # Produce test IIDR CDC events
make iidr-verify                # Verify data in target databases
```

## Compatibility

- **Java**: 11 (Debezium 2.x) / 17 (Debezium 3.x)
- **Databases**: Any database supported by the Confluent JDBC Sink Connector (MariaDB, MySQL, PostgreSQL, SQL Server, Oracle, etc.)
