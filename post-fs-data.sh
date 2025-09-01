#!/system/bin/sh
# SPDX-FileCopyrightText: 2023-2024 Andrew Gunnerson
# SPDX-License-Identifier: GPL-3.0-only

source "${0%/*}/boot_common.sh" /data/local/tmp/bcr_post-fs-data.log

header Timestamps
ls -ldZ "${cli_apk%/*}"
find /data/system/package_cache -name "${app_id}-*" -exec ls -ldZ {} \+

header Clear package manager caches
run_cli_apk com.teletalker.app.standalone.ClearPackageManagerCachesKt

# Enhanced audio configuration for TeleTalker
header "Configuring audio properties for TeleTalker"

# Get device info for conditional setup
DEVICE_VENDOR=$(getprop ro.product.vendor)
DEVICE_SOC=$(getprop ro.vendor.qti.soc_name)
ANDROID_VERSION=$(getprop ro.build.version.sdk)

echo "Device vendor: $DEVICE_VENDOR"
echo "SoC: $DEVICE_SOC" 
echo "Android version: $ANDROID_VERSION"

# Function to set property with error checking
set_prop_safe() {
    local prop="$1"
    local value="$2"
    
    if setprop "$prop" "$value"; then
        echo "Set $prop = $value"
    else
        echo "Failed to set $prop = $value"
    fi
}

# Qualcomm-specific properties (most common)
if echo "$DEVICE_SOC" | grep -qi "qualcomm\|qcom\|msm\|sdm\|sm"; then
    echo "Applying Qualcomm-specific audio properties..."
    
    set_prop_safe "persist.vendor.audio.fluence.voicecall" "true"
    set_prop_safe "persist.vendor.audio.fluence.voicecomm" "true"
    set_prop_safe "persist.vendor.audio.fluence.speaker" "true"
    set_prop_safe "persist.vendor.radio.enable_voicecall_recording" "true"
    
    # Additional Qualcomm properties
    set_prop_safe "persist.vendor.audio.record.play.concurrent" "true"
    set_prop_safe "vendor.audio.record.multiple.enabled" "true"
    
    # Android 10+ specific
    if [ "$ANDROID_VERSION" -ge 29 ]; then
        set_prop_safe "persist.vendor.audio.voicecall.speaker.stereo" "true"
    fi
    
elif echo "$DEVICE_VENDOR" | grep -qi "mediatek\|mtk"; then
    echo "Applying MediaTek-specific audio properties..."
    
    set_prop_safe "vendor.audiohal.telephonytx.enable" "true"
    set_prop_safe "ro.vendor.mtk_audio_tuning_tool_ver" "V2.2"
    
elif echo "$DEVICE_VENDOR" | grep -qi "samsung"; then
    echo "Applying Samsung-specific audio properties..."
    
    set_prop_safe "ro.config.vc_call_vol_steps" "15"
    set_prop_safe "persist.vendor.radio.calls.on.ims" "1"
    
else
    echo "Unknown vendor, applying generic properties..."
    
    set_prop_safe "persist.vendor.radio.enable_voicecall_recording" "true"
    set_prop_safe "ro.config.media_vol_steps" "25"
fi

# Universal properties that should work on most devices
set_prop_safe "persist.vendor.radio.enable_voicecall_recording" "true"
set_prop_safe "vendor.audio.record.multiple.enabled" "true"

# Optional: force reroute audio path (risky - disabled by default)
# Uncomment only if you're sure about your device
# if [ "$DEVICE_SOC" = "specific_soc_name" ]; then
#     echo "Applying audio rerouting for specific device..."
#     service call audio 7 i32 3 && echo "Audio rerouting applied" || echo "Audio rerouting failed"
# fi

# Create injection directory
mkdir -p /data/local/tmp/call_injector
chmod 755 /data/local/tmp/call_injector

chmod 755 /data/adb/modules/com.teletalker.app/inject_audio.sh
chmod 755 /data/adb/modules/com.teletalker.app/detect_mixers.sh


# Log for debugging
echo "TeleTalker: Audio properties configured at $(date)" >> /data/local/tmp/call_injector/setup.log

header "TeleTalker configuration complete"