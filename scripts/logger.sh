# SynapseOS logging framework
# Source this file after common.sh to enable structured build logging.

LOG_FILE="${LOG_FILE:-${OUTPUT_DIR}/build.log}"
BUILD_START_TIME=""

log_init() {
    mkdir -p "$(dirname "$LOG_FILE")"
    : > "$LOG_FILE"
    BUILD_START_TIME=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    log_info "Build started at ${BUILD_START_TIME}"
}

_log_timestamp() {
    date -u +"%Y-%m-%dT%H:%M:%SZ"
}

_log_elapsed() {
    if [ -n "$BUILD_START_TIME" ]; then
        local start_s end_s
        start_s=$(date -d "$BUILD_START_TIME" +%s 2>/dev/null || echo 0)
        end_s=$(date -u +%s)
        echo $((end_s - start_s))
    else
        echo 0
    fi
}

log_stage() {
    local ts
    ts=$(_log_timestamp)
    local elapsed
    elapsed=$(_log_elapsed)
    printf "[%s] [elapsed: %ds] === %s ===\n" "$ts" "$elapsed" "$*" | tee -a "$LOG_FILE"
}

log_info() {
    local ts
    ts=$(_log_timestamp)
    printf "[%s] INFO: %s\n" "$ts" "$*" | tee -a "$LOG_FILE"
}

log_warn() {
    local ts
    ts=$(_log_timestamp)
    printf "[%s] WARN: %s\n" "$ts" "$*" | tee -a "$LOG_FILE"
}

log_error() {
    local ts
    ts=$(_log_timestamp)
    printf "[%s] ERROR: %s\n" "$ts" "$*" | tee -a "$LOG_FILE" >&2
}
