#!/system/bin/sh
# Enhanced service script with streaming support

source "${0%/*}/boot_common.sh" /data/local/tmp/bcr_service.log

# Existing BCR setup
header Remove hard restrictions
run_cli_apk com.teletalker.app.standalone.RemoveHardRestrictionsKt

header Package state
dumpsys package "${app_id}"

# Fix SELinux labels
header Fixing DP storage SELinux label
restorecon -RDv /data/user_de/0/"${app_id}"

# NEW: Streaming setup
header Setting up audio streaming
WORK_DIR="/data/local/tmp/call_injector"
LOG_FILE="$WORK_DIR/service.log"

# Create working directory
mkdir -p "$WORK_DIR"
chmod 777 "$WORK_DIR"

# Copy/update scripts from module
MODULE_DIR="/data/adb/modules/${app_id}"
if [ -d "$MODULE_DIR/scripts" ]; then
    cp "$MODULE_DIR/scripts/"*.sh "$WORK_DIR/" 2>/dev/null
    chmod 755 "$WORK_DIR/"*.sh
fi

# Run detection
echo "$(date): Running mixer detection..." >> "$LOG_FILE"
if [ -f "$WORK_DIR/detect_mixers.sh" ]; then
    "$WORK_DIR/detect_mixers.sh" >> "$LOG_FILE" 2>&1
fi

# Create named pipe for streaming
PIPE_FILE="$WORK_DIR/audio_stream.pipe"
rm -f "$PIPE_FILE" 2>/dev/null
mkfifo "$PIPE_FILE"
chmod 666 "$PIPE_FILE"

# Set SELinux contexts
chcon -R u:object_r:app_data_file:s0 "$WORK_DIR" 2>/dev/null

echo "$(date): Audio streaming setup complete" >> "$LOG_FILE"