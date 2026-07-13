#!/bin/bash
# SynapseOS Build System
# Usage: sudo ./build.sh [--clean] [--version]
#
# Single entry point for building SynapseOS ISO images.
# Running without arguments performs an incremental build.
#   --clean    Purge all caches and do a full clean build
#   --version  Print the detected version and exit

set -Eeuo pipefail

export PROJECT_ROOT="$(cd "$(dirname "$0")" && pwd)"

source "${PROJECT_ROOT}/scripts/common.sh"
source "${PROJECT_ROOT}/scripts/logger.sh"
source "${PROJECT_ROOT}/scripts/validate.sh"
source "${PROJECT_ROOT}/scripts/metadata.sh"
source "${PROJECT_ROOT}/scripts/build.sh"

clean_flag=false

for arg in "$@"; do
    case "$arg" in
        --clean) clean_flag=true ;;
        --version)
            detect_version
            exit 0
            ;;
        *)
            echo "Usage: sudo $0 [--clean] [--version]" >&2
            exit 1
            ;;
    esac
done

build_main "$clean_flag"
