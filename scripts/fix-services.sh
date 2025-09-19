#!/usr/bin/env bash
set -euo pipefail

# Colors for output
RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; CYAN='\033[0;36m'; NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $*"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*"; }

# Settings
export COMPOSE_PROJECT_NAME="${COMPOSE_PROJECT_NAME:-digit-oss}"
export NETWORK_NAME="${NETWORK_NAME:-digit-network}"

compose() {
    docker compose -p "${COMPOSE_PROJECT_NAME}" \
        -f docker-compose.infra.yml \
        -f docker-compose.services.yml \
        "$@"
}

log_info "🔧 DIGIT OSS Service Fix Script"
echo "=================================="

# Step 1: Stop all unhealthy services
log_info "1. Stopping unhealthy services..."
compose stop nginx-gateway user workflow-v2 billing-service collection-services notification-sms filestore egov-idgen
log_success "Stopped unhealthy services"

# Step 2: Restart infrastructure services to ensure they're healthy
log_info "2. Ensuring infrastructure is healthy..."
compose restart postgres redis elasticsearch kafka
sleep 10

# Step 3: Check database connectivity
log_info "3. Testing database connectivity..."
if docker exec "${COMPOSE_PROJECT_NAME}-postgres" pg_isready -U postgres -d egov; then
    log_success "✅ PostgreSQL is ready"
else
    log_error "❌ PostgreSQL is not ready - please check database configuration"
    exit 1
fi

# Step 4: Restart services in dependency order
log_info "4. Restarting core services in correct order..."

# Start MDMS first (no dependencies)
log_info "  Starting MDMS service..."
compose up -d mdms-service
sleep 15

# Wait for MDMS to be healthy
log_info "  Waiting for MDMS to be healthy..."
timeout=60
while [ $timeout -gt 0 ]; do
    if curl -sf http://localhost:8083/egov-mdms-service/health > /dev/null 2>&1; then
        log_success "✅ MDMS service is healthy"
        break
    fi
    sleep 2
    ((timeout-=2))
done

# Start User service (depends on postgres, redis)
log_info "  Starting User service..."
compose up -d user
sleep 20

# Start Access Control (depends on user)
log_info "  Starting Access Control..."
compose up -d access-control
sleep 15

# Start Workflow service (depends on user, mdms)
log_info "  Starting Workflow service..."
compose up -d workflow-v2
sleep 20

# Start remaining services
log_info "  Starting Billing service..."
compose up -d billing-service
sleep 15

log_info "  Starting Collection service..."
compose up -d collection-services
sleep 15

log_info "  Starting Notification SMS..."
compose up -d notification-sms
sleep 10

log_info "  Starting ID Generation service..."
compose up -d egov-idgen
sleep 15

log_info "  Starting Filestore service..."
compose up -d filestore
sleep 15

# Step 5: Start nginx gateway last
log_info "5. Starting nginx gateway..."
compose up -d nginx-gateway
sleep 10

# Step 6: Restart custom services
log_info "6. Restarting custom services..."
compose restart permit-service vc-service
sleep 15

# Step 7: Final health check
log_info "7. Running final health check..."
sleep 10

echo
log_success "🎉 Service restart complete!"
echo

# Show service status
log_info "Current service status:"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep "${COMPOSE_PROJECT_NAME}"

echo
log_info "Run './scripts/health-check.sh' to verify all services are healthy"
echo
log_info "If some services are still unhealthy, wait 2-3 minutes and run the health check again"
echo "Services may take time to fully initialize and pass health checks"