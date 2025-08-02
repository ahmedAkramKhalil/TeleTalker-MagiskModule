#!/system/bin/sh
# Script to inject audio during calls

AUDIO_FILE="$1"
CONFIG_FILE="/data/local/tmp/call_injector/mixer_config.txt"

# Check if audio file exists
if [ ! -f "$AUDIO_FILE" ]; then
    echo "Error: Audio file not found: $AUDIO_FILE"
    exit 1
fi

# Load configuration
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: Mixer configuration not found. Running detection..."
    /system/bin/sh /data/adb/modules/call_audio_injector/detect_mixers.sh
    source "$CONFIG_FILE"
fi

# Check if we have valid configuration
if [ -z "$MIXER_CONTROL" ] || [ -z "$DEVICE_ID" ]; then
    echo "Error: No valid mixer control found"
    exit 1
fi

# Enable mixer
tinymix "$MIXER_CONTROL" 1

# Play audio
tinyplay "$AUDIO_FILE" -D 0 -d "$DEVICE_ID"
PLAY_RESULT=$?

# Disable mixer
tinymix "$MIXER_CONTROL" 0

exit $PLAY_RESULT