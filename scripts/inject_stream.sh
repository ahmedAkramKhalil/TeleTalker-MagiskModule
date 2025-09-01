#!/system/bin/sh
# Stream injection script - Fixed for proper tinymix syntax

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

# Set defaults if not defined
TINYMIX_BIN="${TINYMIX_BIN:-tinymix}"
TINYPLAY_BIN="${TINYPLAY_BIN:-tinyplay}"

# Validate config
if [ -z "$MIXER_CONTROL" ] || [ -z "$DEVICE_ID" ]; then
    echo "ERROR: Invalid configuration" | tee -a "$LOG_FILE"
    exit 1
fi

# Stream mode function
inject_stream() {
    echo "$(date): Starting stream mode" >> "$LOG_FILE"
    
    # Create pipe
    if [ ! -p "$PIPE_FILE" ]; then
        rm -f "$PIPE_FILE" 2>/dev/null
        mkfifo "$PIPE_FILE"
        chmod 666 "$PIPE_FILE"
    fi
    
    echo "Stream pipe ready at: $PIPE_FILE"
    
    # Enable mixer - FIXED: Use proper syntax
    $TINYMIX_BIN set "$MIXER_CONTROL" 1
    
    # Stream loop
    while [ -p "$PIPE_FILE" ]; do
        if timeout 5 cat "$PIPE_FILE" 2>/dev/null | $TINYPLAY_BIN -i - -r 16000 -c 1 -b 16 -D 0 -d "$DEVICE_ID" 2>/dev/null; then
            echo "$(date): Stream chunk played" >> "$LOG_FILE"
        else
            [ ! -p "$PIPE_FILE" ] && break
            sleep 0.1
        fi
    done
    
    # Disable mixer - FIXED: Use proper syntax
    $TINYMIX_BIN set "$MIXER_CONTROL" 0
    echo "$(date): Stream mode ended" >> "$LOG_FILE"
}

# File mode function
inject_file() {
    local file="$1"
    echo "$(date): Injecting file: $file" >> "$LOG_FILE"
    
    # FIXED: Use proper syntax
    $TINYMIX_BIN set "$MIXER_CONTROL" 1
    sleep 0.5
    $TINYPLAY_BIN "$file" -D 0 -d "$DEVICE_ID"
    $TINYMIX_BIN set "$MIXER_CONTROL" 0
}

# Main execution
case "$MODE" in
    stream)
        inject_stream
        ;;
    file)
        [ -z "$INPUT" ] && echo "ERROR: No file specified" && exit 1
        [ ! -f "$INPUT" ] && echo "ERROR: File not found: $INPUT" && exit 1
        inject_file "$INPUT"
        ;;
    test)
        echo "Testing injection..."
        # FIXED: Use proper syntax
        $TINYMIX_BIN set "$MIXER_CONTROL" 1
        sleep 1
        $TINYMIX_BIN set "$MIXER_CONTROL" 0
        echo "Test complete"
        ;;
    *)
        echo "Usage: $0 [stream|file|test] [filename]"
        exit 1
        ;;
esac