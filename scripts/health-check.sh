#!/bin/bash
##############################################################################
# HEALTH CHECK SCRIPT
# Comprehensive health check for all services
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DEPLOY_PATH="/opt/homelab"
ERRORS=0

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}  HOMELAB HEALTH CHECK${NC}"
echo -e "${BLUE}========================================${NC}"
echo "Timestamp: $(date)"
echo ""

##############################################################################
# HELPER FUNCTIONS
##############################################################################

check_service() {
    local service=$1
    local url=$2
    local expected_code=${3:-200}
    
    echo -n "Checking $service... "
    
    if curl -f -s -o /dev/null -w "%{http_code}" "$url" | grep -q "$expected_code"; then
        echo -e "${GREEN}✅ OK${NC}"
        return 0
    else
        echo -e "${RED}❌ FAILED${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_container() {
    local container=$1
    
    echo -n "Checking container $container... "
    
    if docker ps | grep -q "$container.*Up"; then
        echo -e "${GREEN}✅ Running${NC}"
        return 0
    else
        echo -e "${RED}❌ Not running${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

check_port() {
    local port=$1
    local service=$2
    
    echo -n "Checking port $port ($service)... "
    
    if nc -z localhost "$port" 2>/dev/null; then
        echo -e "${GREEN}✅ Open${NC}"
        return 0
    else
        echo -e "${RED}❌ Closed${NC}"
        ERRORS=$((ERRORS + 1))
        return 1
    fi
}

##############################################################################
# DOCKER HEALTH
##############################################################################

echo -e "${YELLOW}=== Docker Health ===${NC}"
echo "Docker version: $(docker --version)"
echo "Docker Compose version: $(docker-compose --version)"
echo ""

##############################################################################
# CONTAINER CHECKS
##############################################################################

echo -e "${YELLOW}=== Container Status ===${NC}"
cd "$DEPLOY_PATH"

check_container "traefik"
check_container "crowdsec"
check_container "authelia"
check_container "prometheus"
check_container "grafana"
check_container "loki"
check_container "gotify"
check_container "tailscale"

echo ""

##############################################################################
# PORT CHECKS
##############################################################################

echo -e "${YELLOW}=== Port Status ===${NC}"

check_port 80 "HTTP"
check_port 443 "HTTPS"
check_port 8080 "Traefik Dashboard"
check_port 9090 "Prometheus"
check_port 3000 "Grafana"
check_port 3100 "Loki"
check_port 9091 "Authelia"

echo ""

##############################################################################
# SERVICE ENDPOINT CHECKS
##############################################################################

echo -e "${YELLOW}=== Service Endpoints ===${NC}"

# Internal endpoints
check_service "Traefik" "http://localhost:8080/ping"
check_service "Prometheus" "http://localhost:9090/-/healthy"
check_service "Grafana" "http://localhost:3000/api/health"
check_service "Loki" "http://localhost:3100/ready"
check_service "Authelia" "http://localhost:9091/api/health"

echo ""

# External endpoints (if accessible)
if [ -n "$DOMAIN" ]; then
    echo -e "${YELLOW}=== External Endpoints ===${NC}"
    check_service "Traefik (external)" "https://traefik.$DOMAIN/ping"
    check_service "Grafana (external)" "https://grafana.$DOMAIN/api/health"
    check_service "Authelia (external)" "https://auth.$DOMAIN/api/health"
    echo ""
fi

##############################################################################
# RESOURCE USAGE
##############################################################################

echo -e "${YELLOW}=== Resource Usage ===${NC}"

# Memory
TOTAL_MEM=$(free -h | awk '/^Mem:/ {print $2}')
USED_MEM=$(free -h | awk '/^Mem:/ {print $3}')
MEM_PERCENT=$(free | awk '/^Mem:/ {printf "%.1f", $3/$2 * 100}')

echo "Memory: $USED_MEM / $TOTAL_MEM (${MEM_PERCENT}%)"

if (( $(echo "$MEM_PERCENT > 90" | bc -l) )); then
    echo -e "${RED}⚠️  High memory usage!${NC}"
    ERRORS=$((ERRORS + 1))
fi

# Disk
DISK_USAGE=$(df -h / | awk 'NR==2 {print $5}' | sed 's/%//')
DISK_INFO=$(df -h / | awk 'NR==2 {print $3 " / " $2}')

echo "Disk: $DISK_INFO (${DISK_USAGE}%)"

if [ "$DISK_USAGE" -gt 90 ]; then
    echo -e "${RED}⚠️  High disk usage!${NC}"
    ERRORS=$((ERRORS + 1))
fi

# CPU Load
LOAD_AVG=$(uptime | awk -F'load average:' '{print $2}')
echo "Load Average: $LOAD_AVG"

echo ""

##############################################################################
# DOCKER STATS
##############################################################################

echo -e "${YELLOW}=== Container Resource Usage ===${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"
echo ""

##############################################################################
# SSL CERTIFICATE CHECK
##############################################################################

echo -e "${YELLOW}=== SSL Certificates ===${NC}"

if [ -f "$DEPLOY_PATH/config/traefik/acme.json" ]; then
    CERT_COUNT=$(jq '.cloudflare.Certificates | length' "$DEPLOY_PATH/config/traefik/acme.json" 2>/dev/null || echo "0")
    echo "Certificates stored: $CERT_COUNT"
    
    # Check certificate expiry
    if [ -n "$DOMAIN" ]; then
        EXPIRY=$(echo | openssl s_client -servername "$DOMAIN" -connect "$DOMAIN:443" 2>/dev/null | openssl x509 -noout -enddate 2>/dev/null | cut -d= -f2)
        if [ -n "$EXPIRY" ]; then
            EXPIRY_EPOCH=$(date -d "$EXPIRY" +%s)
            NOW_EPOCH=$(date +%s)
            DAYS_LEFT=$(( ($EXPIRY_EPOCH - $NOW_EPOCH) / 86400 ))
            
            echo "Certificate expires in $DAYS_LEFT days ($EXPIRY)"
            
            if [ "$DAYS_LEFT" -lt 7 ]; then
                echo -e "${RED}⚠️  Certificate expiring soon!${NC}"
                ERRORS=$((ERRORS + 1))
            fi
        fi
    fi
else
    echo -e "${YELLOW}⚠️  No ACME certificate file found${NC}"
fi

echo ""

##############################################################################
# CROWDSEC STATUS
##############################################################################

echo -e "${YELLOW}=== CrowdSec Status ===${NC}"

if docker exec crowdsec cscli version >/dev/null 2>&1; then
    echo "CrowdSec version: $(docker exec crowdsec cscli version | head -1)"
    
    # Active decisions
    DECISIONS=$(docker exec crowdsec cscli decisions list -o json 2>/dev/null | jq length 2>/dev/null || echo "0")
    echo "Active bans: $DECISIONS"
    
    # Alerts
    ALERTS=$(docker exec crowdsec cscli alerts list -o json 2>/dev/null | jq length 2>/dev/null || echo "0")
    echo "Recent alerts: $ALERTS"
else
    echo -e "${RED}❌ Cannot query CrowdSec${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

##############################################################################
# STORAGE CHECK
##############################################################################

echo -e "${YELLOW}=== Storage Box Status ===${NC}"

if mountpoint -q /mnt/hetzner-storage 2>/dev/null; then
    echo -e "${GREEN}✅ Hetzner Storage Box mounted${NC}"
    
    STORAGE_USAGE=$(df -h /mnt/hetzner-storage | awk 'NR==2 {print $3 " / " $2 " (" $5 ")"}')
    echo "Storage usage: $STORAGE_USAGE"
else
    echo -e "${RED}❌ Hetzner Storage Box NOT mounted${NC}"
    ERRORS=$((ERRORS + 1))
fi

echo ""

##############################################################################
# SUMMARY
##############################################################################

echo -e "${BLUE}========================================${NC}"

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}✅ ALL CHECKS PASSED${NC}"
    echo -e "${BLUE}========================================${NC}"
    exit 0
else
    echo -e "${RED}❌ $ERRORS CHECK(S) FAILED${NC}"
    echo -e "${BLUE}========================================${NC}"
    exit 1
fi

