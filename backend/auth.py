from functools import wraps
from flask import request, jsonify
from config import API_KEY


def require_auth(f):
    """Decorator to require Bearer token authentication"""
    @wraps(f)
    def decorated_function(*args, **kwargs):
        auth_header = request.headers.get('Authorization')

        if not auth_header:
            return jsonify({'error': 'No authorization header'}), 401

        try:
            scheme, token = auth_header.split()
            if scheme.lower() != 'bearer':
                return jsonify({'error': 'Invalid authorization scheme'}), 401

            if token != API_KEY:
                return jsonify({'error': 'Invalid token'}), 401

        except ValueError:
            return jsonify({'error': 'Invalid authorization header format'}), 401

        return f(*args, **kwargs)

    return decorated_function
