-- Ollama Production Database Initialization
-- Tables for storing connection info, API keys, usage stats, etc.

-- Create schemas
CREATE SCHEMA IF NOT EXISTS ollama;
CREATE SCHEMA IF NOT EXISTS audit;

-- API Keys & Credentials table
CREATE TABLE IF NOT EXISTS ollama.api_keys (
    id SERIAL PRIMARY KEY,
    key_hash VARCHAR(255) UNIQUE NOT NULL,
    name VARCHAR(100) NOT NULL,
    description TEXT,
    domain VARCHAR(255) NOT NULL,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    last_used TIMESTAMP,
    is_active BOOLEAN DEFAULT true,
    rate_limit_per_minute INTEGER DEFAULT 100,
    rate_limit_per_hour INTEGER DEFAULT 5000,
    rate_limit_per_day INTEGER DEFAULT 50000,
    created_by VARCHAR(100),
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Connection Pool Info
CREATE TABLE IF NOT EXISTS ollama.connection_pools (
    id SERIAL PRIMARY KEY,
    pool_name VARCHAR(100) UNIQUE NOT NULL,
    min_size INTEGER DEFAULT 5,
    max_size INTEGER DEFAULT 25,
    idle_timeout INTEGER DEFAULT 900,
    max_lifetime INTEGER DEFAULT 3600,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- API Usage Statistics
CREATE TABLE IF NOT EXISTS ollama.api_usage (
    id BIGSERIAL PRIMARY KEY,
    api_key_id INTEGER REFERENCES ollama.api_keys(id) ON DELETE CASCADE,
    endpoint VARCHAR(255) NOT NULL,
    model VARCHAR(100),
    method VARCHAR(10),
    status_code INTEGER,
    response_time_ms INTEGER,
    tokens_used INTEGER,
    request_size_bytes INTEGER,
    response_size_bytes INTEGER,
    domain VARCHAR(255),
    client_ip VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Model Configuration Storage
CREATE TABLE IF NOT EXISTS ollama.model_configs (
    id SERIAL PRIMARY KEY,
    model_name VARCHAR(100) UNIQUE NOT NULL,
    version VARCHAR(20),
    description TEXT,
    default_temperature DECIMAL(3,2) DEFAULT 0.7,
    default_top_k INTEGER DEFAULT 40,
    default_top_p DECIMAL(3,2) DEFAULT 0.9,
    max_tokens INTEGER DEFAULT 4096,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Domain Whitelist
CREATE TABLE IF NOT EXISTS ollama.domain_whitelist (
    id SERIAL PRIMARY KEY,
    domain VARCHAR(255) UNIQUE NOT NULL,
    api_key_id INTEGER REFERENCES ollama.api_keys(id) ON DELETE CASCADE,
    description TEXT,
    is_active BOOLEAN DEFAULT true,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Rate Limit Tracking (for real-time monitoring)
CREATE TABLE IF NOT EXISTS ollama.rate_limits (
    id SERIAL PRIMARY KEY,
    api_key_id INTEGER REFERENCES ollama.api_keys(id) ON DELETE CASCADE,
    request_count INTEGER DEFAULT 0,
    reset_time TIMESTAMP,
    window_type VARCHAR(20), -- 'minute', 'hour', 'day'
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Audit Log for security
CREATE TABLE IF NOT EXISTS audit.access_log (
    id BIGSERIAL PRIMARY KEY,
    api_key_id INTEGER,
    action VARCHAR(100) NOT NULL,
    resource VARCHAR(255),
    status VARCHAR(20),
    details JSONB,
    ip_address VARCHAR(45),
    user_agent TEXT,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Error Log
CREATE TABLE IF NOT EXISTS ollama.error_log (
    id BIGSERIAL PRIMARY KEY,
    api_key_id INTEGER REFERENCES ollama.api_keys(id) ON DELETE SET NULL,
    endpoint VARCHAR(255),
    error_code VARCHAR(50),
    error_message TEXT,
    stack_trace TEXT,
    request_body JSONB,
    client_ip VARCHAR(45),
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Health Check History
CREATE TABLE IF NOT EXISTS ollama.health_checks (
    id SERIAL PRIMARY KEY,
    service_name VARCHAR(100) NOT NULL,
    status VARCHAR(20) NOT NULL,
    response_time_ms INTEGER,
    details JSONB,
    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- Create Indexes
CREATE INDEX IF NOT EXISTS idx_api_keys_domain ON ollama.api_keys(domain);
CREATE INDEX IF NOT EXISTS idx_api_keys_active ON ollama.api_keys(is_active);
CREATE INDEX IF NOT EXISTS idx_connection_pools_active ON ollama.connection_pools(is_active);
CREATE INDEX IF NOT EXISTS idx_model_configs_active ON ollama.model_configs(is_active);
CREATE INDEX IF NOT EXISTS idx_usage_api_key ON ollama.api_usage(api_key_id);
CREATE INDEX IF NOT EXISTS idx_usage_created ON ollama.api_usage(created_at);
CREATE INDEX IF NOT EXISTS idx_usage_endpoint ON ollama.api_usage(endpoint);
CREATE INDEX IF NOT EXISTS idx_domain_active ON ollama.domain_whitelist(domain, is_active);
CREATE INDEX IF NOT EXISTS idx_rate_limit_api_key ON ollama.rate_limits(api_key_id);
CREATE INDEX IF NOT EXISTS idx_audit_created ON audit.access_log(created_at);
CREATE INDEX IF NOT EXISTS idx_audit_action ON audit.access_log(action);
CREATE INDEX IF NOT EXISTS idx_audit_api_key ON audit.access_log(api_key_id);
CREATE INDEX IF NOT EXISTS idx_error_created ON ollama.error_log(created_at);
CREATE INDEX IF NOT EXISTS idx_error_code ON ollama.error_log(error_code);
CREATE INDEX IF NOT EXISTS idx_health_service ON ollama.health_checks(service_name, created_at);

-- Create Views for common queries

-- View: Active API Keys
CREATE OR REPLACE VIEW ollama.v_active_api_keys AS
SELECT 
    id,
    name,
    domain,
    created_at,
    last_used,
    rate_limit_per_minute,
    rate_limit_per_hour,
    rate_limit_per_day
FROM ollama.api_keys
WHERE is_active = true;

-- View: API Usage Statistics
CREATE OR REPLACE VIEW ollama.v_usage_stats AS
SELECT 
    DATE(created_at) as usage_date,
    endpoint,
    model,
    COUNT(*) as request_count,
    AVG(response_time_ms) as avg_response_time_ms,
    MAX(response_time_ms) as max_response_time_ms,
    SUM(tokens_used) as total_tokens,
    SUM(request_size_bytes) as total_request_bytes,
    SUM(response_size_bytes) as total_response_bytes
FROM ollama.api_usage
GROUP BY DATE(created_at), endpoint, model;

-- View: Domain Mappings
CREATE OR REPLACE VIEW ollama.v_domain_mappings AS
SELECT 
    d.domain,
    d.api_key_id,
    a.name as api_key_name,
    a.is_active,
    d.created_at
FROM ollama.domain_whitelist d
LEFT JOIN ollama.api_keys a ON d.api_key_id = a.id
WHERE d.is_active = true;

-- Grants (optional: for different user roles)
-- GRANT SELECT ON ollama.v_active_api_keys TO ollama_readonly;
-- GRANT SELECT ON ollama.v_usage_stats TO ollama_readonly;
-- GRANT SELECT, INSERT ON ollama.api_usage TO ollama_app;

-- Example data
INSERT INTO ollama.model_configs (model_name, version, description, default_temperature)
VALUES 
    ('gemma2:2b', '2b', 'Google Gemma 2B - Lightweight and fast', 0.7),
    ('gemma2:9b', '9b', 'Google Gemma 9B - Balanced', 0.7),
    ('llama2', '7b', 'Meta Llama 2 7B', 0.7),
    ('mistral', '7b', 'Mistral 7B - Very fast', 0.7),
    ('neural-chat', '7b', 'Optimized for chat', 0.7),
    ('dolphin-mixtral', 'mixtral', 'Dolphin Mixtral MoE', 0.7)
ON CONFLICT (model_name) DO NOTHING;

INSERT INTO ollama.connection_pools (pool_name, min_size, max_size, description)
VALUES 
    ('default', 5, 25, 'Default connection pool'),
    ('api_requests', 10, 50, 'API request processing'),
    ('background_jobs', 2, 10, 'Background job processing')
ON CONFLICT (pool_name) DO NOTHING;

-- Create extension for better JSON support
CREATE EXTENSION IF NOT EXISTS pg_trgm;
