import os
import json
from datetime import datetime
from flask import Flask, request, jsonify, send_file
from flask_cors import CORS
from werkzeug.utils import secure_filename
from auth import require_auth
from config import (
    API_KEY, SECRET_KEY, MUSIC_DIR, DATA_DIR,
    SONGS_DB, ALLOWED_EXTENSIONS, MAX_CONTENT_LENGTH
)

app = Flask(__name__)
app.config['SECRET_KEY'] = SECRET_KEY
app.config['MAX_CONTENT_LENGTH'] = MAX_CONTENT_LENGTH
CORS(app)

# Ensure directories exist
os.makedirs(MUSIC_DIR, exist_ok=True)
os.makedirs(DATA_DIR, exist_ok=True)


def allowed_file(filename):
    """Check if file extension is allowed"""
    return '.' in filename and filename.rsplit('.', 1)[1].lower() in ALLOWED_EXTENSIONS


def load_songs():
    """Load songs database from JSON file"""
    if not os.path.exists(SONGS_DB):
        return []
    with open(SONGS_DB, 'r') as f:
        return json.load(f)


def save_songs(songs):
    """Save songs database to JSON file"""
    with open(SONGS_DB, 'w') as f:
        json.dump(songs, f, indent=2)


@app.route('/login', methods=['POST'])
def login():
    """Login endpoint - validates API key"""
    data = request.get_json()

    if not data or 'api_key' not in data:
        return jsonify({'error': 'API key required'}), 400

    if data['api_key'] == API_KEY:
        return jsonify({
            'success': True,
            'token': API_KEY,
            'message': 'Login successful'
        }), 200

    return jsonify({'error': 'Invalid API key'}), 401


@app.route('/songs', methods=['GET'])
@require_auth
def get_songs():
    """Get list of all songs"""
    songs = load_songs()
    return jsonify({'songs': songs}), 200


@app.route('/upload', methods=['POST'])
@require_auth
def upload_file():
    """Upload one or multiple music files"""
    if 'file' not in request.files and 'files' not in request.files:
        return jsonify({'error': 'No file(s) provided'}), 400

    # Get files from request - support both 'file' (single) and 'files' (multiple)
    files_to_upload = []

    # Check for multiple files
    if 'files' in request.files:
        files_list = request.files.getlist('files')
        files_to_upload.extend(files_list)

    # Check for single file
    if 'file' in request.files:
        single_file = request.files['file']
        if single_file.filename != '':
            files_to_upload.append(single_file)

    if not files_to_upload:
        return jsonify({'error': 'No file selected'}), 400

    uploaded_files = []
    failed_files = []
    songs = load_songs()

    for file in files_to_upload:
        if file.filename == '':
            continue

        if not allowed_file(file.filename):
            failed_files.append({
                'filename': file.filename,
                'error': f'Invalid file type. Allowed: {", ".join(ALLOWED_EXTENSIONS)}'
            })
            continue

        try:
            filename = secure_filename(file.filename)
            filepath = os.path.join(MUSIC_DIR, filename)

            # Save file
            file.save(filepath)

            # Get file info
            file_size = os.path.getsize(filepath)

            # Check if song already exists
            existing = next((s for s in songs if s['filename'] == filename), None)
            if existing:
                existing['updated_at'] = datetime.now().isoformat()
                existing['size'] = file_size
            else:
                songs.append({
                    'filename': filename,
                    'size': file_size,
                    'uploaded_at': datetime.now().isoformat(),
                    'title': filename.rsplit('.', 1)[0]
                })

            uploaded_files.append(filename)

        except Exception as e:
            failed_files.append({
                'filename': file.filename,
                'error': str(e)
            })

    # Save updated songs database
    save_songs(songs)

    # Prepare response
    response = {
        'success': len(uploaded_files) > 0,
        'uploaded': len(uploaded_files),
        'failed': len(failed_files),
        'files': uploaded_files
    }

    if failed_files:
        response['errors'] = failed_files

    status_code = 201 if len(uploaded_files) > 0 else 400

    return jsonify(response), status_code


@app.route('/stream/<filename>', methods=['GET'])
@require_auth
def stream_file(filename):
    """Stream a music file"""
    filename = secure_filename(filename)
    filepath = os.path.join(MUSIC_DIR, filename)

    if not os.path.exists(filepath):
        return jsonify({'error': 'File not found'}), 404

    return send_file(
        filepath,
        mimetype='audio/mpeg',
        as_attachment=False,
        download_name=filename
    )


@app.route('/download/<filename>', methods=['GET'])
@require_auth
def download_file(filename):
    """Download a music file"""
    filename = secure_filename(filename)
    filepath = os.path.join(MUSIC_DIR, filename)

    if not os.path.exists(filepath):
        return jsonify({'error': 'File not found'}), 404

    return send_file(
        filepath,
        mimetype='audio/mpeg',
        as_attachment=True,
        download_name=filename
    )


@app.route('/health', methods=['GET'])
def health():
    """Health check endpoint"""
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat()
    }), 200


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=5000, debug=True)
