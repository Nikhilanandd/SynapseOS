#!/bin/bash
# SynapseOS QEMU boot verification
# Usage: ./scripts/test-qemu.sh [iso-path]
#
# Boots a SynapseOS ISO in QEMU with KVM and verifies it reaches
# the login prompt within a timeout.

set -Eeuo pipefail

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT_DIR="${PROJECT_ROOT}/output"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Default ISO path
if [ $# -ge 1 ]; then
    ISO_PATH="$1"
else
    ISO_PATH=$(find "$OUTPUT_DIR" -name "*.iso" -type f | head -1)
fi

if [ -z "$ISO_PATH" ] || [ ! -f "$ISO_PATH" ]; then
    echo -e "${RED}ERROR: ISO not found at ${ISO_PATH:-<none>}${NC}"
    echo "Usage: $0 [path-to-iso]"
    exit 1
fi

echo -e "${YELLOW}=== SynapseOS QEMU Boot Test ===${NC}"
echo "ISO:  $ISO_PATH"
echo ""

# Check for required commands
for cmd in qemu-system-x86_64 qemu-kvm; do
    if command -v "$cmd" &>/dev/null; then
        QEMU_CMD="$cmd"
        break
    fi
done

if [ -z "${QEMU_CMD:-}" ]; then
    echo -e "${RED}ERROR: qemu-system-x86_64 or qemu-kvm not found${NC}"
    echo "Install with: sudo apt-get install -y qemu-system-x86 qemu-kvm"
    exit 1
fi

# Check for KVM support
KVM_FLAG=""
if [ -e /dev/kvm ]; then
    KVM_FLAG="-accel kvm"
    echo "KVM acceleration available"
else
    echo -e "${YELLOW}WARN: KVM not available, emulation will be slow${NC}"
fi

TIMEOUT="${TIMEOUT:-120}"
SERIAL_LOG=$(mktemp /tmp/synapseos-qemu-XXXXXX)
echo "Serial log: ${SERIAL_LOG}"
echo "Timeout:    ${TIMEOUT}s"
echo ""

# Cleanup on exit
cleanup() {
    kill "${QEMU_PID:-0}" 2>/dev/null || true
    wait "${QEMU_PID:-0}" 2>/dev/null || true
}
trap cleanup EXIT INT TERM

# Launch QEMU
"$QEMU_CMD" \
    -m 2048 \
    $KVM_FLAG \
    -cdrom "$ISO_PATH" \
    -boot d \
    -vga virtio \
    -display none \
    -serial file:"${SERIAL_LOG}" \
    -no-reboot \
    -cpu host \
    -smp 2 \
    -netdev user,id=net0 \
    -device virtio-net,netdev=net0 \
    -nographic \
    -append "console=tty0 console=ttyS0,115200n8 boot=live components quiet" \
    &
QEMU_PID=$!

echo "QEMU PID: ${QEMU_PID}"
echo "Waiting for boot (timeout: ${TIMEOUT}s)..."
echo ""

# Poll serial log for boot completion signals
BOOT_OK=0
BOOT_FAIL=1
RESULT=$BOOT_FAIL

END_TIME=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$END_TIME" ]; do
    if ! kill -0 "$QEMU_PID" 2>/dev/null; then
        echo -e "${YELLOW}QEMU process exited early${NC}"
        break
    fi
    if grep -q "login:" "${SERIAL_LOG}" 2>/dev/null; then
        echo -e "${GREEN}SUCCESS: Boot completed - login prompt detected${NC}"
        RESULT=$BOOT_OK
        break
    fi
    if grep -qi "kernel panic\|emergency\|failed to start\|reboot: restarting" "${SERIAL_LOG}" 2>/dev/null; then
        echo -e "${RED}FAILURE: Boot error detected in serial log${NC}"
        break
    fi
    sleep 2
done

if [ "$RESULT" -eq "$BOOT_FAIL" ]; then
    if kill -0 "$QEMU_PID" 2>/dev/null; then
        echo -e "${RED}FAILURE: Timed out after ${TIMEOUT}s${NC}"
    fi
    echo ""
    echo -e "${YELLOW}Last 30 lines of serial log:${NC}"
    tail -30 "${SERIAL_LOG}"
fi

echo ""
if [ "$RESULT" -eq "$BOOT_OK" ]; then
    echo -e "${GREEN}=== Boot Test PASSED ===${NC}"
else
    echo -e "${RED}=== Boot Test FAILED ===${NC}"
fi

rm -f "${SERIAL_LOG}"
exit "$RESULT"
