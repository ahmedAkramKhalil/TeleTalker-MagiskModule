#!/system/bin/sh
# Enhanced mixer detection script with better error handling and broader device support
# FIXED: Proper binary usage and detection logic

set -e  # Exit on any error

# IMPORTANT: Separate files for config and logs
CONFIG_FILE="/data/local/tmp/call_injector/mixer_config.txt"
LOGFILE="/data/local/tmp/call_injector/detection.log"
LOGDIR="/data/local/tmp/call_injector"

MIXER_CONTROL=""
DEVICE_ID=""
DEVICE_MODEL=$(getprop ro.product.model)
DEVICE_VENDOR=$(getprop ro.product.vendor)

# Create directory if it doesn't exist
mkdir -p "$LOGDIR"

# Clear previous log
> "$LOGFILE"

# Function to log messages (to LOG file, not config!)
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOGFILE"
}

# Find tinyalsa binaries FIRST
find_binary() {
    local bin="$1"
    for path in /system/bin /vendor/bin /system/xbin; do
        if [ -x "$path/$bin" ]; then
            echo "$path/$bin"
            return 0
        fi
    done
    # Fallback: try which command
    if which "$bin" >/dev/null 2>&1; then
        which "$bin"
        return 0
    fi
    # Last resort fallback
    echo "/system/bin/$bin"
    return 1
}

# Find binary paths
TINYMIX_BIN=$(find_binary "tinymix")
TINYPLAY_BIN=$(find_binary "tinyplay")

# NOW check if tinymix is available (after trying to find it)
if [ ! -x "$TINYMIX_BIN" ]; then
    log_message "ERROR: tinymix not found at $TINYMIX_BIN. Audio injection not supported on this device."
    exit 1
fi

log_message "Starting mixer detection on $DEVICE_VENDOR $DEVICE_MODEL"
log_message "Using tinymix: $TINYMIX_BIN"
log_message "Using tinyplay: $TINYPLAY_BIN"
log_message "Available mixer controls:"
$TINYMIX_BIN controls | head -20 >> "$LOGFILE"

# Function to test mixer control safely (USING DETECTED BINARY)
test_mixer() {
    local control="$1"
    log_message "Testing mixer control: $control"
    
    # Check if control exists first
    if ! $TINYMIX_BIN controls | grep -q "$control"; then
        log_message "Control '$control' not found in mixer"
        return 1
    fi
    
    # Try to set it to 1 and then back to 0
    if $TINYMIX_BIN set "$control" 1 2>/dev/null && $TINYMIX_BIN set "$control" 0 2>/dev/null; then
        log_message "Control '$control' test successful"
        return 0
    else
        log_message "Control '$control' test failed"
        return 1
    fi
}

# Function to get device ID from multimedia name (SAME AS OLD SCRIPT)
get_device_id() {
    local mm="$1"
    case $mm in
        "MultiMedia1") echo "0" ;;
        "MultiMedia2") echo "1" ;;
        "MultiMedia5") echo "12" ;;
        "MultiMedia9") echo "14" ;;
        "MultiMedia3") echo "2" ;;
        "MultiMedia4") echo "3" ;;
        "MultiMedia6") echo "13" ;;
        "MultiMedia7") echo "15" ;;
        "MultiMedia8") echo "16" ;;
        *) echo "0" ;;  # Default fallback
    esac
}

# Extended list of multimedia devices to test (SAME AS OLD SCRIPT)
MM_DEVICES="MultiMedia1 MultiMedia2 MultiMedia3 MultiMedia4 MultiMedia5 MultiMedia6 MultiMedia7 MultiMedia8 MultiMedia9"

# Test Incall_Music controls first (most common) - SAME LOGIC AS OLD SCRIPT
log_message "Testing Incall_Music Audio Mixer controls..."
for mm in $MM_DEVICES; do
    control="Incall_Music Audio Mixer $mm"
    if test_mixer "$control"; then
        MIXER_CONTROL="$control"
        DEVICE_ID=$(get_device_id "$mm")
        log_message "Found working control: $MIXER_CONTROL with device ID: $DEVICE_ID"
        break
    fi
done

# If not found, try Incall_Music_2 - SAME LOGIC AS OLD SCRIPT
if [ -z "$MIXER_CONTROL" ]; then
    log_message "Testing Incall_Music_2 Audio Mixer controls..."
    for mm in $MM_DEVICES; do
        control="Incall_Music_2 Audio Mixer $mm"
        if test_mixer "$control"; then
            MIXER_CONTROL="$control"
            DEVICE_ID=$(get_device_id "$mm")
            log_message "Found working control: $MIXER_CONTROL with device ID: $DEVICE_ID"
            break
        fi
    done
fi

# Try alternative naming patterns for different vendors - SAME LOGIC AS OLD SCRIPT
if [ -z "$MIXER_CONTROL" ]; then
    log_message "Testing alternative mixer control patterns..."
    
    # Samsung/Exynos patterns
    for mm in $MM_DEVICES; do
        control="CALL_REC Audio Mixer $mm"
        if test_mixer "$control"; then
            MIXER_CONTROL="$control"
            DEVICE_ID=$(get_device_id "$mm")
            break
        fi
    done
    
    # MediaTek patterns
    if [ -z "$MIXER_CONTROL" ]; then
        for mm in $MM_DEVICES; do
            control="CALL_RECORD Audio Mixer $mm"
            if test_mixer "$control"; then
                MIXER_CONTROL="$control"
                DEVICE_ID=$(get_device_id "$mm")
                break
            fi
        done
    fi
fi

# Create CLEAN configuration file (no logs, only variables!)
cat > "$CONFIG_FILE" << EOF
# Mixer configuration for $DEVICE_VENDOR $DEVICE_MODEL
# Generated on $(date)
MIXER_CONTROL="$MIXER_CONTROL"
DEVICE_ID="$DEVICE_ID"
TINYMIX_BIN="$TINYMIX_BIN"
TINYPLAY_BIN="$TINYPLAY_BIN"
DETECTION_SUCCESS=$([ -n "$MIXER_CONTROL" ] && echo "true" || echo "false")
DEVICE_MODEL="$DEVICE_MODEL"
DEVICE_VENDOR="$DEVICE_VENDOR"
EOF

# Show results
if [ -n "$MIXER_CONTROL" ]; then
    log_message "SUCCESS: Detection complete."
    log_message "Mixer Control: $MIXER_CONTROL"
    log_message "Device ID: $DEVICE_ID"
    
    echo "========================================="
    echo "✓ Detection SUCCESSFUL!"
    echo "Mixer Control: $MIXER_CONTROL"
    echo "Device ID: $DEVICE_ID"
    echo "Config saved to: $CONFIG_FILE"
    echo "Log saved to: $LOGFILE"
    echo "========================================="
    
    # Test the configuration once more to be sure (USING DETECTED BINARY)
    if $TINYMIX_BIN controls | grep -q "$MIXER_CONTROL" && $TINYMIX_BIN set "$MIXER_CONTROL" 1 2>/dev/null && $TINYMIX_BIN set "$MIXER_CONTROL" 0 2>/dev/null; then
        log_message "Final validation successful"
        exit 0
    else
        log_message "ERROR: Final validation failed"
        exit 1
    fi
else
    log_message "ERROR: No compatible mixer control found"
    log_message "This device may not support audio injection"
    
    echo "========================================="
    echo "✗ Detection FAILED!"
    echo "No compatible mixer control found."
    echo "Check log at: $LOGFILE"
    echo "========================================="
    
    # Dump all available controls for debugging (USING DETECTED BINARY)
    log_message "All available mixer controls:"
    $TINYMIX_BIN controls >> "$LOGFILE" 2>&1
    
    exit 1
fi