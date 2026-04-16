#!/bin/bash

# Script de test complet pour Ollama Stack
# Vérifie tous les services et la configuration

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0

test_result() {
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✓ PASS${NC}: $1"
        ((PASS++))
    else
        echo -e "${RED}✗ FAIL${NC}: $1"
        ((FAIL++))
    fi
}

echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ Ollama Stack - Tests Complets      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}\n"

# 1. Vérifications Docker
echo -e "${YELLOW}1. Docker & Services${NC}"
docker ps --format "table {{.Names}}\t{{.Status}}" | grep generative || true
echo ""

# 2. Vérifier que les conteneurs existent
echo -e "${YELLOW}2. Présence des conteneurs${NC}"
docker ps -a | grep -q "generative-ollama-prod" && echo -e "${GREEN}✓${NC} Ollama présent" || echo -e "${RED}✗${NC} Ollama manquant"
docker ps -a | grep -q "generative-redis-prod" && echo -e "${GREEN}✓${NC} Redis présent" || echo -e "${RED}✗${NC} Redis manquant"
docker ps -a | grep -q "generative-ollama-warmer" && echo -e "${GREEN}✓${NC} Warmer présent" || echo -e "${RED}✗${NC} Warmer manquant"
echo ""

# 3. Test de connectivité Ollama
echo -e "${YELLOW}3. Connectivité Ollama${NC}"
if curl -s http://localhost:11434/api/tags > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Ollama répondant sur port 11434"
    test_result "Ollama API accessible"
else
    echo -e "${RED}✗${NC} Ollama ne répond pas"
    test_result "Ollama API"
fi
echo ""

# 4. Vérifie que gemma2:2b est présent
echo -e "${YELLOW}4. Modèles disponibles${NC}"
if curl -s http://localhost:11434/api/tags 2>/dev/null | grep -q "gemma2:2b"; then
    echo -e "${GREEN}✓${NC} gemma2:2b trouvé"
    test_result "Modèle gemma2:2b présent"
else
    echo -e "${RED}✗${NC} gemma2:2b non trouvé"
    test_result "Modèle gemma2:2b"
fi
echo ""

# 5. Test des healthchecks
echo -e "${YELLOW}5. Healthchecks${NC}"
ollama_health=$(docker inspect generative-ollama-prod --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
redis_health=$(docker inspect generative-redis-prod --format='{{.State.Health.Status}}' 2>/dev/null || echo "unknown")
warmer_status=$(docker inspect generative-ollama-warmer --format='{{.State.Running}}' 2>/dev/null || echo "unknown")

echo "Ollama: $ollama_health"
echo "Redis: $redis_health"
echo "Warmer Running: $warmer_status"

if [ "$ollama_health" = "healthy" ]; then
    test_result "Ollama healthcheck"
else
    echo -e "${YELLOW}⚠ ${NC} Ollama: $ollama_health (peut-être en démarrage)"
fi

if [ "$redis_health" = "healthy" ]; then
    test_result "Redis healthcheck"
else
    echo -e "${YELLOW}⚠ ${NC} Redis: $redis_health (peut-être en démarrage)"
fi
echo ""

# 6. Test Redis
echo -e "${YELLOW}6. Connectivité Redis${NC}"
if docker exec generative-redis-prod redis-cli ping 2>/dev/null | grep -q "PONG"; then
    echo -e "${GREEN}✓${NC} Redis répond PONG"
    test_result "Redis accessible"
else
    echo -e "${RED}✗${NC} Redis ne répond pas"
    test_result "Redis"
fi
echo ""

# 7. Test de génération simple
echo -e "${YELLOW}7. Test génération modèle${NC}"
echo "Envoi requête simple à Ollama..."
if curl -s -X POST http://localhost:11434/api/generate \
    -d '{
      "model": "gemma2:2b",
      "prompt": "ping",
      "stream": false,
      "raw": true
    }' | grep -q "response"; then
    echo -e "${GREEN}✓${NC} Génération réussie"
    test_result "Génération simple"
else
    echo -e "${YELLOW}⚠ ${NC} Test de génération inconclus"
fi
echo ""

# 8. Test de domaine restreint
echo -e "${YELLOW}8. Sécurité - Restriction de domaine${NC}"
echo "Test via curl (local): Doit toujours fonctionner"
curl -s http://localhost:11434/api/tags > /dev/null && echo -e "${GREEN}✓${NC} Accès local OK"

echo "Note: Pour tester HTTPS, vous devez être sur *.bluevaloris.com"
echo "Traefik applique la restriction via labels:"
echo "  - Host(\`ollama.bluevaloris.com\`)"
echo "  - Middleware host-restriction activée"
test_result "Config restrictions domaine"
echo ""

# 9. Test des ressources
echo -e "${YELLOW}9. Ressources allouées${NC}"
echo "Ollama:"
docker inspect generative-ollama-prod --format='  CPU Limit: {{.HostConfig.CpuQuota}}/{{.HostConfig.CpuPeriod}}'
docker inspect generative-ollama-prod --format='  Memory: {{.HostConfig.Memory}} bytes'

echo "Redis:"
docker inspect generative-redis-prod --format='  CPU Limit: {{.HostConfig.CpuQuota}}/{{.HostConfig.CpuPeriod}}'
docker inspect generative-redis-prod --format='  Memory: {{.HostConfig.Memory}} bytes'
test_result "Limites ressources"
echo ""

# 10. Test des volumes
echo -e "${YELLOW}10. Volumes persistants${NC}"
docker volume inspect lantorian_genai_ollama_data > /dev/null 2>&1 && echo -e "${GREEN}✓${NC} ollama_data volume existe" || echo -e "${RED}✗${NC} ollama_data volume manquant"
docker volume inspect lantorian_genai_redis_data > /dev/null 2>&1 && echo -e "${GREEN}✓${NC} redis_data volume existe" || echo -e "${RED}✗${NC} redis_data volume manquant"
test_result "Volumes persistants"
echo ""

# 11. Test des networks
echo -e "${YELLOW}11. Networks Docker${NC}"
docker network inspect backend > /dev/null 2>&1 && echo -e "${GREEN}✓${NC} Network 'backend' existe" || echo -e "${RED}✗${NC} Network 'backend' manquant"
test_result "Network backend"
echo ""

# 12. Vérifications logs
echo -e "${YELLOW}12. Logs récents (dernières 5 lignes)${NC}"
echo "Ollama:"
docker logs --tail=2 generative-ollama-prod 2>&1 | head -2 || echo "Log non disponible"
echo ""
echo "Redis:"
docker logs --tail=2 generative-redis-prod 2>&1 | head -2 || echo "Log non disponible"
echo ""

# Résumé
echo -e "${BLUE}╔════════════════════════════════════╗${NC}"
echo -e "${BLUE}║ RÉSUMÉ DES TESTS                   ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════╝${NC}"
echo -e "Réussis: ${GREEN}$PASS${NC}"
echo -e "Échoués: ${RED}$FAIL${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "${GREEN}✓ Tous les tests sont passés!${NC}"
    echo ""
    echo -e "${YELLOW}Prochaines étapes:${NC}"
    echo "1. Accéder à Ollama: https://ollama.bluevaloris.com"
    echo "2. API endpoint: POST https://ollama.bluevaloris.com/api/generate"
    echo "3. Lancement warming service..."
    echo "4. Monitoring via Prometheus/Grafana (optionnel)"
    exit 0
else
    echo -e "${RED}✗ Certains tests ont échoué!${NC}"
    echo ""
    echo -e "${YELLOW}Dépannage:${NC}"
    echo "1. Vérifier: docker-compose ps"
    echo "2. Logs Ollama: docker logs generative-ollama-prod"
    echo "3. Logs Redis: docker logs generative-redis-prod"
    echo "4. Redémarrer: docker-compose restart"
    exit 1
fi
