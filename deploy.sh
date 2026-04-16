#!/bin/bash

# Script de déploiement Ollama avec Redis + PostgreSQL + PgBouncer
# Configuration entièrement dynamique via .env
# Assurez-vous d'avoir créé les volumes externes d'abord

set -e

echo "🚀 Déploiement Ollama Stack (Ollama + Redis + PostgreSQL + PgBouncer)..."

load_env_file() {
    env_file="$1"

    while IFS= read -r line || [ -n "$line" ]; do
        line="$(printf '%s' "$line" | tr -d '\r')"

        case "$line" in
            ''|\#*)
                continue
                ;;
        esac

        key="${line%%=*}"
        value="${line#*=}"
        key="$(printf '%s' "$key" | tr -d '[:space:]')"

        if [ -n "$key" ]; then
            export "$key=$value"
        fi
    done < "$env_file"
}

# Vérifier si les volumes existent, sinon les créer
echo "📦 Création des volumes persistants..."

docker volume inspect lantorian_genai_ollama_data >/dev/null 2>&1 || {
    echo "  ✓ Création du volume lantorian_genai_ollama_data..."
    docker volume create lantorian_genai_ollama_data
}

docker volume inspect lantorian_genai_redis_data >/dev/null 2>&1 || {
    echo "  ✓ Création du volume lantorian_genai_redis_data..."
    docker volume create lantorian_genai_redis_data
}

docker volume inspect lantorian_genai_postgres_data >/dev/null 2>&1 || {
    echo "  ✓ Création du volume lantorian_genai_postgres_data..."
    docker volume create lantorian_genai_postgres_data
}

# Charger les variables d'environnement
if [ -f .env ]; then
    echo "📋 Fichier .env trouvé, utilisation des variables..."
    load_env_file .env
else
    echo "⚠️  Fichier .env non trouvé, utilisation des valeurs par défaut"
    cp .env.example .env
    load_env_file .env
fi

echo ""
echo "📊 Configuration active:"
echo "  ├─ Modèle Ollama: ${OLLAMA_DEFAULT_MODEL:-gemma2:2b}"
echo "  ├─ Performance: ${OLLAMA_NUM_PARALLEL:-4} parallèle, ${OLLAMA_NUM_THREAD:-4} threads"
echo "  ├─ Domaine: ${OLLAMA_DOMAIN:-ollama.bluevaloris.com}"
echo "  ├─ Warmer: toutes les ${WARMER_INTERVAL:-300}s"
echo "  ├─ PostgreSQL: ${POSTGRES_HOST:-postgres}:${POSTGRES_PORT:-5432}"
echo "  ├─ PgBouncer Pool: ${PGBOUNCER_DEFAULT_POOL_SIZE:-25} (${PGBOUNCER_POOL_MODE:-transaction} mode)"
echo "  └─ DB: ${POSTGRES_DB:-ollama_db} (user: ${POSTGRES_USER:-ollama_user})"
echo ""

# ⚠️ Avertissement de sécurité
if [ "${POSTGRES_PASSWORD}" = "change_me_in_production" ]; then
    echo "⚠️  ATTENTION: Mot de passe PostgreSQL par défaut détecté!"
    echo "   En production, éditer .env et changer POSTGRES_PASSWORD"
    echo ""
fi

# Démarrer les services
echo "🐳 Démarrage des services Docker..."
docker compose -f docker-compose.ollama.yml up -d

# Attendre que PostgreSQL soit prêt
echo "⏳ Attente du démarrage de PostgreSQL et PgBouncer..."
sleep 10

# Attendre que Ollama soit prêt
echo "⏳ Attente du démarrage d'Ollama... (60 secondes)"
sleep 60

# Vérifier la santé des services
echo "🏥 Vérification de l'état des services..."
docker compose -f docker-compose.ollama.yml ps

# Télécharger le modèle par défaut
echo "📥 Téléchargement du modèle ${OLLAMA_DEFAULT_MODEL:-gemma2:2b}..."
docker exec generative-ollama-prod ollama pull ${OLLAMA_DEFAULT_MODEL:-gemma2:2b}

# Tester Ollama
echo "🔌 Test de la connexion à Ollama..."
if docker exec generative-ollama-prod ollama list >/dev/null 2>&1; then
    echo "✅ Ollama est opérationnel"
    docker exec generative-ollama-prod ollama list | grep -q "${OLLAMA_DEFAULT_MODEL:-gemma2:2b}" && echo "✅ Modèle ${OLLAMA_DEFAULT_MODEL:-gemma2:2b} est présent"
else
    echo "❌ Impossible de se connecter à Ollama"
    exit 1
fi

# Tester Redis
echo "🔴 Test de la connexion à Redis..."
if docker exec generative-redis-prod redis-cli -p ${REDIS_INTERNAL_PORT:-16379} ping; then
    echo "✅ Redis est opérationnel"
else
    echo "❌ Impossible de se connecter à Redis"
    exit 1
fi

# Tester PostgreSQL
echo "🗄️ Test de la connexion à PostgreSQL..."
if docker exec generative-postgres-prod psql -p ${POSTGRES_INTERNAL_PORT:-15432} -U ${POSTGRES_USER:-ollama_user} -d ${POSTGRES_DB:-ollama_db} -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ PostgreSQL est opérationnel"
    echo "✅ Base de données ${POSTGRES_DB:-ollama_db} créée avec schémas"
else
    echo "❌ Impossible de se connecter à PostgreSQL"
    exit 1
fi

# Tester PgBouncer
echo "🔗 Test de la connexion à PgBouncer (pool)..."
if docker exec generative-pgbouncer-prod psql -h localhost -p ${PGBOUNCER_INTERNAL_PORT:-16432} -U ${POSTGRES_USER:-ollama_user} -d ${POSTGRES_DB:-ollama_db} -c "SELECT 1;" >/dev/null 2>&1; then
    echo "✅ PgBouncer est opérationnel (connection pooling actif)"
else
    echo "❌ Impossible de se connecter à PgBouncer"
    exit 1
fi

echo ""
echo "✨ Déploiement terminé avec succès!"
echo ""
echo "📚 Documentation & URLs:"
echo "  - Ollama API: https://${OLLAMA_DOMAIN:-ollama.bluevaloris.com}"
echo "  - Redis: ${REDIS_HOST:-redis}:${REDIS_INTERNAL_PORT:-16379} (interne)"
echo "  - PostgreSQL direct: localhost:${POSTGRES_HOST_PORT:-25432}"
echo "  - PostgreSQL pool: localhost:${PGBOUNCER_HOST_PORT:-26432} (recommandé)"
echo ""
echo "📖 Documentation:"
echo "  - Configuration dynamique: QUICK-CONFIG.md"
echo "  - Configuration modèles: DYNAMIC-CONFIG.md"
echo "  - Guide API: API-USAGE.md"
echo "  - Base de données: DATABASE.md"
echo "  - Déploiement: DEPLOYMENT-GUIDE.md"
echo ""
echo "🔐 Connexion à la base de données:"
echo "  - psql -h localhost -p ${PGBOUNCER_HOST_PORT:-26432} -U ${POSTGRES_USER:-ollama_user} -d ${POSTGRES_DB:-ollama_db}"
echo "  - Ou via Docker: docker exec -it generative-pgbouncer-prod psql -h localhost -p ${PGBOUNCER_INTERNAL_PORT:-16432}"
echo ""
echo "💡 Commandes utiles:"
echo "  - Voir logs: docker compose logs -f"
echo "  - Voir santé: ./test-stack.sh"
echo "  - Redémarrer: docker compose restart"
echo "  - Arrêter: docker compose down"
