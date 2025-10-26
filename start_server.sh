#!/bin/bash

# Start script for Music Server

echo "Starting Music Server..."

# Check if virtual environment exists
if [ ! -d "backend/venv" ]; then
    echo "Creating virtual environment..."
    python3 -m venv backend/venv
fi

# Activate virtual environment
source backend/venv/bin/activate

# Install dependencies if needed
echo "Installing dependencies..."
pip install -q -r backend/requirements.txt

# Set default API key if not already set
if [ -z "$API_KEY" ]; then
    export API_KEY="your-secret-api-key-123"
    echo "Using default API key: $API_KEY"
fi

# Create required directories
mkdir -p music data

echo ""
echo "========================================="
echo "Music Server is starting..."
echo "API Key: $API_KEY"
echo "Server will run on: http://0.0.0.0:5000"
echo "========================================="
echo ""

# Start the server
cd backend && python app.py
