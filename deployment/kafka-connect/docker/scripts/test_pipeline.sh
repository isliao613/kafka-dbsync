#!/bin/bash
# Test script for Big-5 encoding pipeline
# This script helps test the LegacyCharsetTransform SMT

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DOCKER_DIR="$(dirname "$SCRIPT_DIR")"

cd "$DOCKER_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

wait_for_connect() {
    log_info "Waiting for Kafka Connect to be ready..."
    until curl -sf http://localhost:8083/connectors > /dev/null 2>&1; do
        echo -n "."
        sleep 2
    done
    echo ""
    log_info "Kafka Connect is ready!"
}

deploy_connector() {
    local config_file=$1
    local connector_name=$(jq -r '.name' "$config_file")

    log_info "Deploying connector: $connector_name"

    # Check if connector exists
    if curl -sf "http://localhost:8083/connectors/$connector_name" > /dev/null 2>&1; then
        log_warn "Connector $connector_name already exists, deleting..."
        curl -sf -X DELETE "http://localhost:8083/connectors/$connector_name"
        sleep 2
    fi

    # Deploy connector
    curl -sf -X POST \
        -H "Content-Type: application/json" \
        -d @"$config_file" \
        "http://localhost:8083/connectors" | jq .

    log_info "Connector $connector_name deployed"
}

consume_topic() {
    local topic=$1
    local count=${2:-5}

    log_info "Consuming $count messages from topic: $topic"
    docker compose exec -T kafka-consumer /opt/kafka/bin/kafka-console-consumer.sh \
        --bootstrap-server kafka:9092 \
        --topic "$topic" \
        --from-beginning \
        --max-messages "$count" \
        --timeout-ms 10000 2>/dev/null | jq -r '.payload.after // .after // .' 2>/dev/null || cat
}

list_topics() {
    log_info "Listing Kafka topics..."
    docker compose exec -T kafka /opt/kafka/bin/kafka-topics.sh \
        --bootstrap-server localhost:9092 \
        --list
}

case "${1:-help}" in
    start)
        log_info "Starting all services..."
        docker compose up -d --build
        log_info "Waiting for services to be healthy..."
        sleep 10
        wait_for_connect
        log_info "All services started!"
        ;;

    stop)
        log_info "Stopping all services..."
        docker compose down
        ;;

    clean)
        log_info "Cleaning up volumes..."
        docker compose down -v
        ;;

    insert-data)
        log_info "Inserting Big-5 test data..."
        docker compose exec oracle bash -c 'cd /container-entrypoint-startdb.d && ./insert_big5_data.sh'
        ;;

    deploy-without-smt)
        wait_for_connect
        deploy_connector "connectors/oracle-source.json"
        log_info "Connector deployed WITHOUT SMT transformation"
        log_info "Topic will be: oracle.TESTUSER.CUSTOMERS"
        ;;

    deploy-with-smt)
        wait_for_connect
        deploy_connector "connectors/oracle-source-with-smt.json"
        log_info "Connector deployed WITH SMT transformation"
        log_info "Topic will be: oracle-smt.TESTUSER.CUSTOMERS"
        ;;

    consume-raw)
        consume_topic "oracle.TESTUSER.CUSTOMERS" "${2:-5}"
        ;;

    consume-smt)
        consume_topic "oracle-smt.TESTUSER.CUSTOMERS" "${2:-5}"
        ;;

    topics)
        list_topics
        ;;

    connectors)
        log_info "Listing connectors..."
        curl -s http://localhost:8083/connectors | jq .
        ;;

    connector-status)
        local name=${2:-oracle-source}
        log_info "Connector status: $name"
        curl -s "http://localhost:8083/connectors/$name/status" | jq .
        ;;

    logs)
        docker compose logs -f "${2:-kafka-connect}"
        ;;

    help|*)
        echo "Usage: $0 <command>"
        echo ""
        echo "Commands:"
        echo "  start              - Start all services"
        echo "  stop               - Stop all services"
        echo "  clean              - Stop and remove volumes"
        echo "  insert-data        - Insert Big-5 test data into Oracle"
        echo "  deploy-without-smt - Deploy Oracle connector WITHOUT SMT"
        echo "  deploy-with-smt    - Deploy Oracle connector WITH SMT"
        echo "  consume-raw [n]    - Consume n messages from raw topic"
        echo "  consume-smt [n]    - Consume n messages from SMT topic"
        echo "  topics             - List Kafka topics"
        echo "  connectors         - List deployed connectors"
        echo "  connector-status   - Show connector status"
        echo "  logs [service]     - Follow logs for a service"
        echo ""
        echo "Test workflow:"
        echo "  1. $0 start"
        echo "  2. $0 insert-data"
        echo "  3. $0 deploy-without-smt"
        echo "  4. $0 consume-raw        # Shows garbled Big-5 data"
        echo "  5. $0 deploy-with-smt"
        echo "  6. $0 consume-smt        # Shows properly decoded UTF-8"
        ;;
esac
