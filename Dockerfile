# Dockerfile for Kamal deployments
# This creates a single image containing all configurations

FROM alpine:3.19

# Install required packages
RUN apk add --no-cache \
    docker-cli \
    docker-compose \
    bash \
    curl \
    jq \
    openssh-client \
    git

# Set working directory
WORKDIR /opt/homelab

# Copy configuration files
COPY config/ ./config/
COPY scripts/ ./scripts/
COPY docker-compose.yml ./
COPY Makefile ./
COPY README.md ./
COPY docs/ ./docs/

# Make scripts executable
RUN chmod +x scripts/*.sh

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s --retries=3 \
    CMD curl -f http://localhost:8080/ping || exit 1

# Default command
CMD ["docker-compose", "up", "-d"]

