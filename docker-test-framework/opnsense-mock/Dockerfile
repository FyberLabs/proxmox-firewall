FROM python:3.11-alpine

# Install required packages
RUN apk add --no-cache \
    curl \
    openssl \
    ca-certificates \
    && rm -rf /var/cache/apk/*

# Create app user
RUN addgroup -g 1000 opnsense && \
    adduser -D -s /bin/sh -u 1000 -G opnsense opnsense

# Set working directory
WORKDIR /app

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --upgrade pip && \
    pip install --no-cache-dir -r requirements.txt

# Copy application files
COPY src/ ./src/

# Create necessary directories
RUN mkdir -p /var/lib/opnsense-mock /var/log/opnsense-mock && \
    chown -R opnsense:opnsense /var/lib/opnsense-mock /var/log/opnsense-mock /app

# Generate self-signed certificate for HTTPS
RUN mkdir -p /app/certs && \
    openssl req -x509 -newkey rsa:4096 -keyout /app/certs/key.pem -out /app/certs/cert.pem -days 365 -nodes \
    -subj "/C=US/ST=Test/L=Test/O=OPNsense Mock/CN=localhost" && \
    chown -R opnsense:opnsense /app/certs

# Switch to app user
USER opnsense

# Expose port
EXPOSE 443

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -k -f https://localhost:443/health || exit 1

# Start the application
CMD ["uvicorn", "src.main:app", "--host", "0.0.0.0", "--port", "443", "--ssl-keyfile", "/app/certs/key.pem", "--ssl-certfile", "/app/certs/cert.pem"]
