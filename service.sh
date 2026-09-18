#!/system/bin/sh
# Copyright (c) Teletalker Digital Solution. All rights reserved.
# Proprietary and confidential. Unauthorized copying or distribution prohibited.
# Enhanced service script with streaming support (late_start).
# Privilege acquisition is centralized in ensure_privileges() (boot_common.sh).

source "${0%/*}/boot_common.sh" /data/local/tmp/teletalker_service.log

MODDIR="/data/adb/modules/com.teletalker.app"
WORK_DIR="/data/local/tmp/call_injector"
LOG_FILE="$WORK_DIR/service.log"

# Remove hard restrictions FIRST so the protected perms become grantable.
header Remove hard restrictions
run_cli_apk com.teletalker.app.standalone.RemoveHardRestrictionsKt

# Samsung A11 fix: force resource cache refresh / re-indexing.
header Force package re-indexing
pm compile -m verify -f "${app_id}" 2>/dev/null || true
cmd package compile -m speed-profile -f "${app_id}" 2>/dev/null || true
rm -rf /data/resource-cache/*"${app_id}"* 2>/dev/null || true

# Reliable, verified runtime-permission + appops acquisition (bounded, idempotent).
# Waits for the package manager, grants -> verifies -> retries, then snapshots state.
header Ensure privileges
ensure_privileges

header Package state
dumpsys package "${app_id}"

# Fix SELinux label on the app's DE storage.
header Fixing DP storage SELinux label
restorecon -RDv /data/user_de/0/"${app_id}" 2>/dev/null || true

# ---- Audio streaming setup (best-effort FIFO enhancement) ----
header Setting up audio streaming
mkdir -p "$WORK_DIR"
chmod 777 "$WORK_DIR"

# Copy/update scripts from the module into the work dir, and make them executable.
if [ -d "$MODDIR/scripts" ]; then
    cp "$MODDIR/scripts/"*.sh "$WORK_DIR/" 2>/dev/null || true
    find "$WORK_DIR" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true
    find "$MODDIR/scripts" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true
fi

# Run mixer detection (writes mixer_config.txt; harmless if it fails).
echo "$(date): Running mixer detection..." >> "$LOG_FILE"
if [ -f "$WORK_DIR/detect_mixers.sh" ]; then
    "$WORK_DIR/detect_mixers.sh" >> "$LOG_FILE" 2>&1 || true
fi

# Create the streaming FIFO. World-writable is intentional (internal build):
# the app's untrusted_app domain must be able to open it for writing.
PIPE_FILE="$WORK_DIR/audio_stream.pipe"
rm -f "$PIPE_FILE" 2>/dev/null || true
mkfifo "$PIPE_FILE" 2>/dev/null || true
chmod 666 "$PIPE_FILE" 2>/dev/null || true
chcon -R u:object_r:app_data_file:s0 "$WORK_DIR" 2>/dev/null || true

# Hidden-API access + battery exemption (kept broad for reliability).
settings put global hidden_api_policy 1 2>/dev/null || true
dumpsys deviceidle whitelist +com.teletalker.app 2>/dev/null || true

# SELinux permissive is kept for this internal build to maximize injection
# reliability across devices; the scoped sepolicy.rule is also shipped as a
# backup. Security hardening is explicitly out of scope for this build.
setenforce 0 2>/dev/null || true

# Audio-policy overrides that help the recording path.
setprop persist.audio.voicecall 1 2>/dev/null || true
setprop persist.vendor.audio.voicecall 1 2>/dev/null || true

echo "$(date): Audio streaming setup complete" >> "$LOG_FILE"
