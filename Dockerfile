# Use Python 3.11 slim image
FROM python:3.11-slim

# Set working directory
WORKDIR /app

# Install uv
COPY --from=ghcr.io/astral-sh/uv:latest /uv /usr/local/bin/uv

# Set environment variables
ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    UV_SYSTEM_PYTHON=1

# Copy backend requirements
COPY backend/requirements.txt /app/requirements.txt

# Install Python dependencies using uv
RUN uv pip install --system --no-cache -r requirements.txt

# Copy backend code
COPY backend/ /app/

# Create directories for music and data
RUN mkdir -p /app/music /app/data

# Expose port
EXPOSE 5000

# Set default API key (can be overridden with environment variable)
ENV API_KEY=your-secret-api-key-123

# Run the application
CMD ["python", "app.py"]
