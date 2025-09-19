#!/bin/bash

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  Stopping DIGIT OSS Services${NC}"
echo -e "${BLUE}========================================${NC}"

case "${1:-all}" in
    "infrastructure"|"infra")
        log_info "Stopping infrastructure services..."
        docker-compose -f docker-compose.infra.yml down
        log_success "Infrastructure services stopped"
        ;;
    "core")
        log_info "Stopping core DIGIT services..."
        docker-compose -f docker-compose.services.yml down
        log_success "Core services stopped"
        ;;
    "custom")
        log_info "Stopping custom services..."
        docker-compose stop permit-service vc-service
        docker-compose rm -f permit-service vc-service
        log_success "Custom services stopped"
        ;;
    "all")
        log_info "Stopping all services..."
        docker-compose down
        log_success "All services stopped"
        ;;
    "clean")
        log_warning "Stopping all services and removing volumes (data will be lost)..."
        docker-compose down -v
        log_info "Removing unused Docker resources..."
        docker system prune -f
        log_success "Complete cleanup done"
        ;;
    *)
        echo "Usage: $0 [infrastructure|core|custom|all|clean]"
        echo
        echo "Commands:"
        echo "  infrastructure - Stop infrastructure services only"
        echo "  core          - Stop core DIGIT services only"
        echo "  custom        - Stop custom services only"
        echo "  all           - Stop all services (default)"
        echo "  clean         - Stop all services and remove volumes (destructive)"
        exit 1
        ;;
esac

echo
log_info "Use './scripts/start.sh' to restart services"