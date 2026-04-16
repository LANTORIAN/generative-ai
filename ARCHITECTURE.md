# 🏗️ Full Stack Architecture - Ollama Production

Stack complet avec Ollama, Redis, PostgreSQL, PgBouncer, et Traefik.

---

## 📊 Architecture globale

```
┌────────────────────────────────────────────────────────────────┐
│                    Internet / Clients                          │
│                      *.bluevaloris.com                        │
└────────────────────┬─────────────────────────────────────────┘
                     │ HTTPS
                     ▼
        ┌────────────────────────────┐
        │   Traefik Load Balancer    │
        │   - HTTPS (TLS)            │
        │   - Domain routing         │
        │   - SSL certificates       │
        └────────────┬───────────────┘
                     │
        ┌────────────┴──────────────────┐
        │ (Port 11434)                  │
        ▼                               ▼
  ┌──────────────────┐        ┌──────────────────────┐
  │     OLLAMA       │        │  API Requests        │
  │   - gemma2:2b    │        │  (Warming service)   │
  │   - llama2       │        │  (every 300s)        │
  │   - mistral      │        └──────────────────────┘
  │   4x parallel    │
  │   14GB RAM       │
  │   Healthcheck    │
  └────────┬─────────┘
           │ (Cache)
           ▼
  ┌──────────────────┐
  │   REDIS STACK    │
  │   - caching      │
  │   - 1GB RAM      │
  │   port 6379      │
  │   LRU policy     │
  └──────────────────┘

  ┌──────────────────┐        ┌──────────────────────────┐
  │   PostgreSQL     │◄──────┤  API Keys                │
  │   - Tables       │        │  Domains               │
  │   - Schemas      │        │  Usage Stats           │
  │   - 200 conn max │        │  Error Logs            │
  │   - 2GB RAM      │        │  Audit Logs            │
  │   port 5432      │        │  Health Checks         │
  └────────┬─────────┘        └──────────────────────────┘
           │
           ▼
  ┌──────────────────┐
  │  PgBouncer Pool  │
  │  - 25 conn pool  │
  │  - transaction   │
  │  mode            │
  │  - port 6432     │
  │  - 512MB RAM     │
  └────────┬─────────┘
           │
           ▼
   ┌────────────────┐
   │  Clients       │
   │  Applications  │
   │  Monitoring    │
   └────────────────┘
```

---

## 🔌 Services & Ports

| Service | Port (External) | Port (Internal) | Purpose |
|---------|-----------------|-----------------|---------|
| Traefik | 443 (HTTPS) | Via domain | HTTPS endpoint |
| Ollama | Via Traefik | 11434 | LLM API |
| Redis | N/A | 6379 | Cache layer |
| PostgreSQL | 5432 | 5432 | Database (direct) |
| PgBouncer | 6432 | 6432 | Database (pool) |
| Warmer | N/A (internal) | N/A | Keep-warm service |

---

## 📚 Services détaillés

### 1. **OLLAMA** 🤖
- **Image**: `ollama/ollama:latest`
- **Container**: `generative-ollama-prod`
- **Port**: 11434 (internal)
- **RAM**: 10-14GB
- **CPU**: 4-3.5 cores
- **Role**: LLM inference
- **Features**:
  - Modèles multiples (gemma2, llama2, mistral, etc.)
  - Parallelism 4x
  - Redis caching
  - Keep-alive 60 minutes
  - Healthcheck toutes les 30s
  - Redémarrage automatique

### 2. **REDIS** 🔴
- **Image**: `redis/redis-stack-server:latest`
- **Container**: `generative-redis-prod`
- **Port**: 6379 (internal)
- **RAM**: 512MB - 1GB
- **CPU**: 0.25-0.5 cores
- **Role**: Caching layer
- **Features**:
  - Persistent store (appendonly)
  - LRU expiration policy
  - Max memory 1GB
  - Healthcheck toutes les 10s

### 3. **PostgreSQL** 🗄️
- **Image**: `postgres:16-alpine`
- **Container**: `generative-postgres-prod`
- **Port**: 5432 (internal)
- **RAM**: 1-2GB
- **CPU**: 0.5-1.0 cores
- **Role**: Data persistence
- **Features**:
  - Schémas: ollama, audit
  - Tables pour API keys, usage, errors, etc.
  - Max connections: 200
  - Shared buffers: 256MB
  - Healthcheck toutes les 10s

### 4. **PgBouncer** 🔗
- **Image**: `pgbouncer/pgbouncer:latest`
- **Container**: `generative-pgbouncer-prod`
- **Port**: 6432 (internal)
- **RAM**: 256-512MB
- **CPU**: 0.25-0.5 cores
- **Role**: Connection pooling
- **Features**:
  - Transaction mode (recommandé)
  - Pool size: 25 (configurable)
  - Max clients: 1000
  - Route vers PostgreSQL
  - Healthcheck toutes les 10s

### 5. **WARMER** 🔥
- **Image**: `curlimages/curl:latest`
- **Container**: `generative-ollama-warmer`
- **Role**: Keep-warm service
- **Features**:
  - Ping Ollama toutes les 5 min
  - Modèle toujours en RAM
  - Latence <100ms
  - Configurable via env

---

## 🔄 Flux de requête

### 1. Client → Traefik

```
client@myapp.bluevaloris.com
    ↓
Traefik HTTPS (Port 443)
    ↓
Host check: ollama.bluevaloris.com ✅
    ↓
Middleware validation ✅
    ↓
Route vers Ollama:11434
```

### 2. Ollama → Cache

```
Request: POST /api/generate
    ↓
Check Redis cache
    ↓
Cache hit? → Return cached response
Cell miss? → Generate with LLM
    ↓
Store in Redis (LRU)
```

### 3. Data → Database

```
API request
    ↓
Log usage en PostgreSQL
    ↓
Update rate limits
    ↓
Store in audit.access_log
    ↓
(Toutes via PgBouncer pool)
```

---

## 📦 Volumes (Persistance)

| Volume | Size | Path | Content |
|--------|------|------|---------|
| `lantorian_genai_ollama_data` | 10-50GB | `/root/.ollama` | Modèles téléchargés |
| `lantorian_genai_redis_data` | 1GB | `/data` | Cache Redis |
| `lantorian_genai_postgres_data` | 5-50GB | `/var/lib/postgresql/data` | Base de données |

---

## 🌍 Networks

| Réseau | Type | Scope | Usage |
|--------|------|-------|-------|
| `backend` | bridge (interne) | Projet | Communication interne |
| `traefik` | external | Global | Routage via Traefik |
| `monitoring` | bridge (interne) | Projet | Monitoring futur |

---

## 🚀 Déploiement

### Pre-requisites

```bash
# 1. Volumes doivent exister
docker volume create lantorian_genai_ollama_data
docker volume create lantorian_genai_redis_data
docker volume create lantorian_genai_postgres_data

# 2. Réseau Traefik doit exister
docker network create coolify 2>/dev/null || true

# 3. Traefik doit tourner
docker ps | grep traefik
```

### Déploiement

```bash
# 1. Configuration
cp .env.example .env
nano .env  # Adapter les valeurs

# 2. Lancer
./deploy.sh

# 3. Vérifier
./test-stack.sh
```

### Ordre de démarrage

1. ✅ PostgreSQL (healthcheck 60s)
2. ✅ PgBouncer (attend PostgreSQL)
3. ✅ Redis (indépendant)
4. ✅ Ollama (attend Redis)
5. ✅ Warmer (attend Ollama)

---

## ⚙️ Configuration

### Variables importantes

```env
# Modèle & Performance
OLLAMA_DEFAULT_MODEL=gemma2:2b
OLLAMA_NUM_PARALLEL=4
OLLAMA_KEEP_ALIVE=60m

# Base de données
POSTGRES_PASSWORD=secure_password  # ⚠️ CHANGER!
PGBOUNCER_DEFAULT_POOL_SIZE=25

# Warming
WARMER_INTERVAL=300

# Domaine
OLLAMA_DOMAIN=ollama.bluevaloris.com
```

Voir `.env.example` pour tous les paramètres.

---

## 📊 Monitoring

### Health Checks

```bash
# Ollama
curl http://localhost:11434/api/tags

# Redis
docker exec generative-redis-prod redis-cli ping

# PostgreSQL
psql -h localhost -p 5432 -U ollama_user -d ollama_db -c "SELECT 1;"

# PgBouncer (pool)
psql -h localhost -p 6432 -U ollama_user -d ollama_db -c "SELECT 1;"
```

### Logs real-time

```bash
docker-compose logs -f

# Ou per service
docker logs -f generative-ollama-prod
docker logs -f generative-postgres-prod
docker logs -f generative-pgbouncer-prod
```

### Stats

```bash
# Resource usage
docker stats

# Database size
docker exec generative-postgres-prod psql -U ollama_user -d ollama_db \
  -c "SELECT pg_size_pretty(pg_database_size('ollama_db'));"

# Cache usage
docker exec generative-redis-prod redis-cli INFO memory
```

---

## 🔐 Sécurité

### Domain Whitelist

```
✅ Connexions acceptées:
   https://ollama.bluevaloris.com/api/generate
   https://api.bluevaloris.com/api/generate

❌ Connexions rejetées:
   https://ollama.example.com/api/generate
   github.com (domaine non whitelisté)
```

### Database Access

```
✅ Interne uniquement:
   PostgreSQL: localhost:5432 (Docker network)
   PgBouncer: localhost:6432 (Docker network)
   Redis: localhost:6379 (Docker network)

❌ Pas d'accès externe par défaut
(Peut être ouvert si nécessaire)
```

### API Keys

- Stockées en hash SHA256
- Rate limits par clé
- Audit trail complète
- Domaine par clé

---

## 📈 Scaling

### Augmenter la performance

```env
# Plus de parallelism
OLLAMA_NUM_PARALLEL=8

# Plus de RAM
OLLAMA_MEMORY_LIMIT=32G

# Modèle plus puissant
OLLAMA_DEFAULT_MODEL=llama2:13b

# Pool plus grand
PGBOUNCER_DEFAULT_POOL_SIZE=50
```

### Multi-instance

```bash
# Créer plusieurs Ollama containers
# (Nécessite load balancing)
# Voir docker-compose.scaling.yml (à créer)
```

---

## 🛑 Shutdown & Cleanup

### Arrêter

```bash
docker-compose down

# Garder les volumes
docker-compose down -v  # Supprime les volumes (ATTENTION!)
```

### Backup avant suppression

```bash
# Ollama models
docker run --rm -v lantorian_genai_ollama_data:/data \
  -v $(pwd):/backup ubuntu tar czf /backup/ollama-backup.tar.gz -C /data .

# PostgreSQL
docker exec generative-postgres-prod pg_dump -U ollama_user -d ollama_db \
  > ollama_db_backup.sql

# Redis (optional)
docker exec generative-redis-prod redis-cli BGSAVE
```

---

## 📖 Documentation

| Document | Usage |
|----------|-------|
| `QUICK-CONFIG.md` | Configuration rapide |
| `DYNAMIC-CONFIG.md` | Tous les modèles |
| `DATABASE.md` | PostgreSQL + PgBouncer |
| `DATABASE-CLI.md` | Gestion CLI |
| `API-USAGE.md` | Endpoints API |
| `DEPLOYMENT-GUIDE.md` | Déploiement détaillé |
| `ARCHITECTURE.md` | Ce fichier |

---

## ✅ Checklist Post-Deployment

- [ ] Ollama responding (`curl http://localhost:11434/api/tags`)
- [ ] Redis ping (`docker exec redis redis-cli ping`)
- [ ] PostgreSQL accessible (`psql -h localhost -p 5432`)
- [ ] PgBouncer working (`psql -h localhost -p 6432`)
- [ ] Warmer running (`docker logs generative-ollama-warmer`)
- [ ] Domain resolved (`nslookup ollama.bluevaloris.com`)
- [ ] HTTPS working (`curl https://ollama.bluevaloris.com`)
- [ ] API key created (`python db-manage.py key create ...`)
- [ ] Domain whitelisted (`python db-manage.py domain add ...`)
- [ ] Monitoring (check dashboard)

---

**Full Stack Ollama Production Ready** ✅
