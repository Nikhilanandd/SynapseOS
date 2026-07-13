#!/bin/bash
# SynapseOS pre-build validation
# Usage: ./scripts/validate.sh
# Can be sourced (provides validate()) or executed directly.

set -Eeuo pipefail

if [ -z "${PROJECT_ROOT:-}" ]; then
    PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
fi

_find_cmd() {
    local cmd="$1"
    command -v "$cmd" &>/dev/null && return 0
    for dir in /usr/sbin /usr/bin /sbin /bin; do
        [ -x "${dir}/${cmd}" ] && return 0
    done
    return 1
}

validate() {
    local errors=0

    echo "=== SynapseOS Validation ==="

    local required_commands=(lb sudo debootstrap mksquashfs xorriso dpkg git)
    for cmd in "${required_commands[@]}"; do
        if _find_cmd "$cmd"; then
            echo "  OK:      ${cmd}"
        else
            echo "  MISSING: ${cmd}"
            errors=$((errors + 1))
        fi
    done

    local required_dirs=(config config/package-lists)
    for dir in "${required_dirs[@]}"; do
        if [ ! -d "${PROJECT_ROOT}/${dir}" ]; then
            echo "  MISSING: ${dir}/"
            errors=$((errors + 1))
        else
            echo "  OK:      ${dir}/"
        fi
    done

    local required_configs=(config/common config/bootstrap config/chroot config/binary)
    for cfg in "${required_configs[@]}"; do
        if [ ! -f "${PROJECT_ROOT}/${cfg}" ]; then
            echo "  MISSING: ${cfg}"
            errors=$((errors + 1))
        else
            echo "  OK:      ${cfg}"
        fi
    done

    if ls "${PROJECT_ROOT}/config/package-lists/"*.list.chroot &>/dev/null 2>&1; then
        echo "  OK:      package lists (*.list.chroot)"
    else
        echo "  MISSING: no package lists in config/package-lists/"
        errors=$((errors + 1))
    fi

    local available_mb
    available_mb=$(df -m "${PROJECT_ROOT}" 2>/dev/null | awk 'NR==2 {print $4}')
    if [ -n "$available_mb" ] && [ "$available_mb" -ge 10240 ]; then
        echo "  OK:      disk space (${available_mb}MB available)"
    else
        echo "  WARN:    low disk space (${available_mb:-unknown}MB, 10240MB recommended)"
    fi

    local available_memory_mb
    available_memory_mb=$(free -m 2>/dev/null | awk '/^Mem:/ {print $7}')
    if [ -n "$available_memory_mb" ] && [ "$available_memory_mb" -ge 2048 ]; then
        echo "  OK:      memory (${available_memory_mb}MB available)"
    else
        echo "  WARN:    low memory (${available_memory_mb:-unknown}MB, 2048MB recommended)"
    fi

    if [ ! -r "${PROJECT_ROOT}/config" ]; then
        echo "  ERROR:   cannot read config directory"
        errors=$((errors + 1))
    fi

    if [ "$errors" -gt 0 ]; then
        echo ""
        echo "Validation FAILED with ${errors} error(s)"
        return 1
    fi

    echo ""
    echo "Validation PASSED"
    return 0
}

if [ "${BASH_SOURCE[0]}" = "$0" ]; then
    PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
    validate "$@"
fi
