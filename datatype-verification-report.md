# Data Type Verification Report: Debezium 2.x vs. 3.x

## 1. Summary

The data type verification test, executed via `make datatype-verify`, completed **successfully**. A detailed comparison of data processed by both Debezium 2.x and Debezium 3.x configurations reveals **no discrepancies**. This indicates that data integrity and type consistency are maintained across both versions.

## 2. Test Objective

The primary objective of this test was to verify that a wide range of data types are handled consistently when captured and streamed through different major versions of Debezium (2.x and 3.x) into a MariaDB sink.

## 3. Test Results

The log contains two data dumps from a MariaDB table, corresponding to two separate test runs:

*   **Debezium 2.x Data:** The dataset processed by the older connector version.
*   **Debezium 3.x Data:** The dataset processed by the newer connector version.

A comparison of these two datasets shows them to be **identical**. The test suite was comprehensive, covering scenarios such as:
*   A variety of numeric, character, and timestamp formats.
*   Large objects (CLOB, BLOB).
*   Positive and negative values.
*   `NULL` values and zero/empty values.

### Tested Data Types

**Numeric Types:**
*   `NUMBER`
*   `NUMBER(5,0)`
*   `NUMBER(10,0)`
*   `NUMBER(19,0)`
*   `NUMBER(38,0)`
*   `NUMBER(10,2)`
*   `NUMBER(15,5)`
*   `FLOAT`
*   `BINARY_FLOAT`
*   `BINARY_DOUBLE`

**Character String Types:**
*   `CHAR(10)`
*   `CHAR(50)`
*   `VARCHAR2(50)`
*   `VARCHAR2(500)`
*   `VARCHAR2(4000)`
*   `NCHAR(10)`
*   `NVARCHAR2`
*   `CLOB` (Character Large Object)
*   `NCLOB` (National Character Large Object)

**Datetime Types:**
*   `DATE`
*   `TIMESTAMP`
*   `TIMESTAMP(3)`
*   `TIMESTAMP(6)`
*   `TIMESTAMP(9)`
*   `TIMESTAMP WITH TIME ZONE`
*   `TIMESTAMP WITH LOCAL TIME ZONE`

**Interval Types:**
*   `INTERVAL YEAR TO MONTH`
*   `INTERVAL DAY TO SECOND`

**Binary Types:**
*   `BLOB` (Binary Large Object)
*   `RAW`

**Boolean (Simulated):**
*   `BOOLEAN_SIM` (Likely simulated using a `NUMBER` type)

## 4. Conclusion

The fact that both datasets are identical confirms that the data processing pipeline behaves consistently across both Debezium 2.x and 3.x. The test demonstrates that an upgrade or migration between these versions is unlikely to cause data corruption or unintended data type transformations for the tested schema.

The verification is considered a **success**.

## 5. Appendix: Raw Verification Log

```log
make[1]: 進入目錄「/home/kasm-user/workspaces/kafka-dbsync」
[INFO] Verifying data in MariaDB for datatype testing...
[INFO] Debezium 2.x data:
ID	COL_NUMBER	COL_NUMBER_5	COL_NUMBER_10	COL_NUMBER_19	COL_NUMBER_38	COL_NUMBER_10_2	COL_NUMBER_15_5	COL_FLOAT	COL_BINARY_FLOAT	COL_BINARY_DOUBLE	COL_CHAR	COL_CHAR_50	COL_VARCHAR2_50	COL_VARCHAR2_500	COL_VARCHAR2_4000	COL_NCHAR	COL_NVARCHAR2	COL_DATE	COL_TIMESTAMP	COL_TIMESTAMP_3	COL_TIMESTAMP_6	COL_TIMESTAMP_9	COL_TIMESTAMP_TZ	COL_TIMESTAMP_LTZ	COL_INTERVAL_YM	COL_INTERVAL_DS	COL_CLOB	COL_NCLOB	COL_BLOB	COL_RAW	COL_BOOLEAN_SIM
1	123456.789	12345	1234567890	1234567890123456789	12345678901234567890123456789012345678	12345678.90	1234567890.12345	3.14159	3.14159	3.141592653589793	CHAR10    	Character data with padding                       	VARCHAR2 short	VARCHAR2 medium length text	VARCHAR2 longer text content here	NCHAR     	Unicode text	1749945600000	1749997845123456	1749997845123	1749997845123456	1749997845123456789	2025-06-15T14:30:45.123456+09:00	2025-06-15T14:30:45.123456Z	165677400000000	883815123456	This is a CLOB test content.	This is NCLOB with Unicode	Binary BLOB data	Raw binary	1
2	-999999.999	-99999	-2147483648	-9223372036854775808	-99999999999999999999999999999999999999	-99999999.99	-9999999999.99999	-3.14159	-3.14159	-3.141592653589793	NEG       	Negative test values                              	Negative	Edge case negative numbers	Testing negative handling	NEG       	Negative test	0	1	1	1	1	1970-01-01T00:00:00.000001-12:00	1970-01-01T00:00:00.000001Z	-3153130200000000	-8639999999999	CLOB negative test	NCLOB negative	Negative BLOB	NegRaw	0
3	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL
4	0	0	0	0	0	0.00	0.00000	0	0	0	          	                                                  	NULL	NULL	NULL	          	NULL	946684800000	946684800000000	946684800000	946684800000000	946684800000000000	2000-01-01T00:00:00.000000Z	2000-01-01T00:00:00.000000Z	0	0	NULL	NULL	NULL	NULL	0
[INFO] Debezium 3.x data:
ID	COL_NUMBER	COL_NUMBER_5	COL_NUMBER_10	COL_NUMBER_19	COL_NUMBER_38	COL_NUMBER_10_2	COL_NUMBER_15_5	COL_FLOAT	COL_BINARY_FLOAT	COL_BINARY_DOUBLE	COL_CHAR	COL_CHAR_50	COL_VARCHAR2_50	COL_VARCHAR2_500	COL_VARCHAR2_4000	COL_NCHAR	COL_NVARCHAR2	COL_DATE	COL_TIMESTAMP	COL_TIMESTAMP_3	COL_TIMESTAMP_6	COL_TIMESTAMP_9	COL_TIMESTAMP_TZ	COL_TIMESTAMP_LTZ	COL_INTERVAL_YM	COL_INTERVAL_DS	COL_CLOB	COL_NCLOB	COL_BLOB	COL_RAW	COL_BOOLEAN_SIM
1	123456.789	12345	1234567890	1234567890123456789	12345678901234567890123456789012345678	12345678.90	1234567890.12345	3.14159	3.14159	3.141592653589793	CHAR10    	Character data with padding                       	VARCHAR2 short	VARCHAR2 medium length text	VARCHAR2 longer text content here	NCHAR     	Unicode text	1749945600000	1749997845123456	1749997845123	1749997845123456	1749997845123456789	2025-06-15T14:30:45.123456+09:00	2025-06-15T14:30:45.123456Z	165677400000000	883815123456	This is a CLOB test content.	This is NCLOB with Unicode	Binary BLOB data	Raw binary	1
2	-999999.999	-99999	-2147483648	-9223372036854775808	-99999999999999999999999999999999999999	-99999999.99	-9999999999.99999	-3.14159	-3.14159	-3.141592653589793	NEG       	Negative test values                              	Negative	Edge case negative numbers	Testing negative handling	NEG       	Negative test	0	1	1	1	1	1970-01-01T00:00:00.000001-12:00	1970-01-01T00:00:00.000001Z	-3153130200000000	-8639999999999	CLOB negative test	NCLOB negative	Negative BLOB	NegRaw	0
3	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL	NULL
4	0	0	0	0	0	0.00	0.00000	0	0	0	          	                                                  	NULL	NULL	NULL	          	NULL	946684800000	946684800000000	946684800000	946684800000000	946684800000000000	2000-01-01T00:00:00.000000Z	2000-01-01T00:00:00.000000Z	0	0	NULL	NULL	NULL	NULL	0
make[1]: 離開目錄「/home/kasm-user/workspaces/kafka-dbsync」
```
