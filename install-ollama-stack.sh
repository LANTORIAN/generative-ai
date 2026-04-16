#!/bin/bash
# Installation script pour Ollama Stack sur VPS
# Usage: ./install-ollama-stack.sh

set -e

echo "🚀 Ollama Stack Installation Script"
echo "===================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Check if running as root
if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}This script must be run as root${NC}"
   exit 1
fi

echo -e "${BLUE}Step 1: Checking prerequisites...${NC}"

# Check Docker
if ! command -v docker &> /dev/null; then
    echo -e "${YELLOW}Docker not found. Installing...${NC}"
    curl -fsSL https://get.docker.com -o get-docker.sh
    sh get-docker.sh
    rm get-docker.sh
    echo -e "${GREEN}✓ Docker installed${NC}"
else
    echo -e "${GREEN}✓ Docker already installed${NC}"
fi

# Check Docker Compose
if ! command -v docker-compose &> /dev/null; then
    echo -e "${YELLOW}Docker Compose not found. Installing...${NC}"
    curl -L "https://github.com/docker/compose/releases/download/v2.20.2/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    echo -e "${GREEN}✓ Docker Compose installed${NC}"
else
    echo -e "${GREEN}✓ Docker Compose already installed${NC}"
fi

# Start Docker daemon
systemctl start docker
systemctl enable docker

echo ""
echo -e "${BLUE}Step 2: Setting up project directories...${NC}"

# Create project directory
PROJECT_DIR="/opt/ollama-stack"
if [ -d "$PROJECT_DIR" ]; then
    echo -e "${YELLOW}$PROJECT_DIR already exists${NC}"
    read -p "Do you want to continue with existing directory? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborting..."
        exit 1
    fi
else
    mkdir -p "$PROJECT_DIR"
    echo -e "${GREEN}✓ Created $PROJECT_DIR${NC}"
fi

cd "$PROJECT_DIR"

echo ""
echo -e "${BLUE}Step 3: Creating Docker volumes...${NC}"

docker volume create lantorian_genai_ollama_data 2>/dev/null || true
docker volume create lantorian_genai_redis_data 2>/dev/null || true
docker volume create lantorian_genai_postgres_data 2>/dev/null || true

echo -e "${GREEN}✓ Docker volumes created${NC}"

echo ""
echo -e "${BLUE}Step 4: Configuring environment variables...${NC}"

# Check if .env exists
if [ -f ".env" ]; then
    echo -e "${YELLOW}⚠️  .env already exists${NC}"
    read -p "Do you want to use the existing .env? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Nn]$ ]]; then
        # Backup old .env
        cp .env ".env.backup.$(date +%Y%m%d_%H%M%S)"
        echo -e "${YELLOW}✓ Old .env backed up${NC}"
    fi
else
    if [ -f ".env.example" ]; then
        cp .env.example .env
        echo -e "${GREEN}✓ .env created from .env.example${NC}"
    else
        echo -e "${RED}✗ .env.example not found${NC}"
        exit 1
    fi
fi

echo ""
echo -e "${BLUE}Step 5: Customizing configuration...${NC}"

# Read user inputs
read -p "Enter your production domain (e.g., bluevaloris.com): " PROD_DOMAIN
read -p "Enter Ollama domain (e.g., ollama.$PROD_DOMAIN): " OLLAMA_DOMAIN
read -s -p "Enter PostgreSQL password (min 12 chars): " PG_PASSWORD
echo
read -s -p "Enter Config Manager admin password: " ADMIN_PASSWORD
echo

# Validate inputs
if [ -z "$PROD_DOMAIN" ] || [ -z "$OLLAMA_DOMAIN" ] || [ -z "$PG_PASSWORD" ] || [ -z "$ADMIN_PASSWORD" ]; then
    echo -e "${RED}✗ All inputs are required${NC}"
    exit 1
fi

if [ ${#PG_PASSWORD} -lt 12 ]; then
    echo -e "${RED}✗ PostgreSQL password must be at least 12 characters${NC}"
    exit 1
fi

# Update .env
sed -i "s|PRODUCTION_DOMAIN=.*|PRODUCTION_DOMAIN=$PROD_DOMAIN|g" .env
sed -i "s|OLLAMA_DOMAIN=.*|OLLAMA_DOMAIN=$OLLAMA_DOMAIN|g" .env
sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=$PG_PASSWORD|g" .env
sed -i "s|CONFIG_ADMIN_PASSWORD=.*|CONFIG_ADMIN_PASSWORD=$ADMIN_PASSWORD|g" .env

echo -e "${GREEN}✓ Configuration updated${NC}"

echo ""
echo -e "${BLUE}Step 6: Starting services...${NC}"

# Start services
docker-compose -f docker-compose.ollama.yml up -d

# Wait for services to be healthy
echo -e "${YELLOW}Waiting for services to start...${NC}"
sleep 10

# Check service status
services_ready=false
for i in {1..12}; do
    if docker-compose -f docker-compose.ollama.yml ps | grep -q "healthy"; then
        services_ready=true
        break
    fi
    echo -n "."
    sleep 5
done

echo ""

if [ "$services_ready" = true ]; then
    echo -e "${GREEN}✓ Services started successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Services may still be starting. Check logs with:${NC}"
    echo "docker-compose -f docker-compose.ollama.yml logs -f"
fi

echo ""
echo -e "${BLUE}Step 7: Creating first API key...${NC}"

# Wait for database to be ready
sleep 5

# Try to create initial API key
if [ -f "db-manage.py" ]; then
    echo -e "${YELLOW}Creating initial API key for testing...${NC}"
    
    if docker-compose -f docker-compose.ollama.yml exec -T config-manager \
        python db-manage.py key create --name "Default" --domain "$OLLAMA_DOMAIN" &>/dev/null; then
        echo -e "${GREEN}✓ Initial API key created${NC}"
        echo -e "${YELLOW}Use 'docker-compose -f docker-compose.ollama.yml exec config-manager python db-manage.py key list' to view it${NC}"
    else
        echo -e "${YELLOW}⚠️  Could not auto-create API key. You can create it via the web UI.${NC}"
    fi
else
    echo -e "${YELLOW}db-manage.py not found${NC}"
fi

echo ""
echo "======================================"
echo -e "${GREEN}✅ Installation Complete!${NC}"
echo "======================================"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "1. Verify services are running:"
echo -e "   ${YELLOW}docker-compose -f docker-compose.ollama.yml ps${NC}"
echo ""
echo "2. Access the Configuration Manager:"
echo -e "   ${YELLOW}https://config.$PROD_DOMAIN${NC}"
echo -e "   Password: ${YELLOW}$ADMIN_PASSWORD${NC}"
echo ""
echo "3. Test the Ollama API:"
echo -e "   ${YELLOW}curl https://$OLLAMA_DOMAIN/api/tags${NC}"
echo ""
echo "4. Create API keys via Config Manager or CLI:"
echo -e "   ${YELLOW}docker-compose -f docker-compose.ollama.yml exec config-manager python db-manage.py key create --name 'MyApp' --domain 'myapp.$PROD_DOMAIN'${NC}"
echo ""
echo -e "${BLUE}Documentation:${NC}"
echo "   - Quick start: CONFIG-MANAGER.md"
echo "   - VPS guide: VPS-DEPLOYMENT.md"
echo "   - API docs: API-USAGE.md"
echo "   - Database: DATABASE.md"
echo ""
echo -e "${YELLOW}⚠️  Save these credentials securely:${NC}"
echo "   - PostgreSQL password: $PG_PASSWORD"
echo "   - Admin password: $ADMIN_PASSWORD"
echo ""
echo -e "${GREEN}Happy deploying! 🚀${NC}"
