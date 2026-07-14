# SynapseOS build orchestration
# This file is sourced by the root build.sh entry point.
# Contains the main build logic: validation, live-build, artifact management.

LOCK_FILE="${PROJECT_ROOT}/.build.lock"

_acquire_lock() {
    if [ -f "$LOCK_FILE" ]; then
        local pid
        pid=$(cat "$LOCK_FILE" 2>/dev/null || echo 0)
        if [ "$pid" -gt 0 ] && kill -0 "$pid" 2>/dev/null; then
            log_error "Build already in progress (PID: ${pid}). Lock file: ${LOCK_FILE}"
            exit 1
        fi
        log_warn "Stale lock file found (PID: ${pid:-unknown}). Removing."
    fi
    echo "$$" > "$LOCK_FILE"
    trap '_release_lock' EXIT INT TERM
}

_release_lock() {
    rm -f "$LOCK_FILE"
}

build_main() {
    local clean_first="${1:-false}"

    local version
    version=$(detect_version)

    mkdir -p "$OUTPUT_DIR"
    LOG_FILE="${OUTPUT_DIR}/build.log"
    log_init

    log_stage "Build Starting"
    log_info "Building SynapseOS version: ${version}"

    ensure_root
    ensure_command lb
    _acquire_lock

    log_stage "Validating Environment"
    validate || { log_error "Validation failed"; exit 1; }

    export PATH="${PATH}:/usr/sbin:/sbin"
    export LB_ISO_APPLICATION="SynapseOS"
    export LB_ISO_PREPARER="SynapseOS Build System"
    export LB_ISO_PUBLISHER="SynapseOS Project"
    export LB_ISO_VOLUME="SynapseOS ${version}"

    if [ "$clean_first" = "true" ]; then
        log_stage "Clean Build Requested"
        log_info "Purging caches..."
        sudo lb clean --purge 2>/dev/null || true
    fi

    log_stage "Configuring live-build"
    sudo lb config 2>&1 | tee -a "$LOG_FILE" || \
        { log_error "lb config failed"; exit 1; }

    # Inject build-time overrides into .build/config so they take effect in lb build
    if [ -f .build/config ]; then
        sudo tee -a .build/config > /dev/null << EOF
LB_ISO_APPLICATION="${LB_ISO_APPLICATION}"
LB_ISO_PREPARER="${LB_ISO_PREPARER}"
LB_ISO_PUBLISHER="${LB_ISO_PUBLISHER}"
LB_ISO_VOLUME="${LB_ISO_VOLUME}"
EOF
    fi
    sudo chown -R "$(whoami)" .build config local 2>/dev/null || true

    log_stage "Running live-build"
    log_info "This may take a while. See ${LOG_FILE} for details."
    log_info "Distribution: bookworm, Architecture: amd64"

    local lb_exit=0
    sudo lb build 2>&1 | tee -a "$LOG_FILE" || lb_exit=$?

    if [ "$lb_exit" -eq 0 ]; then
        log_info "live-build completed successfully"
    else
        log_error "live-build failed. Check ${LOG_FILE} for details."
        sudo umount -lf chroot/dev chroot/proc chroot/sys chroot/run 2>/dev/null || true
        sudo lb clean 2>/dev/null || true
        exit 1
    fi

    # Clean up root-owned build artifacts so next checkout doesn't fail
    sudo umount -lf chroot/dev chroot/proc chroot/sys chroot/run 2>/dev/null || true
    sudo lb clean 2>/dev/null || true

    local iso_file
    iso_file=$(find "${PROJECT_ROOT}" -maxdepth 1 -name "*.iso" -type f | head -1)

    if [ -z "$iso_file" ]; then
        log_error "No ISO file found after build"
        exit 1
    fi

    local output_iso="${OUTPUT_DIR}/synapseos-${version}-amd64.hybrid.iso"

    log_stage "Organizing Artifacts"
    mv "$iso_file" "$output_iso"
    log_info "ISO moved to: ${output_iso}"

    log_stage "Generating Checksums"
    (cd "$OUTPUT_DIR" && sha256sum "synapseos-${version}-amd64.hybrid.iso" > SHA256SUMS)
    log_info "SHA256SUMS generated"

    log_stage "Generating Package Manifest"
    if [ -d "${PROJECT_ROOT}/chroot" ] && [ -x "${PROJECT_ROOT}/chroot" ]; then
        sudo chroot "${PROJECT_ROOT}/chroot" dpkg-query -W 2>/dev/null \
            > "${OUTPUT_DIR}/package.manifest" || \
        cat "${PROJECT_ROOT}/config/package-lists/"*.list.chroot \
            > "${OUTPUT_DIR}/package.manifest"
    else
        cat "${PROJECT_ROOT}/config/package-lists/"*.list.chroot \
            > "${OUTPUT_DIR}/package.manifest"
    fi
    log_info "Package manifest generated"

    log_stage "Generating Metadata"
    generate_metadata "$version" "$output_iso"

    local iso_size packages
    iso_size=$(stat -c%s "$output_iso" 2>/dev/null || echo 0)
    packages=$(wc -l < "${OUTPUT_DIR}/package.manifest" 2>/dev/null || echo 0)

    log_stage "Build Complete"
    log_info "Version:       ${version}"
    log_info "ISO Size:      ${iso_size} bytes ($(( iso_size / 1048576 ))MB)"
    log_info "Packages:      ${packages}"
    log_info "Output:        ${OUTPUT_DIR}"
    log_info "Build Log:     ${LOG_FILE}"

    sudo chown -R "$(whoami)" .build config local 2>/dev/null || true

    echo ""
    echo "========================================"
    echo "  SynapseOS Build Complete"
    echo "  Version: ${version}"
    echo "  ISO:     ${output_iso}"
    echo "========================================"
}
