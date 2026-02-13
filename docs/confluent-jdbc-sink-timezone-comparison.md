# Confluent JDBC Sink Connector Timezone Comparison

## Pipeline

```
MariaDB (source) → Debezium MySQL Source Connector → Kafka → Confluent JDBC Sink Connector → MariaDB (target)
```

## Test Environment

- Source: MariaDB with binlog enabled
- Source Connector: `io.debezium.connector.mysql.MySqlConnector` (with `ExtractNewRecordState` SMT)
- Sink Connector: `io.confluent.connect.jdbc.JdbcSinkConnector` (auto.create=true)
- Target: MariaDB

## Test Matrix

| JDBC Sink Version | `db.timezone` | `date.timezone` | Notes |
|---|---|---|---|
| 10.6.4 | UTC | _(N/A, not supported)_ | Old image (3.4.0) |
| 10.6.4 | Asia/Taipei | _(N/A, not supported)_ | Old image (3.4.0) |
| 10.9.2 | UTC | _(default = db_timezone)_ | New image (3.4.1) |
| 10.9.2 | Asia/Taipei | _(default = db_timezone)_ | New image (3.4.1) |
| 10.9.2 | Asia/Taipei | utc | New image (3.4.1) |

### `date.timezone` Config Details (new in 10.9.2)

- Only accepts 2 values: `db_timezone` (default, inherits from `db.timezone`) or `utc`
- Does NOT accept timezone IDs like `Asia/Taipei`
- Purpose: decouple DATE-type column handling from `db.timezone`
- Documentation: "Name of the JDBC timezone that should be used in the connector when inserting DATE type values. Defaults to DB_TIMEZONE that uses the timezone set for db.timezone configuration (to maintain backward compatibility). It is recommended to set this to UTC to avoid conversion for DATE type values."

## Source Data

| ID | CREATED_AT (DATETIME) | UPDATED_AT (TIMESTAMP) | ORDER_DATE (DATE) | ORDER_TIME (TIME) |
|---|---|---|---|---|
| 1 | 2026-01-15 10:00:00 | 2026-01-15 10:00:00 | 2026-01-15 | 10:00:00 |
| 2 | 2026-01-15 14:30:00 | 2026-01-15 14:30:00 | 2026-01-15 | 14:30:00 |
| 3 | 2026-01-15 23:59:59 | 2026-01-15 23:59:59 | 2026-01-15 | 23:59:59 |
| 4 | 2026-01-16 00:00:00 | 2026-01-16 00:00:00 | 2026-01-16 | 00:00:00 |
| 5 | 2026-06-15 12:00:00 | 2026-06-15 12:00:00 | 2026-06-15 | 12:00:00 |

---

## Test 1: `time.precision.mode=adaptive_time_microseconds` (default)

### Debezium Wire Format

| Source Column | Source Type | Debezium Logical Type | Wire Schema | Example Wire Value |
|---|---|---|---|---|
| `CREATED_AT` | `DATETIME` | `io.debezium.time.Timestamp` | INT64 (ms since epoch) | `1768471200000` |
| `UPDATED_AT` | `TIMESTAMP` | `io.debezium.time.ZonedTimestamp` | STRING (ISO-8601) | `2026-01-15T10:00:00Z` |
| `ORDER_DATE` | `DATE` | `io.debezium.time.Date` | INT32 (days since epoch) | `20468` |
| `ORDER_TIME` | `TIME` | `io.debezium.time.MicroTime` | INT64 (microseconds) | `36000000000` |

### Results (Row ID=1, source: `2026-01-15 10:00:00`)

#### CREATED_AT (source: DATETIME)

| JDBC Sink Ver | `db.timezone` | `date.timezone` | Target Column Type | Target Value | Match Source? |
|---|---|---|---|---|---|
| 10.6.4 | UTC | _(N/A)_ | `bigint(20)` | `1768471200000` | No (raw epoch) |
| 10.6.4 | Asia/Taipei | _(N/A)_ | `bigint(20)` | `1768471200000` | No (raw epoch) |
| 10.9.2 | UTC | _(default)_ | `bigint(20)` | `1768471200000` | No (raw epoch) |
| 10.9.2 | Asia/Taipei | _(default)_ | `bigint(20)` | `1768471200000` | No (raw epoch) |
| 10.9.2 | Asia/Taipei | utc | `bigint(20)` | `1768471200000` | No (raw epoch) |

#### UPDATED_AT (source: TIMESTAMP)

| JDBC Sink Ver | `db.timezone` | `date.timezone` | Target Column Type | Target Value | Match Source? |
|---|---|---|---|---|---|
| 10.6.4 | UTC | _(N/A)_ | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |
| 10.6.4 | Asia/Taipei | _(N/A)_ | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |
| 10.9.2 | UTC | _(default)_ | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |
| 10.9.2 | Asia/Taipei | _(default)_ | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |
| 10.9.2 | Asia/Taipei | utc | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |

#### ORDER_DATE (source: DATE)

| JDBC Sink Ver | `db.timezone` | `date.timezone` | Target Column Type | Target Value | Match Source? |
|---|---|---|---|---|---|
| 10.6.4 | UTC | _(N/A)_ | `int(11)` | `20468` | No (raw days) |
| 10.6.4 | Asia/Taipei | _(N/A)_ | `int(11)` | `20468` | No (raw days) |
| 10.9.2 | UTC | _(default)_ | `int(11)` | `20468` | No (raw days) |
| 10.9.2 | Asia/Taipei | _(default)_ | `int(11)` | `20468` | No (raw days) |
| 10.9.2 | Asia/Taipei | utc | `int(11)` | `20468` | No (raw days) |

#### ORDER_TIME (source: TIME)

| JDBC Sink Ver | `db.timezone` | `date.timezone` | Target Column Type | Target Value | Match Source? |
|---|---|---|---|---|---|
| 10.6.4 | UTC | _(N/A)_ | `bigint(20)` | `36000000000` | No (raw µs) |
| 10.6.4 | Asia/Taipei | _(N/A)_ | `bigint(20)` | `36000000000` | No (raw µs) |
| 10.9.2 | UTC | _(default)_ | `bigint(20)` | `36000000000` | No (raw µs) |
| 10.9.2 | Asia/Taipei | _(default)_ | `bigint(20)` | `36000000000` | No (raw µs) |
| 10.9.2 | Asia/Taipei | utc | `bigint(20)` | `36000000000` | No (raw µs) |

### Test 1 Conclusion

**All 5 configurations produce identical output.** `db.timezone`, `date.timezone`, and JDBC sink version have **zero effect**.

**Root cause**: Confluent JDBC Sink does not recognize `io.debezium.time.*` logical types. It falls back to raw Kafka Connect schema types (INT64→`bigint`, INT32→`int`, STRING→`text`). Since target columns are not temporal types, timezone settings have nothing to convert.

---

## Test 1b: `time.precision.mode=adaptive` (default) + Pre-Created Tables (`auto.create=false`)

### 情境

如果不用 `auto.create=true`，而是自行建立目標表並使用正確的時間欄位型別（`DATETIME`, `TIMESTAMP`, `DATE`, `TIME`），會發生什麼事？

### 目標表結構（手動建立）

```sql
CREATE TABLE target_database.TZ_MANUAL_UTC (
  ID BIGINT PRIMARY KEY,
  ORDER_NAME VARCHAR(255) NOT NULL,
  AMOUNT DOUBLE NOT NULL,
  STATUS VARCHAR(255) DEFAULT 'NEW',
  CREATED_AT DATETIME NOT NULL,
  UPDATED_AT TIMESTAMP NULL,
  ORDER_DATE DATE NOT NULL,
  ORDER_TIME TIME NOT NULL
);
```

### 結果：FAILED

兩個 Sink Connector（`db.timezone=UTC` 和 `db.timezone=Asia/Taipei`）都 **Task FAILED**，錯誤訊息：

```
Incorrect datetime value: '1768471200000' for column `target_database`.`TZ_MANUAL_UTC`.`CREATED_AT` at row 1
```

### 原因

Confluent JDBC Sink 不認識 `io.debezium.time.Timestamp`，所以它把 `CREATED_AT` 的值 `1768471200000` 當作普通的 INT64 處理，直接呼叫 `setLong(1768471200000)` 寫入 `DATETIME` 欄位。MariaDB 無法將一個整數 `1768471200000` 解析為合法的 datetime 值，因此拒絕寫入。

### 結論

**使用預設 `time.precision.mode=adaptive` 時，Confluent JDBC Sink 無法寫入手動建立的時間欄位。** 只有兩種選擇：

1. **`auto.create=true`** → 欄位自動建為 `bigint`/`text`，資料能寫入但型別錯誤
2. **`time.precision.mode=connect`** → Debezium 使用 Kafka Connect 標準型別 → Confluent JDBC Sink 認識 → 欄位正確建為 `datetime(3)`/`date`/`time(3)` → 資料正確寫入

---

## Test 1c: `time.precision.mode=adaptive` (default) + `TimestampConverter` SMT

### 情境

使用 `org.apache.kafka.connect.transforms.TimestampConverter$Value` SMT 在 Sink 端將 Debezium 的時間型別轉換為 Kafka Connect 標準型別，然後再寫入。

### Sink Connector 設定

```json
{
  "transforms": "convertCreatedAt,convertOrderDate,convertOrderTime",
  "transforms.convertCreatedAt.type": "org.apache.kafka.connect.transforms.TimestampConverter$Value",
  "transforms.convertCreatedAt.field": "CREATED_AT",
  "transforms.convertCreatedAt.target.type": "Timestamp",
  "transforms.convertOrderDate.type": "org.apache.kafka.connect.transforms.TimestampConverter$Value",
  "transforms.convertOrderDate.field": "ORDER_DATE",
  "transforms.convertOrderDate.target.type": "Date",
  "transforms.convertOrderTime.type": "org.apache.kafka.connect.transforms.TimestampConverter$Value",
  "transforms.convertOrderTime.field": "ORDER_TIME",
  "transforms.convertOrderTime.target.type": "Time"
}
```

### 結果：部分成功

**三欄位同時轉換 → FAILED：**

```
Schema{io.debezium.time.Date:INT32} does not correspond to a known timestamp type format
```

`TimestampConverter` SMT **也不認識** `io.debezium.time.Date` 和 `io.debezium.time.MicroTime`，只認識：
- `org.apache.kafka.connect.data.Timestamp`
- `org.apache.kafka.connect.data.Date`
- `org.apache.kafka.connect.data.Time`
- 以及無 schema name 的純 INT64/INT32/STRING

因為 `io.debezium.time.Date` 帶有 schema name 但不是已知的 timestamp 型別，SMT 直接拒絕處理。

**只轉換 CREATED_AT → 成功：**

`io.debezium.time.Timestamp`（INT64 ms）可以被 `TimestampConverter` 成功轉為 `org.apache.kafka.connect.data.Timestamp`，因為底層格式完全相同（都是 epoch ms）。

| CONFIG | CREATED_AT | ORDER_DATE | ORDER_TIME |
|---|---|---|---|
| Source | 2026-01-15 10:00:00 | 2026-01-15 | 10:00:00 |
| SMT + db.tz=UTC | **2026-01-15 10:00:00.000** (datetime(3)) | 20468 (int) | 36000000000 (bigint) |
| SMT + db.tz=Taipei | **2026-01-15 18:00:00.000** (datetime(3)) | 20468 (int) | 36000000000 (bigint) |

### 結論

- `TimestampConverter` SMT **只能轉換 `CREATED_AT`**（DATETIME → `io.debezium.time.Timestamp`），因為它底層就是 epoch ms，跟 Kafka Connect 的 `Timestamp` 格式相同
- **無法轉換 `ORDER_DATE`**（`io.debezium.time.Date`）和 **`ORDER_TIME`**（`io.debezium.time.MicroTime`），因為 SMT 不認識這些 Debezium 邏輯型別
- 轉換後 `db.timezone` 生效：`Asia/Taipei` 會讓 CREATED_AT **多加 8 小時**
- **不是一個完整的解決方案** — 只能部分修復，且增加了設定複雜度

---

## Test 2: `time.precision.mode=connect`

### Debezium Wire Format

| Source Column | Source Type | Kafka Connect Logical Type | Wire Schema | Example Wire Value |
|---|---|---|---|---|
| `CREATED_AT` | `DATETIME` | `org.apache.kafka.connect.data.Timestamp` | INT64 (ms since epoch) | `1768471200000` |
| `UPDATED_AT` | `TIMESTAMP` | `io.debezium.time.ZonedTimestamp` | STRING (ISO-8601) | `2026-01-15T10:00:00Z` |
| `ORDER_DATE` | `DATE` | `org.apache.kafka.connect.data.Date` | INT32 (days since epoch) | `20468` |
| `ORDER_TIME` | `TIME` | `org.apache.kafka.connect.data.Time` | INT32 (ms since midnight) | `36000000` |

Note: `TIMESTAMP` still uses `io.debezium.time.ZonedTimestamp` (string) regardless of `time.precision.mode`.

### Results (Row ID=1, source: `2026-01-15 10:00:00`)

#### CREATED_AT (source: DATETIME)

| JDBC Sink Ver | `db.timezone` | `date.timezone` | Target Column Type | Target Value | Match Source? |
|---|---|---|---|---|---|
| 10.6.4 | UTC | _(N/A)_ | `datetime(3)` | `2026-01-15 10:00:00.000` | Yes |
| 10.6.4 | Asia/Taipei | _(N/A)_ | `datetime(3)` | `2026-01-15 18:00:00.000` | **No (+8h shift)** |
| 10.9.2 | UTC | _(default)_ | `datetime(3)` | `2026-01-15 10:00:00.000` | Yes |
| 10.9.2 | Asia/Taipei | _(default)_ | `datetime(3)` | `2026-01-15 18:00:00.000` | **No (+8h shift)** |
| 10.9.2 | Asia/Taipei | utc | `datetime(3)` | `2026-01-15 18:00:00.000` | **No (+8h shift)** |

#### UPDATED_AT (source: TIMESTAMP) — still `io.debezium.time.ZonedTimestamp`

| JDBC Sink Ver | `db.timezone` | `date.timezone` | Target Column Type | Target Value | Match Source? |
|---|---|---|---|---|---|
| 10.6.4 | UTC | _(N/A)_ | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |
| 10.6.4 | Asia/Taipei | _(N/A)_ | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |
| 10.9.2 | UTC | _(default)_ | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |
| 10.9.2 | Asia/Taipei | _(default)_ | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |
| 10.9.2 | Asia/Taipei | utc | `text` | `2026-01-15T10:00:00Z` | No (ISO string) |

#### ORDER_DATE (source: DATE)

| JDBC Sink Ver | `db.timezone` | `date.timezone` | Target Column Type | Target Value | Match Source? |
|---|---|---|---|---|---|
| 10.6.4 | UTC | _(N/A)_ | `date` | `2026-01-15` | Yes |
| 10.6.4 | Asia/Taipei | _(N/A)_ | `date` | `2026-01-15` | Yes |
| 10.9.2 | UTC | _(default)_ | `date` | `2026-01-15` | Yes |
| 10.9.2 | Asia/Taipei | _(default)_ | `date` | `2026-01-15` | Yes |
| 10.9.2 | Asia/Taipei | utc | `date` | `2026-01-15` | Yes |

#### ORDER_TIME (source: TIME)

| JDBC Sink Ver | `db.timezone` | `date.timezone` | Target Column Type | Target Value | Match Source? |
|---|---|---|---|---|---|
| 10.6.4 | UTC | _(N/A)_ | `time(3)` | `10:00:00.000` | Yes |
| 10.6.4 | Asia/Taipei | _(N/A)_ | `time(3)` | `18:00:00.000` | **No (+8h shift)** |
| 10.9.2 | UTC | _(default)_ | `time(3)` | `10:00:00.000` | Yes |
| 10.9.2 | Asia/Taipei | _(default)_ | `time(3)` | `18:00:00.000` | **No (+8h shift)** |
| 10.9.2 | Asia/Taipei | utc | `time(3)` | `18:00:00.000` | **No (+8h shift)** |

### All 5 Rows — CREATED_AT Comparison

| ID | Source | db.tz=UTC | db.tz=Asia/Taipei | Shift |
|---|---|---|---|---|
| 1 | 2026-01-15 10:00:00 | 2026-01-15 10:00:00.000 | 2026-01-15 18:00:00.000 | +8h |
| 2 | 2026-01-15 14:30:00 | 2026-01-15 14:30:00.000 | 2026-01-15 22:30:00.000 | +8h |
| 3 | 2026-01-15 23:59:59 | 2026-01-15 23:59:59.000 | 2026-01-16 07:59:59.000 | +8h (crosses midnight) |
| 4 | 2026-01-16 00:00:00 | 2026-01-16 00:00:00.000 | 2026-01-16 08:00:00.000 | +8h |
| 5 | 2026-06-15 12:00:00 | 2026-06-15 12:00:00.000 | 2026-06-15 20:00:00.000 | +8h |

### Test 2 Conclusion

With `time.precision.mode=connect`, the Confluent JDBC Sink **recognizes** Kafka Connect's built-in logical types and creates proper temporal columns (`datetime(3)`, `date`, `time(3)`).

**`db.timezone` now has a real effect:**
- `db.timezone=UTC` → target matches source exactly
- `db.timezone=Asia/Taipei` → CREATED_AT and ORDER_TIME are shifted +8 hours

**`date.timezone=utc` has no additional effect** — ORDER_DATE is identical across all configurations (no shift observed).

**No regression between 10.6.4 and 10.9.2** — both versions produce identical results for the same `db.timezone` setting.

---

## Cross-Version Comparison Summary

| Comparison | `time.precision.mode=adaptive` (default) | `time.precision.mode=connect` |
|---|---|---|
| 10.6.4 vs 10.9.2 (db.tz=UTC) | IDENTICAL | IDENTICAL |
| 10.6.4 vs 10.9.2 (db.tz=Asia/Taipei) | IDENTICAL | IDENTICAL |
| UTC vs Asia/Taipei (same version) | IDENTICAL (no effect) | **DIFF: +8h on CREATED_AT, ORDER_TIME** |
| `date.timezone` effect (10.9.2) | None | None (ORDER_DATE unaffected) |

## Key Takeaways

1. **No regression from 10.6.4 → 10.9.2** in either precision mode.

2. **`time.precision.mode` on the source connector is the critical factor**, not the sink version:
   - `adaptive_time_microseconds` (default) → Debezium types (`io.debezium.time.*`) → Confluent JDBC Sink stores as BIGINT/INT/TEXT → `db.timezone` has no effect
   - `connect` → Kafka Connect types (`org.apache.kafka.connect.data.*`) → Confluent JDBC Sink creates proper `datetime(3)`/`date`/`time(3)` → `db.timezone` **does** shift DATETIME and TIME values

3. **`db.timezone=UTC` is the correct setting** when the source data is stored without timezone awareness (MariaDB DATETIME). Setting it to a non-UTC timezone causes incorrect +N hour shifts on DATETIME and TIME columns.

4. **`date.timezone` (new in 10.9.2) has no observable effect** in this test — ORDER_DATE values are identical regardless of the setting.

5. **TIMESTAMP → `io.debezium.time.ZonedTimestamp`** is always stored as `text` in both modes. The Confluent JDBC Sink does not convert this to a temporal column regardless of `time.precision.mode`.

6. **Debezium MySQL Source Connector 沒有 `database.connectionTimezone` 參數**。`connectionTimezone` 是 MySQL JDBC Driver (`mysql-connector-j`) 的連線參數，不是 Debezium connector 的設定項。Debezium MySQL connector 唯一跟時區相關的參數是 `time.precision.mode`。

---

## 原理解析（中文）

### 資料流經的路徑

```
MariaDB Source → Debezium Source Connector → Kafka Topic → Confluent JDBC Sink → MariaDB Target
                 ^^^^^^^^^^^^^^^^^^^^^^^^                   ^^^^^^^^^^^^^^^^^^^^
                 這裡決定 wire format                        這裡決定怎麼寫入
```

### 第一個關鍵：Debezium Source 的 `time.precision.mode`

Debezium 從 MariaDB 讀取時間欄位後，要把它序列化成 Kafka 訊息。**怎麼序列化**取決於 `time.precision.mode`：

**`adaptive_time_microseconds`（預設值）**

Debezium 用**自己定義的邏輯型別**（`io.debezium.time.*`）：

| 來源型別 | schema name | 實際傳輸格式 | 範例 |
|---|---|---|---|
| DATETIME | `io.debezium.time.Timestamp` | INT64 毫秒數 | `1768471200000` |
| TIMESTAMP | `io.debezium.time.ZonedTimestamp` | ISO-8601 字串 | `2026-01-15T10:00:00Z` |
| DATE | `io.debezium.time.Date` | INT32 天數 | `20468` |
| TIME | `io.debezium.time.MicroTime` | INT64 微秒數 | `36000000000` |

**`connect`（Kafka Connect 標準型別）**

Debezium 用 **Kafka Connect 內建的邏輯型別**（`org.apache.kafka.connect.data.*`）：

| 來源型別 | schema name | 實際傳輸格式 | 範例 |
|---|---|---|---|
| DATETIME | `org.apache.kafka.connect.data.Timestamp` | INT64 毫秒數 | `1768471200000` |
| DATE | `org.apache.kafka.connect.data.Date` | INT32 天數 | `20468` |
| TIME | `org.apache.kafka.connect.data.Time` | INT32 毫秒數 | `36000000` |

注意：雖然底層都是 INT64/INT32，但 **schema 上標記的 name 不同**。這個 name 就是 Sink Connector 判斷「這是不是時間型別」的依據。

### 第二個關鍵：Confluent JDBC Sink 只認自家人

Confluent JDBC Sink 在 `auto.create=true` 時，會根據 schema 的 logical name 決定要建什麼型別的欄位：

- 看到 `org.apache.kafka.connect.data.Timestamp` → 建 `datetime(3)` ✅
- 看到 `org.apache.kafka.connect.data.Date` → 建 `date` ✅
- 看到 `org.apache.kafka.connect.data.Time` → 建 `time(3)` ✅
- 看到 `io.debezium.time.Timestamp` → **不認識** → 只看底層 schema type 是 INT64 → 建 `bigint(20)` ❌
- 看到 `io.debezium.time.ZonedTimestamp` → **不認識** → 只看底層 schema type 是 STRING → 建 `text` ❌

**這就是為什麼預設模式下所有時間欄位都變成 bigint/text。**

**如果手動建表用 `DATETIME` 欄位 + 預設 `adaptive` 模式呢？** Sink 會直接 crash：

```
Incorrect datetime value: '1768471200000' for column CREATED_AT at row 1
```

因為 Sink 不認識 `io.debezium.time.Timestamp`，所以直接把 INT64 值 `1768471200000` 用 `setLong()` 塞進 `DATETIME` 欄位，MariaDB 無法接受這個值，寫入失敗。

**所以預設模式下只有兩條路：**
1. `auto.create=true` → 自動建 `bigint` 欄位 → 能寫入但型別錯誤
2. 手動建表用 `DATETIME` → **直接 FAILED，無法寫入**

### 第三個關鍵：`db.timezone` 只對「真正的時間欄位」生效

`db.timezone` 的作用是：在寫入 JDBC 時，設定 `Calendar` 物件的時區，告訴 JDBC driver「這個 epoch 毫秒數要用什麼時區來解釋」。

```
epoch ms 1768471200000
    ↓
用 UTC 解釋      → 2026-01-15 10:00:00  ✅ 正確
用 Asia/Taipei 解釋 → 2026-01-15 18:00:00  ❌ 多了 8 小時
```

但這個轉換只在呼叫 `PreparedStatement.setTimestamp()` 時才會發生。如果欄位是 `bigint`，Sink 呼叫的是 `setLong()`，根本不經過時區轉換，所以 `db.timezone` 完全沒用。

**總結流程：**

```
time.precision.mode=adaptive (預設)
  → io.debezium.time.* (Confluent 不認識)
    → 建 bigint/text 欄位
      → setLong() / setString()
        → db.timezone 無效
          → 所有設定結果完全一樣

time.precision.mode=connect
  → org.apache.kafka.connect.data.* (Confluent 認識)
    → 建 datetime(3)/date/time(3) 欄位
      → setTimestamp() / setDate() / setTime()
        → db.timezone 生效
          → Asia/Taipei 會多 +8 小時！
```

### 為什麼 `db.timezone=UTC` 才是正確的？

MariaDB 的 `DATETIME` 是**無時區**的型別，它只是存「年月日時分秒」，不帶時區資訊。Debezium 讀取時預設把它當作 UTC epoch 毫秒數寫入 Kafka。

所以 Sink 端也要用 UTC 來解讀這個 epoch 毫秒數，才能還原出一模一樣的時間值：

```
Source: 2026-01-15 10:00:00 (無時區)
  → Debezium 當 UTC 讀: epoch = 1768471200000
    → Sink 用 UTC 寫: 2026-01-15 10:00:00 ✅
    → Sink 用 +08 寫: 2026-01-15 18:00:00 ❌ (被多加了 8 小時)
```

### `date.timezone`（10.9.2 新增）為什麼沒效果？

`date.timezone` 只影響 `DATE` 型別（`setDate()` 呼叫）。在我們的測試中，DATE 欄位不管用什麼時區設定，值都是一樣的（`2026-01-15`），因為日期沒有跨日邊界。理論上如果 epoch 值落在時區換算後跨日的位置，`date.timezone` 才會造成差異。

### 10.6.4 vs 10.9.2 為什麼完全一樣？

因為時區處理的核心邏輯（用 `Calendar` 設定時區傳給 JDBC driver）在兩個版本之間沒有改變。10.9.2 只是多了 `date.timezone` 選項來讓 DATE 的時區設定可以獨立於 `db.timezone`，但底層的轉換機制是一樣的。**升級不會造成 regression。**

---

## 測試總結（中文）

### 測試目的

驗證 Confluent JDBC Sink Connector 從 10.6.4 升級到 10.9.2 是否有時區處理的 regression。

### 結論

**升級 10.6.4 → 10.9.2 無 regression，兩個版本在所有情境下結果完全一致。**

### 兩種模式的差異

| | `time.precision.mode=adaptive`（預設） | `time.precision.mode=connect` |
|---|---|---|
| Kafka 內的 schema name | `io.debezium.time.*` | `org.apache.kafka.connect.data.*` |
| Confluent Sink 是否認識 | 不認識 | 認識 |
| 自動建立的目標欄位型別 | `bigint` / `int` / `text` | `datetime(3)` / `date` / `time(3)` |
| `db.timezone` 是否生效 | 無效（raw 值直接存入） | **有效（會做時區轉換）** |
| `db.timezone=Asia/Taipei` 影響 | 無 | DATETIME 和 TIME **被多加 8 小時** |
| `date.timezone`（10.9.2 新增）影響 | 無 | 無（DATE 在測試中未跨日） |

### 實務建議

1. **`db.timezone` 應設為 `UTC`** — MariaDB 的 DATETIME 無時區資訊，Debezium 以 UTC 讀取，Sink 端也要用 UTC 寫入才能還原正確的值
2. **`time.precision.mode` 決定一切** — 它決定了 Confluent JDBC Sink 能不能認識時間型別，進而決定 `db.timezone` 有沒有作用
3. **升級安全** — 10.6.4 和 10.9.2 在相同設定下產出完全一致的結果
4. **預設 `adaptive` 模式下不可手動建表用 `DATETIME` 欄位** — Confluent JDBC Sink 會把 epoch 毫秒數直接塞進 `DATETIME` 欄位，MariaDB 拒絕寫入，connector task 直接 FAILED
5. **Debezium MySQL Source 沒有 `database.connectionTimezone` 參數** — 那是 MySQL JDBC Driver 的連線參數，不是 Debezium connector 的設定項
