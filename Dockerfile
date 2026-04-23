# --- Build Stage ---
FROM python:3.12-slim AS builder
WORKDIR /build
COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

# --- Runtime Stage ---
FROM python:3.12-slim
WORKDIR /app

# Copy the installed libraries from the builder
COPY --from=builder /usr/local/lib/python3.12/site-packages /usr/local/lib/python3.12/site-packages
COPY --from=builder /usr/local/bin /usr/local/bin

COPY app/ ./app/

# Create a non-root user for security
RUN useradd -m appuser && chown -R appuser:appuser /app
USER appuser

EXPOSE 8080

# Gunicorn will look for 'create_app()' inside the 'app' package
CMD ["gunicorn", "--bind", "0.0.0.0:8080", "app:create_app()"]