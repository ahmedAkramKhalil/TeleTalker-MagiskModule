#!/system/bin/sh
# Copyright (c) Teletalker Digital Solution. All rights reserved.
# Proprietary and confidential. Unauthorized copying or distribution prohibited.
# Stream injection script — SELinux-aware so the app's untrusted_app domain
# can actually open the FIFO for writing on modern Android/One UI.

MODE="${1:-stream}"
INPUT="$2"

WORK_DIR="/data/local/tmp/call_injector"
CONFIG_FILE="$WORK_DIR/mixer_config.txt"
PIPE_FILE="$WORK_DIR/audio_stream.pipe"
LOG_FILE="$WORK_DIR/injection.log"

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "Running detection first..." | tee -a "$LOG_FILE"
    "$WORK_DIR/detect_mixers.sh"
fi

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

TINYMIX_BIN="${TINYMIX_BIN:-tinymix}"
TINYPLAY_BIN="${TINYPLAY_BIN:-tinyplay}"

if [ -z "$MIXER_CONTROL" ] || [ -z "$DEVICE_ID" ]; then
    echo "ERROR: Invalid configuration" | tee -a "$LOG_FILE"
    exit 1
fi

# -----------------------------------------------------------------------------
# Make the FIFO + work dir reachable by the app's untrusted_app SELinux
# domain. Without this, open() returns EACCES even with mode 666 because
# SELinux runs the check before the DAC bits.
#
# We try the most permissive label first; if chcon fails we fall back to a
# couple of common labels that are also acceptable to untrusted_app.
# -----------------------------------------------------------------------------
relabel_for_app() {
    local target="$1"
    chcon u:object_r:fuse:s0            "$target" 2>>"$LOG_FILE" && return 0
    chcon u:object_r:media_rw_data_file:s0 "$target" 2>>"$LOG_FILE" && return 0
    chcon u:object_r:app_data_file:s0   "$target" 2>>"$LOG_FILE" && return 0
    echo "$(date): WARNING — could not relabel $target" >> "$LOG_FILE"
    return 1
}

# Stream mode function
inject_stream() {
    echo "$(date): Starting stream mode" >> "$LOG_FILE"

    # Ensure parent dir is reachable
    chmod 0777 "$WORK_DIR" 2>/dev/null
    relabel_for_app "$WORK_DIR"

    # Re-create the pipe with friendly perms + label each time. A stale FIFO
    # from a previous call could still carry the old (denied) context.
    rm -f "$PIPE_FILE" 2>/dev/null
    mkfifo "$PIPE_FILE"
    chmod 0666 "$PIPE_FILE"
    relabel_for_app "$PIPE_FILE"

    # Belt + braces: log the final state so future debugging is easy.
    ls -lZ "$PIPE_FILE" >> "$LOG_FILE" 2>&1

    echo "Stream pipe ready at: $PIPE_FILE"

    $TINYMIX_BIN set "$MIXER_CONTROL" 1

    while [ -p "$PIPE_FILE" ]; do
        if timeout 5 cat "$PIPE_FILE" 2>/dev/null | $TINYPLAY_BIN -i - -r 16000 -c 1 -b 16 -D 0 -d "$DEVICE_ID" 2>/dev/null; then
            echo "$(date): Stream chunk played" >> "$LOG_FILE"
        else
            [ ! -p "$PIPE_FILE" ] && break
            sleep 0.1
        fi
    done

    $TINYMIX_BIN set "$MIXER_CONTROL" 0
    echo "$(date): Stream mode ended" >> "$LOG_FILE"
}

# File mode function
inject_file() {
    local file="$1"
    echo "$(date): Injecting file: $file" >> "$LOG_FILE"

    $TINYMIX_BIN set "$MIXER_CONTROL" 1
    sleep 0.5
    $TINYPLAY_BIN "$file" -D 0 -d "$DEVICE_ID"
    $TINYMIX_BIN set "$MIXER_CONTROL" 0
}

case "$MODE" in
    stream) inject_stream ;;
    file)   inject_file "$INPUT" ;;
    *)      echo "Usage: $0 {stream|file <path>}"; exit 1 ;;
esac
