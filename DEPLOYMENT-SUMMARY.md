# 📦 Ollama Stack - Déploiement Complet

## 🎯 Résumé des modifications

### Nouvelles Fonctionnalités Ajoutées

#### 1. 🎛️ Config Manager - Interface Web
- **Fichiers créés:**
  - `config-manager.py` - Application FastAPI principale
  - `config-manager/` - Répertoire avec Dockerfile et requirements
  - `CONFIG-MANAGER.md` - Documentation complète

- **Fonctionnalités:**
  - Interface web accessible via HTTPS
  - Gestion des variables d'environnement
  - Création/suppression des clés API
  - Whitelist des domaines
  - Monitoring des services
  - Redémarrage des services

- **Accès:** `https://config.bluevaloris.com`


#### 2. 🚀 Scripts de déploiement VPS
- **Fichiers créés:**
  - `install-ollama-stack.sh` - Installation automatique complète
  - `VPS-DEPLOYMENT.md` - Guide détaillé de déploiement

- **Fonctionnalités:**
  - Installation Docker/Docker Compose
  - Création volumes
  - Configuration interactive
  - Tests automatiques

#### 3. 📖 Documentation complète
- **Fichiers créés:**
  - CONFIG-MANAGER.md - Interface web
  - VPS-DEPLOYMENT.md - Déploiement VPS
  - README.md - Mise à jour

- **Total:** 8+ fichiers de documentation

---

## 📁 Structure des fichiers

```
generative-ai/
├── docker-compose.ollama.yml          # 5 services (updated)
├── .env.example                       # Configuration template (updated)
├── .env.local                         # Local config (updated)
│
├── config-manager.py                  # ✨ NEW - Application FastAPI
├── config-manager/
│   ├── Dockerfile                     # ✨ NEW - Image Docker
│   ├── requirements.txt               # ✨ NEW - Dépendances Python
│   └── .dockerignore                  # ✨ NEW
│
├── init-db.sql                        # Schéma PostgreSQL
├── pgbouncer.ini                      # Configuration connection pool
│
├── db-manage.py                       # CLI de gestion DB
│
├── deploy.sh                          # Script déploiement
├── test-stack.sh                      # Tests de validation
├── install-ollama-stack.sh            # ✨ NEW - Installation VPS
│
├── CONFIG-MANAGER.md                  # ✨ NEW - Documentation interface
├── VPS-DEPLOYMENT.md                  # ✨ NEW - Guide VPS
├── README.md                          # ✨ UPDATED
├── DATABASE.md                        # Gestion DB
├── DATABASE-CLI.md                    # CLI guide
├── ARCHITECTURE.md                    # Architecture
├── API-USAGE.md                       # API examples
├── DEPLOYMENT-GUIDE.md                # Déploiement manuel
└── QUICK-CONFIG.md                    # Quick reference
```

---

## 🔧 Configuration initiale

### Fichier `.env` - Paramètres clés

```bash
# ===== Domaine et accès =====
PRODUCTION_DOMAIN=bluevaloris.com
OLLAMA_DOMAIN=ollama.bluevaloris.com

# ===== Sécurité ⚠️ À CHANGER =====
POSTGRES_PASSWORD=change_me_in_production
CONFIG_ADMIN_PASSWORD=admin

# ===== Config Manager =====
CONFIG_ADMIN_PASSWORD=votre_mot_passe_secure

# ===== Ressources (adapter à votre serveur) =====
OLLAMA_CPU_LIMIT=3.5
OLLAMA_MEMORY_LIMIT=14G
OLLAMA_NUM_PARALLEL=4

# ===== Modèle par défaut =====
OLLAMA_DEFAULT_MODEL=gemma2:2b
```

---

## 🚀 Démarrage rapide

### VPS - Installation automatique (recommandé)

```bash
# 1. SSH sur le VPS
ssh root@<VPS_IP>

# 2. Télécharger les fichiers
cd /opt && git clone <votre-repo> ollama-stack
cd ollama-stack

# 3. Lancer l'installation automatique
chmod +x install-ollama-stack.sh
sudo ./install-ollama-stack.sh

# 4. Suivre les instructions interactives
# - Domaine: bluevaloris.com
# - Mot de passe PostgreSQL: <STRONG>
# - Mot de passe Admin: <STRONG>

# 5. Accéder au dashboard
https://config.bluevaloris.com
Login avec CONFIG_ADMIN_PASSWORD
```

### Local/Docker déjà installé

```bash
# 1. Créer les volumes
docker volume create lantorian_genai_{ollama,redis,postgres}_data

# 2. Configurer .env
cp .env.example .env
nano .env  # Adapter les valeurs

# 3. Démarrer
docker-compose -f docker-compose.ollama.yml up -d
```

---

## 🎮 Utilisation du Config Manager

### Accès web
- **URL:** `https://config.bluevaloris.com`
- **Authentification:** Mot de passe défini dans `CONFIG_ADMIN_PASSWORD`

### Tabs disponibles

1. **⚙️ Environnement**
   - Modifier les variables d'environnement
   - Sauvegarder directement dans `.env`

2. **🔑 Clés API**
   - Créer des clés API
   - Lister les clés existantes
   - Supprimer (désactiver) les clés

3. **🌐 Domaines**
   - Ajouter des domaines à la whitelist
   - Associer à une clé API
   - Tout stocké dans PostgreSQL

4. **🐳 Services**
   - Redémarrer Ollama
   - Redémarrer Redis
   - Redémarrer PostgreSQL
   - Redémarrer PgBouncer

### CLI alternative (db-manage.py)

```bash
# Via Docker
docker-compose exec config-manager python db-manage.py key create --name "App1" --domain "app1.com"
docker-compose exec config-manager python db-manage.py key list
docker-compose exec config-manager python db-manage.py usage show --days 7
```

---

## 🏗️ Architecture services

```
┌─────────────────────────────────────────────────────────┐
│                    Traefik (HTTPS)                      │
│         config.bluevaloris.com                          │
└──────────────────────┬──────────────────────────────────┘
                       │
        ┌──────────────────────────────┐
        │   Config Manager (8888)      │
        │   - FastAPI                  │
        │   - Web UI                   │
        │   - API REST                 │
        └──────────┬───────────────────┘
                   │
    ┌──────────────┼──────────────┬──────────────────────┐
    │              │              │                      │
┌───▼────┐  ┌─────▼──┐  ┌────────▼────────┐  ┌────────┐ │
│ Ollama │  │ Redis  │  │ PostgreSQL      │  │PgBouncer
│ 11434  │  │ 6379   │  │ 5432            │  │6432    │
└────────┘  └────────┘  └─────────────────┘  └────────┘
    │           │             │
    └───────────┼─────────────┘
                │
         ┌──────────────┐
         │  Client Apps │
         │ (via HTTPS)  │
         └──────────────┘
```

---

## 📊 Services Docker

| Service | Port | Interne | Healthcheck | Restart |
|---------|------|---------|-------------|---------|
| Ollama | 11434 | Oui | 30s | Always |
| Redis | 6379 | Oui | 10s | Always |
| PostgreSQL | 5432 | Oui | 10s | Always |
| PgBouncer | 6432 | Oui | 30s | Always |
| Config Manager | 8888 | HTTPS | 30s | Always |

---

## 🔐 Sécurité

### Mots de passe à changer EN PRODUCTION
```bash
POSTGRES_PASSWORD=change_me_in_production      # À changer
CONFIG_ADMIN_PASSWORD=admin                    # À changer
```

### HTTPS automatique
- Traefik gère le certificat SSL
- Tous les endpoints protégés
- Redirection HTTP → HTTPS

### Isolation réseau
- Services sur réseau interne `backend`
- Config Manager sur réseau Traefik + backend
- Accès externe uniquement via Traefik

---

## 📊 Monitoring

### Logs en temps réel
```bash
docker-compose logs -f config-manager
docker-compose logs -f ollama
docker-compose logs -f postgres
```

### Statut des services
```bash
docker-compose ps
docker stats
```

### Via Config Manager
```
https://config.bluevaloris.com
→ Indicateurs en haut avec état des 4 services
→ Refresh automatique toutes les 5 sec
```

---

## 🆘 Troubleshooting

### Config Manager ne se lance pas
```bash
docker-compose logs config-manager
# Vérifier les variables d'environnement dans .env
```

### Erreur de connexion à PostgreSQL
```bash
docker-compose exec pgbouncer psql -c "show pools"
docker-compose exec postgres psql -U ollama_user -d ollama_db -c "SELECT 1"
```

### Port déjà utilisé
```bash
lsof -i :8888
kill -9 <PID>
```

### Mot de passe oublié
```bash
# Modifier .env
CONFIG_ADMIN_PASSWORD=new_password

# Redémarrer
docker-compose restart config-manager
```

---

## 📚 Documentation

| Fichier | Contenu |
|---------|---------|
| [CONFIG-MANAGER.md](CONFIG-MANAGER.md) | Interface web, utilisation, sécurité |
| [VPS-DEPLOYMENT.md](VPS-DEPLOYMENT.md) | Déploiement sur VPS, checklist production |
| [API-USAGE.md](API-USAGE.md) | Exemples API Ollama |
| [DATABASE.md](DATABASE.md) | PostgreSQL, schéma, opérations |
| [DATABASE-CLI.md](DATABASE-CLI.md) | CLI db-manage.py |
| [ARCHITECTURE.md](ARCHITECTURE.md) | Architecture complète |
| [QUICK-CONFIG.md](QUICK-CONFIG.md) | Configuration rapide |

---

## ✅ Checklist post-déploiement

- [ ] Accéder à `https://config.bluevaloris.com`
- [ ] Créer une clé API
- [ ] Ajouter un domaine à la whitelist
- [ ] Tester l'API Ollama
- [ ] Vérifier les logs
- [ ] Configurer les backups (voir VPS-DEPLOYMENT.md)
- [ ] Mettre à jour les mots de passe
- [ ] Documenter les accès

---

## 🎉 Résultat

Un stack production-ready avec:
- ✅ Interface web pour configuration
- ✅ Gestion des clés API intégrée
- ✅ Monitoring centralisé
- ✅ Persistence des données
- ✅ HTTPS automatique
- ✅ Haute disponibilité
- ✅ Documentation complète
- ✅ Scripts d'automation

**Prêt pour un VPS! 🚀**
