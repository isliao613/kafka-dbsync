package com.example.debezium.smt;

import org.apache.kafka.common.config.ConfigDef;
import org.apache.kafka.connect.connector.ConnectRecord;
import org.apache.kafka.connect.data.Date;
import org.apache.kafka.connect.data.Schema;
import org.apache.kafka.connect.data.SchemaBuilder;
import org.apache.kafka.connect.data.Struct;
import org.apache.kafka.connect.data.Time;
import org.apache.kafka.connect.data.Timestamp;
import org.apache.kafka.connect.errors.DataException;
import org.apache.kafka.connect.header.Header;
import org.apache.kafka.connect.transforms.Transformation;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

import java.nio.charset.StandardCharsets;
import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.Set;
import java.util.TimeZone;

/**
 * Kafka Connect SMT that translates IIDR CDC records for use with the
 * Confluent JDBC Sink Connector.
 *
 * <p>This transform:
 * <ul>
 *   <li>Extracts the {@code TableName} header and overrides the record topic
 *       (so {@code table.name.format=${topic}} routes to the correct table)</li>
 *   <li>Extracts the {@code A_ENTTYP} header to determine the CDC operation</li>
 *   <li>Converts schemaless keys/values (Maps from JsonConverter) into Structs
 *       with Connect Schemas, as required by the JDBC Sink Connector</li>
 *   <li>Coerces string fields to typed values (timestamp, date, time) based on
 *       the {@code field.type.overrides} config</li>
 *   <li>For DELETE codes (DL, DR): returns a tombstone (null value) so the
 *       JDBC Sink Connector deletes by PK</li>
 *   <li>For UPSERT codes (PT, RR, PX, UP, FI, FP, UR): passes the record
 *       through with schema for upsert</li>
 *   <li>For missing/invalid headers: throws {@link DataException} so Kafka
 *       Connect DLQ can handle it</li>
 * </ul>
 */
public class IidrToJdbcSinkTransform<R extends ConnectRecord<R>> implements Transformation<R> {

    private static final Logger log = LoggerFactory.getLogger(IidrToJdbcSinkTransform.class);

    private static final String TABLE_HEADER_CONFIG = "table.header";
    private static final String TABLE_HEADER_DEFAULT = "TableName";
    private static final String ENTRY_TYPE_HEADER_CONFIG = "entry.type.header";
    private static final String ENTRY_TYPE_HEADER_DEFAULT = "A_ENTTYP";
    private static final String TABLE_NAME_CASE_CONFIG = "table.name.case";
    private static final String TABLE_NAME_CASE_DEFAULT = "none";
    private static final String FIELD_NAME_CASE_CONFIG = "field.name.case";
    private static final String FIELD_NAME_CASE_DEFAULT = "none";
    private static final String TABLE_NAME_FILTER_CONFIG = "table.name.filter";
    private static final String TABLE_NAME_FILTER_DEFAULT = "";
    private static final String FIELD_TYPE_OVERRIDES_CONFIG = "field.type.overrides";
    private static final String FIELD_TYPE_OVERRIDES_DEFAULT = "";

    private static final Set<String> UPSERT_CODES = Set.of("PT", "RR", "PX", "UP", "FI", "FP", "UR");
    private static final Set<String> DELETE_CODES = Set.of("DL", "DR");

    // Timestamp format patterns to try in order (most specific first)
    private static final String[] TIMESTAMP_PATTERNS = {
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss.SSS",
            "yyyy-MM-dd HH:mm:ss"
    };
    private static final String[] DATE_PATTERNS = {"yyyy-MM-dd"};
    private static final String[] TIME_PATTERNS = {"HH:mm:ss.SSS", "HH:mm:ss"};

    private static final ConfigDef CONFIG_DEF = new ConfigDef()
            .define(TABLE_HEADER_CONFIG, ConfigDef.Type.STRING, TABLE_HEADER_DEFAULT,
                    ConfigDef.Importance.MEDIUM, "Header name containing the target table name")
            .define(ENTRY_TYPE_HEADER_CONFIG, ConfigDef.Type.STRING, ENTRY_TYPE_HEADER_DEFAULT,
                    ConfigDef.Importance.MEDIUM, "Header name containing the IIDR entry type code")
            .define(TABLE_NAME_CASE_CONFIG, ConfigDef.Type.STRING, TABLE_NAME_CASE_DEFAULT,
                    ConfigDef.Importance.LOW, "Convert table name case: 'lower', 'upper', or 'none' (default)")
            .define(FIELD_NAME_CASE_CONFIG, ConfigDef.Type.STRING, FIELD_NAME_CASE_DEFAULT,
                    ConfigDef.Importance.LOW, "Convert field/column name case: 'lower', 'upper', or 'none' (default)")
            .define(TABLE_NAME_FILTER_CONFIG, ConfigDef.Type.STRING, TABLE_NAME_FILTER_DEFAULT,
                    ConfigDef.Importance.MEDIUM, "Only process records matching this table name (from TableName header). Empty means process all.")
            .define(FIELD_TYPE_OVERRIDES_CONFIG, ConfigDef.Type.STRING, FIELD_TYPE_OVERRIDES_DEFAULT,
                    ConfigDef.Importance.MEDIUM,
                    "Comma-separated list of field:type pairs to coerce string values to typed values. "
                            + "Supported types: timestamp, date, time. "
                            + "Example: 'created_at:timestamp,order_date:date,order_time:time'");

    private String tableHeader;
    private String entryTypeHeader;
    private String tableNameCase;
    private String fieldNameCase;
    private String tableNameFilter;
    private Map<String, String> fieldTypeOverrides;

    @Override
    public void configure(Map<String, ?> configs) {
        Object table = configs.get(TABLE_HEADER_CONFIG);
        tableHeader = table != null ? table.toString() : TABLE_HEADER_DEFAULT;
        Object entryType = configs.get(ENTRY_TYPE_HEADER_CONFIG);
        entryTypeHeader = entryType != null ? entryType.toString() : ENTRY_TYPE_HEADER_DEFAULT;
        Object tCase = configs.get(TABLE_NAME_CASE_CONFIG);
        tableNameCase = tCase != null ? tCase.toString() : TABLE_NAME_CASE_DEFAULT;
        Object fCase = configs.get(FIELD_NAME_CASE_CONFIG);
        fieldNameCase = fCase != null ? fCase.toString() : FIELD_NAME_CASE_DEFAULT;
        Object filter = configs.get(TABLE_NAME_FILTER_CONFIG);
        tableNameFilter = filter != null ? filter.toString().trim() : TABLE_NAME_FILTER_DEFAULT;
        Object overrides = configs.get(FIELD_TYPE_OVERRIDES_CONFIG);
        fieldTypeOverrides = parseFieldTypeOverrides(
                overrides != null ? overrides.toString().trim() : FIELD_TYPE_OVERRIDES_DEFAULT);
    }

    private Map<String, String> parseFieldTypeOverrides(String config) {
        if (config == null || config.isEmpty()) {
            return Collections.emptyMap();
        }
        Map<String, String> result = new HashMap<>();
        for (String pair : config.split(",")) {
            String trimmed = pair.trim();
            if (trimmed.isEmpty()) continue;
            String[] parts = trimmed.split(":", 2);
            if (parts.length != 2) {
                throw new DataException("Invalid field.type.overrides entry: '" + trimmed
                        + "'. Expected format: field_name:type");
            }
            String fieldName = parts[0].trim();
            String typeName = parts[1].trim().toLowerCase();
            if (!typeName.equals("timestamp") && !typeName.equals("date") && !typeName.equals("time")) {
                throw new DataException("Unsupported type '" + typeName + "' for field '" + fieldName
                        + "'. Supported types: timestamp, date, time");
            }
            result.put(fieldName, typeName);
        }
        return result;
    }

    @Override
    @SuppressWarnings("unchecked")
    public R apply(R record) {
        if (record.value() == null && record.key() == null) {
            return record;
        }

        String tableName = extractHeader(record, tableHeader);
        if (tableName == null || tableName.trim().isEmpty()) {
            throw new DataException("Missing or empty header: " + tableHeader);
        }
        tableName = applyCase(tableName, tableNameCase);

        // Filter: drop records not matching the configured table
        if (!tableNameFilter.isEmpty() && !tableNameFilter.equalsIgnoreCase(tableName)) {
            log.debug("Skipping record: table={} does not match filter={}", tableName, tableNameFilter);
            return null;
        }

        String entryType = extractHeader(record, entryTypeHeader);
        if (entryType == null || entryType.trim().isEmpty()) {
            throw new DataException("Missing or empty header: " + entryTypeHeader);
        }

        String code = entryType.trim().toUpperCase();

        // Convert schemaless key (Map) to Struct if needed
        Schema keySchema = record.keySchema();
        Object key = record.key();
        if (key instanceof Map && keySchema == null) {
            Map<String, Object> keyMap = (Map<String, Object>) key;
            keySchema = buildSchema(keyMap);
            key = buildStruct(keySchema, keyMap);
        }

        if (DELETE_CODES.contains(code)) {
            log.debug("DELETE operation ({}): table={}, key={}", code, tableName, record.key());
            return record.newRecord(
                    tableName, record.kafkaPartition(),
                    keySchema, key,
                    null, null,
                    record.timestamp(),
                    record.headers()
            );
        }

        if (UPSERT_CODES.contains(code)) {
            log.debug("UPSERT operation ({}): table={}, key={}", code, tableName, record.key());

            // Convert schemaless value (Map) to Struct if needed
            Schema valSchema = record.valueSchema();
            Object value = record.value();
            if (value instanceof Map && valSchema == null) {
                Map<String, Object> valMap = (Map<String, Object>) value;
                valSchema = buildSchema(valMap);
                value = buildStruct(valSchema, valMap);
            }

            return record.newRecord(
                    tableName, record.kafkaPartition(),
                    keySchema, key,
                    valSchema, value,
                    record.timestamp(),
                    record.headers()
            );
        }

        throw new DataException("Unrecognized entry type code: " + code);
    }

    private String applyCase(String name, String caseConfig) {
        if ("lower".equalsIgnoreCase(caseConfig)) {
            return name.toLowerCase();
        }
        if ("upper".equalsIgnoreCase(caseConfig)) {
            return name.toUpperCase();
        }
        return name;
    }

    /**
     * Build a Connect Schema from a Map by inferring field types from values.
     * Fields listed in field.type.overrides get typed schemas (Timestamp, Date, Time).
     */
    private Schema buildSchema(Map<String, Object> map) {
        SchemaBuilder builder = SchemaBuilder.struct();
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            String fieldName = applyCase(entry.getKey(), fieldNameCase);
            String typeOverride = fieldTypeOverrides.get(fieldName);
            if (typeOverride != null) {
                builder.field(fieldName, getOverrideSchema(typeOverride));
            } else {
                builder.field(fieldName, inferSchema(entry.getValue()));
            }
        }
        return builder.build();
    }

    /**
     * Build a Struct from a Map using the given schema.
     * Fields listed in field.type.overrides are coerced from strings to typed values.
     */
    private Struct buildStruct(Schema schema, Map<String, Object> map) {
        Struct struct = new Struct(schema);
        for (Map.Entry<String, Object> entry : map.entrySet()) {
            String fieldName = applyCase(entry.getKey(), fieldNameCase);
            String typeOverride = fieldTypeOverrides.get(fieldName);
            if (typeOverride != null && entry.getValue() instanceof String) {
                struct.put(fieldName, coerceValue((String) entry.getValue(), typeOverride));
            } else {
                struct.put(fieldName, entry.getValue());
            }
        }
        return struct;
    }

    private Schema getOverrideSchema(String typeName) {
        switch (typeName) {
            case "timestamp": return Timestamp.builder().optional().build();
            case "date":      return Date.builder().optional().build();
            case "time":      return Time.builder().optional().build();
            default:          return Schema.OPTIONAL_STRING_SCHEMA;
        }
    }

    /**
     * Coerce a string value to a java.util.Date using the appropriate format patterns.
     * Tries multiple patterns to handle format variations (e.g. 'T' vs space separator).
     */
    private java.util.Date coerceValue(String value, String typeName) {
        if (value == null || value.trim().isEmpty()) {
            return null;
        }
        String[] patterns;
        switch (typeName) {
            case "timestamp": patterns = TIMESTAMP_PATTERNS; break;
            case "date":      patterns = DATE_PATTERNS; break;
            case "time":      patterns = TIME_PATTERNS; break;
            default: throw new DataException("Unsupported type override: " + typeName);
        }
        for (String pattern : patterns) {
            try {
                SimpleDateFormat sdf = new SimpleDateFormat(pattern);
                sdf.setTimeZone(TimeZone.getTimeZone("UTC"));
                sdf.setLenient(false);
                return sdf.parse(value.trim());
            } catch (ParseException e) {
                // Try next pattern
            }
        }
        throw new DataException("Cannot parse '" + value + "' as " + typeName
                + ". Tried patterns: " + String.join(", ", patterns));
    }

    /**
     * Infer a Connect Schema from a Java value produced by JsonConverter.
     */
    private Schema inferSchema(Object value) {
        if (value == null) {
            return Schema.OPTIONAL_STRING_SCHEMA;
        }
        if (value instanceof String) {
            return Schema.OPTIONAL_STRING_SCHEMA;
        }
        if (value instanceof Integer) {
            return Schema.OPTIONAL_INT32_SCHEMA;
        }
        if (value instanceof Long) {
            return Schema.OPTIONAL_INT64_SCHEMA;
        }
        if (value instanceof Double || value instanceof Float) {
            return Schema.OPTIONAL_FLOAT64_SCHEMA;
        }
        if (value instanceof Boolean) {
            return Schema.OPTIONAL_BOOLEAN_SCHEMA;
        }
        // Fallback: treat as string
        return Schema.OPTIONAL_STRING_SCHEMA;
    }

    private String extractHeader(R record, String headerName) {
        Header header = record.headers().lastWithName(headerName);
        if (header == null) {
            return null;
        }
        Object value = header.value();
        if (value == null) {
            return null;
        }
        if (value instanceof byte[]) {
            return new String((byte[]) value, StandardCharsets.UTF_8);
        }
        return value.toString();
    }

    @Override
    public ConfigDef config() {
        return CONFIG_DEF;
    }

    @Override
    public void close() {
        // No resources to release
    }
}
