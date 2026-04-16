# 🚀 Guide de déploiement Ollama sur VPS

Guide complet pour déployer la stack Ollama + Config Manager sur un VPS (DigitalOcean, Linode, AWS EC2, etc.)

## 📋 Prérequis

### Système
- Ubuntu 20.04 LTS ou supérieur
- 8GB RAM minimum (16GB recommandé)
- 50GB disque libre (SSD)
- 2 vCPU minimum (4 vCPU recommandé)

### Logiciels
- Docker 20.10+
- Docker Compose v2 (`docker compose`)
- Git
- curl

## ⚡ Installation rapide (5 minutes)

### 1. Installer Docker et Docker Compose

```bash
# SSH sur le VPS en root
ssh root@<VPS_IP>

# Installer Docker
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Vérifier l'installation
docker --version
docker compose version
```

### 2. Cloner le projet

```bash
# Créer le répertoire
mkdir -p /opt/ollama-stack
cd /opt/ollama-stack

# Cloner le repository (ou copier les fichiers)
git clone <votre-repo> .
# OU
scp -r /path/local/generative-ai root@<VPS_IP>:/opt/ollama-stack
```

### 3. Configurer les volumes Docker

```bash
# Créer les volumes externes
docker volume create lantorian_genai_ollama_data
docker volume create lantorian_genai_redis_data
docker volume create lantorian_genai_postgres_data

# Vérifier
docker volume ls | grep lantorian_genai
```

### 4. Configurer les variables d'environnement

```bash
cd /opt/ollama-stack

# Copier le template
cp .env.example .env

# Éditer avec vos paramètres
nano .env
```

**Paramètres critiques à modifier:**

```bash
# Sécurité
POSTGRES_PASSWORD=<STRONG_PASSWORD_HERE>      # ⚠️ À CHANGER
CONFIG_ADMIN_PASSWORD=<ADMIN_PASSWORD_HERE>   # ⚠️ À CHANGER

# Domaine
PRODUCTION_DOMAIN=votre-domaine.com           # Ex: bluevaloris.com
OLLAMA_DOMAIN=ollama.votre-domaine.com        # Ex: ollama.bluevaloris.com
OLLAMA_HOST_PORT=21434
CONFIG_MANAGER_HOST_PORT=18888

# Ressources (adapter à votre VPS)
OLLAMA_CPU_LIMIT=3.5
OLLAMA_MEMORY_LIMIT=12G
OLLAMA_NUM_PARALLEL=4

# Modèle par défaut
OLLAMA_DEFAULT_MODEL=gemma2:2b
```

### 5. Configurer Traefik (si besoin)

```bash
# Si vous utilisez Coolify/Traefik, vérifier:
# 1. Le réseau traefik existe
docker network ls | grep coolify

# 2. Sinon, le créer
docker network create coolify

# 3. Vérifier dans docker-compose.ollama.yml
# - TRAEFIK_NETWORK=coolify
# - labels traefik.enabled=true
```

### 5.b Configurer Nginx avec les domaines (sans Traefik)

Option rapide (script inclus):

```bash
chmod +x setup-nginx.sh
./setup-nginx.sh
```

Option manuelle:

```bash
sudo apt-get update && sudo apt-get install -y nginx

cd /opt/ollama-stack
CONFIG_DOMAIN="config.${PRODUCTION_DOMAIN}"

sudo sed -e "s/OLLAMA_DOMAIN_PLACEHOLDER/${OLLAMA_DOMAIN}/g" \
         -e "s/CONFIG_DOMAIN_PLACEHOLDER/${CONFIG_DOMAIN}/g" \
         -e "s/OLLAMA_HOST_PORT_PLACEHOLDER/${OLLAMA_HOST_PORT}/g" \
         -e "s/CONFIG_HOST_PORT_PLACEHOLDER/${CONFIG_MANAGER_HOST_PORT}/g" \
         -e "s|TLS_CERT_PATH_PLACEHOLDER|/etc/letsencrypt/live/${OLLAMA_DOMAIN}/fullchain.pem|g" \
         -e "s|TLS_KEY_PATH_PLACEHOLDER|/etc/letsencrypt/live/${OLLAMA_DOMAIN}/privkey.pem|g" \
         nginx.conf | sudo tee /etc/nginx/sites-available/ollama-stack.conf >/dev/null

sudo ln -sf /etc/nginx/sites-available/ollama-stack.conf /etc/nginx/sites-enabled/ollama-stack.conf
sudo nginx -t
sudo systemctl reload nginx
```

Notes:
- `ollama.<domaine>` est proxifie vers `127.0.0.1:${OLLAMA_HOST_PORT:-21434}`
- `config.<domaine>` est proxifie vers `127.0.0.1:${CONFIG_MANAGER_HOST_PORT:-18888}`
- Le certificat doit couvrir les 2 domaines (SAN) ou adaptez en 2 fichiers Nginx.

### 6. Lancer le stack

```bash
# Démarrer tous les services
docker compose -f docker-compose.ollama.yml up -d

# Vérifier l'état
docker compose -f docker-compose.ollama.yml ps

# Voir les logs
docker compose -f docker-compose.ollama.yml logs -f ollama
```

**Temps de démarrage:**
- Redis: 5-10 secondes ✅
- PostgreSQL: 15-30 secondes ✅
- PgBouncer: 10-20 secondes ✅
- Ollama: 30-60 secondes (téléchargement modèle) ⏳
- Config Manager: 5-10 secondes ✅

### 7. Tester le déploiement

```bash
# Test Ollama
curl http://localhost:21434/api/tags

# Test PostgreSQL
docker compose -f docker-compose.ollama.yml exec pgbouncer \
  psql -U ollama_user -d ollama_db -c "SELECT * FROM ollama.api_keys LIMIT 1;"

# Test Config Manager
curl http://localhost:18888/api/status

# Tous les tests
./test-stack.sh
```

### 8. Accéder au Config Manager

```
URL: https://config.votre-domaine.com
Mot de passe: <CONFIG_ADMIN_PASSWORD>
```

## 🔧 Configuration post-déploiement

### Créer la première clé API

```bash
# Option 1: Via CLI
python db-manage.py key create --name "App1" --domain "app1.votre-domaine.com"

# Option 2: Via Web UI
1. Accéder à https://config.votre-domaine.com
2. Tab "Clés API"
3. Remplir Nom et Domaine
4. Cliquer "Créer une clé API"
5. Copier la clé brute (affichée une fois seulement)
```

### Ajouter un domaine à la whitelist

```bash
# Via Web UI
1. Tab "Domaines"
2. Entrer: api.app1.votre-domaine.com
3. Sélectionner la clé API
4. Cliquer "Ajouter un domaine"
```

### Modifier la configuration

```bash
# Via Web UI (recommandé)
1. https://config.votre-domaine.com
2. Tab "Environnement"
3. Modifier les valeurs
4. Cliquer "Sauvegarder"
5. Tab "Services" → Restart du service concerné

# OU Manuellement
1. nano .env
2. Modifier les valeurs
3. docker compose -f docker-compose.ollama.yml restart ollama
```

## 📊 Monitoring

### Logs en temps réel

```bash
# Ollama
docker compose -f docker-compose.ollama.yml logs -f ollama

# Config Manager
docker compose -f docker-compose.ollama.yml logs -f config-manager

# Tous les services
docker compose -f docker-compose.ollama.yml logs -f
```

### Statut des services

```bash
# Via Web UI
https://config.votre-domaine.com → Voir les indicateurs en haut

# Via CLI
docker compose -f docker-compose.ollama.yml ps

# Détails
docker stats
```

### Utilisation disque

```bash
# Vérifier l'espace utilisé
df -h

# Taille des volumes Docker
docker volume ls --format "table {{.Name}}\t{{.Mountpoint}}"
du -sh /var/lib/docker/volumes/lantorian_genai_*

# Nettoyer les images inutilisées
docker image prune -a
```

## 🔐 Production Security Checklist

- [ ] Changer `POSTGRES_PASSWORD`
- [ ] Changer `CONFIG_ADMIN_PASSWORD`
- [ ] Configurer HTTPS via Traefik (TLS=true)
- [ ] Configurer les backups journaliers de PostgreSQL
- [ ] Configurer les logs centralisés
- [ ] Mettre en place un monitoring (Prometheus, ELK, etc.)
- [ ] Activer les pare-feu (UFW, Security Groups)
- [ ] Configurer SSH keys (pas de mot de passe)
- [ ] Mettre à jour les OS régulièrement
- [ ] Mettre en place une politique de rotation des clés API
- [ ] Ajouter une IP whitelist sur Config Manager (optionnel)

## 🆘 Dépannage courant

### Erreur: "Couldn't connect to Docker daemon"

```bash
# Docker n'est pas actif
sudo systemctl start docker
sudo systemctl enable docker

# Ou ajouter l'utilisateur au groupe docker
sudo usermod -aG docker $USER
newgrp docker
```

### Erreur: "port X is already allocated"

```bash
# Vérifier quel service utilise le port
lsof -i :11434

# Arrêter le service
docker compose -f docker-compose.ollama.yml stop

# Ou changer le port dans .env
OLLAMA_HOST_PORT=11435  # Nouveau port
```

### Postgres n'arrive pas à démarrer

```bash
# Vérifier les logs
docker compose -f docker-compose.ollama.yml logs postgres

# Supprimer le volume et recommencer
docker volume rm lantorian_genai_postgres_data
docker compose -f docker-compose.ollama.yml up -d postgres
```

### Config Manager ne se connecte pas à la DB

```bash
# Test de connectivité
docker compose -f docker-compose.ollama.yml exec pgbouncer \
  psql -h pgbouncer -U ollama_user -d ollama_db -c "SELECT 1"

# Vérifier les variables d'environnement
docker compose -f docker-compose.ollama.yml exec config-manager env | grep PGBOUNCER
docker compose -f docker-compose.ollama.yml exec config-manager env | grep POSTGRES
```

### Ollama n'arrive pas à charger le modèle

```bash
# Vérifier l'espace disque
df -h /var/lib/docker/volumes/lantorian_genai_ollama_data

# Voir les logs Ollama
docker compose -f docker-compose.ollama.yml logs -f ollama | tail -100

# Télécharger le modèle manuellement
docker compose -f docker-compose.ollama.yml exec ollama ollama pull gemma2:2b
```

## 📈 Performance & Scaling

### Augmenter les ressources

```bash
# Modifier .env
OLLAMA_CPU_LIMIT=4.0           # Plus de CPU
OLLAMA_MEMORY_LIMIT=16G        # Plus de RAM
OLLAMA_NUM_PARALLEL=8          # Plus de parallélisme
PGBOUNCER_DEFAULT_POOL_SIZE=50 # Plus de connexions

# Appliquer les changements
docker compose -f docker-compose.ollama.yml up -d --force-recreate ollama
docker compose -f docker-compose.ollama.yml restart pgbouncer
```

### Monitorer les performances

```bash
# CPU et mémoire en temps réel
docker stats

# Connexions PostgreSQL
docker compose -f docker-compose.ollama.yml exec pgbouncer \
  psql -U postgres -d pgbouncer -c "SHOW pools"

# Statistiques Redis
docker compose -f docker-compose.ollama.yml exec redis \
  redis-cli INFO stats
```

## 🔄 Backups & Recovery

### Backup automatique PostgreSQL

```bash
# Script backup
cat > /usr/local/bin/backup-ollama-db.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR=/backups/ollama
mkdir -p $BACKUP_DIR

docker compose -f /opt/ollama-stack/docker-compose.ollama.yml exec -T postgres \
  pg_dump -U ollama_user ollama_db | gzip > $BACKUP_DIR/ollama_db_$DATE.sql.gz

# Garder seulement les 7 derniers backups
find $BACKUP_DIR -type f -name "*.sql.gz" -mtime +7 -delete

echo "Backup completed: $BACKUP_DIR/ollama_db_$DATE.sql.gz"
EOF

chmod +x /usr/local/bin/backup-ollama-db.sh

# Ajouter à crontab (quotidien à 2h du matin)
(crontab -l 2>/dev/null; echo "0 2 * * * /usr/local/bin/backup-ollama-db.sh") | crontab -
```

### Restore à partir d'un backup

```bash
# Décompresser
gunzip backup_file.sql.gz

# Importer dans PostgreSQL
docker compose -f docker-compose.ollama.yml exec -T postgres \
  psql -U ollama_user ollama_db < backup_file.sql
```

## 📚 Fichiers importants

| Fichier | Purpose |
|---------|---------|
| `docker-compose.ollama.yml` | Configuration services |
| `.env` | Variables d'environnement |
| `config-manager.py` | Interface web |
| `init-db.sql` | Schéma PostgreSQL |
| `pgbouncer.ini` | Configuration pool |
| `db-manage.py` | CLI gestion DB |
| `deploy.sh` | Script déploiement |
| `test-stack.sh` | Tests validation |

## 🔗 Documentation complète

- [CONFIG-MANAGER.md](CONFIG-MANAGER.md) - Interface web
- [API-USAGE.md](API-USAGE.md) - API Ollama
- [DATABASE.md](DATABASE.md) - PostgreSQL
- [DATABASE-CLI.md](DATABASE-CLI.md) - CLI tools
- [ARCHITECTURE.md](ARCHITECTURE.md) - Architecture complète

## 📞 Support

Pour les problèmes:

1. Vérifier les logs: `docker compose logs -f`
2. Consulter DATABASE.md et DEPLOYMENT-GUIDE.md
3. Exécuter les tests: `./test-stack.sh`
4. Vérifier l'état: https://config.votre-domaine.com

## ✅ Résumé déploiement

```bash
# 1. SSH sur VPS
ssh root@<IP>

# 2. Installer Docker
curl -fsSL https://get.docker.com | sh

# 3. Télécharger les fichiers
cd /opt && git clone <repo>

# 4. Créer les volumes
docker volume create lantorian_genai_{ollama,redis,postgres}_data

# 5. Configurer .env
cd ollama-stack && nano .env

# 6. Lancer
docker compose -f docker-compose.ollama.yml up -d

# 7. Accéder à l'interface
https://config.votre-domaine.com
```

**Deployment success! 🎉**
