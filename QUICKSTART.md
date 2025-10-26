# Quick Start Guide

## Start the Backend

### Option 1: Direct Python

```bash
./start_server.sh
```

### Option 2: Docker

```bash
docker build -t music-server .
docker run -d --name music-server -p 5000:5000 \
  -v $(pwd)/music:/app/music -v $(pwd)/data:/app/data music-server
```

Default settings:
- Server: `http://0.0.0.0:5000`
- API Key: `your-secret-api-key-123`

## Run the Flutter App

**Android:**
```bash
cd flutter_music_app
flutter pub get
flutter run  # Device must be connected
```

**Linux:**
```bash
cd flutter_music_app
flutter pub get
flutter run -d linux
```

## First Login

In the Flutter app, enter:
- **Server URL**: `http://YOUR_COMPUTER_IP:5000`
  - Find your IP: `ip addr` (Linux) or `ipconfig` (Windows)
  - Example: `http://192.168.1.100:5000`
- **API Key**: `your-secret-api-key-123`

## Features

- **Play**: Tap on any song to stream and play it
- **Upload**: Use the floating action button to upload music from your device
- **Download**: Tap the download icon on any song to save it locally to your device

## Test with curl

```bash
# Login
curl -X POST http://localhost:5000/login \
  -H "Content-Type: application/json" \
  -d '{"api_key":"your-secret-api-key-123"}'

# Upload a song
curl -X POST http://localhost:5000/upload \
  -H "Authorization: Bearer your-secret-api-key-123" \
  -F "file=@path/to/your/song.mp3"

# List songs
curl http://localhost:5000/songs \
  -H "Authorization: Bearer your-secret-api-key-123"
```

## Change API Key

Set environment variable before starting:
```bash
export API_KEY="my-super-secret-key"
./start_server.sh
```

Or edit `backend/config.py`
