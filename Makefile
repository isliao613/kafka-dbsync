# Makefile
#
# Main aggregator Makefile that delegates to sub-Makefiles.
# This provides a unified interface for all operations.
#
# Each sub-Makefile can also be run independently:
#   make -f Makefile.common <target>   # Infrastructure and utilities
#   make -f Makefile.docker <target>   # Docker image builds
#   make -f Makefile.e2e <target>      # E2E testing
#   make -f Makefile.datatype <target> # Datatype testing
#   make -f Makefile.iidr <target>     # IIDR CDC sink testing
#
# ==============================================================================

.DEFAULT_GOAL := help

# Include shared parameters for display in help
include Makefile.param

# =============================================================================
# Help
# =============================================================================

.PHONY: help
help:
	@echo "Kafka DBSync - CDC Testing Framework"
	@echo "====================================="
	@echo ""
	@echo "Usage: make [target]"
	@echo ""
	@echo "You can also run each Makefile independently:"
	@echo "  make -f Makefile.common help    # Infrastructure and utilities"
	@echo "  make -f Makefile.docker help    # Docker image builds"
	@echo "  make -f Makefile.e2e help       # E2E testing"
	@echo "  make -f Makefile.datatype help  # Datatype testing"
	@echo "  make -f Makefile.iidr help      # IIDR CDC sink testing"
	@echo ""
	@echo "=== Infrastructure (Makefile.common) ==="
	@echo "  base-infra-up        - Create Kind cluster and deploy base services"
	@echo "  clean                - Delete Kind cluster and all services"
	@echo "  .tools               - Install required tools (kubectl, helm, kind)"
	@echo "  setup-oracle         - Set up Oracle XE 21c for CDC"
	@echo "  setup-mariadb        - Set up MariaDB target database"
	@echo "  setup-postgres       - Set up PostgreSQL target database"
	@echo "  logs                 - View Kafka Connect logs"
	@echo "  status               - Check connector status"
	@echo "  port-forward         - Set up port forwarding"
	@echo ""
	@echo "=== Docker Builds (Makefile.docker) ==="
	@echo "  build                - Build Kafka Connect with Debezium"
	@echo ""
	@echo "=== E2E Testing (Makefile.e2e) ==="
	@echo "  e2e-all              - Full E2E pipeline"
	@echo "  e2e-setup            - Set up databases for testing"
	@echo "  e2e-run              - Run CDC tests (insert, update, delete)"
	@echo "  e2e-verify           - Verify data in target tables"
	@echo "  e2e-clean            - Clean up connectors and tables"
	@echo "  e2e-register         - Register connectors"
	@echo ""
	@echo "=== Datatype Testing (Makefile.datatype) ==="
	@echo "  datatype-all         - Full datatype test"
	@echo "  datatype-setup       - Set up Oracle and MariaDB for datatype testing"
	@echo "  datatype-register    - Register Debezium connectors"
	@echo "  datatype-verify      - Verify data in MariaDB"
	@echo "  datatype-clean       - Clean up connectors and tables"
	@echo ""
	@echo "=== IIDR CDC Sink Testing (Makefile.iidr) ==="
	@echo "  iidr-all             - Full IIDR test"
	@echo "  iidr-setup           - Set up Kafka topic and databases"
	@echo "  iidr-register        - Register IIDR MariaDB sink connector"
	@echo "  iidr-register-pg     - Register IIDR PostgreSQL sink"
	@echo "  iidr-register-jdbc   - Register IIDR JDBC sink (MariaDB, SMT-based)"
	@echo "  iidr-register-jdbc-pg - Register IIDR JDBC sink (PostgreSQL, SMT-based)"
	@echo "  iidr-run             - Produce test IIDR CDC events"
	@echo "  iidr-verify          - Verify data in MariaDB and PostgreSQL"
	@echo "  iidr-status          - Check IIDR connector status"
	@echo "  iidr-clean           - Clean up IIDR test resources"
	@echo ""
	@echo "Kafka Connect Service:"
	@echo "  Debezium: $(KAFKA_CONNECT_SVC):8083"

# =============================================================================
# Infrastructure (Makefile.common)
# =============================================================================

.PHONY: base-infra-up clean .tools .check-tools setup-oracle setup-mariadb setup-postgres \
	logs status port-forward

base-infra-up:
	@$(MAKE) -f Makefile.common base-infra-up

clean:
	@$(MAKE) -f Makefile.common clean

.tools:
	@$(MAKE) -f Makefile.common .tools

.check-tools:
	@$(MAKE) -f Makefile.common .check-tools

setup-oracle:
	@$(MAKE) -f Makefile.common setup-oracle

setup-mariadb:
	@$(MAKE) -f Makefile.common setup-mariadb

setup-postgres:
	@$(MAKE) -f Makefile.common setup-postgres

logs:
	@$(MAKE) -f Makefile.common logs

status:
	@$(MAKE) -f Makefile.common status

port-forward:
	@$(MAKE) -f Makefile.common port-forward

# =============================================================================
# Docker Builds (Makefile.docker)
# =============================================================================

.PHONY: build

build:
	@$(MAKE) -f Makefile.docker build

# =============================================================================
# E2E Testing (Makefile.e2e)
# =============================================================================

.PHONY: e2e-all \
	e2e-setup e2e-run e2e-verify e2e-clean \
	e2e-register

e2e-all:
	@$(MAKE) -f Makefile.e2e all

e2e-setup:
	@$(MAKE) -f Makefile.e2e test-setup

e2e-run:
	@$(MAKE) -f Makefile.e2e test-run

e2e-verify:
	@$(MAKE) -f Makefile.e2e test-verify

e2e-clean:
	@$(MAKE) -f Makefile.e2e test-clean

e2e-register:
	@$(MAKE) -f Makefile.e2e register

# =============================================================================
# Datatype Testing (Makefile.datatype)
# =============================================================================

.PHONY: datatype-all \
	datatype-setup datatype-register datatype-verify datatype-clean

datatype-all:
	@$(MAKE) -f Makefile.datatype all

datatype-setup:
	@$(MAKE) -f Makefile.datatype setup

datatype-register:
	@$(MAKE) -f Makefile.datatype register

datatype-verify:
	@$(MAKE) -f Makefile.datatype verify

datatype-clean:
	@$(MAKE) -f Makefile.datatype clean

# =============================================================================
# IIDR CDC Sink Testing (Makefile.iidr)
# =============================================================================

.PHONY: iidr-all \
	iidr-setup iidr-register iidr-register-pg \
	iidr-register-jdbc iidr-register-jdbc-pg \
	iidr-run iidr-verify iidr-status iidr-clean

iidr-all:
	@$(MAKE) -f Makefile.iidr all

iidr-setup:
	@$(MAKE) -f Makefile.iidr setup

iidr-register:
	@$(MAKE) -f Makefile.iidr register

iidr-register-pg:
	@$(MAKE) -f Makefile.iidr register-pg

iidr-register-jdbc:
	@$(MAKE) -f Makefile.iidr register-jdbc

iidr-register-jdbc-pg:
	@$(MAKE) -f Makefile.iidr register-jdbc-pg

iidr-run:
	@$(MAKE) -f Makefile.iidr run

iidr-verify:
	@$(MAKE) -f Makefile.iidr verify

iidr-status:
	@$(MAKE) -f Makefile.iidr status

iidr-clean:
	@$(MAKE) -f Makefile.iidr clean
