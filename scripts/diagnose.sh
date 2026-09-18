#!/system/bin/sh
# Copyright (c) Teletalker Digital Solution. All rights reserved.
# Proprietary and confidential. Unauthorized copying or distribution prohibited.
# TeleTalker device diagnostic — reports which link in the recording and
# injection chains works on THIS device. Run as root: su -c sh diagnose.sh
# (or /data/local/tmp/call_injector/diagnose.sh after install).

PKG="com.teletalker.app"
WORK_DIR="/data/local/tmp/call_injector"
CONFIG_FILE="$WORK_DIR/mixer_config.txt"

ok()   { echo "  [ OK ]  $1"; }
bad()  { echo "  [FAIL]  $1"; }
info() { echo "  [info]  $1"; }

echo "================ TeleTalker diagnostics ================"
echo "Device : $(getprop ro.product.manufacturer) $(getprop ro.product.model)"
echo "SoC    : $(getprop ro.vendor.qti.soc_name)$(getprop ro.board.platform)"
echo "Android: API $(getprop ro.build.version.sdk) ($(getprop ro.build.version.release))"
echo "SELinux: $(getenforce)"
echo "privapp enforcement: $(getprop ro.control_privapp_permissions)"
echo

echo "---- 1. Install / privileged perms ----"
if pm path "$PKG" >/dev/null 2>&1; then ok "app installed: $(pm path $PKG | head -1)"; else bad "app not installed"; fi
for p in CAPTURE_AUDIO_OUTPUT MODIFY_PHONE_STATE CALL_PRIVILEGED CONTROL_INCALL_EXPERIENCE DUMP; do
  if dumpsys package "$PKG" 2>/dev/null | grep -q "android.permission.$p: granted=true"; then
    ok "priv perm $p granted"
  else
    bad "priv perm $p NOT granted (check privapp allowlist / enforce mode)"
  fi
done
echo

echo "---- 2. AppOps (recording) ----"
for op in RECORD_AUDIO PHONE_CALL_MICROPHONE RECORD_AUDIO_OUTPUT; do
  val=$(appops get "$PKG" "$op" 2>/dev/null | head -1)
  case "$val" in
    *allow*) ok "appop $op: $val" ;;
    "") info "appop $op: (unset/unknown)" ;;
    *) bad "appop $op: $val" ;;
  esac
done
echo

echo "---- 3. Recording HAL flag ----"
rec=$(getprop persist.vendor.radio.enable_voicecall_recording)
[ "$rec" = "true" ] && ok "voicecall_recording prop = true" || info "voicecall_recording prop = '${rec:-unset}' (2-way may be HAL-fused-off)"
echo

echo "---- 4. Injection toolchain ----"
for b in tinymix tinyplay tinycap; do
  if command -v "$b" >/dev/null 2>&1; then ok "$b present"; else bad "$b MISSING"; fi
done
echo

echo "---- 5. Injection mixer detection ----"
if [ -f "$CONFIG_FILE" ]; then
  . "$CONFIG_FILE"
  if [ "${DETECTION_SUCCESS:-false}" = "true" ] && [ -n "$MIXER_CONTROL" ]; then
    ok "mixer control: '$MIXER_CONTROL' (device id $DEVICE_ID)"
  else
    bad "no injection mixer detected — injection unsupported; app should fall back to speaker playback"
  fi
else
  info "no mixer_config.txt yet — run detect_mixers.sh first"
  info "candidate controls on this device:"
  tinymix controls 2>/dev/null | grep -iE "incall|call.*rec|voice.*music" | head -10
fi
echo

echo "---- 6. FIFO + SELinux label ----"
PIPE="$WORK_DIR/audio_stream.pipe"
if [ -p "$PIPE" ]; then ok "FIFO exists"; ls -lZ "$PIPE" 2>/dev/null; else info "FIFO not created yet (created on call)"; fi
echo "======================================================="
