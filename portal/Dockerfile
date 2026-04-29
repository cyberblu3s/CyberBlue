FROM python:3.9-slim

# Set working directory
WORKDIR /app

# Install system dependencies including Docker CLI, YARA, Git, and build tools.
# NOTE on build tools (gcc/python3-dev): psutil 5.9.5 on python:3.9-slim no
# longer ships a matching prebuilt wheel for linux/arm64, so pip has to compile
# from source. Without gcc + python3-dev the portal image fails to build on
# arm64 with "command 'gcc' failed: No such file or directory" and the whole
# `docker compose up --build` aborts before any CyberBlueSOC service starts.
# Keeping these packages in place is a no-op on amd64 (wheels are used) and
# unblocks arm64 entirely - cost is ~120MB image size, acceptable.
RUN apt-get update && apt-get install -y \
    curl \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    yara \
    git \
    gcc \
    python3-dev \
    libffi-dev \
    && curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg \
    && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null \
    && apt-get update \
    && apt-get install -y docker-ce-cli \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements first for better caching
COPY requirements.txt .

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Install Sigma CLI and backends for threat hunting
RUN pip install --no-cache-dir sigma-cli pysigma-backend-elasticsearch pysigma-backend-opensearch

# Configure git to trust mounted rule directories
RUN git config --global --add safe.directory /opt/yara-rules && \
    git config --global --add safe.directory /opt/sigma-rules

# Copy application code
COPY . .

# Create necessary directories
RUN mkdir -p /app/logs

# Expose port
EXPOSE 5500

# Set environment variables
ENV PORT=5500
ENV FLASK_ENV=production

# Health check
#
# The portal listens on HTTP (port 5500) OR HTTPS (port 5443) depending on
# the ENABLE_HTTPS env var. In docker-compose.yml we set ENABLE_HTTPS=true,
# so Flask ONLY binds 5443 and port 5500 is not served — the old
# "curl http://localhost:5500/health" healthcheck was always failing,
# marking the container "unhealthy" even though the portal itself was
# perfectly reachable at https://host:5443. Probe HTTPS first, fall back
# to HTTP so this works in either ENABLE_HTTPS=true or =false mode.
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s --retries=3 \
    CMD curl -fks https://localhost:5443/health >/dev/null 2>&1 \
        || curl -fs http://localhost:5500/health >/dev/null 2>&1 \
        || exit 1

# Start the application
CMD ["python3", "app.py"] 