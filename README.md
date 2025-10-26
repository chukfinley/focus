# Personal Music Server

A simple personal music streaming system with upload capabilities, designed for self-hosting.

## Features

- Simple token-based authentication
- Upload music files (MP3, FLAC, Opus)
- Stream music from your server
- Download songs to your device with progress indicators
- **Cross-platform app**: Android and Linux support
- Docker support with uv for fast builds
- No database required - uses JSON and local files

## Architecture

- **Backend**: Flask (Python) REST API
- **Frontend**: Flutter mobile app
- **Storage**: Local file system
- **Auth**: Bearer token authentication

## Setup

### Backend Setup

1. Navigate to the backend directory:
```bash
cd backend
```

2. Create a virtual environment and install dependencies:
```bash
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
pip install -r requirements.txt
```

3. Set your API key (optional, defaults to 'your-secret-api-key-123'):
```bash
export API_KEY="your-custom-api-key"
```

4. Run the server:
```bash
python app.py
```

The server will start on `http://0.0.0.0:5000`

### Docker Setup (Alternative)

If you prefer using Docker with **persistent storage**:

```bash
# Build the image
docker build -t music-server .

# Run the container with persistent volumes
docker run -d \
  --name music-server \
  --restart unless-stopped \
  -p 5000:5000 \
  -e API_KEY="your-custom-api-key" \
  -v $(pwd)/music:/app/music \
  -v $(pwd)/data:/app/data \
  music-server
```

**Important:** The `-v` flags mount local directories to persist your music and data.
Without these, your songs will be lost when the container is removed!

See [DOCKER.md](DOCKER.md) for detailed Docker instructions and deployment options.

### Flutter App Setup

The Flutter app supports **Android** and **Linux** platforms.

1. Navigate to the Flutter app directory:
```bash
cd flutter_music_app
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the app:

**For Android:**
```bash
# Connect your Android device via USB or start an emulator
flutter devices
flutter run
```

**For Linux:**
```bash
flutter run -d linux
```

**For Android APK (Release):**
```bash
flutter build apk --release
# APK will be in: build/app/outputs/flutter-apk/app-release.apk
```

### Configuration

#### Backend Configuration

Edit `backend/config.py` to customize:
- `API_KEY`: Authentication token (or set via environment variable)
- `MUSIC_DIR`: Directory for storing music files
- `ALLOWED_EXTENSIONS`: Supported audio formats
- `MAX_CONTENT_LENGTH`: Maximum upload file size

#### Flutter App Configuration

On first launch, enter:
- **Server URL**: Your server's IP and port (e.g., `http://192.168.1.100:5000`)
- **API Key**: The same key you configured in the backend

## API Endpoints

### Authentication

#### POST /login
Login with API key
```json
{
  "api_key": "your-secret-api-key-123"
}
```

Response:
```json
{
  "success": true,
  "token": "your-secret-api-key-123",
  "message": "Login successful"
}
```

### Songs

All endpoints below require `Authorization: Bearer <token>` header.

#### GET /songs
Get list of all songs
```json
{
  "songs": [
    {
      "filename": "song.mp3",
      "size": 5242880,
      "uploaded_at": "2024-01-15T10:30:00",
      "title": "song"
    }
  ]
}
```

#### POST /upload
Upload a music file
- Content-Type: `multipart/form-data`
- Field name: `file`
- Supported formats: MP3, FLAC, Opus

#### GET /stream/\<filename\>
Stream a music file
- Returns audio file with proper headers for streaming

#### GET /download/\<filename\>
Download a music file
- Returns audio file as attachment for download
- Same authentication as /stream endpoint

#### GET /health
Health check endpoint (no auth required)

## Deployment on Hetzner

1. Create a server instance on Hetzner Cloud

2. SSH into your server:
```bash
ssh root@your-server-ip
```

3. Install dependencies:
```bash
apt update
apt install python3 python3-pip python3-venv git -y
```

4. Clone your repository:
```bash
git clone https://github.com/your-username/music-server.git
cd music-server/backend
```

5. Set up the backend:
```bash
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

6. Set your API key:
```bash
export API_KEY="your-secure-api-key"
```

7. Run with a production server (using gunicorn):
```bash
pip install gunicorn
gunicorn -w 4 -b 0.0.0.0:5000 app:app
```

8. (Optional) Set up systemd service for auto-start:

Create `/etc/systemd/system/music-server.service`:
```ini
[Unit]
Description=Music Server
After=network.target

[Service]
User=root
WorkingDirectory=/root/music-server/backend
Environment="API_KEY=your-secure-api-key"
ExecStart=/root/music-server/backend/venv/bin/gunicorn -w 4 -b 0.0.0.0:5000 app:app
Restart=always

[Install]
WantedBy=multi-user.target
```

Enable and start:
```bash
systemctl enable music-server
systemctl start music-server
```

9. (Optional) Set up nginx as reverse proxy for HTTPS

10. Configure firewall:
```bash
ufw allow 5000/tcp
ufw enable
```

## Development

### Project Structure

```
.
├── backend/
│   ├── app.py              # Main Flask application
│   ├── auth.py             # Authentication middleware
│   ├── config.py           # Configuration
│   └── requirements.txt    # Python dependencies
├── flutter_music_app/
│   ├── lib/
│   │   ├── main.dart       # App entry point
│   │   ├── models/
│   │   │   └── song.dart   # Song model
│   │   ├── screens/
│   │   │   ├── login_screen.dart
│   │   │   └── music_list_screen.dart
│   │   └── services/
│   │       └── api_service.dart
│   └── pubspec.yaml        # Flutter dependencies
├── music/                  # Music files storage
├── data/                   # JSON database
│   └── songs.json          # Songs metadata
├── Dockerfile              # Docker image with uv
├── DOCKER.md               # Docker documentation
├── start_server.sh         # Quick start script
└── README.md               # This file
```

### Testing

Test the backend with curl:

```bash
# Login
curl -X POST http://localhost:5000/login \
  -H "Content-Type: application/json" \
  -d '{"api_key":"your-secret-api-key-123"}'

# Get songs
curl http://localhost:5000/songs \
  -H "Authorization: Bearer your-secret-api-key-123"

# Upload a song
curl -X POST http://localhost:5000/upload \
  -H "Authorization: Bearer your-secret-api-key-123" \
  -F "file=@/path/to/song.mp3"

# Stream a song
curl http://localhost:5000/stream/song.mp3 \
  -H "Authorization: Bearer your-secret-api-key-123" \
  --output song.mp3
```

## Security Notes

- Change the default API key in production
- Use HTTPS in production (set up nginx with SSL)
- Keep your API key secret
- Consider implementing rate limiting for production use
- For Hetzner deployment, use environment variables for secrets

## License

MIT
