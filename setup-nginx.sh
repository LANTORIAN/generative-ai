#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="${SCRIPT_DIR}/.env"
TEMPLATE_FILE="${SCRIPT_DIR}/nginx.conf"
NGINX_SITE_PATH="/etc/nginx/sites-available/ollama-stack.conf"
NGINX_ENABLED_PATH="/etc/nginx/sites-enabled/ollama-stack.conf"

if [[ ! -f "${ENV_FILE}" ]]; then
    echo "[ERROR] Missing ${ENV_FILE}. Create it from .env.example first."
    exit 1
fi

if [[ ! -f "${TEMPLATE_FILE}" ]]; then
    echo "[ERROR] Missing ${TEMPLATE_FILE}."
    exit 1
fi

if ! command -v nginx >/dev/null 2>&1; then
    echo "[ERROR] nginx is not installed. Install it first: sudo apt-get install -y nginx"
    exit 1
fi

load_env_file() {
    local env_file="$1"
    local line key value

    while IFS= read -r line || [[ -n "${line}" ]]; do
        line="$(printf '%s' "${line}" | tr -d '\r')"

        case "${line}" in
            ''|\#*)
                continue
                ;;
        esac

        key="${line%%=*}"
        value="${line#*=}"
        key="$(printf '%s' "${key}" | tr -d '[:space:]')"

        if [[ -n "${key}" ]]; then
            export "${key}=${value}"
        fi
    done < "${env_file}"
}

load_env_file "${ENV_FILE}"

if [[ -z "${PRODUCTION_DOMAIN:-}" ]]; then
    echo "[ERROR] PRODUCTION_DOMAIN is missing in .env"
    exit 1
fi

if [[ -z "${OLLAMA_DOMAIN:-}" ]]; then
    echo "[ERROR] OLLAMA_DOMAIN is missing in .env"
    exit 1
fi

CONFIG_DOMAIN="${CONFIG_DOMAIN:-config.${PRODUCTION_DOMAIN}}"
OLLAMA_HOST_PORT="${OLLAMA_HOST_PORT:-21434}"
CONFIG_MANAGER_HOST_PORT="${CONFIG_MANAGER_HOST_PORT:-18888}"

TLS_CERT_PATH="${TLS_CERT_PATH:-/etc/letsencrypt/live/${OLLAMA_DOMAIN}/fullchain.pem}"
TLS_KEY_PATH="${TLS_KEY_PATH:-/etc/letsencrypt/live/${OLLAMA_DOMAIN}/privkey.pem}"

if [[ ! -f "${TLS_CERT_PATH}" || ! -f "${TLS_KEY_PATH}" ]]; then
    echo "[ERROR] TLS cert/key not found:"
    echo "        cert: ${TLS_CERT_PATH}"
    echo "        key : ${TLS_KEY_PATH}"
    echo "        Issue cert first (or set TLS_CERT_PATH/TLS_KEY_PATH in .env)."
    exit 1
fi

TMP_CONF="$(mktemp)"

sed -e "s/OLLAMA_DOMAIN_PLACEHOLDER/${OLLAMA_DOMAIN}/g" \
    -e "s/CONFIG_DOMAIN_PLACEHOLDER/${CONFIG_DOMAIN}/g" \
    -e "s/OLLAMA_HOST_PORT_PLACEHOLDER/${OLLAMA_HOST_PORT}/g" \
    -e "s/CONFIG_HOST_PORT_PLACEHOLDER/${CONFIG_MANAGER_HOST_PORT}/g" \
    -e "s|TLS_CERT_PATH_PLACEHOLDER|${TLS_CERT_PATH}|g" \
    -e "s|TLS_KEY_PATH_PLACEHOLDER|${TLS_KEY_PATH}|g" \
    "${TEMPLATE_FILE}" > "${TMP_CONF}"

if [[ -f "${NGINX_SITE_PATH}" ]]; then
    sudo cp "${NGINX_SITE_PATH}" "${NGINX_SITE_PATH}.bak.$(date +%Y%m%d_%H%M%S)"
fi

sudo cp "${TMP_CONF}" "${NGINX_SITE_PATH}"
sudo ln -sf "${NGINX_SITE_PATH}" "${NGINX_ENABLED_PATH}"

rm -f "${TMP_CONF}"

sudo nginx -t
sudo systemctl reload nginx

echo "[OK] Nginx configured successfully"
echo "     - Ollama: https://${OLLAMA_DOMAIN} -> 127.0.0.1:${OLLAMA_HOST_PORT}"
echo "     - Config: https://${CONFIG_DOMAIN} -> 127.0.0.1:${CONFIG_MANAGER_HOST_PORT}"
