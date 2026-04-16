# 🤖 Ollama Stack Production - Avec Config Manager

Configuration Docker Compose complète pour Ollama avec Redis, PostgreSQL, gestion API keys, et interface web de configuration.

## 📋 Caractéristiques

✅ **Interface de Configuration Web** (`config-manager`)
- 🎛️ Tableau de bord HTTPS pour gérer les variables d'environnement
- 🔑 Gestion des clés API sans accès SSH
- 🌐 Whitelist des domaines
- 📊 Monitoring de l'état des services
- URL: `https://config.bluevaloris.com`

✅ **Haute Disponibilité 24/7**
- Restart policy: `always` pour récupération automatique
- Healthchecks intégrés pour tous les services
- Persistent volumes pour les données
- 5 services: Ollama, Redis, PostgreSQL, PgBouncer, Config Manager

✅ **Modèle Optimisé**
- Modèle par défaut: `gemma2:2b`
- Serveur de warming automatique (ping toutes les 5 minutes)
- OLLAMA_KEEP_ALIVE=60m pour maintenir le modèle en mémoire

✅ **Caching & Performance**
- Redis pour caching automatique des réponses
- PgBouncer pour connection pooling (réduction latence DB)
- Variables d'environnement OLLAMA_REDIS_* configurées
- Policy LRU Redis pour gestion mémoire

✅ **Persistence & Audit**
- PostgreSQL pour: API keys, domaines, usage logs, audit trails
- Schéma pré-créé avec 9 tables et 8 views
- Tracking complet de chaque requête API

✅ **Sécurité Domaine**
- Restreint à `*.bluevaloris.com` via Traefik
- HTTPS obligatoire (tls=true)
- Middleware de restriction d'hôte
- Authentification par clé API (stockée en SHA256)

✅ **Performance optimale**
- CPU: 3.5 - 4.0 cores Ollama (configurable)
- RAM: 10GB - 14GB Ollama (configurable)
- Port Ollama: 11434 (standard)
- Connection pooling: 25-50 connexions simultanées


## 🚀 Déploiement

### 1. Prérequis

```bash
# Créer les volumes persistants
docker volume create chatbot-engine_ollama_data
docker volume create chatbot-engine_redis_data

# S'assurer que le réseau Traefik existe (coolify par défaut)
docker network inspect coolify || docker network create coolify
docker network create backend-network 2>/dev/null || true
```

### 2. Configuration

Copier `.env.example` vers `.env` et ajuster si nécessaire:

```bash
cp .env.example .env
```

Variables disponibles:
```env
OLLAMA_NUM_PARALLEL=4          # Requêtes parallèles
OLLAMA_NUM_THREAD=4           # Threads CPU
TRAEFIK_NETWORK=coolify       # Réseau Traefik
PRODUCTION_DOMAIN=bluevaloris.com
```

### 3. Lancer le déploiement

```bash
# 🚀 Installation automatique VPS (recommandé)
chmod +x install-ollama-stack.sh
sudo ./install-ollama-stack.sh

# Ou pour Linux/Docker déjà installé:
chmod +x deploy.sh
./deploy.sh

# Manuel:
docker-compose -f docker-compose.ollama.yml up -d
sleep 60
docker exec generative-ollama-prod ollama pull gemma2:2b
```

## 🎛️ Config Manager - Interface Web

Après le déploiement, accéder au tableau de bord:

```
URL:      https://config.bluevaloris.com
Mot de passe: <CONFIG_ADMIN_PASSWORD> (depuis .env)
```

**Fonctionnalités:**
- ⚙️ Modifier les variables d'environnement (modèles, ressources, timeouts)
- 🔑 Créer/supprimer les clés API sans SSH
- 🌐 Whitelist des domaines
- 📊 Monitorer l'état (Ollama, Redis, PostgreSQL, PgBouncer)
- 🚀 Redémarrer les services individuellement

👉 [Voir documentation CONFIG-MANAGER.md](CONFIG-MANAGER.md)

## 📡 Endpoints & Utilisation

### Accès externe (HTTPS)
```bash
# Depuis any.bluevaloris.com (réstrictor de domaine)
curl -X POST https://ollama.bluevaloris.com/api/generate \
  -d '{
    "model": "gemma2:2b",
    "prompt": "Bonjour",
    "stream": false
  }'

# Lister les modèles
curl https://ollama.bluevaloris.com/api/tags
```

### Accès interne (Docker network)
```bash
# Depuis un autre conteneur
curl -X POST http://ollama:11434/api/generate \
  -d '{
    "model": "gemma2:2b",
    "prompt": "test"
  }'
```

## 🔥 Warming & Performance

Le service `ollama-warmer` maintient le modèle **chaud** via:
- Ping automatique toutes les 5 minutes (300s)
- Après chaque ping, gemma2:2b reste en RAM
- Temps de réponse instantané (<100ms)

Pour ajuster l'intervalle de ping, modifier dans `docker-compose.ollama.yml`:
```yaml
sleep 300;  # Changer 300 (5 min) en autre valeur
```

## 🏥 Monitoring & Santé

Vérifier l'état des services:
```bash
docker-compose -f docker-compose.ollama.yml ps
docker logs generative-ollama-prod
docker logs generative-redis-prod
docker logs generative-ollama-warmer
```

Vérifier les healthchecks:
```bash
docker inspect generative-ollama-prod --format='{{.State.Health.Status}}'
docker inspect generative-redis-prod --format='{{.State.Health.Status}}'
```

## 🔐 Sécurité Domaine

**Restriction stricte:** Seules les requêtes avec `Host: *.bluevaloris.com` sont acceptées.

Configuration Traefik:
```yaml
- traefik.http.routers.generative-production.rule=Host(`ollama.bluevaloris.com`)
- traefik.http.middlewares.host-restriction.headers.customrequestheaders.X-Forwarded-Host=ollama.bluevaloris.com
```

## 📊 Ressources Alloués

| Service | CPU Min | CPU Max | RAM Min | RAM Max |
|---------|---------|---------|---------|---------|
| Ollama  | 4.0     | 3.5     | 10GB    | 14GB    |
| Redis   | 0.25    | 0.5     | 512MB   | 1GB     |

## 🛑 Arrêt & Maintenance

```bash
# Arrêter tous les services
docker-compose -f docker-compose.ollama.yml down

# Arrêter et supprimer les volumes (ATTENTION!)
docker-compose -f docker-compose.ollama.yml down -v

# Redémarrer
docker-compose -f docker-compose.ollama.yml restart

# Checker les logs en temps réel
docker-compose -f docker-compose.ollama.yml logs -f
```

## 🐛 Troubleshooting

### Ollama ne démarre pas
```bash
docker logs generative-ollama-prod
# Vérifier qu'il y a assez de RAM/CPU
```

### Module gemma2:2b ne charge pas
```bash
# Vérifier le modèle manuellement
docker exec generative-ollama-prod ollama list
docker exec generative-ollama-prod ollama pull gemma2:2b
```

### Redis ne se connecte pas
```bash
# Vérifier la connectivité
docker exec generative-ollama-prod redis-cli -h redis ping
```

### Erreur 403 Forbidden
- Vérifier que la requête vient de `*.bluevaloris.com`
- Traefik doit être configuré sur le bon réseau
- Vérifier les logs Traefik

## 📚 Documentation Supplémentaire

- [Ollama API](https://github.com/ollama/ollama/blob/main/docs/api.md)
- [Redis Stack](https://redis.io/docs/stack/)
- [Traefik Middleware](https://doc.traefik.io/traefik/middlewares/overview/)

## 📞 Support

Pour les problèmes:
1. Vérifier les logs: `docker-compose logs -f`
2. Vérifier les healthchecks: `docker ps --no-trunc`
3. Tester manuellement: `curl http://localhost:11434/api/tags`

---

**Version**: 1.0.0  
**Dernière mise à jour**: 2024  
**Status**: Production Ready ✅
