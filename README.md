# Kafka-DBSync

Kubernetes-based CDC toolkit for database replication using Kafka, Debezium, and JDBC connectors.

## Features

- **Multi-Database CDC**: Oracle, MariaDB, MSSQL via Debezium
- **Dual Debezium Support**: Run 2.x and 3.x side-by-side for migration testing
- **IIDR Sink Connector**: Custom connector for IBM InfoSphere Data Replication events
- **Kafka 4.0**: KRaft mode (no ZooKeeper)
- **Web UIs**: Redpanda Console and Kafka Connect UI
- **Kubernetes-Native**: Helm charts for all components

## Architecture

```
┌─────────────┐     ┌─────────────────────────────────┐     ┌─────────────┐
│   Source    │     │          Kafka Cluster          │     │   Target    │
│  (Oracle/   │────▶│  ┌─────────────────────────┐    │────▶│  (MariaDB/  │
│   MSSQL)    │     │  │ Kafka Connect 2.x / 3.x │    │     │   MySQL)    │
└─────────────┘     │  └─────────────────────────┘    │     └─────────────┘
                    └─────────────────────────────────┘
```

## Quick Start

```bash
# Install tools (kubectl, helm, kind)
make .tools

# Full E2E pipeline with both Debezium 2.x and 3.x
make all-dual

# Or single version
make all-v2   # Debezium 2.x only
make all-v3   # Debezium 3.x only

# Verify replication
make test-verify

# Cleanup
make clean
```

## Make Targets

### Main Workflows

| Target | Description |
|--------|-------------|
| `all-v2` | Full E2E with Debezium 2.x |
| `all-v3` | Full E2E with Debezium 3.x |
| `all-dual` | Full E2E with both versions |
| `clean` | Delete cluster and services |

### Infrastructure

| Target | Description |
|--------|-------------|
| `.tools` | Install kubectl, helm, kind |
| `base-infra-up` | Create cluster, deploy Kafka/Oracle/MariaDB |
| `build-v2` / `build-v3` | Build Kafka Connect images |
| `port-forward` | Forward all service ports |

### Testing

| Target | Description |
|--------|-------------|
| `test-setup` | Set up databases |
| `test-run` | Run CDC tests (INSERT/UPDATE/DELETE) |
| `test-verify` | Verify target tables |
| `test-clean` | Clean up connectors and tables |
| `register-v2` / `register-v3` | Register connectors |
| `verify-v2` / `verify-v3` | Verify specific version |

### Data Type Testing

| Target | Description |
|--------|-------------|
| `datatype-all-dual` | Compare 2.x vs 3.x data type handling |
| `datatype-verify` | Show data from both versions |

### IIDR Sink Connector

| Target | Description |
|--------|-------------|
| `iidr-all-v2` / `iidr-all-v3` | Full IIDR sink test |
| `iidr-run` | Produce test IIDR events |
| `iidr-verify` | Verify IIDR sink results |

### Utilities

| Target | Description |
|--------|-------------|
| `logs-v2` / `logs-v3` | View Kafka Connect logs |
| `status-v2` / `status-v3` | Check connector status |

## Web UIs

```bash
make port-forward
```

| UI | URL | Description |
|----|-----|-------------|
| Redpanda Console | http://localhost:8080 | Topics, messages, consumer groups |
| Kafka Connect UI | http://localhost:8000 | Connector management |

## Project Structure

```
kafka-dbsync/
├── Makefile*            # Automation targets
├── deployment/          # Helm wrapper charts
│   ├── kafka/          # Kafka (Bitnami)
│   ├── kafka-connect/  # Confluent Kafka Connect + Debezium
│   ├── oracle/         # Oracle XE 21c
│   └── mariadb/        # MariaDB
├── hack/               # Test configs and scripts
│   ├── source-debezium/  # Debezium connector configs
│   ├── sink-jdbc/        # JDBC sink configs
│   └── sql/              # Database setup scripts
└── helm-chart/         # Source Helm charts
```

## Dual Debezium Mode

Run both versions for migration testing:

| Version | Service | Java | Debezium |
|---------|---------|------|----------|
| 2.x | `dbrep-kafka-connect-cp-kafka-connect:8083` | 11 | 2.6.x |
| 3.x | `dbrep-kafka-connect-v3-cp-kafka-connect:8083` | 17 | 3.4.x |

Each version writes to separate target tables (`*_v2`, `*_v3`) for comparison.

## IIDR Sink Connector

Custom sink connector for IBM IIDR CDC events with A_ENTTYP header mapping:

| A_ENTTYP | Operation |
|----------|-----------|
| PT, RR, PX, UR | UPSERT |
| UP, FI, FP | UPSERT |
| DL, DR | DELETE |

See [IIDR Connector README](deployment/kafka-connect/docker/sink/IidrCdcSinkConnector/README.md) for details.

## Troubleshooting

```bash
# Check pods
kubectl get pods -n dev

# View logs
make logs-v2
make logs-v3

# Check connector status
make status-v2
make status-v3

# Reset everything
make clean && make all-dual
```

| Issue | Solution |
|-------|----------|
| Pods not starting | Increase Docker memory (8GB+ recommended) |
| Connector FAILED | Check logs, verify database connectivity |
| No data replicating | Check connector status |

## Documentation

- [E2E Test Guide](hack/E2E_TEST_ORACLE_CDC.md)
- [IIDR Sink Connector](deployment/kafka-connect/docker/sink/IidrCdcSinkConnector/README.md)
- [Connector Configs](hack/)

## References

- [Debezium](https://debezium.io/)
- [Confluent Kafka Connect](https://docs.confluent.io/platform/current/connect/)
- [Apache Kafka](https://kafka.apache.org/)
