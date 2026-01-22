# LegacyCharsetTransform SMT

A Debezium Single Message Transform (SMT) that decodes legacy charset strings from Oracle US7ASCII databases to Unicode.

## Background

Many legacy Oracle databases use `US7ASCII` character set but store multi-byte Chinese characters (BIG5 or GB2312) directly as raw bytes. This was a common practice before Unicode adoption.

**Problem:** CDC tools like Debezium assume a specific encoding when reading VARCHAR2 columns. Oracle JDBC converts bytes >= 0x80 to Unicode codepoints in the "halfwidth" range (0xFF00-0xFFFF), resulting in garbled output.

**Solution:** This SMT recovers the original bytes and decodes them using the specified source encoding, outputting standard Unicode (UTF-8) strings.

## Supported Encodings

| Encoding | Region | Example |
|----------|--------|---------|
| `BIG5` | Taiwan, Hong Kong | Traditional Chinese |
| `GB2312` | China | Simplified Chinese |
| `GBK` | China | Extended Chinese |
| `Shift_JIS` | Japan | Japanese |
| `EUC-KR` | Korea | Korean |

Any Java-supported charset can be used.

## Configuration

| Property | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `encoding` | String | **Yes** | - | Source character encoding (e.g., BIG5, GB2312, GBK, Shift_JIS) |
| `columns` | String | No | (all) | Comma-separated list of column names to decode |
| `tables` | String | No | (all) | Comma-separated list of table patterns (regex). Format: `topic.schema.table` |

## Usage Examples

### Basic Configuration

Decode all columns from all tables using BIG5 encoding:

```properties
transforms=legacycharset
transforms.legacycharset.type=com.example.debezium.smt.LegacyCharsetTransform
transforms.legacycharset.encoding=BIG5
```

### Column Filtering

Decode only specific columns:

```properties
transforms=legacycharset
transforms.legacycharset.type=com.example.debezium.smt.LegacyCharsetTransform
transforms.legacycharset.encoding=BIG5
transforms.legacycharset.columns=NAME,DESCRIPTION,ADDRESS
```

### Table Filtering

Apply only to specific tables (using regex patterns):

```properties
transforms=legacycharset
transforms.legacycharset.type=com.example.debezium.smt.LegacyCharsetTransform
transforms.legacycharset.encoding=BIG5
transforms.legacycharset.columns=NAME
transforms.legacycharset.tables=.*\\.USR1\\.CUSTOMERS,.*\\.USR1\\.ORDERS
```

### Multiple Encodings

For databases with different encodings in different tables, use multiple SMT instances:

```properties
transforms=taiwan,china

# BIG5 for Taiwan tables
transforms.taiwan.type=com.example.debezium.smt.LegacyCharsetTransform
transforms.taiwan.encoding=BIG5
transforms.taiwan.columns=NAME,ADDRESS
transforms.taiwan.tables=.*\\.SCHEMA1\\.TW_.*

# GB2312 for China tables
transforms.china.type=com.example.debezium.smt.LegacyCharsetTransform
transforms.china.encoding=GB2312
transforms.china.columns=CUSTOMER_NAME,CITY
transforms.china.tables=.*\\.SCHEMA1\\.CN_.*
```

## Kafka Connect Connector Example

```json
{
  "name": "oracle-connector",
  "config": {
    "connector.class": "io.debezium.connector.oracle.OracleConnector",
    "database.hostname": "oracle-host",
    "database.port": "1521",
    "database.user": "dbzuser",
    "database.password": "dbzpwd",
    "database.dbname": "ORCL",
    "topic.prefix": "oracle",
    "schema.include.list": "MYSCHEMA",
    "transforms": "legacycharset",
    "transforms.legacycharset.type": "com.example.debezium.smt.LegacyCharsetTransform",
    "transforms.legacycharset.encoding": "BIG5",
    "transforms.legacycharset.columns": "NAME,DESCRIPTION"
  }
}
```

## Building

### Using Maven

```bash
mvn clean package -DskipTests
```

The JAR will be created at `target/legacy-charset-smt-1.0.0.jar`.

### Using Docker

The JAR is automatically built as part of the kafka-connect Docker image build process.

## Installation

Copy the JAR to the Kafka Connect plugin path:

```bash
cp target/legacy-charset-smt-1.0.0.jar /usr/share/java/
```

Or mount it in Docker:

```yaml
volumes:
  - ./legacy-charset-smt-1.0.0.jar:/usr/share/java/legacy-charset-smt-1.0.0.jar:ro
```

## How It Works

1. Oracle JDBC converts high bytes (>=0x80) to Unicode halfwidth range (0xFFxx)
2. The SMT intercepts specified columns in matching tables
3. Recovers original bytes: `byte = codepoint - 0xFF00` for codepoints >= 0xFF00
4. Decodes recovered bytes using the specified source encoding
5. Outputs Unicode (UTF-8) strings for downstream consumers

### Example Transformation

| Input (Garbled) | Output (Decoded) |
|-----------------|------------------|
| `ﾴ￺ﾸￕﾤﾤﾤ￥` | `測試中文` |
| `ﾧAﾦnﾥ@ﾬ￉` | `你好世界` |
| `ﾥxﾥ_ﾥﾫ` | `台北市` |
