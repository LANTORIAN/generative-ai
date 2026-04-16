# Configuration Dynamique - Modèles & Variables

La configuration est entièrement dynamique via `.env`. Tous les paramètres peuvent être ajustés sans modifier le code.

---

## 🔄 Changer de modèle facilement

### Option 1: Modifier `.env` et redémarrer

```bash
# Éditer .env
OLLAMA_DEFAULT_MODEL=llama2

# Redémarrer les services
docker-compose -f docker-compose.ollama.yml restart ollama ollama-warmer
```

### Option 2: Utiliser différentes configurations

```bash
# Développement (petit modèle)
cp .env.example .env
echo "OLLAMA_DEFAULT_MODEL=gemma2:2b" >> .env

# Production (modèle puissant)
cp .env.example .env.prod
echo "OLLAMA_DEFAULT_MODEL=llama2" >> .env.prod

# Déployer prod
docker-compose --env-file .env.prod up -d
```

### Option 3: Override en ligne de commande

```bash
docker-compose -f docker-compose.ollama.yml \
  -e OLLAMA_DEFAULT_MODEL=mistral \
  up -d
```

---

## 📚 Modèles disponibles

### Gemma 2
```env
OLLAMA_DEFAULT_MODEL=gemma2:2b      # 2B - Léger, rapide
OLLAMA_DEFAULT_MODEL=gemma2:9b      # 9B - Équilibré
OLLAMA_DEFAULT_MODEL=gemma2:27b     # 27B - Puissant
```
- Créé par Google
- Bon pour: Génération rapide, résumés
- Taille: 1.6GB (2b), 5.2GB (9b), 15GB (27b)

### Llama 2
```env
OLLAMA_DEFAULT_MODEL=llama2         # 7B standard
OLLAMA_DEFAULT_MODEL=llama2:13b     # 13B versions
```
- Meta AI, très populaire
- Bon pour: Conversation, code
- Taille: 3.8GB, 7.3GB

### Mistral
```env
OLLAMA_DEFAULT_MODEL=mistral        # 7B très rapide
OLLAMA_DEFAULT_MODEL=mistral:8x7b   # 8x7B MoE (expert)
```
- Très performant
- Bon pour: Réponses ultra-rapides
- Taille: 4.1GB, 26GB (MoE)

### Neural Chat
```env
OLLAMA_DEFAULT_MODEL=neural-chat    # 7B optimisé chat
```
- Spécialisé conversations
- Taille: 4.7GB

### Dolphin Mixtral
```env
OLLAMA_DEFAULT_MODEL=dolphin-mixtral  # 8x7B MoE puissant
```
- Très puissant, multi-domaine
- Taille: 26GB

### Embedding (pas pour génération)
```env
OLLAMA_DEFAULT_MODEL=nomic-embed-text  # Pour embeddings
```
- Créer des vecteurs de texte
- Taille: 274MB

---

## ⚙️ Configuration complète disponible

### Paramètres Ollama

```env
# Modèles
OLLAMA_DEFAULT_MODEL=gemma2:2b         # Modèle par défaut
OLLAMA_MODELS_TO_PULL=gemma2:2b        # Modèles à télécharger au démarrage

# Performance
OLLAMA_NUM_PARALLEL=4                   # Requêtes parallèles
OLLAMA_NUM_THREAD=4                     # Threads CPU
OLLAMA_KEEP_ALIVE=60m                   # Durée modèle en RAM
OLLAMA_HOST=0.0.0.0:11434              # Host:port binding

# Redis  
OLLAMA_REDIS_HOST=redis                 # Host Redis
OLLAMA_REDIS_PORT=6379                  # Port Redis
```

### Paramètres Redis

```env
REDIS_MAX_MEMORY=1gb                    # Max mémoire
REDIS_MAX_MEMORY_POLICY=allkeys-lru     # Politique expiration
REDIS_APPENDONLY=yes                    # Persistence
REDIS_HOST=redis                        # Host
REDIS_PORT=6379                         # Port
```

### Paramètres Warmer

```env
WARMER_INTERVAL=300                     # Secondes entre pings
WARMER_PROMPT=ping                      # Prompt warmup
```

### Ressources Docker

```env
# Ollama
OLLAMA_CPU_LIMIT=3.5                    # CPU max
OLLAMA_CPU_RESERVATION=4.0              # CPU min garanti
OLLAMA_MEMORY_LIMIT=14G                 # RAM max
OLLAMA_MEMORY_RESERVATION=10G           # RAM min garanti

# Redis
REDIS_CPU_LIMIT=0.5                     
REDIS_CPU_RESERVATION=0.25              
REDIS_MEMORY_LIMIT=1G                   
REDIS_MEMORY_RESERVATION=512M
```

### Traefik & Domaine

```env
TRAEFIK_NETWORK=coolify                 # Réseau Traefik
TRAEFIK_ENTRYPOINT=websecure           # Entrypoint (https)
TRAEFIK_TLS=true                        # TLS obligatoire
PRODUCTION_DOMAIN=bluevaloris.com       # Domaine restriction
OLLAMA_DOMAIN=ollama.bluevaloris.com   # Domaine Ollama
```

---

## 🚀 Cas d'usage courants

### 1. Development local (rapide)
```env
OLLAMA_DEFAULT_MODEL=gemma2:2b
OLLAMA_NUM_PARALLEL=2
OLLAMA_NUM_THREAD=2
OLLAMA_MEMORY_RESERVATION=4G
OLLAMA_KEEP_ALIVE=10m
WARMER_INTERVAL=600
```

### 2. Production (équilibré)
```env
OLLAMA_DEFAULT_MODEL=gemma2:9b
OLLAMA_NUM_PARALLEL=4
OLLAMA_NUM_THREAD=4
OLLAMA_MEMORY_RESERVATION=10G
OLLAMA_KEEP_ALIVE=60m
WARMER_INTERVAL=300
```

### 3. Production (puissant)
```env
OLLAMA_DEFAULT_MODEL=llama2:13b
OLLAMA_NUM_PARALLEL=8
OLLAMA_NUM_THREAD=8
OLLAMA_MEMORY_RESERVATION=20G
OLLAMA_KEEP_ALIVE=120m
WARMER_INTERVAL=600
```

### 4. Haute performance (MoE)
```env
OLLAMA_DEFAULT_MODEL=dolphin-mixtral
OLLAMA_NUM_PARALLEL=4
OLLAMA_NUM_THREAD=8
OLLAMA_MEMORY_RESERVATION=30G
OLLAMA_KEEP_ALIVE=120m
WARMER_INTERVAL=900
```

---

## 📥 Télécharger plusieurs modèles

Pour avoir plusieurs modèles disponibles:

```bash
# Via .env
OLLAMA_MODELS_TO_PULL=gemma2:2b,llama2,mistral

# Ou manuellement
docker exec generative-ollama-prod ollama pull llama2
docker exec generative-ollama-prod ollama pull mistral
docker exec generative-ollama-prod ollama pull neural-chat

# Lister les modèles
docker exec generative-ollama-prod ollama list
```

---

## 🔄 Workflow: Tester différents modèles

```bash
# 1. Déployer avec gemma2:2b
echo "OLLAMA_DEFAULT_MODEL=gemma2:2b" > .env
docker-compose up -d
sleep 60
curl http://localhost:11434/api/tags

# 2. Tester une requête
curl -X POST http://localhost:11434/api/generate \
  -d '{"model":"gemma2:2b","prompt":"test","stream":false}'

# 3. Changer vers llama2
echo "OLLAMA_DEFAULT_MODEL=llama2" > .env

# 4. Redémarrer et attendre le téléchargement
docker-compose restart
docker exec generative-ollama-prod ollama pull llama2

# 5. Tester llama2
curl -X POST http://localhost:11434/api/generate \
  -d '{"model":"llama2","prompt":"test","stream":false}'
```

---

## 📊 Comparaison modèles

| Modèle | Taille | Vitesse | Qualité | Mémoire | Cas d'usage |
|--------|--------|---------|---------|---------|-------------|
| gemma2:2b | 1.6GB | ⭐⭐⭐⭐⭐ | ⭐⭐ | 4GB | Rapid prototyping |
| gemma2:9b | 5.2GB | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 8GB | Production équilibré |
| mistral | 4.1GB | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ | 8GB | Ultra-rapide |
| llama2:13b | 7.3GB | ⭐⭐⭐ | ⭐⭐⭐⭐⭐ | 12GB | Production puissant |
| neural-chat | 4.7GB | ⭐⭐⭐⭐ | ⭐⭐⭐⭐ | 8GB | Chat spécialisé |
| dolphin-mixtral | 26GB | ⭐⭐ | ⭐⭐⭐⭐⭐ | 30GB | Expert multi-domaine |

---

## 🎯 Migration modèle en production

### Approche safe (zéro downtime)

```bash
# 1. Télécharger nouveau modèle
docker exec generative-ollama-prod ollama pull llama2

# 2. Mettre à jour .env (pas encore appliqué)
sed -i 's/gemma2:2b/llama2/g' .env

# 3. Mettre à jour warmer petit à petit (via rolling restart)
docker-compose restart ollama-warmer

# 4. Vérifier que ancien modèle est stable
docker exec generative-ollama-prod ollama list

# 5. Redémarrer Ollama (attendus ~30s downtime)
docker-compose restart ollama

# 6. Vérifier nouveau modèle actif
curl http://localhost:11434/api/tags
```

---

**Tous les paramètres sont configurables via `.env` - aucune modification du code nécessaire!** ✅
