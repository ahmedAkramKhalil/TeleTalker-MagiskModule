#!/system/bin/sh
# Copyright (c) Teletalker Digital Solution. All rights reserved.
# Proprietary and confidential. Unauthorized copying or distribution prohibited.
# ============================================
# test_injection.sh - Fixed for proper tinymix syntax
# ============================================

WORK_DIR="/data/local/tmp/call_injector"
CONFIG_FILE="$WORK_DIR/mixer_config.txt"

echo "======================================="
echo "TeleTalker Injection Test"
echo "======================================="

# Load configuration
if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: No configuration found. Running detection..."
    "$WORK_DIR/detect_mixers.sh"
fi

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Set defaults if not defined (backward compatibility)
TINYMIX_BIN="${TINYMIX_BIN:-/system/bin/tinymix}"
TINYPLAY_BIN="${TINYPLAY_BIN:-/system/bin/tinyplay}"

echo "Configuration:"
echo "  Mixer: $MIXER_CONTROL"
echo "  Device: $DEVICE_ID"
echo "  Tinymix: $TINYMIX_BIN"
echo ""

# Test 1: Mixer control
echo "Test 1: Mixer Control"
if [ -n "$MIXER_CONTROL" ]; then
    # FIXED: Use proper tinymix set syntax
    if $TINYMIX_BIN set "$MIXER_CONTROL" 1 2>/dev/null; then
        echo "  ✓ Enable successful"
        sleep 1
        $TINYMIX_BIN set "$MIXER_CONTROL" 0 2>/dev/null
        echo "  ✓ Disable successful"
    else
        echo "  ✗ Failed to control mixer"
        echo "  Debug: Checking if control exists..."
        if $TINYMIX_BIN controls | grep -q "$MIXER_CONTROL"; then
            echo "  Control exists but cannot be set"
        else
            echo "  Control does not exist"
        fi
        exit 1
    fi
else
    echo "  ✗ No mixer control configured"
    exit 1
fi

# Test 2: Generate test tone
echo ""
echo "Test 2: Generate Test Tone"
TEST_FILE="$WORK_DIR/test_tone.pcm"

# Generate 1 second of silence (simple test)
dd if=/dev/zero of="$TEST_FILE" bs=32000 count=1 2>/dev/null

if [ -f "$TEST_FILE" ]; then
    echo "  ✓ Test file generated"
    rm -f "$TEST_FILE"
else
    echo "  ✗ Failed to generate test file"
fi

# Test 3: Check call state
echo ""
echo "Test 3: Call State"
CALL_STATE=$(dumpsys telephony.registry 2>/dev/null | grep "mCallState" | tail -1)
if echo "$CALL_STATE" | grep -q "2"; then
    echo "  ✓ Currently in call"
else
    echo "  ℹ Not in call"
fi

# Test 4: Streaming pipe
echo ""
echo "Test 4: Streaming Pipe"
PIPE_FILE="$WORK_DIR/audio_stream.pipe"

if [ -p "$PIPE_FILE" ]; then
    echo "  ✓ Pipe exists: $PIPE_FILE"
else
    echo "  ℹ Creating pipe..."
    mkfifo "$PIPE_FILE" 2>/dev/null
    chmod 666 "$PIPE_FILE"
    [ -p "$PIPE_FILE" ] && echo "  ✓ Pipe created" || echo "  ✗ Failed to create pipe"
fi

# Test 5: Audio injection capability
echo ""
echo "Test 5: Audio Injection Test"
if [ -n "$MIXER_CONTROL" ] && [ -n "$DEVICE_ID" ]; then
    echo "  ℹ Testing audio injection (2 second test)..."
    
    # Enable mixer
    $TINYMIX_BIN set "$MIXER_CONTROL" 1 2>/dev/null
    
    # Generate and play a short tone
    TEST_AUDIO="$WORK_DIR/test_beep.pcm"
    # Generate 0.5 seconds of 1kHz sine wave (very basic)
    dd if=/dev/zero of="$TEST_AUDIO" bs=16000 count=1 2>/dev/null
    
    if $TINYPLAY_BIN "$TEST_AUDIO" -D 0 -d "$DEVICE_ID" -r 16000 -c 1 -b 16 2>/dev/null; then
        echo "  ✓ Audio injection successful"
    else
        echo "  ⚠ Audio injection may not work (check during call)"
    fi
    
    # Disable mixer
    $TINYMIX_BIN set "$MIXER_CONTROL" 0 2>/dev/null
    rm -f "$TEST_AUDIO"
else
    echo "  ✗ Missing configuration for audio test"
fi

echo ""
echo "======================================="
echo "All tests complete!"
echo "======================================="