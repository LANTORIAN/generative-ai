# 🗄️ Database Management - Quick Guide

Gérer facilement les clés API, domaines, et statistiques avec le CLI `db-manage.py`.

---

## 🛠️ Installation des dépendances

```bash
# Python 3.7+
pip install psycopg2-binary

# Ou via conda
conda install -c conda-forge psycopg2
```

---

## 📋 Commandes disponibles

### Info générale

```bash
python db-manage.py info

# Affiche:
# - Nombre de clés API actives
# - Domaines whitelistés
# - Modèles configurés
# - Connection pools
# - Statistiques d'utilisation
```

### 🔐 Gestion des clés API

#### Créer une nouvelle clé

```bash
python db-manage.py key create \
  --name "My App" \
  --domain "myapp.bluevaloris.com" \
  --min-rate 100 \
  --hour-rate 5000 \
  --day-rate 50000
```

**Output:**
```
✅ API Key created successfully
   ID: 1
   Name: My App
   Domain: myapp.bluevaloris.com
   Raw Key (save this!): <long_secure_key_here>
   Hash: <hash_value>
   Created: 2024-04-16 12:34:56
```

⚠️ **Important**: Sauvegarder la clé brute (Raw Key) - elle ne sera pas visible après!

#### Lister les clés actives

```bash
python db-manage.py key list

# Affiche toutes les clés API actives avec:
# - ID
# - Nom
# - Domaine
# - Limites de taux
```

#### Désactiver une clé

```bash
python db-manage.py key delete <KEY_ID>
```

---

### 🌐 Gestion des domaines

#### Ajouter un domaine à la whitelist

```bash
python db-manage.py domain add \
  --domain "api.myapp.bluevaloris.com" \
  --key-id 1 \
  --desc "Production API endpoint"
```

#### Lister les domaines whitelistés

```bash
python db-manage.py domain list

# Affiche:
# - Domaine
# - ID de la clé API associée
# - Date de création
```

---

### 📊 Statistiques d'utilisation

#### Voir les statistiques d'utilisation

```bash
python db-manage.py usage show --days 7

# Affiche par jour/endpoint/modèle:
# - Nombre de requêtes
# - Temps moyen de réponse
# - Tokens utilisés
```

#### Voir l'utilisation par modèle

```bash
python db-manage.py usage models --days 7

# Affiche:
# - Modèle utilisé
# - Nombre de requêtes
# - Temps moyen
# - Tokens totaux
```

---

### 🤖 Gestion des modèles

#### Lister les modèles configurés

```bash
python db-manage.py model list

# Affiche:
# - Nom du modèle
# - Description
# - Statut (Actif/Inactif)
```

---

## 💡 Workflow complet

### 1. Setup initial

```bash
# Vérifier la base de données
python db-manage.py info

# Affiche les tables créées
```

### 2. Créer des clés API pour les clients

```bash
# Client 1
python db-manage.py key create \
  --name "Client A" \
  --domain "clienta.bluevaloris.com"

# Client 2
python db-manage.py key create \
  --name "Client B" \
  --domain "clientb.bluevaloris.com" \
  --min-rate 50 \
  --hour-rate 2000
```

### 3. Ajouter des domaines supplémentaires

```bash
# Pour Client A
python db-manage.py domain add \
  --domain "api.clienta.bluevaloris.com" \
  --key-id 1

python db-manage.py domain add \
  --domain "backup-api.clienta.bluevaloris.com" \
  --key-id 1
```

### 4. Consulter les performances

```bash
# Aujourd'hui
python db-manage.py usage show

# Derniers 7 jours par modèle
python db-manage.py usage models --days 7
```

### 5. Monitoring

```bash
# Vérifier régulièrement
python db-manage.py info

# Si problème détecté, analyser l'utilisation
python db-manage.py usage show --days 1
```

---

## 🔌 Connexion personnalisée

### Paramètres par défaut

Le script utilise automatiquement:
- `PGBOUNCER_HOST` = localhost
- `PGBOUNCER_PORT` = 6432 (via PgBouncer)
- `POSTGRES_USER` = ollama_user
- `POSTGRES_DB` = ollama_db

### Surcharger les paramètres

Via les variables d'environnement:

```bash
export PGBOUNCER_HOST=prod-db.example.com
export PGBOUNCER_PORT=5432
export POSTGRES_PASSWORD=my_secure_password

python db-manage.py info
```

Ou lors de la connexion directe à PostgreSQL (pas via pool):

```bash
# Éditer le script pour utiliser:
# - POSTGRES_HOST au lieu de PGBOUNCER_HOST
# - POSTGRES_PORT au lieu de PGBOUNCER_PORT
```

---

## 🔐 Sécurité

### Bonnes pratiques

1. **Clés API**
   - Les clés brutes ne s'affichent qu'une seule fois
   - Stockées en hash SHA256 en base
   - Ne jamais committer les clés dans Git

2. **Domaines**
   - Un domaine peut avoir plusieurs clés API
   - Chaque clé peut avoir plusieurs domaines
   - Validation de domaine côté Traefik

3. **Audit**
   - Toutes les actions sont loggées dans `audit.access_log`
   - Erreurs d'accès dans `ollama.error_log`
   - Chaque requête API enregistrée

### Vérifier l'audit

```bash
# Directe (bypass le pool)
psql -h localhost -p 5432 -U ollama_user -d ollama_db -c \
  "SELECT action, status, ip_address, created_at FROM audit.access_log ORDER BY created_at DESC LIMIT 20;"
```

---

## ⚙️ Configuration avancée

### Rate Limiting

Rate limits configurables par clé:

```bash
python db-manage.py key create \
  --name "Heavy User" \
  --domain "heavy.bluevaloris.com" \
  --min-rate 1000 \
  --hour-rate 100000 \
  --day-rate 1000000
```

### Batch operations

Créer plusieurs clés:

```bash
for i in {1..10}; do
  python db-manage.py key create \
    --name "Client $i" \
    --domain "client$i.bluevaloris.com"
done
```

### Export data

Exporter les statistiques:

```bash
# Via SQL direct
psql -c "COPY (SELECT * FROM ollama.v_usage_stats WHERE usage_date = CURRENT_DATE) TO STDOUT WITH CSV HEADER;" > usage_today.csv

# Via Python (ajouter dans le script)
import csv
cursor = db.execute("SELECT * FROM ollama.v_usage_stats")
with open('export.csv', 'w') as f:
    writer = csv.DictWriter(f, fieldnames=[desc[0] for desc in cursor.description])
    writer.writeheader()
    writer.writerows(cursor.fetchall())
```

---

## 🐛 Troubleshooting

### Connection refused

```bash
# Vérifier que PgBouncer démarre
docker ps | grep pgbouncer

# Lancer manuellement pour debug
docker exec generative-pgbouncer-prod psql -h localhost -p 6432 -U ollama_user -d ollama_db
```

### Too many connections

```bash
# Augmenter le pool size dans .env
PGBOUNCER_DEFAULT_POOL_SIZE=40

# Redémarrer
docker-compose restart pgbouncer
```

### Module psycopg2 not found

```bash
pip install psycopg2-binary

# Ou pour macOS avec M1/M2
pip install psycopg2-binary --no-binary psycopg2-binary
```

---

## 📚 Resources

- **DATABASE.md** - Documentation complète PostgreSQL
- **DEPLOYMENT-GUIDE.md** - Déploiement
- [psycopg2 docs](https://www.psycopg.org/)
- [PostgreSQL docs](https://www.postgresql.org/docs/)

---

**Database Management CLI Ready** ✅
