# Plan: IidrToJdbcSink SMT

## Context

The current `IidrCdcSinkConnector` is a ~1500-line custom sink connector that re-implements what the Confluent JDBC Sink Connector already provides (dialect-specific UPSERT, auto-create/evolve, type-aware binding). The only IIDR-specific logic is header parsing (~100 lines).

**Goal:** Replace the custom sink connector with a lightweight SMT + Confluent JDBC Sink Connector. The SMT handles IIDR format translation; the JDBC Sink Connector handles all database operations.

**Pipeline:**
```
IIDR Topic → IidrToJdbcSinkTransform SMT → Confluent JDBC Sink Connector → Target DB
```

The old `IidrCdcSinkConnector` remains in the Docker image for backward compatibility.

---

## Step 1: Create SMT Source

**Create `deployment/kafka-connect/docker/smt/IidrToJdbcSinkTransform/`** following the `LegacyCharsetTransform` pattern (flat layout, Maven build).

### `pom.xml`
- Same structure as `smt/LegacyCharsetTransform/pom.xml`
- Artifact: `iidr-to-jdbc-sink-smt-1.0.0.jar`
- Dependencies: `connect-api` + `slf4j-api` (both `provided` scope)

### `IidrToJdbcSinkTransform.java`

**Config properties:**

| Property | Default | Description |
|----------|---------|-------------|
| `table.header` | `TableName` | Header name for target table |
| `entry.type.header` | `A_ENTTYP` | Header name for operation code |

**Core logic (`apply` method):**

1. Extract `TableName` header → override record topic (for `table.name.format=${topic}` routing)
2. Extract `A_ENTTYP` header → determine operation
3. DELETE codes (`DL`, `DR`) → return record with null value (tombstone)
4. UPSERT codes (`PT`, `RR`, `PX`, `UP`, `FI`, `FP`, `UR`) → return record with value as-is
5. Missing/invalid headers → throw `DataException` (Kafka Connect DLQ handles it)

**Entry type codes** (from existing `EntryTypeMapper.java`):
```java
UPSERT_CODES = Set.of("PT", "RR", "PX", "UP", "FI", "FP", "UR");
DELETE_CODES = Set.of("DL", "DR");
```

**Header extraction** (from existing `HeaderExtractor.java` pattern):
- Use `record.headers().lastWithName(headerName)`
- Handle `byte[]` (UTF-8 decode) and `String` values

~100 lines of actual code.

---

## Step 2: Update Dockerfiles

Modify **both** `Dockerfile.debezium-v2` and `Dockerfile.debezium-v3`.

**Add new builder stage** (after existing `smt-builder`):
```dockerfile
FROM maven:3.9-eclipse-temurin-17 AS iidr-smt-builder
WORKDIR /build
RUN mkdir -p src/main/java/com/example/debezium/smt
COPY smt/IidrToJdbcSinkTransform/pom.xml .
COPY smt/IidrToJdbcSinkTransform/IidrToJdbcSinkTransform.java \
     src/main/java/com/example/debezium/smt/
RUN mvn clean package -DskipTests -q
```

**Add COPY in final stage** (alongside existing `legacy-charset-smt` copy):
```dockerfile
COPY --from=iidr-smt-builder /build/target/iidr-to-jdbc-sink-smt-1.0.0.jar \
     /usr/share/java/iidr-to-jdbc-sink-smt-1.0.0.jar
```

For v2: use `maven:3.9-eclipse-temurin-11`.

---

## Step 3: Create Connector Config Files

Create **`hack/sink-jdbc/`** with example configs.

### `iidr_jdbc_sink-test-3x.json` (MariaDB)
```json
{
    "name": "iidr_jdbc_sink_test_3x",
    "config": {
        "connector.class": "io.confluent.connect.jdbc.JdbcSinkConnector",
        "topics": "iidr.CDC.TEST_ORDERS",
        "connection.url": "jdbc:mariadb://dbrep-mariadb.dev.svc.cluster.local:3306/target_database",
        "connection.user": "root",
        "connection.password": "root_password",
        "table.name.format": "${topic}",
        "insert.mode": "upsert",
        "delete.enabled": "true",
        "pk.mode": "record_key",
        "pk.fields": "ID",
        "auto.create": "false",
        "errors.tolerance": "all",
        "errors.deadletterqueue.topic.name": "dlq-iidr-jdbc-sink",
        "errors.deadletterqueue.topic.replication.factor": "1",
        "errors.deadletterqueue.context.headers.enable": "true",
        "transforms": "iidrToJdbc",
        "transforms.iidrToJdbc.type": "com.example.debezium.smt.IidrToJdbcSinkTransform",
        "key.converter": "org.apache.kafka.connect.json.JsonConverter",
        "key.converter.schemas.enable": "false",
        "value.converter": "org.apache.kafka.connect.json.JsonConverter",
        "value.converter.schemas.enable": "false"
    }
}
```

### `iidr_jdbc_sink-pg-test-3x.json` (PostgreSQL)
Same structure, different connection URL/credentials.

### 2x variants
Same configs registered on the v2 Kafka Connect instance.

**Key config points:**
- `table.name.format=${topic}` — SMT overrides topic to TableName header value, JDBC Sink uses it as table name
- `insert.mode=upsert` — handles both INSERT and UPDATE
- `delete.enabled=true` — tombstone (null value) triggers DELETE by PK
- `errors.tolerance=all` + DLQ — replaces custom `streaming_corrupt_events` table

---

## Step 4: Update Makefiles

### `Makefile.iidr` — add new targets:
- `register-jdbc-v3` — register MariaDB JDBC sink on v3
- `register-jdbc-pg-v3` — register PostgreSQL JDBC sink on v3
- `register-jdbc-v2` / `register-jdbc-pg-v2` — same for v2

Follow existing `register-v3` pattern (`kubectl cp` JSON + `curl -d @/tmp/file.json`).

### `Makefile` — add delegation targets:
- `iidr-register-jdbc-v3`, `iidr-register-jdbc-pg-v3`, etc.

---

## Files Summary

| Action | File |
|--------|------|
| Create | `deployment/kafka-connect/docker/smt/IidrToJdbcSinkTransform/pom.xml` |
| Create | `deployment/kafka-connect/docker/smt/IidrToJdbcSinkTransform/IidrToJdbcSinkTransform.java` |
| Modify | `deployment/kafka-connect/docker/Dockerfile.debezium-v2` |
| Modify | `deployment/kafka-connect/docker/Dockerfile.debezium-v3` |
| Create | `hack/sink-jdbc/iidr_jdbc_sink-test-3x.json` |
| Create | `hack/sink-jdbc/iidr_jdbc_sink-pg-test-3x.json` |
| Create | `hack/sink-jdbc/iidr_jdbc_sink-test-2x.json` |
| Create | `hack/sink-jdbc/iidr_jdbc_sink-pg-test-2x.json` |
| Modify | `Makefile.iidr` |
| Modify | `Makefile` |

---

## Verification

1. `make build-v3` — build Docker image with new SMT
2. `make iidr-setup` — set up test databases and topics
3. `make iidr-register-jdbc-v3` — register SMT-based MariaDB connector
4. `make iidr-register-jdbc-pg-v3` — register SMT-based PostgreSQL connector
5. `make iidr-run` — produce IIDR test events
6. `make iidr-verify` — verify INSERT/UPDATE/DELETE in target tables
7. Check DLQ topic for corrupt events: `kafka-console-consumer --topic dlq-iidr-jdbc-sink`

---

## Known Limitations

- **Data types**: JDBC Sink uses `setObject()` for schemaless JSON. JDBC drivers handle most implicit conversions (string→date, number→decimal). If specific types fail, a follow-up type-coercion SMT can be added.
- **Corrupt events**: DLQ topic replaces the custom `streaming_corrupt_events` table. Records go to a Kafka topic instead of a database table.
