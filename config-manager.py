#!/usr/bin/env python3
"""
Ollama Configuration Management Web Interface
API + Web UI pour gérer les configurations dynamiques en production
"""

from fastapi import (
    FastAPI,
    HTTPException,
    Depends,
    Request,
    HTTPException as FastHTTPException,
)
from fastapi.responses import HTMLResponse, FileResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from pathlib import Path
import os
import json
from typing import Optional, List, Dict, Any
import subprocess
from datetime import datetime
import hashlib
import secrets
import psycopg2
from psycopg2.extras import RealDictCursor
from dotenv import load_dotenv, dotenv_values, set_key
import logging

# Configuration
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI(title="Ollama Config Manager", version="1.0.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configuration
ENV_FILE = ".env"
ADMIN_PASSWORD_HASH = os.getenv("CONFIG_ADMIN_PASSWORD", "admin")

# ===== Models =====


class EnvVariable(BaseModel):
    key: str
    value: str
    description: Optional[str] = None


class EnvUpdate(BaseModel):
    variables: Dict[str, str]


class APIKeyCreate(BaseModel):
    name: str
    domain: str
    rate_limit_min: int = 100
    rate_limit_hour: int = 5000
    rate_limit_day: int = 50000


class APIKeyResponse(BaseModel):
    id: int
    name: str
    domain: str
    created_at: str
    is_active: bool


class DomainCreate(BaseModel):
    domain: str
    api_key_id: int
    description: Optional[str] = None


class LoginRequest(BaseModel):
    password: str


# ===== Database =====


class Database:
    def __init__(self):
        self.host = os.getenv("PGBOUNCER_HOST", "localhost")
        self.port = os.getenv("PGBOUNCER_PORT", 16432)
        self.user = os.getenv("POSTGRES_USER", "ollama_user")
        self.password = os.getenv("POSTGRES_PASSWORD", "change_me_in_production")
        self.dbname = os.getenv("POSTGRES_DB", "ollama_db")
        self.conn = None

    def connect(self):
        try:
            self.conn = psycopg2.connect(
                host=self.host,
                port=self.port,
                user=self.user,
                password=self.password,
                database=self.dbname,
            )
        except psycopg2.Error as e:
            logger.error(f"Database connection failed: {e}")

    def execute(self, query, params=None):
        if not self.conn:
            self.connect()
        cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        try:
            cursor.execute(query, params)
            self.conn.commit()
            return cursor
        except psycopg2.Error as e:
            self.conn.rollback()
            raise e

    def close(self):
        if self.conn:
            self.conn.close()


db = Database()

# ===== Authentication =====


def verify_password(password: str) -> bool:
    """Verify admin password"""
    password_hash = hashlib.sha256(password.encode()).hexdigest()
    admin_hash = hashlib.sha256(ADMIN_PASSWORD_HASH.encode()).hexdigest()
    return password_hash == admin_hash


# ===== Environment Management =====


def get_env_vars() -> Dict[str, str]:
    """Load environment variables from .env"""
    if os.path.exists(ENV_FILE):
        return dotenv_values(ENV_FILE)
    return {}


def set_env_var(key: str, value: str) -> None:
    """Set environment variable in .env file"""
    if not os.path.exists(ENV_FILE):
        open(ENV_FILE, "a").close()
    set_key(ENV_FILE, key, value)


def get_env_description(key: str) -> str:
    """Get description for environment variable"""
    descriptions = {
        "OLLAMA_DEFAULT_MODEL": "Modèle Ollama par défaut (gemma2:2b, llama2, mistral, etc.)",
        "OLLAMA_NUM_PARALLEL": "Nombre de requêtes parallèles (1-16)",
        "OLLAMA_NUM_THREAD": "Nombre de threads CPU (1-16)",
        "OLLAMA_KEEP_ALIVE": "Durée de maintien du modèle en RAM (60m, 120m, etc.)",
        "REDIS_MAX_MEMORY": "Mémoire max Redis (1gb, 2gb, etc.)",
        "POSTGRES_PASSWORD": "⚠️ Mot de passe PostgreSQL - À CHANGER EN PRODUCTION",
        "PGBOUNCER_DEFAULT_POOL_SIZE": "Taille du pool de connexions (10-50)",
        "WARMER_INTERVAL": "Intervalle de ping warm-up en secondes (300 = 5min)",
        "OLLAMA_DOMAIN": "Domaine Ollama (ex: ollama.bluevaloris.com)",
        "PRODUCTION_DOMAIN": "Domaine de restriction (ex: bluevaloris.com)",
    }
    return descriptions.get(key, "")


# ===== Routes =====


@app.get("/", response_class=HTMLResponse)
async def serve_dashboard():
    """Serve main dashboard UI"""
    return get_dashboard_html()


@app.post("/api/auth/login")
async def login(request: LoginRequest):
    """Login endpoint"""
    if verify_password(request.password):
        token = secrets.token_urlsafe(32)
        return {"token": token, "message": "Login successful"}
    raise HTTPException(status_code=401, detail="Invalid password")


@app.get("/api/env")
async def get_env():
    """Get all environment variables"""
    env_vars = get_env_vars()
    result = []
    for key, value in env_vars.items():
        result.append(
            {"key": key, "value": value, "description": get_env_description(key)}
        )
    return result


@app.post("/api/env/{key}")
async def update_env(key: str, request: EnvVariable):
    """Update environment variable"""
    set_env_var(key, request.value)
    return {"status": "success", "key": key, "value": request.value}


@app.post("/api/env/bulk-update")
async def bulk_update_env(request: EnvUpdate):
    """Update multiple environment variables"""
    for key, value in request.variables.items():
        set_env_var(key, value)
    return {"status": "success", "updated": len(request.variables)}


# API Keys Management
@app.get("/api/keys")
async def list_api_keys():
    """List all API keys"""
    try:
        cursor = db.execute(
            "SELECT id, name, domain, created_at, is_active FROM ollama.api_keys"
        )
        keys = cursor.fetchall()
        return keys if keys else []
    except Exception as e:
        logger.error(f"Error listing API keys: {e}")
        return []


@app.post("/api/keys")
async def create_api_key(request: APIKeyCreate):
    """Create new API key"""
    try:
        raw_key = secrets.token_urlsafe(32)
        key_hash = hashlib.sha256(raw_key.encode()).hexdigest()

        query = """
        INSERT INTO ollama.api_keys (key_hash, name, domain, rate_limit_per_minute,
                                    rate_limit_per_hour, rate_limit_per_day, created_by)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING id, created_at
        """

        cursor = db.execute(
            query,
            (
                key_hash,
                request.name,
                request.domain,
                request.rate_limit_min,
                request.rate_limit_hour,
                request.rate_limit_day,
                "web-ui",
            ),
        )
        result = cursor.fetchone()

        return {
            "status": "success",
            "id": result["id"],
            "name": request.name,
            "raw_key": raw_key,
            "message": "⚠️ Sauvegarder cette clé, elle ne s'affichera plus!",
        }
    except Exception as e:
        logger.error(f"Error creating API key: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.delete("/api/keys/{key_id}")
async def delete_api_key(key_id: int):
    """Deactivate API key"""
    try:
        db.execute(
            "UPDATE ollama.api_keys SET is_active = false WHERE id = %s", (key_id,)
        )
        return {"status": "success", "message": "API key deactivated"}
    except Exception as e:
        logger.error(f"Error deleting API key: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# Domains Management
@app.get("/api/domains")
async def list_domains():
    """List whitelisted domains"""
    try:
        cursor = db.execute("SELECT * FROM ollama.v_domain_mappings")
        domains = cursor.fetchall()
        return domains if domains else []
    except Exception as e:
        logger.error(f"Error listing domains: {e}")
        return []


@app.post("/api/domains")
async def add_domain(request: DomainCreate):
    """Add domain to whitelist"""
    try:
        query = """
        INSERT INTO ollama.domain_whitelist (domain, api_key_id, description)
        VALUES (%s, %s, %s)
        RETURNING id, created_at
        """
        cursor = db.execute(
            query, (request.domain, request.api_key_id, request.description)
        )
        result = cursor.fetchone()

        return {
            "status": "success",
            "domain": request.domain,
            "created_at": str(result["created_at"]),
        }
    except Exception as e:
        logger.error(f"Error adding domain: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@app.get("/api/status")
async def get_status():
    """Get system status"""
    status = {
        "ollama": "checking...",
        "redis": "checking...",
        "postgres": "checking...",
        "pgbouncer": "checking...",
        "timestamp": datetime.now().isoformat(),
    }

    # Check Ollama
    try:
        import requests

        ollama_url = os.getenv("OLLAMA_STATUS_URL", "http://ollama:21434/api/tags")
        resp = requests.get(ollama_url, timeout=2)
        status["ollama"] = "✅ Running" if resp.status_code == 200 else "❌ Error"
    except:
        status["ollama"] = "❌ Unreachable"

    # Check Redis
    try:
        import redis

        redis_host = os.getenv("REDIS_HOST", "redis")
        redis_port = int(os.getenv("REDIS_PORT", "16379"))
        r = redis.Redis(host=redis_host, port=redis_port, socket_connect_timeout=2)
        r.ping()
        status["redis"] = "✅ Running"
    except:
        status["redis"] = "❌ Unreachable"

    # Check PostgreSQL
    try:
        cursor = db.execute("SELECT 1")
        status["postgres"] = "✅ Running"
    except:
        status["postgres"] = "❌ Unreachable"

    # Check PgBouncer
    try:
        import psycopg2

        conn = psycopg2.connect(
            host=os.getenv("PGBOUNCER_HOST", "localhost"),
            port=os.getenv("PGBOUNCER_PORT", 16432),
            user=os.getenv("POSTGRES_USER", "ollama_user"),
            password=os.getenv("POSTGRES_PASSWORD", "change_me_in_production"),
            database=os.getenv("POSTGRES_DB", "ollama_db"),
        )
        conn.close()
        status["pgbouncer"] = "✅ Running"
    except:
        status["pgbouncer"] = "❌ Unreachable"

    return status


@app.post("/api/services/restart/{service}")
async def restart_service(service: str):
    """Restart a Docker service/container"""
    valid_services = ["ollama", "redis", "postgres", "pgbouncer"]

    if service not in valid_services:
        raise HTTPException(status_code=400, detail="Invalid service")

    # Map service names to container names
    container_names = {
        "ollama": "generative-ollama-prod",
        "redis": "generative-redis-prod",
        "postgres": "generative-postgres-prod",
        "pgbouncer": "generative-pgbouncer-prod",
    }

    container = container_names.get(service)

    try:
        subprocess.run(
            ["docker", "restart", container], check=True, capture_output=True
        )
        return {"status": "success", "message": f"{service} restarted"}
    except subprocess.CalledProcessError as e:
        logger.error(f"Error restarting {service}: {e.stderr.decode()}")
        raise HTTPException(status_code=500, detail=str(e))


def get_dashboard_html() -> str:
    """Generate dashboard HTML"""
    return """
    <!DOCTYPE html>
    <html lang="fr">
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <title>Ollama Config Manager</title>
        <style>
            @import url('https://fonts.googleapis.com/css2?family=Manrope:wght@400;600;700;800&family=Space+Grotesk:wght@500;700&display=swap');

            :root {
                --bg-base: #f3f1ea;
                --bg-panel: rgba(255, 255, 255, 0.86);
                --text-main: #182022;
                --text-soft: #4e5a5c;
                --line: #d7dfde;
                --brand: #146b70;
                --brand-strong: #0e4f54;
                --accent: #d17a1b;
                --ok: #1b8f51;
                --bad: #bb3428;
                --shadow: 0 14px 34px rgba(24, 32, 34, 0.14);
                --radius-lg: 18px;
                --radius-sm: 10px;
            }

            * {
                margin: 0;
                padding: 0;
                box-sizing: border-box;
            }

            body {
                font-family: 'Manrope', 'Segoe UI', sans-serif;
                color: var(--text-main);
                background:
                    radial-gradient(circle at 8% 12%, rgba(20, 107, 112, 0.20), transparent 42%),
                    radial-gradient(circle at 88% 18%, rgba(209, 122, 27, 0.16), transparent 46%),
                    linear-gradient(180deg, #faf8f2 0%, var(--bg-base) 100%);
                min-height: 100vh;
                padding: 24px;
            }

            .container {
                max-width: 1240px;
                margin: 0 auto;
            }

            .login-screen {
                background: var(--bg-panel);
                border: 1px solid rgba(255, 255, 255, 0.7);
                backdrop-filter: blur(8px);
                border-radius: var(--radius-lg);
                box-shadow: var(--shadow);
                padding: 42px;
                text-align: center;
                max-width: 420px;
                margin: 90px auto;
                animation: rise-in 0.35s ease;
            }

            .login-screen h1 {
                font-family: 'Space Grotesk', 'Manrope', sans-serif;
                font-size: 30px;
                letter-spacing: 0.2px;
                color: var(--text-main);
                margin-bottom: 24px;
            }

            .login-screen input {
                width: 100%;
                padding: 13px 14px;
                margin-bottom: 16px;
                border: 1px solid var(--line);
                border-radius: var(--radius-sm);
                font-size: 15px;
                background: #fff;
            }

            .dashboard {
                display: none;
            }

            header {
                background: var(--bg-panel);
                border: 1px solid rgba(255, 255, 255, 0.7);
                backdrop-filter: blur(8px);
                padding: 18px 22px;
                border-radius: var(--radius-lg);
                margin-bottom: 20px;
                box-shadow: var(--shadow);
                display: flex;
                justify-content: space-between;
                align-items: center;
                animation: rise-in 0.35s ease;
            }

            header h1 {
                font-family: 'Space Grotesk', 'Manrope', sans-serif;
                color: var(--text-main);
                font-size: 25px;
                letter-spacing: 0.2px;
            }

            .logout-btn {
                background: #fff;
                color: var(--bad);
                border: 1px solid #efb3ac;
                padding: 10px 16px;
                border-radius: var(--radius-sm);
                cursor: pointer;
                font-weight: 700;
            }

            .status-grid {
                display: grid;
                grid-template-columns: repeat(auto-fit, minmax(220px, 1fr));
                gap: 14px;
                margin-bottom: 22px;
            }

            .status-card {
                background: var(--bg-panel);
                border: 1px solid rgba(255, 255, 255, 0.72);
                border-radius: 14px;
                box-shadow: 0 8px 22px rgba(24, 32, 34, 0.11);
                padding: 18px;
            }

            .status-card h3 {
                font-family: 'Space Grotesk', 'Manrope', sans-serif;
                color: var(--text-main);
                margin-bottom: 8px;
                font-size: 14px;
                letter-spacing: 0.7px;
            }

            .status-badge {
                padding: 6px 12px;
                border-radius: 999px;
                font-weight: 700;
                display: inline-block;
                font-size: 13px;
            }

            .status-running {
                background: rgba(27, 143, 81, 0.14);
                color: var(--ok);
                border: 1px solid rgba(27, 143, 81, 0.28);
            }

            .status-error {
                background: rgba(187, 52, 40, 0.14);
                color: var(--bad);
                border: 1px solid rgba(187, 52, 40, 0.24);
            }

            .tabs {
                display: grid;
                grid-template-columns: repeat(4, minmax(0, 1fr));
                gap: 8px;
                margin-bottom: 20px;
                padding: 8px;
                border-radius: 14px;
                background: var(--bg-panel);
                border: 1px solid rgba(255, 255, 255, 0.75);
                box-shadow: 0 8px 22px rgba(24, 32, 34, 0.11);
            }

            .tab-btn {
                padding: 12px 10px;
                background: transparent;
                border: 1px solid transparent;
                cursor: pointer;
                font-weight: 700;
                color: var(--text-soft);
                border-radius: var(--radius-sm);
                transition: all 0.2s ease;
            }

            .tab-btn.active {
                background: linear-gradient(135deg, var(--brand), var(--brand-strong));
                color: #fff;
                box-shadow: 0 6px 14px rgba(20, 107, 112, 0.24);
            }

            .tab-content {
                display: none;
                background: var(--bg-panel);
                border: 1px solid rgba(255, 255, 255, 0.75);
                padding: 28px;
                border-radius: var(--radius-lg);
                box-shadow: var(--shadow);
                animation: rise-in 0.26s ease;
            }

            .tab-content.active {
                display: block;
            }

            .tab-content h2 {
                font-family: 'Space Grotesk', 'Manrope', sans-serif;
                margin-bottom: 14px;
                font-size: 22px;
            }

            .form-group {
                margin-bottom: 18px;
            }

            .form-group label {
                display: block;
                margin-bottom: 7px;
                color: var(--text-main);
                font-weight: 700;
                font-size: 13px;
                letter-spacing: 0.2px;
            }

            .form-group input,
            .form-group textarea,
            .form-group select {
                width: 100%;
                padding: 11px 13px;
                border: 1px solid var(--line);
                border-radius: var(--radius-sm);
                font-size: 14px;
                background: #fff;
            }

            .form-group textarea {
                resize: vertical;
                min-height: 90px;
            }

            .form-group input:focus,
            .form-group textarea:focus,
            .form-group select:focus {
                outline: none;
                border-color: var(--brand);
                box-shadow: 0 0 0 3px rgba(20, 107, 112, 0.16);
            }

            .form-description {
                font-size: 12px;
                color: var(--text-soft);
                margin-top: 4px;
            }

            button {
                background: linear-gradient(135deg, var(--brand), var(--brand-strong));
                color: #fff;
                border: none;
                padding: 11px 20px;
                border-radius: var(--radius-sm);
                cursor: pointer;
                font-weight: 700;
                font-size: 14px;
                transition: transform 0.2s ease, box-shadow 0.2s ease;
            }

            button:hover {
                transform: translateY(-1px);
                box-shadow: 0 8px 16px rgba(20, 107, 112, 0.24);
            }

            .table {
                width: 100%;
                border-collapse: separate;
                border-spacing: 0;
                margin-top: 16px;
                overflow: hidden;
                border-radius: 12px;
                border: 1px solid var(--line);
                background: #fff;
            }

            .table th,
            .table td {
                padding: 13px 14px;
                text-align: left;
                border-bottom: 1px solid #e7eceb;
                font-size: 13px;
            }

            .table th {
                background: #f1f5f5;
                font-weight: 800;
                color: var(--text-main);
            }

            .table tr:last-child td {
                border-bottom: none;
            }

            .table tr:hover {
                background: #f8fbfb;
            }

            .delete-btn {
                background: linear-gradient(135deg, #d44d40, #b23b31);
                padding: 7px 12px;
                font-size: 12px;
            }

            .restart-btn {
                background: linear-gradient(135deg, var(--accent), #b45b0f);
                padding: 10px 14px;
                font-size: 13px;
            }

            .alert {
                padding: 12px 14px;
                margin-bottom: 18px;
                border-radius: 10px;
                display: none;
                font-size: 13px;
                font-weight: 700;
            }

            .alert.success {
                background: rgba(27, 143, 81, 0.13);
                color: var(--ok);
                border: 1px solid rgba(27, 143, 81, 0.25);
                display: block;
            }

            .alert.error {
                background: rgba(187, 52, 40, 0.13);
                color: var(--bad);
                border: 1px solid rgba(187, 52, 40, 0.25);
                display: block;
            }

            .grid-2 {
                display: grid;
                grid-template-columns: repeat(2, minmax(0, 1fr));
                gap: 18px;
            }

            @keyframes rise-in {
                from {
                    opacity: 0;
                    transform: translateY(8px);
                }
                to {
                    opacity: 1;
                    transform: translateY(0);
                }
            }

            @media (max-width: 900px) {
                .tabs {
                    grid-template-columns: repeat(2, minmax(0, 1fr));
                }

                .grid-2 {
                    grid-template-columns: 1fr;
                }
            }

            @media (max-width: 640px) {
                body {
                    padding: 14px;
                }

                .login-screen {
                    margin-top: 38px;
                    padding: 28px;
                }

                header {
                    flex-direction: column;
                    gap: 12px;
                    align-items: flex-start;
                }

                .tabs {
                    grid-template-columns: 1fr;
                }

                .tab-content {
                    padding: 20px;
                }

                .status-grid {
                    grid-template-columns: 1fr;
                }
            }
        </style>
    </head>
    <body>
        <div class="login-screen" id="loginScreen">
            <h1>🔐 Ollama Config Manager</h1>
            <input type="password" id="adminPassword" placeholder="Mot de passe admin">
            <button onclick="login()">Se connecter</button>
        </div>
        
        <div class="dashboard" id="dashboard">
            <header>
                <h1>🚀 Ollama Configuration Manager</h1>
                <button class="logout-btn" onclick="logout()">Déconnexion</button>
            </header>
            
            <!-- Status Cards -->
            <div id="statusGrid" class="status-grid">
                <!-- Loaded via JS -->
            </div>
            
            <!-- Tabs -->
            <div class="tabs">
                <button class="tab-btn active" onclick="switchTab('env')">⚙️ Environnement</button>
                <button class="tab-btn" onclick="switchTab('apikeys')">🔑 Clés API</button>
                <button class="tab-btn" onclick="switchTab('domains')">🌐 Domaines</button>
                <button class="tab-btn" onclick="switchTab('services')">🐳 Services</button>
            </div>
            
            <!-- Environment Tab -->
            <div class="tab-content active" id="env-tab">
                <h2>Variables d'Environnement</h2>
                <div id="alertEnv" class="alert"></div>
                <div id="envVariables" style="max-height: 500px; overflow-y: auto;"></div>
                <button onclick="saveEnvironment()" style="margin-top: 20px;">💾 Sauvegarder</button>
            </div>
            
            <!-- API Keys Tab -->
            <div class="tab-content" id="apikeys-tab">
                <h2>Gestion des Clés API</h2>
                <div id="alertKeys" class="alert"></div>
                
                <h3 style="margin-top: 30px; margin-bottom: 20px;">Créer une nouvelle clé</h3>
                <div class="grid-2">
                    <div class="form-group">
                        <label for="keyName">Nom</label>
                        <input type="text" id="keyName" placeholder="Ex: My App">
                        <div class="form-description">Nom pour identifier la clé</div>
                    </div>
                    <div class="form-group">
                        <label for="keyDomain">Domaine</label>
                        <input type="text" id="keyDomain" placeholder="Ex: myapp.bluevaloris.com">
                        <div class="form-description">Domaine associé</div>
                    </div>
                </div>
                <button onclick="createAPIKey()">➕ Créer une clé API</button>
                
                <h3 style="margin-top: 30px; margin-bottom: 20px;">Clés existantes</h3>
                <table class="table" id="keysTable">
                    <thead>
                        <tr>
                            <th>ID</th>
                            <th>Nom</th>
                            <th>Domaine</th>
                            <th>Créée le</th>
                            <th>Statut</th>
                            <th>Action</th>
                        </tr>
                    </thead>
                    <tbody id="keysList"></tbody>
                </table>
            </div>
            
            <!-- Domains Tab -->
            <div class="tab-content" id="domains-tab">
                <h2>Gestion des Domaines</h2>
                <div id="alertDomains" class="alert"></div>
                
                <h3 style="margin-top: 30px; margin-bottom: 20px;">Ajouter un domaine</h3>
                <div class="grid-2">
                    <div class="form-group">
                        <label for="domainName">Domaine</label>
                        <input type="text" id="domainName" placeholder="Ex: api.myapp.bluevaloris.com">
                    </div>
                    <div class="form-group">
                        <label for="domainKeyId">Clé API</label>
                        <select id="domainKeyId"></select>
                    </div>
                </div>
                <div class="form-group">
                    <label for="domainDesc">Description</label>
                    <textarea id="domainDesc" placeholder="Description optionnelle"></textarea>
                </div>
                <button onclick="addDomain()">➕ Ajouter un domaine</button>
                
                <h3 style="margin-top: 30px; margin-bottom: 20px;">Domaines whitelistés</h3>
                <table class="table" id="domainsTable">
                    <thead>
                        <tr>
                            <th>Domaine</th>
                            <th>Clé API</th>
                            <th>Créé le</th>
                        </tr>
                    </thead>
                    <tbody id="domainsList"></tbody>
                </table>
            </div>
            
            <!-- Services Tab -->
            <div class="tab-content" id="services-tab">
                <h2>Gestion des Services</h2>
                <p style="margin-bottom: 20px; color: #666;">Redémarrer les services Docker</p>
                
                <div style="display: grid; grid-template-columns: repeat(auto-fit, minmax(150px, 1fr)); gap: 15px;">
                    <button class="restart-btn" onclick="restartService('ollama')">🤖 Restart Ollama</button>
                    <button class="restart-btn" onclick="restartService('redis')">🔴 Restart Redis</button>
                    <button class="restart-btn" onclick="restartService('postgres')">🗄️ Restart PostgreSQL</button>
                    <button class="restart-btn" onclick="restartService('pgbouncer')">🔗 Restart PgBouncer</button>
                </div>
            </div>
        </div>
        
        <script>
            let authToken = null;
            
            // Login
            function login() {
                const password = document.getElementById('adminPassword').value;
                fetch('/api/auth/login', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({password})
                })
                .then(r => r.json())
                .then(data => {
                    if (data.token) {
                        authToken = data.token;
                        localStorage.setItem('authToken', authToken);
                        showDashboard();
                        loadAllData();
                    } else {
                        alert('Erreur: ' + (data.detail || 'Erreur de connexion'));
                    }
                })
                .catch(e => alert('Erreur: ' + e));
            }
            
            function logout() {
                authToken = null;
                localStorage.removeItem('authToken');
                document.getElementById('loginScreen').style.display = 'block';
                document.getElementById('dashboard').style.display = 'none';
            }
            
            function showDashboard() {
                document.getElementById('loginScreen').style.display = 'none';
                document.getElementById('dashboard').style.display = 'block';
            }
            
            // Tab switching
            function switchTab(tabName) {
                document.querySelectorAll('.tab-content').forEach(el => el.classList.remove('active'));
                document.querySelectorAll('.tab-btn').forEach(el => el.classList.remove('active'));
                document.getElementById(tabName + '-tab').classList.add('active');
                event.target.classList.add('active');
            }
            
            // Load all data
            async function loadAllData() {
                loadStatus();
                loadEnvironment();
                loadAPIKeys();
                loadDomains();
                setInterval(loadStatus, 30000);
            }
            
            // Status
            function loadStatus() {
                fetch('/api/status')
                    .then(r => r.json())
                    .then(data => {
                        let html = '';
                        for (const [service, status] of Object.entries(data)) {
                            if (service === 'timestamp') continue;
                            const isRunning = status.includes('✅');
                            html += `
                                <div class="status-card">
                                    <h3>${service.toUpperCase()}</h3>
                                    <span class="status-badge ${isRunning ? 'status-running' : 'status-error'}">${status}</span>
                                </div>
                            `;
                        }
                        document.getElementById('statusGrid').innerHTML = html;
                    });
            }
            
            // Environment
            function loadEnvironment() {
                fetch('/api/env')
                    .then(r => r.json())
                    .then(data => {
                        let html = '';
                        data.forEach(v => {
                            html += `
                                <div class="form-group">
                                    <label>${v.key}</label>
                                    <input type="text" data-key="${v.key}" value="${v.value || ''}" />
                                    ${v.description ? '<div class="form-description">' + v.description + '</div>' : ''}
                                </div>
                            `;
                        });
                        document.getElementById('envVariables').innerHTML = html;
                    });
            }
            
            function saveEnvironment() {
                const inputs = document.querySelectorAll('#envVariables input');
                const variables = {};
                inputs.forEach(input => {
                    variables[input.dataset.key] = input.value;
                });
                
                fetch('/api/env/bulk-update', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({variables})
                })
                .then(r => r.json())
                .then(data => {
                    const alert = document.getElementById('alertEnv');
                    alert.className = 'alert success';
                    alert.textContent = '✅ Environnement sauvegardé avec succès!';
                    setTimeout(() => alert.className = 'alert', 3000);
                });
            }
            
            // API Keys
            function loadAPIKeys() {
                fetch('/api/keys')
                    .then(r => r.json())
                    .then(data => {
                        let html = '';
                        data.forEach(key => {
                            html += `
                                <tr>
                                    <td>${key.id}</td>
                                    <td>${key.name}</td>
                                    <td>${key.domain}</td>
                                    <td>${new Date(key.created_at).toLocaleDateString('fr-FR')}</td>
                                    <td>${key.is_active ? '✅ Actif' : '❌ Inactif'}</td>
                                    <td><button class="delete-btn" onclick="deleteAPIKey(${key.id})">Supprimer</button></td>
                                </tr>
                            `;
                        });
                        document.getElementById('keysList').innerHTML = html;
                        
                        // Populate dropdown
                        let option = '<option value="">-- Sélectionner une clé --</option>';
                        data.forEach(key => {
                            option += `<option value="${key.id}">${key.name}</option>`;
                        });
                        document.getElementById('domainKeyId').innerHTML = option;
                    });
            }
            
            function createAPIKey() {
                const name = document.getElementById('keyName').value;
                const domain = document.getElementById('keyDomain').value;
                
                if (!name || !domain) {
                    alert('Veuillez remplir tous les champs');
                    return;
                }
                
                fetch('/api/keys', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({name, domain})
                })
                .then(r => r.json())
                .then(data => {
                    const alert = document.getElementById('alertKeys');
                    alert.className = 'alert success';
                    alert.innerHTML = `<strong>✅ Clé créée!</strong><br>Clé brute: <code style="background: #f0f0f0; padding: 5px;">${data.raw_key}</code><br><strong>${data.message}</strong>`;
                    
                    document.getElementById('keyName').value = '';
                    document.getElementById('keyDomain').value = '';
                    loadAPIKeys();
                });
            }
            
            function deleteAPIKey(keyId) {
                if (!confirm('Êtes-vous sûr?')) return;
                
                fetch(`/api/keys/${keyId}`, {method: 'DELETE'})
                    .then(r => r.json())
                    .then(data => {
                        loadAPIKeys();
                        const alert = document.getElementById('alertKeys');
                        alert.className = 'alert success';
                        alert.textContent = '✅ Clé supprimée';
                    });
            }
            
            // Domains
            function loadDomains() {
                fetch('/api/domains')
                    .then(r => r.json())
                    .then(data => {
                        let html = '';
                        data.forEach(d => {
                            html += `
                                <tr>
                                    <td>${d.domain}</td>
                                    <td>${d.api_key_name || 'N/A'}</td>
                                    <td>${new Date(d.created_at).toLocaleDateString('fr-FR')}</td>
                                </tr>
                            `;
                        });
                        document.getElementById('domainsList').innerHTML = html;
                    });
            }
            
            function addDomain() {
                const domain = document.getElementById('domainName').value;
                const api_key_id = document.getElementById('domainKeyId').value;
                const description = document.getElementById('domainDesc').value;
                
                if (!domain || !api_key_id) {
                    alert('Veuillez remplir les champs requis');
                    return;
                }
                
                fetch('/api/domains', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json'},
                    body: JSON.stringify({domain, api_key_id: parseInt(api_key_id), description})
                })
                .then(r => r.json())
                .then(data => {
                    document.getElementById('domainName').value = '';
                    document.getElementById('domainDesc').value = '';
                    loadDomains();
                    
                    const alert = document.getElementById('alertDomains');
                    alert.className = 'alert success';
                    alert.textContent = '✅ Domaine ajouté!';
                    setTimeout(() => alert.className = 'alert', 3000);
                });
            }
            
            // Services
            function restartService(service) {
                if (!confirm(`Êtes-vous sûr? ${service} sera redémarré...`)) return;
                
                fetch(`/api/services/restart/${service}`, {method: 'POST'})
                    .then(r => r.json())
                    .then(data => {
                        alert('✅ ' + data.message);
                    })
                    .catch(e => alert('❌ Erreur'));
            }
            
            // Check auth on load
            window.addEventListener('load', () => {
                authToken = localStorage.getItem('authToken');
                if (authToken) {
                    showDashboard();
                    loadAllData();
                }
            });
        </script>
    </body>
    </html>
    """


if __name__ == "__main__":
    import uvicorn

    internal_port = int(os.getenv("CONFIG_MANAGER_INTERNAL_PORT", "18889"))
    uvicorn.run(app, host="0.0.0.0", port=internal_port)
