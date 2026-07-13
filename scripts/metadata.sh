#!/bin/bash
# SynapseOS metadata generation
# Usage: ./scripts/metadata.sh <version> [iso-path]
# Can be sourced (provides generate_metadata()) or executed directly.

set -Eeuo pipefail

generate_metadata() {
    local version="$1"
    local iso_path="$2"

    local git_commit git_branch build_time iso_size package_count kernel_version

    git_commit=$(git -C "$PROJECT_ROOT" rev-parse HEAD 2>/dev/null || echo "unknown")
    git_branch=$(git -C "$PROJECT_ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null || echo "unknown")
    build_time=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    iso_size=$(stat -c%s "$iso_path" 2>/dev/null || stat -f%z "$iso_path" 2>/dev/null || echo 0)
    package_count=$(wc -l < "${OUTPUT_DIR}/package.manifest" 2>/dev/null || echo 0)

    if [ -d "${PROJECT_ROOT}/chroot" ] && [ -x "${PROJECT_ROOT}/chroot" ]; then
        kernel_version=$(sudo chroot "${PROJECT_ROOT}/chroot" uname -r 2>/dev/null || echo "unknown")
    else
        kernel_version="unknown"
    fi

    cat > "${OUTPUT_DIR}/metadata.json" <<-METAEOF
{
  "distribution": "SynapseOS",
  "version": "${version}",
  "git_commit": "${git_commit}",
  "git_branch": "${git_branch}",
  "build_time": "${build_time}",
  "debian_version": "bookworm",
  "kernel_version": "${kernel_version}",
  "architecture": "amd64",
  "package_count": ${package_count},
  "iso_size_bytes": ${iso_size},
  "iso_filename": "synapseos-${version}-amd64.hybrid.iso",
  "builder_name": "${BUILDER_NAME:-$(whoami)}",
  "build_machine": "$(hostname 2>/dev/null || echo 'unknown')",
  "build_system": "live-build",
  "build_host": "$(uname -a 2>/dev/null || echo 'unknown')"
}
METAEOF
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    OUTPUT_DIR="${PROJECT_ROOT}/output"
    VERSION="${1:-$(cd "$PROJECT_ROOT" && git describe --tags --always --dirty 2>/dev/null || echo '0.0.0')}"
    ISO_PATH="${2:-$(find "$OUTPUT_DIR" -name '*.iso' -type f | head -1)}"
    if [ -z "$ISO_PATH" ]; then
        echo "No ISO found. Specify path as second argument." >&2
        exit 1
    fi
    generate_metadata "$VERSION" "$ISO_PATH"
    echo "Metadata written to ${OUTPUT_DIR}/metadata.json"
fi
