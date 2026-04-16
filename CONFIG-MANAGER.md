# 🎛️ Config Manager - Interface Web de Configuration

Interface web pour gérer la configuration dynamique d'Ollama, les clés API et les domaines sans accès serveur direct.

## 📋 Vue d'ensemble

Le **Config Manager** est un tableau de bord web accessible via HTTPS qui permet de:

- 🔧 **Gérer les variables d'environnement** (modèles, ressources, timeouts...)
- 🔑 **Créer/supprimer les clés API** sans accès à la base de données
- 🌐 **Whitelist les domaines** pour chaque clé API
- 📊 **Monitorez l'état des services** (Ollama, Redis, PostgreSQL, PgBouncer)
- 🚀 **Redémarrer les services** si nécessaire

## 🚀 Accès

### URL
```
https://config.bluevaloris.com
```

### Authentification
- **Mot de passe**: Défini via `CONFIG_ADMIN_PASSWORD` dans `.env`
- Par défaut: `admin` (à **CHANGER EN PRODUCTION**)

## 🎮 Utilisation

### 1️⃣ Connexion
```
1. Accéder à https://config.bluevaloris.com
2. Entrer le mot de passe admin
3. Cliquer "Se connecter"
```

### 2️⃣ Tab "Environnement" ⚙️

Gérer toutes les variables d'environnement:

```bash
Variables affichées:
├── OLLAMA_DEFAULT_MODEL      # Modèle par défaut
├── OLLAMA_NUM_PARALLEL        # Parallélisme (1-16)
├── OLLAMA_NUM_THREAD          # Threads CPU
├── OLLAMA_KEEP_ALIVE          # Durée en RAM
├── REDIS_MAX_MEMORY           # Limite mémoire Redis
├── POSTGRES_PASSWORD          # ⚠️ Mot de passe DB
├── PGBOUNCER_DEFAULT_POOL_SIZE # Taille du pool
├── WARMER_INTERVAL            # Ping interval
└── ... (60+ variables)
```

**Workflow:**
1. Modifier les valeurs directement
2. Cliquer "💾 Sauvegarder"
3. Les modifications sont écrites dans `.env`
4. **Note**: Certains changements nécessitent un redémarrage du service correspondant (voir tab Services)

### 3️⃣ Tab "Clés API" 🔑

#### Créer une nouvelle clé:
```
1. Remplir "Nom" (ex: "My App")
2. Remplir "Domaine" (ex: "myapp.bluevaloris.com")
3. Cliquer "➕ Créer une clé API"
4. ⚠️ Sauvegarder la clé brute affichée (une fois seulement!)
```

**Clé brute retournée:**
```
eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

Cette clé doit être stockée de façon sécurisée côté client.

#### Liste des clés existantes:
```
┌─────┬──────────────┬──────────────────────────┐
│ ID  │ Nom          │ Domaine                  │
├─────┼──────────────┼──────────────────────────┤
│ 1   │ My App       │ myapp.bluevaloris.com    │
│ 2   │ Mobile App   │ mobile.bluevaloris.com   │
└─────┴──────────────┴──────────────────────────┘
```

- Affiche: ID, Nom, Domaine, Date création, Statut (Actif/Inactif)
- Cliquer "Supprimer" pour désactiver une clé

### 4️⃣ Tab "Domaines" 🌐

#### Ajouter un domaine à la whitelist:
```
1. Entrer "Domaine" (ex: "api.myapp.bluevaloris.com")
2. Sélectionner "Clé API" associée (dropdown)
3. Optionnel: Description
4. Cliquer "➕ Ajouter un domaine"
```

#### Domaines whitelistés:
```
┌────────────────────────────────────┬─────────────────┬────────────┐
│ Domaine                            │ Clé API         │ Créé le    │
├────────────────────────────────────┼─────────────────┼────────────┤
│ api.myapp.bluevaloris.com          │ My App          │ 16/04/2026 │
│ mobile.myapp.bluevaloris.com       │ Mobile App      │ 15/04/2026 │
└────────────────────────────────────┴─────────────────┴────────────┘
```

### 5️⃣ Tab "Services" 🐳

Redémarrer les services Docker individuellement:

```
Boutons disponibles:
├── 🤖 Restart Ollama      # Redémarrer Ollama
├── 🔴 Restart Redis       # Redémarrer Redis
├── 🗄️ Restart PostgreSQL  # Redémarrer PostgreSQL
└── 🔗 Restart PgBouncer   # Redémarrer PgBouncer
```

**Confirmation obligatoire** avant redémarrage.

### 📊 Indicateurs d'état (haut de page)

État des services mis à jour automatiquement toutes les 5 secondes:

```
┌─────────────┬──────────────┬───────────┬──────────────┐
│ OLLAMA      │ REDIS        │ POSTGRES  │ PGBOUNCER    │
├─────────────┼──────────────┼───────────┼──────────────┤
│ ✅ Running  │ ✅ Running   │ ✅ Running│ ✅ Running   │
└─────────────┴──────────────┴───────────┴──────────────┘
```

## 🔐 Sécurité

### Best Practices

1. **Changer le mot de passe admin:**
   ```bash
   # Dans .env (production)
   CONFIG_ADMIN_PASSWORD=super_secret_password_very_long_and_secure
   ```

2. **HTTPS obligatoire** (via Traefik)
   - Connexion chiffrée automatiquement
   - Domaine: `config.bluevaloris.com`

3. **Restricting Access:**
   ```bash
   # Ajouter une IP whitelist (optionnel via Traefik middlewares)
   traefik.http.middlewares.config-ip-restriction.ipwhitelist.sourcerange=203.0.113.0/24
   ```

4. **Rate limiting:**
   ```bash
   # Éviter les brute-force attacks
   # Ajouter via Traefik si nécessaire
   ```

## 📦 Architecture

```
Browser
   ↓ HTTPS
Traefik (config.bluevaloris.com)
   ↓
Config Manager (FastAPI, port 8888)
   ├→ Lecture/Écriture .env
   ├→ Appels API PostgreSQL (via PgBouncer)
   │  ├→ ollama.api_keys
   │  ├→ ollama.domain_whitelist
   │  └→ ollama.api_usage
   ├→ Vérification Ollama API (http://ollama:11434)
   ├→ Vérification Redis (redis:6379)
   └→ Docker CLI (redémarrage services)
```

## 🛠️ Configuration

### Variables d'environnement

```bash
# .env
CONFIG_ADMIN_PASSWORD=admin              # Mot de passe admin
PGBOUNCER_HOST=pgbouncer                 # Hôte connexion DB
PGBOUNCER_PORT=6432                      # Port PgBouncer
POSTGRES_USER=ollama_user                # User DB
POSTGRES_PASSWORD=change_me              # Password DB
POSTGRES_DB=ollama_db                    # Database name

# Ressources Docker (optionnel)
CONFIG_MANAGER_CPU_LIMIT=0.5
CONFIG_MANAGER_CPU_RESERVATION=0.25
CONFIG_MANAGER_MEMORY_LIMIT=512M
CONFIG_MANAGER_MEMORY_RESERVATION=256M
```

### Docker Compose

```yaml
config-manager:
  build:
    context: .
    dockerfile: config-manager-Dockerfile
  environment:
    - CONFIG_ADMIN_PASSWORD=admin
    - PGBOUNCER_HOST=pgbouncer
    # ... autres variables
  ports:
    - "127.0.0.1:8888:8888"  # Accessible uniquement en local
  labels:
    - traefik.enable=true
    - traefik.http.routers.config-manager.rule=Host(`config.bluevaloris.com`)
```

## 🔧 Dépannage

### L'interface ne se lance pas

```bash
# Vérifier les logs
docker-compose logs -f config-manager

# Erreur commune: Port déjà utilisé
lsof -i :8888
kill -9 <PID>
```

### Erreur de connexion PostgreSQL

```bash
# Vérifier PgBouncer
docker-compose exec pgbouncer psql -U postgres -d pgbouncer -c "show pools"

# Vérifier PostgreSQL
docker-compose exec postgres psql -U ollama_user -d ollama_db -c "\dt"
```

### Mot de passe perdu

```bash
# Réinitialiser via .env
CONFIG_ADMIN_PASSWORD=new_password

# Redémarrer le service
docker-compose restart config-manager
```

## 📝 Exemples d'utilisation

### Exemple 1: Changer le modèle par défaut

```
1. Accéder à https://config.bluevaloris.com
2. Tab "Environnement"
3. Trouver "OLLAMA_DEFAULT_MODEL"
4. Changer "gemma2:2b" → "mistral"
5. Cliquer "💾 Sauvegarder"
6. Tab "Services" → Cliquer "🤖 Restart Ollama"
7. Attendre confirmation
```

### Exemple 2: Créer une clé API pour une nouvelle app

```
1. Tab "Clés API"
2. Remplir:
   - Nom: "NewAppV2"
   - Domaine: "newapp-api.bluevaloris.com"
3. Cliquer "➕ Créer une clé API"
4. Copier la clé brute:
   sk_live_5bYqP8nZ9xKqM2vR7pL3...
5. Sauvegarder la clé dans un gestionnaire de secrets
6. Tab "Domaines": Ajouter le domaine à la whitelist
```

### Exemple 3: Augmenter la capacité

```
Configuration actuelle:
- OLLAMA_NUM_PARALLEL=4
- OLLAMA_KEEP_ALIVE=60m
- PGBOUNCER_DEFAULT_POOL_SIZE=25

Modification pour augmenter capacité:
1. OLLAMA_NUM_PARALLEL=8        (+ requêtes parallèles)
2. PGBOUNCER_DEFAULT_POOL_SIZE=50  (+ connexions DB)
3. Cliquer "💾 Sauvegarder"

Services à redémarrer:
- Tab "Services" → Restart Ollama
- Tab "Services" → Restart PgBouncer
```

## 📊 Monitoring

### Vérifier les logs d'accès

```bash
# Via PostgreSQL
psql -U ollama_user -d ollama_db
SELECT * FROM ollama.api_usage ORDER BY created_at DESC LIMIT 10;
SELECT * FROM audit.access_log ORDER BY created_at DESC LIMIT 10;

# Via Docker
docker-compose logs config-manager | tail -50
```

### Exporter les configurations

```bash
# Sauvegarder .env actuel
cp .env .env.backup-$(date +%Y%m%d)

# Exporter les clés API
docker-compose exec config-manager python db-manage.py key list > keys.backup
```

## 🚀 Déploiement en production

### Checklist

- [ ] Changer `CONFIG_ADMIN_PASSWORD` vers un mot de passe fort
- [ ] Activer HTTPS (via Traefik)
- [ ] Configurer les logs
- [ ] Tester l'accès via `https://config.bluevaloris.com`
- [ ] Documenter le mot de passe dans un vault sécurisé
- [ ] Configurer les backups de `.env`
- [ ] Ajouter une IP whitelist si possible
- [ ] Monitorer les logs d'accès

### Logs recommandés

```bash
# Daily rotation
docker-compose logs --tail=1000 config-manager > logs/config-manager-$(date +%Y%m%d).log

# Ou via syslog
# Ajouter au config-manager-Dockerfile:
# RUN apt-get update && apt-get install -y bind-tools curl
# CMD ["python", "-u", "config-manager.py"] # -u pour unbuffered
```

## 📞 Support

Pour des modifications complexes:

```bash
# SSH dans le container
docker-compose exec config-manager bash

# Ou via logs
docker-compose logs -f config-manager
```

## 📚 Documentation liée

- [API-USAGE.md](API-USAGE.md) - Documentation API Ollama
- [DATABASE-CLI.md](DATABASE-CLI.md) - CLI db-manage.py
- [DEPLOYMENT-GUIDE.md](DEPLOYMENT-GUIDE.md) - Guide déploiement complet
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture du système
