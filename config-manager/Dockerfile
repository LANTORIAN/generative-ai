# Config Manager - Interface Web
FROM python:3.11-slim

WORKDIR /app

# Install dependencies (including docker CLI)
RUN apt-get update && apt-get install -y \
    gcc \
    curl \
    docker.io \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY config-manager/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application
COPY config-manager.py .
COPY .env .env

# Create appuser and add to docker group for socket access
RUN useradd -m -u 1000 appuser && \
    groupadd -f docker && \
    usermod -aG docker appuser

RUN chown -R appuser:appuser /app
USER appuser

# Expose port
EXPOSE 8888

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8888/ || exit 1

# Run with unbuffered output for logs
CMD ["python", "-u", "config-manager.py"]
