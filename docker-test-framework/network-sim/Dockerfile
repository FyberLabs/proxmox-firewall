FROM python:3.11-slim

# Install system dependencies for networking
RUN apt-get update && apt-get install -y \
    iproute2 \
    bridge-utils \
    iptables \
    tcpdump \
    netcat-openbsd \
    curl \
    && rm -rf /var/lib/apt/lists/*

# Install Python dependencies
RUN pip install --no-cache-dir \
    fastapi==0.104.1 \
    uvicorn[standard]==0.24.0 \
    pyroute2==0.7.12 \
    netaddr==0.10.1 \
    structlog==23.2.0

# Create app user
RUN useradd -m -s /bin/bash netuser

# Set working directory
WORKDIR /app

# Copy application files
COPY src/ ./src/

# Create necessary directories
RUN mkdir -p /var/lib/network-sim /var/log/network-sim && \
    chown -R netuser:netuser /var/lib/network-sim /var/log/network-sim /app

# Switch to app user for non-privileged operations
# Note: Container will run as root due to networking requirements

# Expose port for API
EXPOSE 8080

# Default command
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "8080"]
