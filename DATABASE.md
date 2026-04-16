# 📊 PostgreSQL + PgBouncer Setup

Stack Ollama inclut maintenant **PostgreSQL** avec **PgBouncer** pour connection pooling et stockage des informations de connexion.

---

## 🏗️ Architecture

```
┌─────────────────────────────────┐
│   Application / API Client      │
└────────────┬────────────────────┘
             │
             ▼ (Port 6432)
┌─────────────────────────────────┐
│    PgBouncer (Connection Pool)  │ ← Pooling, routing
│    mode: transaction            │
│    max_clients: 1000            │
│    pool_size: 25                │
└────────────┬────────────────────┘
             │
             ▼ (Port 5432)
┌─────────────────────────────────┐
│    PostgreSQL 16 Alpine         │ ← Database real
│    max_connections: 200         │
│    Schemas: ollama, audit       │
└─────────────────────────────────┘
```

---

## 🗄️ Tables créées automatiquement

### Ollama Schema

#### `api_keys`
Stocke les clés API, domaines, rate limits

```sql
SELECT * FROM ollama.api_keys;
-- id, key_hash, name, domain, rate_limit_per_minute, etc.
```

#### `domain_whitelist`
Whitelis des domaines autorisés

```sql
SELECT domain, is_active FROM ollama.domain_whitelist;
```

#### `api_usage`
Log de chaque requête API

```sql
SELECT endpoint, model, response_time_ms, tokens_used 
FROM ollama.api_usage 
WHERE created_at > NOW() - INTERVAL '1 day'
ORDER BY created_at DESC;
```

#### `model_configs`
Configuration par modèle

```sql
SELECT * FROM ollama.model_configs WHERE is_active = true;
```

#### `connection_pools`
Pools de connexion disponibles

```sql
SELECT pool_name, min_size, max_size FROM ollama.connection_pools;
```

#### `error_log`
Logs d'erreurs pour debugging

```sql
SELECT error_code, error_message, created_at 
FROM ollama.error_log 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
```

### Audit Schema

#### `access_log`
Audit de tous les accès pour sécurité

```sql
SELECT action, resource, status, created_at 
FROM audit.access_log 
ORDER BY created_at DESC LIMIT 100;
```

---

## 🔌 Connexion à PostgreSQL

### Direct (port 5432)

```bash
# Via psql
psql -h localhost -p 5432 -U ollama_user -d ollama_db

# Via Docker
docker exec generative-postgres-prod psql -U ollama_user -d ollama_db

# Via connection string
postgresql://ollama_user:password@localhost:5432/ollama_db
```

### Via PgBouncer (port 6432) - RECOMMANDÉ

```bash
# Via psql (pool automatique)
psql -h localhost -p 6432 -U ollama_user -d ollama_db

# Via Docker
docker exec generative-pgbouncer-prod psql -h localhost -p 6432 -U ollama_user -d ollama_db

# Via connection string
postgresql://ollama_user:password@localhost:6432/ollama_db
```

---

## 📝 Opérations courantes

### 1. Créer une clé API

```sql
-- Générer une clé (ex: sha256 hash)
INSERT INTO ollama.api_keys (
    key_hash, name, domain, rate_limit_per_minute, created_by
)
VALUES (
    'sha256_hash_of_your_key_here',
    'My App API Key',
    'myapp.bluevaloris.com',
    100,
    'admin'
);

-- Récupérer l'ID
SELECT id, name, created_at FROM ollama.api_keys WHERE name = 'My App API Key';
```

### 2. Ajouter un domaine à la whitelist

```sql
INSERT INTO ollama.domain_whitelist (domain, api_key_id, description)
VALUES (
    'api.myapp.bluevaloris.com',
    1,  -- api_key_id from previous query
    'Production API endpoint'
);
```

### 3. Voir les statistiques d'utilisation

```sql
-- Requêtes par endpoint
SELECT 
    endpoint,
    COUNT(*) as request_count,
    AVG(response_time_ms) as avg_response_time_ms,
    SUM(tokens_used) as total_tokens
FROM ollama.api_usage
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY endpoint
ORDER BY request_count DESC;

-- Par modèle
SELECT 
    model,
    COUNT(*) as request_count,
    AVG(response_time_ms) as avg_response_time_ms
FROM ollama.api_usage
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY model;

-- Vue rapide
SELECT * FROM ollama.v_usage_stats 
WHERE usage_date = CURRENT_DATE;
```

### 4. Voir les domaines actifs

```sql
SELECT * FROM ollama.v_domain_mappings WHERE is_active = true;
```

### 5. Logs d'audit

```sql
-- Tous les accès
SELECT action, resource, status, ip_address, created_at 
FROM audit.access_log 
WHERE created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;

-- Erreurs d'authentification
SELECT * FROM audit.access_log 
WHERE status = 'FAILED' 
AND created_at > NOW() - INTERVAL '24 hours';
```

### 6. Santé des services

```sql
SELECT service_name, status, response_time_ms, created_at 
FROM ollama.health_checks 
WHERE created_at = (
    SELECT MAX(created_at) FROM ollama.health_checks
)
ORDER BY service_name;
```

---

## 🔧 Configuration PgBouncer

### Pool Mode

| Mode | Usage | Trade-off |
|------|-------|-----------|
| `session` | 1 connection per client session | Un peu lourd |
| `transaction` | 1 connection per transaction (défaut) | Léger, recommandé |
| `statement` | 1 connection per statement | Très léger mais experimental |

Actuellement: **transaction mode**

### Tuning (dans `.env`)

```env
# Augmenter pour plus de connections simultanées
PGBOUNCER_MAX_CLIENT_CONN=1000
PGBOUNCER_DEFAULT_POOL_SIZE=25

# Réduire pour moins de connections
PGBOUNCER_DEFAULT_POOL_SIZE=10
```

### Vérifier la santé

```bash
# Via Docker
docker exec generative-pgbouncer-prod redis-cli ping

# Via psql
psql -h localhost -p 6432 -U ollama_user -d olama_db -c "SELECT 1;"
```

---

## 📊 Views utiles

### `v_active_api_keys`

```sql
SELECT * FROM ollama.v_active_api_keys;
```

Retourne toutes les clés API actives avec leurs rate limits.

### `v_usage_stats`

```sql
SELECT * FROM ollama.v_usage_stats 
WHERE usage_date = CURRENT_DATE
ORDER BY request_count DESC;
```

Statistiques agrégées par jour/endpoint/modèle.

### `v_domain_mappings`

```sql
SELECT * FROM ollama.v_domain_mappings;
```

Mapping domaine → clé API.

---

## 🔐 Sécurité

### Mot de passe par défaut

⚠️ **IMPORTANT**: Changer `POSTGRES_PASSWORD` en production!

```bash
# Avant déploiement, éditer .env
POSTGRES_PASSWORD=super_secure_password_here_123456789
```

### Authentification

La base utilise **MD5** par défaut. En production:

```bash
# Utiliser scram-sha-256 (plus sûr)
# Modifier init-db.sql et redéployer
```

### Accès restreint

La base est seulement accessible via:
- `localhost:5432` (direct)  
- `localhost:6432` (via pgbouncer)
- Réseau Docker interne `backend`

Pas d'accès externe par défaut.

---

## 📈 Performance / Monitoring

### Vérifier l'état du pool

```bash
# Connections actives
docker exec generative-postgres-prod psql -U ollama_user -d ollama_db -c \
  "SELECT datname, count(*) FROM pg_stat_activity GROUP BY datname;"

# Taille DB
docker exec generative-postgres-prod psql -U ollama_user -d ollama_db -c \
  "SELECT pg_size_pretty(pg_database_size('ollama_db'));"

# Taille tables
docker exec generative-postgres-prod psql -U ollama_user -d ollama_db -c \
  "SELECT tablename, pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) 
   FROM pg_tables ORDER BY pg_total_relation_size DESC;"
```

### Index statistics

```bash
docker exec generative-postgres-prod psql -U ollama_user -d ollama_db -c \
  "SELECT schemaname, tablename, indexname, idx_scan 
   FROM pg_stat_user_indexes ORDER BY idx_scan DESC;"
```

---

## 🚀 Déploiement

### Avant le déploiement

```bash
# 1. Éditer .env
nano .env

# 2. Créer le volume
docker volume create lantorian_genai_postgres_data

# 3. Adapter le mot de passe (IMPORTANT!)
POSTGRES_PASSWORD=votre_mot_de_passe_secure_ici
```

### Déployer

```bash
# Le script deploy.sh créera les volumes automatiquement
./deploy.sh
```

### Vérifier

```bash
# Santé
docker-compose ps | grep postgres
docker-compose ps | grep pgbouncer

# Logs
docker logs generative-postgres-prod
docker logs generative-pgbouncer-prod

# Connexion
psql -h localhost -p 6432 -U ollama_user -d ollama_db -c "SELECT 1;"
```

---

## 🛑 Maintenance

### Backup

```bash
# Via Docker
docker exec generative-postgres-prod pg_dump -U ollama_user -d ollama_db > backup.sql

# Full backup
docker run --rm -v lantorian_genai_postgres_data:/data -v $(pwd):/backup \
  postgres:16-alpine tar czf /backup/postgres-backup.tar.gz -C /data .
```

### Restore

```bash
# De SQL
docker exec -i generative-postgres-prod psql -U ollama_user -d ollama_db < backup.sql

# De tar
docker exec generative-postgres-prod tar xzf - -C /var/lib/postgresql/data < postgres-backup.tar.gz
```

### Maintenance

```bash
# VACUUM (optimize)
docker exec generative-postgres-prod psql -U ollama_user -d ollama_db -c "VACUUM ANALYZE;"

# Rebuild indexes
docker exec generative-postgres-prod psql -U ollama_user -d ollama_db -c \
  "REINDEX DATABASE ollama_db;"
```

---

## 🐛 Troubleshooting

### Cannot connect

```bash
# Vérifier que services running
docker-compose ps

# Vérifier les logs
docker logs generative-postgres-prod
docker logs generative-pgbouncer-prod

# Tester connexion interne
docker exec generative-pgbouncer-prod nc -zv postgres 5432
```

### Slow queries

```bash
# Analyser les requêtes lentes
docker exec generative-postgres-prod psql -U ollama_user -d ollama_db -c \
  "SELECT query, calls, mean_time, total_time 
   FROM pg_stat_statements 
   ORDER BY mean_time DESC LIMIT 10;"

# Activer query logging
# Modifier POSTGRES_INITDB_ARGS dans .env avec:
# -c log_statement=all -c log_duration=on
```

### Pool exhausted

```bash
# Si "too many connections"
# Augmenter dans .env:
PGBOUNCER_DEFAULT_POOL_SIZE=40

# Redémarrer pgbouncer
docker-compose restart pgbouncer
```

---

## 📚 Resources

- [PostgreSQL Docs](https://www.postgresql.org/docs/)
- [PgBouncer Docs](https://www.pgbouncer.org/config.html)
- [Connection Pooling Best Practices](https://wiki.postgresql.org/wiki/Number_Of_Database_Connections)

---

**PostgreSQL + PgBouncer Setup Complete** ✅
