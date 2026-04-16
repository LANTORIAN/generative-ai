# 🎛️ Configuration Dynamique - Guide Rapide

Stack Ollama **100% configurable via `.env`** - Aucune modification de code nécessaire.

---

## 📋 Démarrage rapide

```bash
# 1. Copier et configurer
cp .env.example .env
nano .env  # Adapter les valeurs

# 2. Créer volumes
docker volume create chatbot-engine_ollama_data
docker volume create chatbot-engine_redis_data

# 3. Déployer
chmod +x deploy.sh
./deploy.sh
```

---

## 🔧 Variables principales

### 🤖 Modèle (plus important)
```env
OLLAMA_DEFAULT_MODEL=gemma2:2b    # Changer ici!
# Options: llama2, mistral, neural-chat, dolphin-mixtral
```

### ⚙️ Performance
```env
OLLAMA_NUM_PARALLEL=4              # 4 requêtes simultanées
OLLAMA_NUM_THREAD=4                # 4 threads CPU
OLLAMA_KEEP_ALIVE=60m              # Modèle reste 60min en RAM
```

### 🔥 Warmer (keep-warm)
```env
WARMER_INTERVAL=300                # Ping toutes les 5 min
```

### 📦 Ressources
```env
OLLAMA_MEMORY_RESERVATION=10G      # RAM min garantie
OLLAMA_MEMORY_LIMIT=14G            # RAM max

REDIS_MEMORY_RESERVATION=512M
REDIS_MEMORY_LIMIT=1G
```

### 🔐 Domaine
```env
OLLAMA_DOMAIN=ollama.bluevaloris.com
PRODUCTION_DOMAIN=bluevaloris.com
```

---

## 🚀 Changements courants

### Changer de modèle
```bash
# Éditer .env
OLLAMA_DEFAULT_MODEL=llama2

# Redémarrer
docker-compose restart
```

### Plus rapide (moins performant)
```env
OLLAMA_DEFAULT_MODEL=gemma2:2b
OLLAMA_NUM_PARALLEL=2
OLLAMA_NUM_THREAD=2
OLLAMA_MEMORY_RESERVATION=4G
```

### Plus performant (consomme plus)
```env
OLLAMA_DEFAULT_MODEL=llama2:13b
OLLAMA_NUM_PARALLEL=8
OLLAMA_MEMORY_RESERVATION=20G
```

### Warming plus rapide (moins économe)
```env
WARMER_INTERVAL=60                 # Ping toutes les minute
```

---

## 📊 Variables complètes

| Variable | Défaut | Description |
|----------|--------|-------------|
| `OLLAMA_DEFAULT_MODEL` | `gemma2:2b` | Modèle par défaut |
| `OLLAMA_NUM_PARALLEL` | `4` | Requêtes parallèles |
| `OLLAMA_NUM_THREAD` | `4` | Threads CPU |
| `OLLAMA_KEEP_ALIVE` | `60m` | Durée modèle en RAM |
| `WARMER_INTERVAL` | `300` | Secondes (ping) |
| `WARMER_PROMPT` | `ping` | Prompt warm-up |
| `REDIS_MAX_MEMORY` | `1gb` | Max mémoire Redis |
| `OLLAMA_MEMORY_RESERVATION` | `10G` | RAM min Ollama |
| `OLLAMA_MEMORY_LIMIT` | `14G` | RAM max Ollama |
| `REDIS_MEMORY_RESERVATION` | `512M` | RAM min Redis |
| `REDIS_MEMORY_LIMIT` | `1G` | RAM max Redis |
| `TRAEFIK_NETWORK` | `coolify` | Réseau Traefik |
| `OLLAMA_DOMAIN` | `ollama.bluevaloris.com` | Domaine Ollama |

---

## ✅ Checklist changement modèle

- [ ] Edition `.env` avec nouveau modèle
- [ ] Test local: `docker-compose ps`
- [ ] Restart: `docker-compose restart`
- [ ] Vérifier: `docker exec generative-ollama-prod ollama list`
- [ ] Test API: `curl http://localhost:11434/api/tags`

---

## 📚 Documentation complète

- **DYNAMIC-CONFIG.md** - Tous les modèles et cas d'usage
- **DEPLOYMENT-GUIDE.md** - Guide déploiement complet
- **API-USAGE.md** - Documentation API

---

**Tout est dynamique via `.env` ✅**
