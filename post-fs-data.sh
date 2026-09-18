#!/system/bin/sh
# Copyright (c) Teletalker Digital Solution
# Proprietary — all rights reserved
#
# Runs early (post-fs-data), before the package manager is up. This stage does
# ONLY what must precede the package scan: SELinux labeling, cache clearing,
# audio props, and working-dir setup. Runtime permissions/appops are granted
# later in service.sh via ensure_privileges() (PM isn't ready here).

source "${0%/*}/boot_common.sh" /data/local/tmp/teletalker_post-fs-data.log

MODDIR="/data/adb/modules/com.teletalker.app"

# Ensure the module's system files carry the correct SELinux label (whole
# subtree, so a per-file filename typo can't leave one mislabeled).
chcon -R u:object_r:system_file:s0 "$MODDIR/system" 2>/dev/null || true

header Timestamps
ls -ldZ "${cli_apk%/*}" 2>/dev/null || true
find /data/system/package_cache -name "${app_id}-*" -exec ls -ldZ {} \+ 2>/dev/null || true

header Clear package manager caches
# Direct removal - Samsung A11 fix
rm -rf /data/system/package_cache/*/"${app_id}"* 2>/dev/null || true
rm -rf /data/system/package_cache/*/"${app_id}"-* 2>/dev/null || true
rm -rf /data/resource-cache/*"${app_id}"* 2>/dev/null || true
rm -rf /data/dalvik-cache/*/*"${app_id}"* 2>/dev/null || true

run_cli_apk com.teletalker.app.standalone.ClearPackageManagerCachesKt

header Clear dalvik cache for TeleTalker
rm -rf /data/dalvik-cache/arm*/system@priv-app@com.teletalker.app@* 2>/dev/null || true
rm -rf /data/dalvik-cache/*/system@priv-app@com.teletalker.app@* 2>/dev/null || true
echo "Dalvik cache cleared"

# Enhanced audio configuration for TeleTalker
header "Configuring audio properties for TeleTalker"

DEVICE_VENDOR=$(getprop ro.product.vendor)
DEVICE_SOC=$(getprop ro.vendor.qti.soc_name)
ANDROID_VERSION=$(getprop ro.build.version.sdk)

echo "Device vendor: $DEVICE_VENDOR"
echo "SoC: $DEVICE_SOC"
echo "Android version: $ANDROID_VERSION"

set_prop_safe() {
    prop="$1"
    value="$2"
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
    set_prop_safe "persist.vendor.audio.record.play.concurrent" "true"
    set_prop_safe "vendor.audio.record.multiple.enabled" "true"
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

# Audio reroute (AudioService binder call). The transaction code (7) means
# different things across Android versions and can destabilize audio on other
# devices, so run it ONLY on the known-good baseline (Samsung / Qualcomm) and
# skip it on unknown vendors. Samsung A12 keeps its current behavior.
if echo "$DEVICE_VENDOR" | grep -qi "samsung" || echo "$DEVICE_SOC" | grep -qi "qualcomm\|qcom\|msm\|sdm\|sm"; then
    echo "Applying audio reroute (baseline device)"
    service call audio 7 i32 3 2>/dev/null || true
else
    echo "Skipping audio reroute on non-baseline device"
fi

# Injection working directory
mkdir -p /data/local/tmp/call_injector
chmod 755 /data/local/tmp/call_injector

# Make module scripts executable (live scripts live under scripts/).
find "$MODDIR/scripts" -type f -name "*.sh" -exec chmod 755 {} \; 2>/dev/null || true

echo "TeleTalker: Audio properties configured at $(date)" >> /data/local/tmp/call_injector/setup.log
header "TeleTalker configuration complete"
