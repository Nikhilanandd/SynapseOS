#!/bin/bash
# SynapseOS First Boot Setup
# Installs AI toolchain based on user-selected profile.
# Runs once via systemd synapse-firstboot.service.

set -euo pipefail

SYNAPSE_LIB="/usr/local/lib"
PROFILES_DIR="${SYNAPSE_LIB}/profiles"
MARKER_DIR="/var/lib/synapse"
MARKER_FILE="${MARKER_DIR}/setup-complete"
SETUP_LOG="/var/log/synapse-firstboot.log"
SYNAPSE_BIN="${SYNAPSE_LIB}/synapse-install-tool"

exec > >(tee -a "$SETUP_LOG") 2>&1

mkdir -p "$MARKER_DIR"

if [ -f "$MARKER_FILE" ]; then
    echo "Setup already completed. Remove ${MARKER_FILE} to re-run."
    exit 0
fi

# Only show menu on real first boot (not in docker/CI)
if [ ! -f /usr/bin/whiptail ]; then
    echo "whiptail not available. Skipping setup."
    touch "$MARKER_FILE"
    exit 0
fi

# Show profile selector
CHOICE=$(whiptail --title "SynapseOS Setup" --menu "\nChoose your AI toolchain profile:\n(Internet connection required)" 20 64 5 \
    "ai-developer"  "OpenCode + VSCodium + Ollama + Aider + Jupyter" \
    "ai-researcher" "Developer + PyTorch + LangChain + Transformers" \
    "ai-agent"      "Developer + LangChain + Chroma + AutoGen + CrewAI" \
    "minimal"       "Base system only, no extra tools" \
    3>&1 1>&2 2>&3)

if [ -z "$CHOICE" ] || [ "$?" -ne 0 ]; then
    echo "No profile selected. Skipping setup."
    touch "$MARKER_FILE"
    exit 0
fi

echo ""
echo "============================================"
echo "  SynapseOS Setup: ${CHOICE} profile"
echo "============================================"
echo ""

PROFILE_FILE="${PROFILES_DIR}/${CHOICE}.list"
if [ ! -f "$PROFILE_FILE" ]; then
    echo "ERROR: Profile not found: ${PROFILE_FILE}"
    exit 1
fi

# Source helper functions
if [ -f "${SYNAPSE_LIB}/synapse-install-tool" ]; then
    source "${SYNAPSE_LIB}/synapse-install-tool"
fi

INSTALLED=0
FAILED=0

while IFS= read -r line; do
    # Skip comments and blank lines
    case "$line" in
        ''|\#*) continue ;;
    esac

    # Parse: type  package  [args...]
    IFS=' ' read -r type package args <<< "$line"

    echo ""
    echo "--- Installing: ${package} (${type}) ---"

    set +e
    case "$type" in
        apt)
            apt install -y "$package" 2>&1
            ;;
        pipx)
            if command -v pipx &>/dev/null; then
                pipx install "$package" 2>&1
            else
                echo "SKIP: pipx not available"
            fi
            ;;
        uv)
            if command -v uv &>/dev/null; then
                uv tool install "$package" 2>&1 || uv pip install "$package" 2>&1
            else
                echo "SKIP: uv not available, falling back to pipx"
                pipx install "$package" 2>&1 || true
            fi
            ;;
        npm)
            npm install -g "$package" 2>&1
            ;;
        script)
            if [ -f "${SYNAPSE_LIB}/install-${package}.sh" ]; then
                bash "${SYNAPSE_LIB}/install-${package}.sh" 2>&1
            else
                echo "SKIP: Install script not found: install-${package}.sh"
            fi
            ;;
        binary)
            if [ -f "${SYNAPSE_LIB}/install-${package}.sh" ]; then
                bash "${SYNAPSE_LIB}/install-${package}.sh" 2>&1
            else
                echo "SKIP: Install script not found: install-${package}.sh"
            fi
            ;;
        *)
            echo "SKIP: Unknown type: ${type}"
            ;;
    esac
    RC=$?
    set -e

    if [ "$RC" -eq 0 ]; then
        echo "OK: ${package} installed successfully"
        INSTALLED=$((INSTALLED + 1))
    else
        echo "WARN: ${package} installation returned code ${RC}"
        FAILED=$((FAILED + 1))
    fi
done < "$PROFILE_FILE"

echo ""
echo "============================================"
echo "  SynapseOS Setup Complete"
echo "  Profile:    ${CHOICE}"
echo "  Installed:  ${INSTALLED}"
echo "  Failed:     ${FAILED}"
echo "  Log:        ${SETUP_LOG}"
echo "============================================"
echo ""

echo "${CHOICE}" > "$MARKER_FILE"
echo "$(date -u +%Y-%m-%dT%H:%M:%SZ)" >> "$MARKER_FILE"

# Clean up
apt-get clean 2>/dev/null || true

exit 0
