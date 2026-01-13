# Architecture Documentation

## Overview

Kafka-DBSync is a Kubernetes-native CDC (Change Data Capture) toolkit that enables real-time database replication using Apache Kafka, Debezium, and JDBC connectors. The architecture follows cloud-native principles with containerized workloads, declarative configurations, and infrastructure-as-code.

## High-Level Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                     Kubernetes Cluster                          │
│                                                                 │
│  ┌──────────────┐     ┌────────────────┐     ┌──────────────┐ │
│  │   Source DB  │────▶│  Kafka Cluster │────▶│  Target DB   │ │
│  │              │     │                │     │              │ │
│  │ Oracle/MSSQL │     │  - Brokers (3) │     │ MariaDB/MSSQL│ │
│  │ MariaDB      │     │  - Topics      │     │              │ │
│  └──────────────┘     │  - KRaft Mode  │     └──────────────┘ │
│         │             └────────────────┘            ▲          │
│         │                      ▲                    │          │
│         │                      │                    │          │
│         │             ┌────────────────┐            │          │
│         └────────────▶│ Kafka Connect  │────────────┘          │
│                       │                │                       │
│                       │ - Debezium CDC │                       │
│                       │ - JDBC Sink    │                       │
│                       └────────────────┘                       │
│                                                                 │
│  ┌──────────────────────────────────────────────────────────┐  │
│  │              Supporting Services                         │  │
│  │  - Kafka Connect UI (port 8000)                          │  │
│  │  - MinIO (S3-compatible storage)                         │  │
│  └──────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────┘
```

## CDC Data Flow

### 1. Source Database Changes

```sql
-- User performs operation in source database
INSERT INTO DEMO.SOURCE_ORDERS VALUES(...);
UPDATE DEMO.SOURCE_ORDERS SET status='COMPLETED' WHERE id=1;
DELETE FROM DEMO.SOURCE_ORDERS WHERE id=3;
```

### 2. Debezium Source Connector

- **LogMiner (Oracle)**: Reads from redo/archive logs
- **CDC (MSSQL)**: Reads from SQL Server CDC tables

Produces Kafka messages:
```json
{
  "before": {...},  // Previous value (for UPDATE/DELETE)
  "after": {...},   // New value (for INSERT/UPDATE)
  "op": "c|u|d|r",  // Operation: create, update, delete, read
  "ts_ms": 1234567890
}
```

### 3. Kafka Topics

Topic naming: `{prefix}.{schema}.{table}`

Example: `cdc_oracle.DEMO.SOURCE_ORDERS`

### 4. JDBC Sink Connector

- Consumes from Kafka topics
- Transforms CDC events to SQL
- Applies to target database (INSERT/UPDATE/DELETE)
- Supports upsert mode for idempotency

### 5. Target Database

Data appears in target database with minimal latency (<1 second typically).

## Helm Chart Pattern

### Two-Tier Architecture

The project uses a **wrapper chart pattern** to separate deployment customization from base chart definitions:

```
deployment/              # Environment-specific wrappers
├── kafka/
│   ├── Chart.yaml      # Dependencies: helm-chart/kafka
│   └── values.yaml     # Override values for this deployment
├── oracle/
│   ├── Chart.yaml      # Dependencies: helm-chart/oracle
│   └── values.yaml     # Override values for this deployment
└── ...

helm-chart/             # Reusable base charts
├── kafka/
│   ├── Chart.yaml      # Chart metadata
│   ├── templates/      # Kubernetes manifests
│   └── values.yaml     # Default values
├── oracle/
│   ├── Chart.yaml
│   ├── templates/
│   └── values.yaml
└── ...
```

### Benefits

1. **Separation of Concerns**
   - Base charts (`helm-chart/`) define the "how" (templates, configurations)
   - Wrapper charts (`deployment/`) define the "what" (environment-specific values)

2. **Reusability**
   - Base charts can be versioned and published to chart repositories
   - Same base chart can be deployed to dev, staging, prod with different wrappers

3. **Maintainability**
   - Update base chart once, all deployments benefit
   - Environment-specific changes isolated to wrapper values

4. **Testing**
   - Base charts can be tested independently
   - Wrapper values can be validated against base schemas

### Example: Kafka Wrapper Chart

**deployment/kafka/Chart.yaml:**
```yaml
apiVersion: v2
name: kafka-wrapper
version: 1.0.0
dependencies:
  - name: kafka
    version: "32.4.3"
    repository: "file://../../helm-chart/kafka"
```

**deployment/kafka/values.yaml:**
```yaml
kafka:  # Override values for the base kafka chart
  replicaCount: 3
  kraft:
    enabled: true
  persistence:
    size: 8Gi
```

**Usage:**
```bash
helm install dbrep-kafka deployment/kafka -f deployment/kafka/values.yaml
```

This installs the base `helm-chart/kafka` chart with customizations from the wrapper.

## Component Details

### Kafka Cluster

- **Mode**: KRaft (Kafka Raft - no ZooKeeper)
- **Brokers**: 3 replicas for high availability
- **Storage**: Persistent volumes for durability
- **Version**: 4.0+
- **Chart**: Bitnami Kafka (community-maintained)

**Key Configurations:**
- `auto.create.topics.enable=true` - Auto-create topics for new tables
- `log.retention.hours=168` - 7-day retention
- `min.insync.replicas=2` - Durability setting

### Kafka Connect

- **Distribution**: Confluent Platform
- **Connectors**:
  - Debezium Oracle/MSSQL (source)
  - Confluent JDBC Sink (sink)
- **REST API**: Port 8083
- **Deployment**: Single replica (can be scaled)

**Connector Management:**
```bash
# List connectors
curl http://localhost:8083/connectors

# Get status
curl http://localhost:8083/connectors/{name}/status

# Register new connector
curl -X POST http://localhost:8083/connectors \
  -H "Content-Type: application/json" \
  -d @connector-config.json
```

### Source Databases

| Database | Image | Version | Mode |
|----------|-------|---------|------|
| Oracle EE | Enterprise Edition | 19c | Full (LIGHTWEIGHT=0) |
| Oracle XE | gvenzl/oracle-xe | 21c | Fast (LIGHTWEIGHT=1) |
| MariaDB | Bitnami MariaDB | 11.x | - |
| MSSQL | Microsoft SQL Server | 2019 | - |

### Target Databases

Typically MariaDB or MSSQL, but any JDBC-compatible database is supported.

## Deployment Modes

### Lightweight Mode (Default)

```bash
make all LIGHTWEIGHT=1
```

- **Oracle**: XE 21c (free, fast startup ~2-3 min)
- **Resources**: Lower memory requirements
- **Use Case**: Development, testing, demos

### Enterprise Mode

```bash
make all LIGHTWEIGHT=0
```

- **Oracle**: EE 19c (full features, slow startup ~10 min)
- **Resources**: Production-like requirements
- **Use Case**: Production testing, performance evaluation

## Network Architecture

### Service Discovery

All services use Kubernetes DNS:

```
{service-name}.{namespace}.svc.cluster.local
```

Examples:
- `dbrep-kafka.dev.svc.cluster.local:9092`
- `dbrep-mariadb.dev.svc.cluster.local:3306`
- `dbrep-oracle-oracle-db.dev.svc.cluster.local:1521`

### Port Forwarding (Development)

```bash
make port-forward
```

Exposes:
- Kafka Connect REST API: `localhost:8083`
- Kafka Connect UI: `localhost:8000`

## Data Persistence

### Storage Classes

- **Kafka**: Uses PVCs for broker data
- **Databases**: Uses PVCs for data files
- **Kind Cluster**: Uses host path for PVs (development only)

### Retention Policies

- **Kafka Topics**: 7 days (configurable)
- **Database Logs**: Varies by database type
  - Oracle: Archive logs (7 days recommended)
  - MariaDB: Binlog retention (7 days)

## Security Considerations

### Development Environment (Current State)

- Default passwords (NOT for production)
- No TLS/SSL encryption
- No authentication on Kafka
- Suitable for local testing only

### Production Recommendations

1. **Secrets Management**: Use Kubernetes Secrets or external vaults
2. **Encryption**: Enable TLS for Kafka and database connections
3. **Authentication**: Enable SASL for Kafka, rotate database credentials
4. **Network Policies**: Restrict pod-to-pod communication
5. **RBAC**: Implement least-privilege access controls

## Scalability

### Horizontal Scaling

- **Kafka Brokers**: Increase `replicaCount` in values
- **Kafka Connect**: Scale deployment for higher throughput
- **Databases**: Configure replication (beyond scope)

### Vertical Scaling

Adjust resource requests/limits in `values.yaml`:

```yaml
resources:
  requests:
    memory: "2Gi"
    cpu: "1000m"
  limits:
    memory: "4Gi"
    cpu: "2000m"
```

## Monitoring and Observability

### Current State

- Kafka Connect UI for connector status
- `kubectl logs` for debugging
- `make status` for health checks

### Production Recommendations

1. **Metrics**: Prometheus exporters for Kafka, databases
2. **Logging**: Centralized logging (ELK, Loki)
3. **Tracing**: Distributed tracing for connector pipeline
4. **Alerting**: Alert on connector failures, lag metrics

## Troubleshooting Architecture

### Common Issues

1. **Connector Fails to Start**
   - Check database connectivity from Kafka Connect pod
   - Verify credentials and privileges
   - Review connector logs: `make logs`

2. **No Data Flowing**
   - Verify topic exists: `make topics`
   - Check source connector is in RUNNING state
   - Verify sink connector is subscribed to correct topic

3. **Performance Issues**
   - Increase Kafka Connect resources
   - Tune connector configurations (batch size, poll interval)
   - Check network latency between components

### Debug Commands

```bash
# Pod status
make pods

# Connector logs
make logs

# Connector status
make status

# List topics
make topics

# Execute into pod
kubectl exec -it <pod-name> -- bash

# View events
kubectl get events -n dev --sort-by='.lastTimestamp'
```

## References

- [Apache Kafka Documentation](https://kafka.apache.org/documentation/)
- [Debezium Documentation](https://debezium.io/documentation/)
- [Confluent Kafka Connect](https://docs.confluent.io/platform/current/connect/)
- [Helm Charts Best Practices](https://helm.sh/docs/chart_best_practices/)
- [Kubernetes Patterns](https://www.oreilly.com/library/view/kubernetes-patterns/9781492050278/)
