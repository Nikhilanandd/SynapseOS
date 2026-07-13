#!/bin/bash
# SynapseOS Cleanup
# Usage: sudo ./clean.sh [--all]
#
# Removes build artifacts from the repository.
# Without arguments: removes build artifacts, preserves APT cache.
#   --all  Also purge APT caches and downloaded packages

set -Eeuo pipefail

export PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

clean_build() {
    local clean_all="${1:-false}"

    echo "=== SynapseOS Clean ==="
    echo ""

    if command -v lb &>/dev/null; then
        echo "  Cleaning live-build cache..."
        sudo lb clean --purge 2>/dev/null || true
    fi

    for dir in output cache chroot binary tmp .build; do
        if [ -e "${PROJECT_ROOT}/${dir}" ]; then
            echo "  Removing ${dir}/..."
            sudo rm -rf "${PROJECT_ROOT:?}/${dir}"
        fi
    done

    find "${PROJECT_ROOT}" -maxdepth 1 -name "*.iso" -type f -delete
    find "${PROJECT_ROOT}" -maxdepth 1 -name "filesystem.squashfs" -type f -delete

    if [ "$clean_all" = "true" ]; then
        echo "  Cleaning APT cache..."
        sudo apt-get clean 2>/dev/null || true
    fi

    echo ""
    echo "=== Clean Complete ==="
}

clean_build "${1:-}"
