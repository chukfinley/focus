# Docker Setup Guide

## Building the Image

Build the Docker image using uv:

```bash
docker build -t music-server .
```

## Running the Container

### Basic Usage

Run with default settings:

```bash
docker run -d \
  --name music-server \
  -p 5000:5000 \
  -v $(pwd)/music:/app/music \
  -v $(pwd)/data:/app/data \
  music-server
```

### With Custom API Key

```bash
docker run -d \
  --name music-server \
  -p 5000:5000 \
  -e API_KEY="my-super-secret-key" \
  -v $(pwd)/music:/app/music \
  -v $(pwd)/data:/app/data \
  music-server
```

## Volume Mounts

- `/app/music` - Directory for uploaded music files
- `/app/data` - Directory for JSON database (songs.json)

Mount these as volumes to persist data between container restarts.

## Environment Variables

- `API_KEY` - Authentication token (default: `your-secret-api-key-123`)
- `SECRET_KEY` - Flask secret key (default: `flask-secret-key-456`)

## Container Management

### View logs

```bash
docker logs music-server
```

### Follow logs

```bash
docker logs -f music-server
```

### Stop container

```bash
docker stop music-server
```

### Start container

```bash
docker start music-server
```

### Remove container

```bash
docker rm music-server
```

## Deploy to Hetzner with Docker

1. SSH into your Hetzner server:

```bash
ssh root@your-server-ip
```

2. Install Docker:

```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sh get-docker.sh
```

3. Clone your repository:

```bash
git clone https://github.com/your-username/music-server.git
cd music-server
```

4. Build and run:

```bash
docker build -t music-server .

docker run -d \
  --name music-server \
  --restart unless-stopped \
  -p 5000:5000 \
  -e API_KEY="your-production-api-key" \
  -v /root/music-server/music:/app/music \
  -v /root/music-server/data:/app/data \
  music-server
```

5. (Optional) Set up nginx reverse proxy for HTTPS:

```bash
apt install nginx certbot python3-certbot-nginx -y
```

Create nginx config at `/etc/nginx/sites-available/music-server`:

```nginx
server {
    listen 80;
    server_name your-domain.com;

    location / {
        proxy_pass http://localhost:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

Enable and get SSL certificate:

```bash
ln -s /etc/nginx/sites-available/music-server /etc/nginx/sites-enabled/
nginx -t
systemctl restart nginx
certbot --nginx -d your-domain.com
```

## Health Check

Check if the server is running:

```bash
curl http://localhost:5000/health
```

Expected response:

```json
{
  "status": "healthy",
  "timestamp": "2024-01-15T10:30:00.000000"
}
```

## Updating

To update the container with new code:

```bash
# Pull latest code
git pull

# Rebuild image
docker build -t music-server .

# Stop and remove old container
docker stop music-server
docker rm music-server

# Run new container
docker run -d \
  --name music-server \
  --restart unless-stopped \
  -p 5000:5000 \
  -e API_KEY="your-api-key" \
  -v $(pwd)/music:/app/music \
  -v $(pwd)/data:/app/data \
  music-server
```
