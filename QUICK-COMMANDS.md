# ⚡ Commands Rapides - Ollama Stack

## 🚀 Démarrage

### Installation VPS (once)
```bash
cd /opt/ollama-stack
chmod +x install-ollama-stack.sh
sudo ./install-ollama-stack.sh
# → Suivre les prompts interactifs
```

### Démarrer les services
```bash
docker-compose -f docker-compose.ollama.yml up -d
```

### Arrêter les services
```bash
docker-compose -f docker-compose.ollama.yml down
```

## 🎛️ Config Manager

### Accès interface web
```
https://config.bluevaloris.com
Mot de passe: <CONFIG_ADMIN_PASSWORD>
```

### Créer clé API (CLI)
```bash
docker-compose exec config-manager python db-manage.py key create \
  --name "MyApp" \
  --domain "myapp.bluevaloris.com"
```

### Lister clés API
```bash
docker-compose exec config-manager python db-manage.py key list
```

### Voir l'utilisation
```bash
docker-compose exec config-manager python db-manage.py usage show --days 7
```

## 🐳 Services

### Redémarrer un service
```bash
docker-compose -f docker-compose.ollama.yml restart ollama
docker-compose -f docker-compose.ollama.yml restart redis
docker-compose -f docker-compose.ollama.yml restart postgres
docker-compose -f docker-compose.ollama.yml restart pgbouncer
docker-compose -f docker-compose.ollama.yml restart config-manager
```

### Voir les logs
```bash
# Ollama
docker-compose -f docker-compose.ollama.yml logs -f ollama

# Config Manager
docker-compose -f docker-compose.ollama.yml logs -f config-manager

# Tous
docker-compose -f docker-compose.ollama.yml logs -f
```

### Statut des services
```bash
docker-compose -f docker-compose.ollama.yml ps
```

## 📊 Monitoring

### Stats en temps réel
```bash
docker stats
```

### État des services
```bash
docker-compose -f docker-compose.ollama.yml ps
```

### Healthchecks
```bash
docker inspect generative-ollama-prod --format='{{.State.Health.Status}}'
```

## 🔧 Configuration

### Modifier .env
```bash
nano .env
# → Modifier les valeurs
# → Sauvegarder (Ctrl+O, Enter, Ctrl+X)
```

### Appliquer les changements
```bash
# Option 1: Via Config Manager
https://config.bluevaloris.com → Environnement → Sauvegarder → Services → Restart

# Option 2: Manuellement
docker-compose -f docker-compose.ollama.yml restart ollama
```

## 📊 Database

### Accès PostgreSQL (direct)
```bash
docker-compose exec postgres \
  psql -U ollama_user -d ollama_db
```

### Accès via PgBouncer (pooled)
```bash
docker-compose exec pgbouncer \
  psql -U ollama_user -d ollama_db
```

### Voir les pools actifs
```bash
docker-compose exec pgbouncer \
  psql -U postgres -d pgbouncer -c "SHOW pools"
```

### Export database
```bash
docker-compose exec -T postgres \
  pg_dump -U ollama_user ollama_db > backup.sql
```

### Import database
```bash
docker-compose exec -T postgres \
  psql -U ollama_user ollama_db < backup.sql
```

## 🧪 Tests

### Tester tous les services
```bash
chmod +x test-stack.sh
./test-stack.sh
```

### Tester Ollama API
```bash
curl http://localhost:11434/api/tags
```

### Tester Config Manager
```bash
curl http://localhost:8888/api/status
```

### Tester PostgreSQL
```bash
docker-compose exec pgbouncer \
  psql -U ollama_user -d ollama_db -c "SELECT 1"
```

### Tester Redis
```bash
docker-compose exec redis redis-cli ping
```

## 🔑 Clés API

### Format de clé générique
```
sk_live_<32_caracteres_aleatoires>
```

### Créer avec rate limits custom
```bash
docker-compose exec config-manager python db-manage.py key create \
  --name "HighThroughput" \
  --domain "api.app.com" \
  --rate-limit-min 1000 \
  --rate-limit-hour 100000 \
  --rate-limit-day 1000000
```

### Désactiver une clé
```bash
# Via Config Manager: Tab "Clés API" → Supprimer

# Ou via CLI:
docker-compose exec postgres \
  psql -U ollama_user -d ollama_db \
  -c "UPDATE ollama.api_keys SET is_active=false WHERE id=<ID>"
```

## 🆘 Troubleshooting

### Port déjà utilisé
```bash
lsof -i :8888  # Config Manager
lsof -i :11434 # Ollama
lsof -i :6379  # Redis
lsof -i :5432  # PostgreSQL
lsof -i :6432  # PgBouncer

kill -9 <PID>
```

### Container ne démarre pas
```bash
docker-compose logs config-manager
# → Voir l'erreur et corriger
```

### Erreur de connexion DB
```bash
# Vérifier PostgreSQL
docker-compose exec postgres psql -U ollama_user -d ollama_db -c "\dt"

# Vérifier PgBouncer
docker-compose exec pgbouncer psql -U postgres -d pgbouncer -c "show pools"
```

### Réinitialiser les données
```bash
# ⚠️ ATTENTION: Cela supprime toutes les données!

# Arrêter les services
docker-compose down

# Supprimer les volumes
docker volume rm lantorian_genai_postgres_data
docker volume rm lantorian_genai_ollama_data
docker volume rm lantorian_genai_redis_data

# Recréer et redémarrer
docker-compose up -d
```

## 💾 Backups

### Backup automatique daily
```bash
# Script
cat > backup.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
docker-compose exec -T postgres \
  pg_dump -U ollama_user ollama_db | gzip > backup_$DATE.sql.gz
echo "Backup créé: backup_$DATE.sql.gz"
EOF

chmod +x backup.sh
./backup.sh
```

### Ajouter à crontab
```bash
# Edit crontab
crontab -e

# Ajouter la ligne (backup chaque jour à 2h)
0 2 * * * cd /opt/ollama-stack && ./backup.sh
```

## 🚀 Performance Tuning

### Augmenter capacité Ollama
```bash
# Modifier .env
OLLAMA_CPU_LIMIT=4.0         # Plus de CPU
OLLAMA_MEMORY_LIMIT=16G      # Plus de RAM
OLLAMA_NUM_PARALLEL=8        # Plus de requêtes parallèles

# Appliquer
docker-compose restart ollama
```

### Augmenter le pool PostgreSQL
```bash
# Modifier .env
PGBOUNCER_DEFAULT_POOL_SIZE=50  # Plus de connexions

# Appliquer
docker-compose restart pgbouncer
```

### Changement de modèle
```bash
# Modifier .env
OLLAMA_DEFAULT_MODEL=mistral

# Appliquer
docker-compose restart ollama

# Vérifier
curl http://localhost:11434/api/tags
```

## 📚 Documentation

- **Quick Start** → QUICK-CONFIG.md
- **Interface Web** → CONFIG-MANAGER.md
- **VPS Deploy** → VPS-DEPLOYMENT.md
- **API Docs** → API-USAGE.md
- **Database** → DATABASE.md
- **Architecture** → ARCHITECTURE.md
- **Summary** → DEPLOYMENT-SUMMARY.md

## 🆘 Support

Voir les logs détaillés:
```bash
docker-compose logs <service_name> --tail=100
```

Pour debug complet:
```bash
./test-stack.sh
```

---

**Speed Guide - Ollama Stack Production** 🚀
