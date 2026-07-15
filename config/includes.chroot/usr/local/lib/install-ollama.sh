#!/bin/bash
# Install Ollama - local LLM runner
set -euo pipefail

if command -v ollama &>/dev/null; then
    echo "ollama already installed, skipping"
    exit 0
fi

echo "Installing Ollama..."
curl -fsSL https://ollama.com/install.sh | sh

# Start the service immediately so user can pull models
systemctl enable ollama 2>/dev/null || true
systemctl start ollama 2>/dev/null || true

echo "ollama installed. Run 'ollama pull llama3.2:1b' to get a model."
