import os

# API Configuration
API_KEY = os.environ.get('API_KEY', 'your-secret-api-key-123')
SECRET_KEY = os.environ.get('SECRET_KEY', 'flask-secret-key-456')

# Paths
BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MUSIC_DIR = os.path.join(BASE_DIR, 'music')
DATA_DIR = os.path.join(BASE_DIR, 'data')
SONGS_DB = os.path.join(DATA_DIR, 'songs.json')

# Upload settings
ALLOWED_EXTENSIONS = {'mp3', 'flac', 'opus'}
MAX_CONTENT_LENGTH = 100 * 1024 * 1024  # 100MB max file size
