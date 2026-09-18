#!/system/bin/sh
# Copyright (c) Teletalker Digital Solution. All rights reserved.
# Proprietary and confidential. Unauthorized copying or distribution prohibited.
# Call Answer Script for TeleTalker

LOG_FILE="/data/local/tmp/call_injector/answer.log"

# Logging function
log_msg() {
    echo "[$(date '+%H:%M:%S')] $1" >> "$LOG_FILE"
}

# Answer call function
answer_call() {
    log_msg "Attempting to answer call..."
    
    # Try primary method - headset hook
    input keyevent KEYCODE_HEADSETHOOK
    sleep 0.2
    
    # Try alternative keycode if first fails
    input keyevent 79
    sleep 0.2
    
    # Try swipe gesture as fallback (Android 10+)
    input swipe 500 1800 500 800 300
    
    log_msg "Call answer commands executed"
}

# Enable speakerphone function
enable_speaker() {
    log_msg "Enabling speakerphone..."
    
    # Try media button
    input keyevent KEYCODE_MEDIA_AUDIO_TRACK
    sleep 0.5
    
    # Try speaker keycode
    input keyevent 164
    
    log_msg "Speakerphone commands executed"
}

# Main execution
case "$1" in
    "answer")
        answer_call
        ;;
    "speaker")
        enable_speaker
        ;;
    "both")
        answer_call
        sleep 1
        enable_speaker
        ;;
    *)
        echo "Usage: $0 {answer|speaker|both}"
        exit 1
        ;;
esac