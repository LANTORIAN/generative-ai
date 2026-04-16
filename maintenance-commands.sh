#!/bin/bash

# Commandes utiles pour Ollama Production Stack
# Ajouter à vos alias shell ou l'exécuter directement

# Colors pour output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Ollama Maintenance Commands ===${NC}\n"

# 1. Status & Health
echo -e "${YELLOW}1. Vérifier l'état des services:${NC}"
echo "docker-compose -f docker-compose.ollama.yml ps"
echo ""

# 2. Logs
echo -e "${YELLOW}2. Voir les logs en temps réel:${NC}"
echo "docker-compose -f docker-compose.ollama.yml logs -f"
echo "docker logs -f generative-ollama-prod"
echo "docker logs -f generative-redis-prod"
echo ""

# 3. Test Ollama
echo -e "${YELLOW}3. Tester Ollama:${NC}"
echo "# Local test"
echo "curl -X POST http://localhost:11434/api/generate \\"
echo "  -d '{\"model\": \"gemma2:2b\", \"prompt\": \"test\", \"stream\": false}'"
echo ""
echo "# Liste les modèles"
echo "curl http://localhost:11434/api/tags"
echo ""

# 4. Redis Commands
echo -e "${YELLOW}4. Commandes Redis:${NC}"
echo "# Connecter à Redis"
echo "docker exec -it generative-redis-prod redis-cli"
echo ""
echo "# Commandes utiles dans Redis:"
echo "  INFO memory          # Mémoire utilisée"
echo "  KEYS *               # List toutes les clés"
echo "  FLUSHDB              # Vider le DB (ATTENTION)"
echo "  MONITOR              # Monitor les requêtes"
echo ""

# 5. Modèles Ollama
echo -e "${YELLOW}5. Gestion des modèles:${NC}"
echo "# Lister les modèles"
echo "docker exec generative-ollama-prod ollama list"
echo ""
echo "# Télécharger un modèle"
echo "docker exec generative-ollama-prod ollama pull gemma2:2b"
echo "docker exec generative-ollama-prod ollama pull llama2"
echo ""
echo "# Supprimer un modèle"
echo "docker exec generative-ollama-prod ollama rm gemma2:2b"
echo ""

# 6. Performance & Resources
echo -e "${YELLOW}6. Monitoring des ressources:${NC}"
echo "# Stats CPU/Memory en temps réel"
echo "docker stats generative-ollama-prod generative-redis-prod"
echo ""
echo "# Détails ressources limites"
echo "docker inspect generative-ollama-prod | grep -A 10 Resources"
echo ""

# 7. Backup & Volumes
echo -e "${YELLOW}7. Backup des données:${NC}"
echo "# Backup Ollama"
echo "docker run --rm -v lantorian_genai_ollama_data:/data -v \$(pwd):/backup \\" 
echo "  alpine tar czf /backup/ollama-backup.tar.gz -C /data ."
echo ""
echo "# Backup Redis"
echo "docker run --rm -v lantorian_genai_redis_data:/data -v \$(pwd):/backup \\" 
echo "  alpine tar czf /backup/redis-backup.tar.gz -C /data ."
echo ""

# 8. Cleaning
echo -e "${YELLOW}8. Nettoyage:${NC}"
echo "# Nettoyer les images non utilisées"
echo "docker image prune -a"
echo ""
echo "# Nettoyer les networks non utilisés"
echo "docker network prune"
echo ""
echo "# Supprimer complètement (ATTENTION!)"
echo "docker-compose -f docker-compose.ollama.yml down -v"
echo ""

# 9. Deploy
echo -e "${YELLOW}9. Déploiement & Restart:${NC}"
echo "# Redémarrer les services"
echo "docker-compose -f docker-compose.ollama.yml restart"
echo ""
echo "# Redémarrer un service spécifique"
echo "docker-compose -f docker-compose.ollama.yml restart ollama"
echo ""
echo "# Rebuild images"
echo "docker-compose -f docker-compose.ollama.yml up -d --build"
echo ""

# 10. Healthcheck
echo -e "${YELLOW}10. Vérification santé complète:${NC}"
echo "# Status Ollama"
echo "docker inspect generative-ollama-prod --format='Ollama Status: {{.State.Health.Status}}'"
echo ""
echo "# Status Redis"
echo "docker inspect generative-redis-prod --format='Redis Status: {{.State.Health.Status}}'"
echo ""
echo "# Status Warmer"
echo "docker inspect generative-ollama-warmer --format='Warmer Status: {{.State.Running}}'"
echo ""

# 11. Security Check
echo -e "${YELLOW}11. Vérification sécurité:${NC}"
echo "# Vérifier les domaines acceptés"
echo "curl -H 'Host: ollama.bluevaloris.com' http://localhost:11434/api/tags"
echo ""
echo "# Tester un accès non autorisé (doit être rejeté)"
echo "curl -H 'Host: ollama.example.com' http://localhost:11434/api/tags"
echo ""

# 12. Performance Test
echo -e "${YELLOW}12. Test de performance:${NC}"
echo "# Générer une réponse (chronomètre)"
echo "time docker exec generative-ollama-prod ollama run gemma2:2b 'test'"
echo ""
echo "# Load test avec wrk/ab"
echo "ab -n 100 -c 10 -p data.json http://localhost:11434/api/generate"
echo ""

echo -e "${GREEN}=== Commandes listées ===${NC}"
