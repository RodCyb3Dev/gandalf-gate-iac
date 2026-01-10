FROM python:3.10-alpine

LABEL org.opencontainers.image.source https://github.com/ghomasHudson/jellyfin-auto-collections

ENV RUNNING_IN_DOCKER true
ENV PYTHONUNBUFFERED=1

# Fix Alpine mirror TLS issues by using HTTP or skipping update if not critical
# The base Python image should already have updated packages
RUN sed -i 's|https://|http://|g' /etc/apk/repositories 2>/dev/null || true
RUN apk update --no-cache 2>&1 | grep -v "TLS: unspecified error" || true

WORKDIR /app

# Copy requirements first for better caching
COPY requirements.txt /app/requirements.txt

# Install Python dependencies
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY . /app

VOLUME [ "/app/config" ]

ENTRYPOINT [ "python3.10", "-u", "main.py", "--config", "/app/config/config.yaml" ]
