#!/system/bin/sh
# Common functions - Fixed for proper tinymix syntax

WORK_DIR="/data/local/tmp/call_injector"
CONFIG_FILE="$WORK_DIR/mixer_config.txt"

# Logging function
log_msg() {
    echo "$(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$WORK_DIR/service.log"
}

# Find binary function
find_binary() {
    local bin="$1"
    for path in /system/bin /vendor/bin /system/xbin; do
        [ -x "$path/$bin" ] && echo "$path/$bin" && return 0
    done
    which "$bin" 2>/dev/null
}

# Load configuration with backward compatibility
load_config() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        
        # Set defaults if not in config (backward compatibility)
        TINYMIX_BIN="${TINYMIX_BIN:-$(find_binary tinymix)}"
        TINYPLAY_BIN="${TINYPLAY_BIN:-$(find_binary tinyplay)}"
        
        # Export for use by other scripts
        export MIXER_CONTROL
        export DEVICE_ID
        export TINYMIX_BIN
        export TINYPLAY_BIN
        
        return 0
    fi
    return 1
}

# Check if in call
is_in_call() {
    local call_state=$(dumpsys telephony.registry 2>/dev/null | grep "mCallState" | tail -1)
    case "$call_state" in
        *"2"*) return 0 ;;  # CALL_STATE_OFFHOOK
        *) return 1 ;;
    esac
}

# Get audio mode
get_audio_mode() {
    dumpsys audio | grep "Mode:" | cut -d':' -f2 | xargs
}

# Run mixer command safely - FIXED: Use proper syntax
run_mixer() {
    local cmd="$1"
    local value="$2"
    
    # Load config if not loaded
    [ -z "$TINYMIX_BIN" ] && load_config
    
    if [ -n "$MIXER_CONTROL" ] && [ -n "$TINYMIX_BIN" ]; then
        $TINYMIX_BIN set "$MIXER_CONTROL" "$value"
        return $?
    fi
    return 1
}

# Enable injection - FIXED: Use proper syntax
enable_injection() {
    log_msg "Enabling audio injection"
    run_mixer set 1
}

# Disable injection - FIXED: Use proper syntax
disable_injection() {
    log_msg "Disabling audio injection"
    run_mixer set 0
}

# Test mixer control - FIXED: Use proper syntax
test_mixer_control() {
    # Load config if not loaded
    [ -z "$TINYMIX_BIN" ] && load_config
    
    if [ -n "$MIXER_CONTROL" ] && [ -n "$TINYMIX_BIN" ]; then
        # Test by setting to 1 then back to 0
        if $TINYMIX_BIN set "$MIXER_CONTROL" 1 2>/dev/null; then
            $TINYMIX_BIN set "$MIXER_CONTROL" 0 2>/dev/null
            return 0
        fi
    fi
    return 1
}

# Get mixer control value - FIXED: Use proper syntax
get_mixer_value() {
    # Load config if not loaded
    [ -z "$TINYMIX_BIN" ] && load_config
    
    if [ -n "$MIXER_CONTROL" ] && [ -n "$TINYMIX_BIN" ]; then
        $TINYMIX_BIN get "$MIXER_CONTROL" 2>/dev/null
    fi
}