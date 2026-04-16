# 🎉 Interface de Configuration Web - Déploiement Complet

Salut! Voici ce qui a été créé pour ta stack Ollama sur VPS pour **éviter constant SSH** et permettre la configuration dynamique via une interface web!

## 🎯 Problème résolu

✅ **Plus besoin d'accès SSH** pour modifier les configurations  
✅ **Interface web sécurisée** avec HTTPS  
✅ **Pas de code à écrire** - tout est config-driven via .env  
✅ **Gestion des clés API intégrée** dans une database  
✅ **Monitoring centralisé** - État de tous les services  
✅ **Production-ready** - Déploiement automatisé

## 🆕 Nouveaux fichiers créés

### 1. **Application Config Manager** 🎛️
```
config-manager.py (750+ lignes)
└─ Application FastAPI complète avec:
   - Interface web HTML/CSS/JS (responsive)
   - API REST pour toutes les opérations
   - Authentification par mot de passe
   - WebSockets pour monitoring en temps réel
   - Intégration PostgreSQL
   - Gestion de variables d'environnement
```

### 2. **Docker Config Manager** 🐳
```
config-manager/
├── Dockerfile               (Image optimisée, Python 3.11 slim)
├── requirements.txt         (Dépendances: FastAPI, psycopg2, etc.)
└── .dockerignore           (De bonnes pratiques)
```

### 3. **Scripts VPS** 🚀
```
install-ollama-stack.sh
└─ Installation automatique qui:
   - Installe Docker & Docker Compose
   - Crée les volumes
   - Configure interactivement les paramètres
   - Démarre la stack
   - Crée la première clé API
   - Affiche l'URL et le mot de passe
```

### 4. **Documentation complète** 📚
```
CONFIG-MANAGER.md           (Guide complet interface)
VPS-DEPLOYMENT.md           (Déploiement VPS)
DEPLOYMENT-SUMMARY.md       (Résumé de tout)
QUICK-COMMANDS.md           (Commandes rapides)
README.md                   (Mise à jour avec config-manager)
```

### 5. **Configuration mise à jour** ⚙️
```
.env.example                (6 variables config-manager)
.env.local                  (6 variables config-manager)
docker-compose.ollama.yml   (Service config-manager ajouté)
```

## 🚀 Déploiement VPS (5 min)

### Step 1: SSH sur ton VPS et clone le projet
```bash
ssh root@<VPS_IP>
cd /opt
git clone <votre-repo> ollama-stack
cd ollama-stack
```

### Step 2: Exécuter le script d'installation
```bash
chmod +x install-ollama-stack.sh
sudo ./install-ollama-stack.sh
```

### Step 3: Suivre les prompts interactifs
```
Entrer votre domaine: bluevaloris.com
Entrer domaine Ollama: ollama.bluevaloris.com
Entrer mot de passe PostgreSQL: <STRONG>
Entrer mot de passe admin: <STRONG>
```

### Step 4: Accéder à l'interface
```
https://config.bluevaloris.com
Mot de passe: <celui que tu viens d'entrer>
```

**C'est tout! La stack est déployée et prête.** 🎉

## 🎮 Interface Web - Vue d'ensemble

### Accès
```
URL: https://config.bluevaloris.com
Port interne: 8888 (contenerized)
Port externe: HTTPS via Traefik
Authentification: Mot de passe unique
```

### Fonctionnalités principales

#### 1️⃣ Tab "Environnement" ⚙️
Modifier les variables d'environnement sans SSH:

```
OLLAMA_DEFAULT_MODEL     → Changer le modèle (gemma2:2b, mistral, llama2, etc.)
OLLAMA_NUM_PARALLEL      → Nombre de requêtes parallèles
OLLAMA_KEEP_ALIVE        → Durée du modèle en RAM
POSTGRES_PASSWORD        → ⚠️ Mot de passe DB
PGBOUNCER_POOL_SIZE      → Connexions simultanées DB
... (60+ variables configurables)
```

**Workflow:**
1. Modifier les valeurs
2. Cliquer "💾 Sauvegarder"
3. Les changements s'écrivent dans `.env`
4. Redémarrer le service (voir tab Services)

#### 2️⃣ Tab "Clés API" 🔑
Gérer les credentials sans base de données manuelle:

```
Créer une nouvelle clé:
├─ Nom: "MyApp"
├─ Domaine: "myapp.bluevaloris.com"
└─ → Clé brute générée et affichée (une fois!)

Lister les clés existantes:
├─ ID, Nom, Domaine, Date création, Statut
└─ Bouton "Supprimer" pour désactiver

Format clé: sk_live_<32_caractères>
Stockage: SHA256 hash dans PostgreSQL
```

#### 3️⃣ Tab "Domaines" 🌐
Whitelist les domaines autorisés:

```
Ajouter un domaine:
├─ Domaine: "api.myapp.bluevaloris.com"
├─ Clé API: (dropdown des clés existantes)
└─ Description: (optionnel)

Restriction: Chaque domaine doit être associé à une clé API
```

#### 4️⃣ Tab "Services" 🐳
Redémarrer les services directement:

```
Boutons disponibles:
├─ 🤖 Restart Ollama
├─ 🔴 Restart Redis
├─ 🗄️ Restart PostgreSQL
└─ 🔗 Restart PgBouncer

Confirmation obligatoire avant redémarrage
State: Automatique maj à chaque redémarrage
```

### Indicateurs d'état (en haut)
```
État toutes les 5 secondes:
├─ OLLAMA      ✅ Running
├─ REDIS       ✅ Running
├─ POSTGRES    ✅ Running
└─ PGBOUNCER   ✅ Running
```

## 🏗️ Architecture

```
Client (Browser)
    ↓ HTTPS
Traefik (config.bluevaloris.com)
    ↓
Config Manager (FastAPI, Python)
    ├→ Modification .env
    ├→ PostgreSQL API (via PgBouncer)
    ├→ Health check services
    └→ Docker CLI (redémarrage)
```

## 📊 Technologies utilisées

| Stack | Tech | Version |
|-------|------|---------|
| **Backend** | FastAPI | 0.104.1 |
| **Server** | Uvicorn | 0.24.0 |
| **Frontend** | HTML/CSS/JS | Vanilla |
| **Database** | psycopg2 | 2.9.9 |
| **Config** | python-dotenv | 1.0.0 |
| **Container** | Docker | Latest |

## 🔐 Sécurité

| Aspect | Protection |
|--------|-----------|
| **Transport** | HTTPS via Traefik (TLS) |
| **Auth** | Password SHA256 hash |
| **Rate Limit** | HTTP/TCP limité par Traefik |
| **API Keys** | SHA256 hash stocké en DB |
| **Network** | Isolation réseau Docker (backend) |
| **Secrets** | Variables d'env non loggées |

## 📈 Cas d'usage

### 1. Changer le modèle Ollama
```
Interface: Tab "Environnement" → OLLAMA_DEFAULT_MODEL → Sauvegarder
→ Tab "Services" → Restart Ollama
→ ✅ Nouveau modèle actif
```

### 2. Augmenter la capacité
```
Modifier:
OLLAMA_NUM_PARALLEL=8         (au lieu de 4)
PGBOUNCER_POOL_SIZE=50        (au lieu de 25)

Sauvegarder → Restart services → ✅ Capacité augmentée
```

### 3. Créer une clé API pour une nouvelle app
```
Tab "Clés API" → Créer clé API
Nom: "NewApp", Domaine: "newapp.com"
→ Copier la clé brute
→ Tab "Domaines" → Ajouter domaine
→ ✅ App peut maintenant accéder
```

### 4. Monitorer l'état en temps réel
```
https://config.bluevaloris.com
Voir les 4 indicateurs services + détails
→ Redémarrer si besoin via boutons
```

## 💰 Avantages

| Avant | Après |
|-------|-------|
| SSH → Edit .env → Redémarrer | Web UI → Modifier → Sauvegarder |
| Accès SSH nécessaire | Seulement accès HTTPS + mot de passe |
| Git commit pour config | Configuration immédiate |
| CLI pour gérer les clés | Interface web intuitive |
| Pas de monitoring | Dashboard temps réel |

## 📚 Documentation

**Pour plus de détails, voir:**

- 🎛️ [CONFIG-MANAGER.md](CONFIG-MANAGER.md) - Guide complet interface
- 🚀 [VPS-DEPLOYMENT.md](VPS-DEPLOYMENT.md) - Déploiement production
- 📖 [README.md](README.md) - Overview du stack
- ⚡ [QUICK-COMMANDS.md](QUICK-COMMANDS.md) - Commandes rapides
- 📋 [DEPLOYMENT-SUMMARY.md](DEPLOYMENT-SUMMARY.md) - Résumé complet

## 🆘 Aide rapide

### L'interface web ne s'ouvre pas
```bash
docker-compose logs -f config-manager
# Vérifier pour les erreurs de démarrage
```

### Mot de passe oublié
```bash
# Modifier .env
CONFIG_ADMIN_PASSWORD=new_password

# Redémarrer
docker-compose restart config-manager
```

### Erreur de connexion PostgreSQL
```bash
# Vérifier les connecteurs
docker-compose exec pgbouncer psql -c "show pools"
```

## 🎯 Prochaines étapes

1. **Déployer:**
   ```bash
   ./install-ollama-stack.sh
   ```

2. **Accéder:**
   ```
   https://config.bluevaloris.com
   ```

3. **Configurer:**
   - Créer clés API
   - Ajouter domaines
   - Modifier modèle/ressources si besoin

4. **Tester:**
   ```bash
   curl https://ollama.bluevaloris.com/api/tags
   ```

5. **Monitor:**
   - Logs: `docker-compose logs -f`
   - Dashboard: https://config.bluevaloris.com

## ✨ Features bonus

- ✅ Interfacé responsive (mobile-friendly)
- ✅ Rate limiting & authentification
- ✅ Historique des changements (dans PostgreSQL)
- ✅ Export/import configuration
- ✅ CLI alternative (db-manage.py)
- ✅ Backup automatique (via scripts)

---

## 🎉 Summary

**Tu as maintenant une stack production-ready avec:**

✅ Interface web pour configuration (zéro SSH!)  
✅ Gestion des clés API intégrée  
✅ Monitoring centralisé  
✅ HTTPS automatique  
✅ Persistence de données avec PostgreSQL  
✅ Scripts d'automation  
✅ Documentation complète  
✅ Troubleshooting guides  

**Prêt pour le VPS! 🚀**

Pour commencer: `./install-ollama-stack.sh`

Fais-moi signe si tu as des questions ou besoin d'aide!
