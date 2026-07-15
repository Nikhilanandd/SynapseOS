#!/bin/bash
# Install OpenCode - CLI AI coding tool
set -euo pipefail

if command -v opencode &>/dev/null; then
    echo "opencode already installed, skipping"
    exit 0
fi

echo "Installing OpenCode (CLI binary)..."

# Try binary install first (preferred)
if curl -fsSL https://opencode.ai/install | bash; then
    echo "opencode installed via install script"
    # Add to PATH for all users
    if [ -f "$HOME/.opencode/bin/opencode" ]; then
        ln -sf "$HOME/.opencode/bin/opencode" /usr/local/bin/opencode 2>/dev/null || true
    fi
    exit 0
fi

# Fallback: install via npm
echo "Falling back to npm install..."
npm install -g opencode-ai 2>/dev/null || {
    echo "WARN: opencode npm install failed. Install manually: npm i -g opencode-ai"
    exit 1
}
