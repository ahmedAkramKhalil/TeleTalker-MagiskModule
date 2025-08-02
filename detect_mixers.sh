#!/system/bin/sh
# Auto-detect correct mixer controls

LOGFILE="mixer_config.txt"
MIXER_CONTROL=""
DEVICE_ID=""

# Function to test mixer control
test_mixer() {
    local control="$1"
    tinymix "$control" 1 2>/dev/null
    return $?
}

# Detect Incall_Music mixers
echo "Detecting mixer controls..." > $LOGFILE

# Check for Incall_Music controls
for mm in "MultiMedia1" "MultiMedia2" "MultiMedia5" "MultiMedia9"; do
    if test_mixer "Incall_Music Audio Mixer $mm"; then
        MIXER_CONTROL="Incall_Music Audio Mixer $mm"
        case $mm in
            "MultiMedia1") DEVICE_ID="0" ;;
            "MultiMedia2") DEVICE_ID="1" ;;
            "MultiMedia5") DEVICE_ID="12" ;;
            "MultiMedia9") DEVICE_ID="14" ;;
        esac
        break
    fi
done

# If not found, try Incall_Music_2
if [ -z "$MIXER_CONTROL" ]; then
    for mm in "MultiMedia1" "MultiMedia2" "MultiMedia5" "MultiMedia9"; do
        if test_mixer "Incall_Music_2 Audio Mixer $mm"; then
            MIXER_CONTROL="Incall_Music_2 Audio Mixer $mm"
            case $mm in
                "MultiMedia1") DEVICE_ID="0" ;;
                "MultiMedia2") DEVICE_ID="1" ;;
                "MultiMedia5") DEVICE_ID="12" ;;
                "MultiMedia9") DEVICE_ID="14" ;;
            esac
            break
        fi
    done
fi

# Save detected configuration
echo "MIXER_CONTROL=\"$MIXER_CONTROL\"" >> $LOGFILE
echo "DEVICE_ID=\"$DEVICE_ID\"" >> $LOGFILE
echo "Detection complete. Control: $MIXER_CONTROL, Device: $DEVICE_ID" >> $LOGFILE

# Reset mixer to off
if [ ! -z "$MIXER_CONTROL" ]; then
    tinymix "$MIXER_CONTROL" 0 2>/dev/null
fi