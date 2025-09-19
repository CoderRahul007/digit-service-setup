#!/usr/bin/env bash
set -euo pipefail

# ---------------- Colors & logging ----------------
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; PURPLE='\033[0;35m'; CYAN='\033[0;36m'; NC='\033[0m'
log_info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error()   { echo -e "${RED}[ERROR]${NC} $*"; }
log_step()    { echo -e "${PURPLE}[STEP]${NC} $*"; }

# ---------------- Settings ----------------
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-digit-oss}"
export NETWORK_NAME="${NETWORK_NAME:-digit-network}"

compose() {
  docker compose -p "${COMPOSE_PROJECT_NAME}" \
    -f docker-compose.infra.yml \
    -f docker-compose.services.yml \
    "$@"
}

# ---------------- Checks ----------------
check_docker() {
  if ! docker info >/dev/null 2>&1; then
    log_error "Docker is not running. Please start Docker Desktop first."
    exit 1
  fi
}

create_network() {
  if ! docker network inspect "${NETWORK_NAME}" >/dev/null 2>&1; then
    log_info "Creating custom network: ${NETWORK_NAME}"
    docker network create "${NETWORK_NAME}" >/dev/null
    log_success "Network ${NETWORK_NAME} created."
  else
    log_info "Network ${NETWORK_NAME} already exists."
  fi
}

# ---------------- Bring-up functions ----------------
start_infrastructure() {
  log_step "Starting infrastructure (Postgres, Redis, Kafka, Elasticsearch, Zookeeper, Nginx gateway)..."
  compose up -d postgres redis kafka zookeeper elasticsearch nginx-gateway

  log_info "Giving infra a moment to initialize..."
  sleep 15

  log_info "Checking Postgres..."
  docker exec "${COMPOSE_PROJECT_NAME}-postgres" pg_isready -U "${DB_USER:-postgres}" -d "${DB_NAME:-egov}" || true

  log_info "Checking Redis..."
  docker exec "${COMPOSE_PROJECT_NAME}-redis" sh -c "redis-cli -a ${REDIS_PASSWORD:-redis123} ping | grep PONG" || true

  log_info "Checking Kafka..."
  docker exec "${COMPOSE_PROJECT_NAME}-kafka" sh -c "kafka-topics --bootstrap-server localhost:9092 --list >/dev/null 2>&1" || true

  log_success "Infrastructure is up."
}

start_core_services() {
  log_step "Starting core DIGIT services..."
  compose up -d user access-control mdms-service workflow-v2 billing-service collection-services notification-sms filestore egov-idgen

  log_info "Letting core services warm up..."
  sleep 30
  log_success "Core services are starting."
}

start_custom_services() {
  log_step "Building & starting custom services (permit-service, vc-service)..."
  if [ -d "services/permit-service" ] && [ -f "services/permit-service/Dockerfile" ]; then
    compose build permit-service
  fi
  if [ -d "services/vc-service" ] && [ -f "services/vc-service/Dockerfile" ]; then
    compose build vc-service
  fi
  compose up -d permit-service vc-service
  log_info "Letting custom services warm up..."
  sleep 10
  log_success "Custom services are starting."
}

show_status() {
  echo
  log_info "Service URLs:"
  echo -e "${CYAN}Gateway:            ${NC} http://localhost:${GATEWAY_PORT:-8080}"
  echo -e "${CYAN}User Service:       ${NC} http://localhost:8081"
  echo -e "${CYAN}Access Control:     ${NC} http://localhost:8082"
  echo -e "${CYAN}MDMS Service:       ${NC} http://localhost:8083"
  echo -e "${CYAN}Workflow Service:   ${NC} http://localhost:8084"
  echo -e "${CYAN}Billing Service:    ${NC} http://localhost:8085"
  echo -e "${CYAN}Collection Service: ${NC} http://localhost:8086"
  echo -e "${CYAN}Notification SMS:   ${NC} http://localhost:8087"
  echo -e "${CYAN}IDGEN Service:      ${NC} http://localhost:8088"
  echo -e "${CYAN}Filestore:          ${NC} http://localhost:8089"
  echo -e "${CYAN}Permit Service:     ${NC} http://localhost:8090"
  echo -e "${CYAN}VC Service:         ${NC} http://localhost:8091"
  echo
  log_info "View logs with: docker compose -p ${COMPOSE_PROJECT_NAME} logs -f <service>"
}

start_all() {
  log_step "Starting ALL DIGIT OSS services..."
  check_docker
  create_network
  start_infrastructure
  start_core_services
  start_custom_services
  log_success "All services have been started."
  show_status
}

# ---------------- Entrypoint ----------------
case "${1:-all}" in
  infra|infrastructure) check_docker; create_network; start_infrastructure ;;
  core)                 check_docker; start_core_services ;;
  custom)               check_docker; start_custom_services ;;
  all)                  start_all ;;
  status)               show_status ;;
  down)
    log_step "Stopping stack..."
    compose down --remove-orphans
    log_success "Stopped."
    ;;
  *)
    echo "Usage: $0 [infrastructure|core|custom|all|status|down]"
    exit 1
    ;;
esac
