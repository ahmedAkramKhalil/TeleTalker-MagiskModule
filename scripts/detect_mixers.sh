#!/system/bin/sh
# Copyright (c) Teletalker Digital Solution. All rights reserved.
# Proprietary and confidential. Unauthorized copying or distribution prohibited.
# Enhanced mixer detection script with better error handling and broader device support
# FIXED: Proper binary usage and detection logic

set -e  # Exit on any error

# IMPORTANT: Separate files for config and logs
CONFIG_FILE="/data/local/tmp/call_injector/mixer_config.txt"
LOGFILE="/data/local/tmp/call_injector/detection.log"
LOGDIR="/data/local/tmp/call_injector"

MIXER_CONTROL=""
DEVICE_ID=""
DETECTION_METHOD="standard"
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

# Parse ONLY: return the real pcm playback device number that /proc/asound/pcm
# assigns to a MultiMediaN front-end, e.g. a line like:
#   "00-09: MultiMedia1 (*) : ... : playback 1 : capture 1"
# means MultiMedia1 -> device 9. Returns "" (empty) if it cannot be determined.
resolve_device_id_raw() {
    local mm="$1" dev=""
    [ -n "$mm" ] || { echo ""; return; }
    dev=$(grep -iE "[0-9]+-[0-9]+:[[:space:]]*$mm[[:space:]]" /proc/asound/pcm 2>/dev/null \
          | grep -i playback | head -1 \
          | sed -E 's/^[0-9]+-0*([0-9]+):.*/\1/' 2>/dev/null)
    echo "$dev" | grep -qE '^[0-9]+$' && echo "$dev" || echo ""
}

# Resolve with fallback to the static map when /proc/asound/pcm can't be parsed.
resolve_device_id() {
    local mm="$1" raw
    raw=$(resolve_device_id_raw "$mm")
    if [ -n "$raw" ]; then echo "$raw"; else get_device_id "$mm"; fi
}

# Ground-truth the device id for an already-chosen control.
#
# SAMSUNG-SAFETY: the static get_device_id() map is a Qualcomm convention that is
# correct on the Samsung reference. /proc/asound/pcm is the kernel's own table,
# so on ANY device where the static id is the one that actually works (Samsung),
# the parsed id equals the static id and this returns it unchanged. It only
# differs on SoCs where the static map is provably wrong — i.e. the kernel lists
# that MultiMediaN at a different device (e.g. Snapdragon 865 / kona on Xiaomi),
# which is exactly the case where the old value injected into a phantom device
# and produced silence. If the table can't be read, the static id is kept.
best_device_id() {
    local ctrl="$1" static_id="$2" mm raw
    mm=$(echo "$ctrl" | grep -oE 'MultiMedia[0-9]+' | head -1)
    [ -n "$mm" ] || { echo "$static_id"; return; }   # no MultiMediaN -> keep static
    raw=$(resolve_device_id_raw "$mm")
    if [ -n "$raw" ]; then echo "$raw"; else echo "$static_id"; fi
}

# Confirm a pcm playback device number actually exists on this device, so we do
# not accept a mixer control that points at a non-existent device (a common way
# the injection ends up silent even though tinymix "set" succeeds).
pcm_device_exists() {
    local id="$1"
    [ -n "$id" ] || return 1
    grep -qiE "[0-9]+-0*$id:[[:space:]]" /proc/asound/pcm 2>/dev/null
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

# Generic auto-discovery for devices whose control names don't match the known
# vendor patterns above (non-Qualcomm, newer Snapdragon, etc). Scans all mixer
# controls for likely in-call music/playback injection paths and tests each.
if [ -z "$MIXER_CONTROL" ]; then
    log_message "Trying generic auto-discovery of injection mixer..."
    OLDIFS="$IFS"
    IFS='
'
    for line in $($TINYMIX_BIN controls 2>/dev/null); do
        name=$(echo "$line" | sed -E 's/^[0-9]+:?[[:space:]]+//' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        case "$name" in
            *[Ii]ncall*[Mm]usic*|*[Ii]ncall*[Pp]layback*|*CALL_REC*[Mm]usic*|*[Vv]oice*[Mm]usic*)
                if test_mixer "$name"; then
                    MIXER_CONTROL="$name"
                    mm=$(echo "$name" | grep -oE 'MultiMedia[0-9]+' | head -1)
                    DEVICE_ID=$(get_device_id "${mm:-MultiMedia1}")
                    log_message "Auto-discovered control: $MIXER_CONTROL (device $DEVICE_ID)"
                    break
                fi
                ;;
        esac
    done
    IFS="$OLDIFS"
fi

# -----------------------------------------------------------------------------
# FALLBACK PASS (Xiaomi / MIUI / newer Snapdragon such as kona/SD865).
#
# SAMSUNG-SAFETY: this block is reached ONLY when every pass above left
# MIXER_CONTROL empty. Any device that already detects a control (Samsung and
# anything else that works today) has broken out long before here, so its result
# is byte-for-byte unchanged. This can only add coverage for currently-broken
# devices; it cannot regress a working one.
#
# Difference vs the generic pass above: we (a) match a broader set of control
# names, (b) resolve the pcm device number from /proc/asound/pcm instead of the
# static Qualcomm map, and (c) require that pcm device to actually exist before
# accepting the control — which avoids the "tinymix set succeeds but audio is
# silent because the device id is wrong" failure that hits MIUI.
# -----------------------------------------------------------------------------
if [ -z "$MIXER_CONTROL" ]; then
    log_message "Fallback pass: scanning for injection mixer via /proc/asound/pcm ..."
    log_message "----- /proc/asound/pcm -----"
    cat /proc/asound/pcm >> "$LOGFILE" 2>&1 || true

    OLDIFS="$IFS"
    IFS='
'
    for line in $($TINYMIX_BIN controls 2>/dev/null); do
        name=$(echo "$line" | sed -E 's/^[0-9]+:?[[:space:]]+//' | sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//')
        case "$name" in
            *[Ii]ncall*[Mm]usic*|*[Ii]ncall*[Pp]layback*|*[Cc]all*[Rr]ec*[Mm]usic*|*[Vv]oice*[Mm]usic*|*[Vv]oice*[Pp]layback*|*[Mm]usic*[Mm]ixer*[Mm]ulti[Mm]edia*)
                mm=$(echo "$name" | grep -oE 'MultiMedia[0-9]+' | head -1)
                cand_id=$(resolve_device_id "${mm:-MultiMedia1}")
                if ! pcm_device_exists "$cand_id"; then
                    log_message "Skipping '$name' — resolved device $cand_id not present in /proc/asound/pcm"
                    continue
                fi
                if test_mixer "$name"; then
                    MIXER_CONTROL="$name"
                    DEVICE_ID="$cand_id"
                    DETECTION_METHOD="fallback-procasound"
                    log_message "Fallback matched control: '$MIXER_CONTROL' -> device $DEVICE_ID (verified present)"
                    break
                fi
                ;;
        esac
    done
    IFS="$OLDIFS"
fi

# Ground-truth the device id against the kernel's own pcm table. No-op when the
# static map already matches (Samsung); fixes SoCs where the static map points at
# the wrong pcm device and injection was therefore silent (Xiaomi/kona).
if [ -n "$MIXER_CONTROL" ] && [ -n "$DEVICE_ID" ]; then
    corrected=$(best_device_id "$MIXER_CONTROL" "$DEVICE_ID")
    if [ -n "$corrected" ] && [ "$corrected" != "$DEVICE_ID" ]; then
        log_message "Ground-truth device id for '$MIXER_CONTROL': static $DEVICE_ID -> real $corrected (from /proc/asound/pcm)"
        DEVICE_ID="$corrected"
        DETECTION_METHOD="${DETECTION_METHOD}+devid-corrected"
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
DETECTION_METHOD="$DETECTION_METHOD"
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

    # Also dump the pcm device table so a control can be hand-mapped for this SoC.
    log_message "----- /proc/asound/pcm -----"
    cat /proc/asound/pcm >> "$LOGFILE" 2>&1 || true
    log_message "----- /proc/asound/cards -----"
    cat /proc/asound/cards >> "$LOGFILE" 2>&1 || true

    exit 1
fi