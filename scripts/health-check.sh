#!/bin/bash

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

check_service() {
    local name=$1
    local url=$2
    local timeout=${3:-30}
    
    printf "%-30s" "$name"
    
    if timeout $timeout curl -sf "$url" > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Healthy${NC}"
        return 0
    else
        echo -e "${RED}✗ Unhealthy${NC}"
        return 1
    fi
}

check_port() {
    local name=$1
    local host=${2:-localhost}
    local port=$3
    
    printf "%-30s" "$name"
    
    if timeout 5 bash -c "</dev/tcp/$host/$port"; then
        echo -e "${GREEN}✓ Port $port open${NC}"
        return 0
    else
        echo -e "${RED}✗ Port $port closed${NC}"
        return 1
    fi
}

echo -e "${BLUE}=====================================================${NC}"
echo -e "${BLUE}  DIGIT OSS Health Check${NC}"
echo -e "${BLUE}=====================================================${NC}"
echo

# Check infrastructure services
echo -e "${YELLOW}Infrastructure Services:${NC}"
check_port "PostgreSQL" localhost 5432
check_port "Redis" localhost 6379
check_port "Elasticsearch" localhost 9200
check_port "Kafka" localhost 9092
check_service "Gateway" "http://localhost:8080/health"

echo

# Check core DIGIT services  
echo -e "${YELLOW}Core DIGIT Services:${NC}"
check_service "User Service" "http://localhost:8081/user/health"
check_service "Access Control" "http://localhost:8082/access/health"
check_service "MDMS Service" "http://localhost:8083/egov-mdms-service/health"
check_service "Workflow Service" "http://localhost:8084/egov-workflow-v2/health"
check_service "Billing Service" "http://localhost:8085/billing-service/health"
check_service "Collection Service" "http://localhost:8086/collection-services/health"
check_service "Notification SMS" "http://localhost:8087/notification-sms/health"
check_service "ID Generation" "http://localhost:8088/egov-idgen/health"
check_service "Filestore" "http://localhost:8089/filestore/health"

echo

# Check custom services
echo -e "${YELLOW}Custom Services:${NC}" 
check_service "Permit Service" "http://localhost:8090/permit/health"
check_service "VC Service" "http://localhost:8091/vc/health"

echo

# Service URLs
echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}  Service URLs${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}API Gateway:${NC} http://localhost:8080"
echo -e "${CYAN}User Service:${NC} http://localhost:8081/user"
echo -e "${CYAN}MDMS Service:${NC} http://localhost:8083/egov-mdms-service"
echo -e "${CYAN}Workflow Service:${NC} http://localhost:8084/egov-workflow-v2"
echo -e "${CYAN}Permit Service:${NC} http://localhost:8090/permit"
echo -e "${CYAN}VC Service:${NC} http://localhost:8091/vc"

echo
echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}  Testing${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}Postman Collection:${NC} DIGIT-OSS-Local-Tests.postman_collection.json"
echo -e "${CYAN}Environment:${NC} Set base_url to http://localhost:8080"

echo
echo -e "${CYAN}=====================================================${NC}"
echo -e "${CYAN}  Quick Test Commands${NC}"
echo -e "${CYAN}=====================================================${NC}"
echo -e "${YELLOW}# Test Gateway${NC}"
echo "curl http://localhost:8080/health"
echo
echo -e "${YELLOW}# Test User Service${NC}"
echo "curl http://localhost:8080/user/health"
echo
echo -e "${YELLOW}# Test MDMS Service${NC}"
echo "curl http://localhost:8080/egov-mdms-service/health"
echo