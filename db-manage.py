#!/usr/bin/env python3
"""
Ollama Database Management CLI
Outil pour gérer les clés API, domaines, et configurations de la base de données
"""

import os
import sys
import argparse
import json
from datetime import datetime
import psycopg2
from psycopg2.extras import RealDictCursor
import hashlib
import secrets

class OllamaDB:
    def __init__(self, host=None, port=None, user=None, password=None, dbname=None):
        """Initialize database connection"""
        self.host = host or os.getenv('PGBOUNCER_HOST', 'localhost')
        self.port = port or os.getenv('PGBOUNCER_PORT', 6432)
        self.user = user or os.getenv('POSTGRES_USER', 'ollama_user')
        self.password = password or os.getenv('POSTGRES_PASSWORD', 'change_me_in_production')
        self.dbname = dbname or os.getenv('POSTGRES_DB', 'ollama_db')
        
        self.conn = None
        self.connect()
    
    def connect(self):
        """Connect to database"""
        try:
            self.conn = psycopg2.connect(
                host=self.host,
                port=self.port,
                user=self.user,
                password=self.password,
                database=self.dbname
            )
            print(f"✅ Connected to {self.dbname} via PgBouncer ({self.host}:{self.port})")
        except psycopg2.Error as e:
            print(f"❌ Connection failed: {e}")
            sys.exit(1)
    
    def close(self):
        """Close database connection"""
        if self.conn:
            self.conn.close()
    
    def execute(self, query, params=None):
        """Execute query and return cursor"""
        cursor = self.conn.cursor(cursor_factory=RealDictCursor)
        try:
            cursor.execute(query, params)
            self.conn.commit()
            return cursor
        except psycopg2.Error as e:
            self.conn.rollback()
            raise e
    
    # ===== API KEY OPERATIONS =====
    
    def create_api_key(self, name, domain, rate_limit_min=100, rate_limit_hour=5000, rate_limit_day=50000, created_by='cli'):
        """Create a new API key"""
        # Generate secure key
        raw_key = secrets.token_urlsafe(32)
        key_hash = hashlib.sha256(raw_key.encode()).hexdigest()
        
        query = """
        INSERT INTO ollama.api_keys (key_hash, name, domain, rate_limit_per_minute, 
                                    rate_limit_per_hour, rate_limit_per_day, created_by)
        VALUES (%s, %s, %s, %s, %s, %s, %s)
        RETURNING id, created_at
        """
        
        cursor = self.execute(query, (key_hash, name, domain, rate_limit_min, rate_limit_hour, rate_limit_day, created_by))
        result = cursor.fetchone()
        
        print(f"✅ API Key created successfully")
        print(f"   ID: {result['id']}")
        print(f"   Name: {name}")
        print(f"   Domain: {domain}")
        print(f"   Raw Key (save this!): {raw_key}")
        print(f"   Hash: {key_hash[:16]}...")
        print(f"   Created: {result['created_at']}")
        
        return result['id'], raw_key
    
    def list_api_keys(self, active_only=True):
        """List all API keys"""
        query = "SELECT * FROM ollama.v_active_api_keys" if active_only else "SELECT * FROM ollama.api_keys"
        cursor = self.execute(query)
        keys = cursor.fetchall()
        
        if not keys:
            print("No API keys found")
            return
        
        print(f"\n📋 API Keys ({len(keys)} found):")
        print("-" * 80)
        for key in keys:
            print(f"ID: {key['id']:<5} | Name: {key['name']:<20} | Domain: {key['domain']:<25} | Limits: {key['rate_limit_per_minute']}/min")
        print()
    
    def delete_api_key(self, key_id):
        """Delete an API key"""
        query = "UPDATE ollama.api_keys SET is_active = false WHERE id = %s"
        self.execute(query, (key_id,))
        print(f"✅ API Key {key_id} deactivated")
    
    # ===== DOMAIN OPERATIONS =====
    
    def add_domain(self, domain, api_key_id, description=None):
        """Add domain to whitelist"""
        query = """
        INSERT INTO ollama.domain_whitelist (domain, api_key_id, description)
        VALUES (%s, %s, %s)
        RETURNING id, created_at
        """
        cursor = self.execute(query, (domain, api_key_id, description))
        result = cursor.fetchone()
        
        print(f"✅ Domain added to whitelist")
        print(f"   Domain: {domain}")
        print(f"   API Key ID: {api_key_id}")
        print(f"   Created: {result['created_at']}")
    
    def list_domains(self, active_only=True):
        """List whitelisted domains"""
        query = "SELECT * FROM ollama.v_domain_mappings" if active_only else "SELECT * FROM ollama.domain_whitelist"
        cursor = self.execute(query)
        domains = cursor.fetchall()
        
        if not domains:
            print("No domains found")
            return
        
        print(f"\n🌐 Whitelisted Domains ({len(domains)} found):")
        print("-" * 80)
        for d in domains:
            print(f"Domain: {d['domain']:<30} | API Key: {d['api_key_id']:<5} | Created: {d['created_at']}")
        print()
    
    # ===== USAGE STATISTICS =====
    
    def show_usage_stats(self, days=1):
        """Show API usage statistics"""
        query = """
        SELECT * FROM ollama.v_usage_stats 
        WHERE usage_date >= CURRENT_DATE - INTERVAL '%s days'
        ORDER BY usage_date DESC, request_count DESC
        """
        cursor = self.execute(query.replace('%s', str(days)))
        stats = cursor.fetchall()
        
        if not stats:
            print(f"No usage data for last {days} day(s)")
            return
        
        print(f"\n📊 Usage Statistics (last {days} day(s)):")
        print("-" * 100)
        print(f"{'Date':<12} {'Endpoint':<20} {'Model':<15} {'Requests':<10} {'Avg Time':<10} {'Tokens':<10}")
        print("-" * 100)
        
        for stat in stats:
            date = stat['usage_date'].isoformat() if stat['usage_date'] else 'N/A'
            endpoint = (stat['endpoint'] or 'N/A')[:19]
            model = (stat['model'] or 'N/A')[:14]
            requests = stat['request_count'] or 0
            avg_time = f"{stat['avg_response_time_ms']:.0f}ms" if stat['avg_response_time_ms'] else 'N/A'
            tokens = stat['total_tokens'] or 0
            
            print(f"{date:<12} {endpoint:<20} {model:<15} {requests:<10} {avg_time:<10} {tokens:<10}")
        print()
    
    def show_model_stats(self, days=1):
        """Show statistics by model"""
        query = """
        SELECT 
            model,
            COUNT(*) as request_count,
            AVG(response_time_ms) as avg_response_time_ms,
            SUM(tokens_used) as total_tokens
        FROM ollama.api_usage
        WHERE created_at > NOW() - INTERVAL '%s days'
        GROUP BY model
        ORDER BY request_count DESC
        """
        cursor = self.execute(query.replace('%s', str(days)))
        stats = cursor.fetchall()
        
        if not stats:
            print(f"No model usage data for last {days} day(s)")
            return
        
        print(f"\n🤖 Model Usage (last {days} day(s)):")
        print("-" * 80)
        print(f"{'Model':<20} {'Requests':<12} {'Avg Time':<12} {'Total Tokens':<15}")
        print("-" * 80)
        
        for stat in stats:
            model = (stat['model'] or 'Unknown')[:19]
            requests = stat['request_count']
            avg_time = f"{stat['avg_response_time_ms']:.0f}ms"
            tokens = stat['total_tokens'] or 0
            
            print(f"{model:<20} {requests:<12} {avg_time:<12} {tokens:<15}")
        print()
    
    # ===== MODEL CONFIGURATION =====
    
    def list_models(self):
        """List model configurations"""
        query = "SELECT * FROM ollama.model_configs ORDER BY model_name"
        cursor = self.execute(query)
        models = cursor.fetchall()
        
        if not models:
            print("No models configured")
            return
        
        print(f"\n🤖 Configured Models ({len(models)} found):")
        print("-" * 80)
        for model in models:
            status = "✅ Active" if model['is_active'] else "❌ Inactive"
            print(f"  {model['model_name']:<20} | {model['description']:<30} | {status}")
        print()
    
    # ===== DATABASE INFO =====
    
    def show_info(self):
        """Show database information"""
        queries = {
            'API Keys': "SELECT COUNT(*) as count FROM ollama.api_keys WHERE is_active = true",
            'Whitelisted Domains': "SELECT COUNT(*) as count FROM ollama.domain_whitelist WHERE is_active = true",
            'Models': "SELECT COUNT(*) as count FROM ollama.model_configs",
            'Connection Pools': "SELECT COUNT(*) as count FROM ollama.connection_pools",
            'Total Requests': "SELECT COUNT(*) as count FROM ollama.api_usage",
            'Errors': "SELECT COUNT(*) as count FROM ollama.error_log",
        }
        
        print("\n📊 Database Information:")
        print("-" * 50)
        
        for label, query in queries.items():
            cursor = self.execute(query)
            result = cursor.fetchone()
            count = result['count']
            print(f"  {label:<25}: {count}")
        print()


def main():
    parser = argparse.ArgumentParser(description='Ollama Database Management')
    subparsers = parser.add_subparsers(title='commands', dest='command', help='Available commands')
    
    # Info command
    subparsers.add_parser('info', help='Show database information')
    
    # API Key commands
    api_key_parser = subparsers.add_parser('key', help='API Key management')
    api_key_sub = api_key_parser.add_subparsers(dest='action')
    
    create_parser = api_key_sub.add_parser('create', help='Create new API key')
    create_parser.add_argument('--name', required=True, help='Key name')
    create_parser.add_argument('--domain', required=True, help='Domain')
    create_parser.add_argument('--min-rate', type=int, default=100, help='Rate limit per minute')
    create_parser.add_argument('--hour-rate', type=int, default=5000, help='Rate limit per hour')
    create_parser.add_argument('--day-rate', type=int, default=50000, help='Rate limit per day')
    
    api_key_sub.add_parser('list', help='List API keys')
    
    delete_parser = api_key_sub.add_parser('delete', help='Delete API key')
    delete_parser.add_argument('key_id', type=int, help='Key ID')
    
    # Domain commands
    domain_parser = subparsers.add_parser('domain', help='Domain management')
    domain_sub = domain_parser.add_subparsers(dest='action')
    
    add_parser = domain_sub.add_parser('add', help='Add domain to whitelist')
    add_parser.add_argument('--domain', required=True, help='Domain name')
    add_parser.add_argument('--key-id', type=int, required=True, help='API Key ID')
    add_parser.add_argument('--desc', help='Description')
    
    domain_sub.add_parser('list', help='List whitelisted domains')
    
    # Usage commands
    usage_parser = subparsers.add_parser('usage', help='Usage statistics')
    usage_sub = usage_parser.add_subparsers(dest='action')
    
    stats_parser = usage_sub.add_parser('show', help='Show usage statistics')
    stats_parser.add_argument('--days', type=int, default=1, help='Days to show')
    
    models_parser = usage_sub.add_parser('models', help='Show model usage')
    models_parser.add_argument('--days', type=int, default=1, help='Days to show')
    
    # Model commands
    model_parser = subparsers.add_parser('model', help='Model management')
    model_sub = model_parser.add_subparsers(dest='action')
    model_sub.add_parser('list', help='List configured models')
    
    args = parser.parse_args()
    
    # Connect to database
    db = OllamaDB()
    
    try:
        if args.command == 'info':
            db.show_info()
        
        elif args.command == 'key':
            if args.action == 'create':
                db.create_api_key(args.name, args.domain, args.min_rate, args.hour_rate, args.day_rate)
            elif args.action == 'list':
                db.list_api_keys()
            elif args.action == 'delete':
                db.delete_api_key(args.key_id)
        
        elif args.command == 'domain':
            if args.action == 'add':
                db.add_domain(args.domain, args.key_id, args.desc)
            elif args.action == 'list':
                db.list_domains()
        
        elif args.command == 'usage':
            if args.action == 'show':
                db.show_usage_stats(args.days)
            elif args.action == 'models':
                db.show_model_stats(args.days)
        
        elif args.command == 'model':
            if args.action == 'list':
                db.list_models()
        
        else:
            parser.print_help()
    
    finally:
        db.close()


if __name__ == '__main__':
    main()
