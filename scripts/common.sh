# SynapseOS common shell functions
# Source this file from all build scripts.
# Provides shared utilities, path constants, and version detection.

set -Eeuo pipefail

export PROJECT_ROOT="${PROJECT_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
export OUTPUT_DIR="${PROJECT_ROOT}/output"
export CONFIG_DIR="${PROJECT_ROOT}/config"
export SCRIPTS_DIR="${PROJECT_ROOT}/scripts"

readonly NC='\033[0m'
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly CYAN='\033[0;36m'

detect_version() {
    local desc
    if desc=$(git -C "$PROJECT_ROOT" describe --tags --match 'v*' --exact-match 2>/dev/null); then
        echo "${desc#v}"
    elif desc=$(git -C "$PROJECT_ROOT" describe --tags --always --dirty 2>/dev/null); then
        echo "${desc#v}"
    else
        echo "0.0.0-unknown"
    fi
}

ensure_root() {
    if [ "$(id -u)" -ne 0 ]; then
        echo "This command requires root privileges. Run with sudo." >&2
        exit 1
    fi
}

ensure_command() {
    local cmd="$1"
    if ! command -v "$cmd" &>/dev/null; then
        echo "Required command not found: $cmd" >&2
        exit 1
    fi
}

check_disk() {
    local required_mb="$1"
    local target="${2:-$PROJECT_ROOT}"
    local available_mb
    available_mb=$(df -m "$target" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -z "$available_mb" ] || [ "$available_mb" -lt "$required_mb" ]; then
        echo "Insufficient disk space. Required: ${required_mb}MB, Available: ${available_mb:-0}MB" >&2
        exit 1
    fi
}

check_memory() {
    local required_mb="$1"
    local available_mb
    available_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}')
    if [ -z "$available_mb" ] || [ "$available_mb" -lt "$required_mb" ]; then
        echo "Insufficient memory. Required: ${required_mb}MB, Available: ${available_mb:-0}MB" >&2
        exit 1
    fi
}
