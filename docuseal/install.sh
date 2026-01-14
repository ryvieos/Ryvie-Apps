#!/bin/bash

# DocuSeal Installation Script
# Starts DocuSeal using Docker Compose

set -e

echo "Starting DocuSeal..."

# Check if Docker is installed
if ! command -v docker &> /dev/null; then
    echo "Error: Docker is not installed"
    exit 1
fi

# Check if Docker Compose is installed
if ! command -v docker compose &> /dev/null; then
    echo "Error: Docker Compose is not installed"
    exit 1
fi

# Start services
docker compose up -d

echo "DocuSeal is starting..."
echo "docuseal install by a script!"