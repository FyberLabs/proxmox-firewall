FROM python:3.11-alpine

# Install required packages
RUN apk add --no-cache \
    curl \
    openssl \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Create app user
RUN addgroup -g 1000 proxmox && \
    adduser -D -s /bin/sh -u 1000 -G proxmox proxmox

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY src/ ./src/
COPY templates/ ./templates/
COPY static/ ./static/

# Create necessary directories
RUN mkdir -p /var/lib/proxmox-mock /var/log/proxmox-mock && \
    chown -R proxmox:proxmox /var/lib/proxmox-mock /var/log/proxmox-mock /app

# Switch to app user
USER proxmox

# Expose port
EXPOSE 8006

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:8006/api2/json/version || exit 1

# Start the application
CMD ["python", "-m", "src.main"]
