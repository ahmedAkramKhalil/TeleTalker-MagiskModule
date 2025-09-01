#!/system/bin/sh
# Enhanced audio injection script with streaming support and proper error handling

set -e  # Exit on any error

# Parse arguments
AUDIO_INPUT="$1"
MODE="${2:-file}"  # "file" or "stream" - defaults to "file"

# Configuration files
CONFIG_FILE="/data/local/tmp/call_injector/mixer_config.txt"
LOG_FILE="/data/local/tmp/call_injector/injection.log"
DETECT_SCRIPT="/data/adb/modules/com.teletalker.app/detect_mixers.sh"
PIPE_FILE="/data/local/tmp/call_injector/audio_stream.pipe"

# Process tracking
PLAY_PID=""
IS_STREAMING=0

# Cleanup function
cleanup() {
    local exit_code=$?
    log_message "Cleanup: Disabling mixer control"
    
    # Kill any running tinyplay process
    if [ -n "$PLAY_PID" ]; then
        kill $PLAY_PID 2>/dev/null || true
    fi
    
    if [ -n "$MIXER_CONTROL" ]; then
        tinymix "$MIXER_CONTROL" 0 2>/dev/null || true
    fi
    
    # Clean up pipe if in streaming mode
    if [ "$IS_STREAMING" -eq 1 ] && [ -p "$PIPE_FILE" ]; then
        rm -f "$PIPE_FILE" 2>/dev/null || true
        log_message "Cleaned up streaming pipe"
    fi
    
    log_message "Injection script finished with exit code: $exit_code"
    exit $exit_code
}

# Set up cleanup trap
trap cleanup EXIT INT TERM

# Logging function
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
}

# Load configuration (ORIGINAL WORKING METHOD)
load_config() {
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "Config file not found, running detection..."
        if [ -f "$DETECT_SCRIPT" ]; then
            sh "$DETECT_SCRIPT"
        else
            log_message "ERROR: Detection script not found: $DETECT_SCRIPT"
            return 1
        fi
    fi
    
    if [ ! -f "$CONFIG_FILE" ]; then
        log_message "ERROR: Configuration file still missing after detection"
        return 1
    fi
    
    # Parse config file - ORIGINAL METHOD THAT WORKS
    MIXER_CONTROL=$(grep '^MIXER_CONTROL=' "$CONFIG_FILE" | cut -d'"' -f2)
    DEVICE_ID=$(grep '^DEVICE_ID=' "$CONFIG_FILE" | cut -d'"' -f2)
    
    log_message "Loaded config - Mixer: '$MIXER_CONTROL', Device: '$DEVICE_ID'"
    
    if [ -z "$MIXER_CONTROL" ] || [ -z "$DEVICE_ID" ]; then
        log_message "ERROR: Invalid configuration - missing mixer control or device ID"
        return 1
    fi
    
    return 0
}

# Setup streaming pipe
setup_streaming_pipe() {
    log_message "Setting up streaming pipe: $PIPE_FILE"
    
    # Create directory if it doesn't exist
    mkdir -p "$(dirname "$PIPE_FILE")"
    
    # Remove old pipe if it exists
    if [ -e "$PIPE_FILE" ]; then
        rm -f "$PIPE_FILE"
    fi
    
    # Create new named pipe
    if ! mkfifo "$PIPE_FILE"; then
        log_message "ERROR: Failed to create named pipe"
        return 1
    fi
    
    # CRITICAL: Set proper permissions and ownership for app access
    chmod 666 "$PIPE_FILE"
    
    # Get the app's UID
    APP_UID=$(dumpsys package com.teletalker.app | grep userId= | head -1 | cut -d'=' -f2 | cut -d' ' -f1)
    
    if [ -n "$APP_UID" ]; then
        # Change ownership to app user
        chown $APP_UID:$APP_UID "$PIPE_FILE"
        log_message "Set pipe owner to app UID: $APP_UID"
    fi
    
    # Fix SELinux context for app access
    chcon u:object_r:app_data_file:s0 "$PIPE_FILE" 2>/dev/null || true
    
    # Make the directory accessible too
    chmod 777 "$(dirname "$PIPE_FILE")"
    
    log_message "Streaming pipe created with proper permissions"
    return 0
}

# Stream mode injection
#!/system/bin/sh

# Stream mode injection - Direct PCM approach
inject_stream_mode() {
    log_message "Starting stream mode injection"
    IS_STREAMING=1
    
    # Setup pipe
    if ! setup_streaming_pipe; then
        exit 1
    fi
    
    log_message "Enabling mixer control: $MIXER_CONTROL"
    tinymix "$MIXER_CONTROL" 1 || exit 1
    
    sleep 0.5
    
    # Method 1: Use a loop to feed data chunks
    log_message "Starting streaming loop"
    
    # Keep the pipe open for reading
    exec 3< "$PIPE_FILE"
    
    # Process audio in chunks
    while [ -p "$PIPE_FILE" ]; do
        # Read a chunk from pipe to a temp file
        CHUNK_FILE="/data/local/tmp/call_injector/chunk_$$.wav"
        
        # Create WAV header for each chunk
        {
            printf "RIFF"
            printf "\x24\x08\x00\x00"  # Small size for chunk (2084 bytes)
            printf "WAVEfmt "
            printf "\x10\x00\x00\x00"
            printf "\x01\x00"          # PCM
            printf "\x01\x00"          # Mono
            printf "\x80\x3e\x00\x00"  # 16000 Hz
            printf "\x00\x7d\x00\x00"  # Byte rate
            printf "\x02\x00"          # Block align
            printf "\x10\x00"          # 16 bits
            printf "data"
            printf "\x00\x08\x00\x00"  # 2048 bytes of data
        } > "$CHUNK_FILE"
        
        # Read 2048 bytes from pipe (or timeout after 1 second)
        if timeout 1 dd if="$PIPE_FILE" bs=2048 count=1 >> "$CHUNK_FILE" 2>/dev/null; then
            # Play the chunk
            tinyplay "$CHUNK_FILE" -D 0 -d "$DEVICE_ID" 2>/dev/null
        else
            # No data received, check if we should continue
            if [ ! -p "$PIPE_FILE" ]; then
                log_message "Pipe closed, stopping"
                break
            fi
        fi
        
        # Clean up chunk file
        rm -f "$CHUNK_FILE"
    done
    
    # Close pipe
    exec 3<&-
    
    log_message "Streaming loop ended"
    tinymix "$MIXER_CONTROL" 0
}


# File mode injection (original working code)
inject_file_mode() {
    log_message "Starting file mode injection"
    
    # Validate audio file
    if [ ! -f "$AUDIO_INPUT" ]; then
        log_message "ERROR: Audio file not found: $AUDIO_INPUT"
        exit 1
    fi
    
    log_message "Enabling mixer control: $MIXER_CONTROL"
    if ! tinymix "$MIXER_CONTROL" 1; then
        log_message "ERROR: Failed to enable mixer control"
        exit 1
    fi
    
    # Small delay to let mixer settle
    sleep 0.5
    
    log_message "Playing audio file: $AUDIO_INPUT (Device: $DEVICE_ID)"
    
    # Play audio with timeout using background process
    timeout 60 tinyplay "$AUDIO_INPUT" -D 0 -d "$DEVICE_ID" &
    PLAY_PID=$!
    
    # Wait for playback to complete
    wait $PLAY_PID
    PLAY_RESULT=$?
    
    if [ $PLAY_RESULT -eq 0 ]; then
        log_message "Audio playback completed successfully"
    elif [ $PLAY_RESULT -eq 124 ]; then
        log_message "ERROR: Audio playback timed out"
    else
        log_message "ERROR: Audio playback failed with exit code: $PLAY_RESULT"
    fi
    
    log_message "Disabling mixer control: $MIXER_CONTROL"
    if ! tinymix "$MIXER_CONTROL" 0; then
        log_message "WARNING: Failed to disable mixer control"
    fi
    
    exit $PLAY_RESULT
}

# Check required tools
check_tools() {
    if ! command -v tinymix >/dev/null 2>&1; then
        log_message "ERROR: tinymix not found"
        return 1
    fi
    
    if ! command -v tinyplay >/dev/null 2>&1; then
        log_message "ERROR: tinyplay not found"
        return 1
    fi
    
    if [ "$MODE" = "stream" ] && ! command -v mkfifo >/dev/null 2>&1; then
        log_message "ERROR: mkfifo not found (required for streaming)"
        return 1
    fi
    
    return 0
}

# Check call state
check_call_state() {
    local audio_mode=$(getprop vendor.audio.record.mode 2>/dev/null || echo "unknown")
    local call_state=$(getprop vendor.ril.telephony.call_state 2>/dev/null || echo "unknown")
    
    log_message "Audio mode: $audio_mode, Call state: $call_state"
    return 0
}

# Main execution
main() {
    log_message "========================================="
    log_message "Starting audio injection - Mode: $MODE"
    
    # Check tools
    if ! check_tools; then
        exit 1
    fi
    
    # Load configuration
    if ! load_config; then
        exit 1
    fi
    
    # Check call state
    check_call_state
    
    # Test mixer control exists
    if ! tinymix | grep -q "$MIXER_CONTROL"; then
        log_message "ERROR: Mixer control '$MIXER_CONTROL' not found"
        exit 1
    fi
    
    # Execute based on mode
    case "$MODE" in
        stream)
            inject_stream_mode
            ;;
        file)
            if [ -z "$AUDIO_INPUT" ]; then
                log_message "ERROR: No audio file specified for file mode"
                exit 1
            fi
            inject_file_mode
            ;;
        *)
            log_message "ERROR: Invalid mode: $MODE (use 'file' or 'stream')"
            exit 1
            ;;
    esac
}

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Run main function
main "$@"