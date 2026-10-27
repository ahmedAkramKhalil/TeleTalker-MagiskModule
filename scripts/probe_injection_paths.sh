#!/system/bin/sh
# Copyright (c) Teletalker Digital Solution. All rights reserved.
# Proprietary and confidential. Unauthorized copying or distribution prohibited.
#
# Which call-audio injection path can work on THIS device?  Read-only: changes
# nothing, sets nothing. Run as root, ideally twice — once idle, once DURING an
# active SIM call (some answers only exist while a call is up):
#
#   su -c sh /data/local/tmp/call_injector/probe_injection_paths.sh
#
# Writes the full report to /data/local/tmp/call_injector/probe_<model>_<time>.txt
# — send that file back.
#
# Paths checked:
#   A) Platform API (Android 13+): AudioManager#getCallUplinkInjectionAudioTrack.
#      Needs the audio policy to expose "Telephony Tx" + CALL_AUDIO_INTERCEPTION.
#   B) Legacy ALSA mixer (what works on A01 Core): "Incall_Music"/"CALL_REC"
#      mixer controls + tinyplay to a MultiMedia front-end.
#   C) Qualcomm AudioReach/PAL (S23-class Snapdragon): no MultiMedia controls;
#      in-call music is a PAL stream type, reachable only through the HAL.

PKG="com.teletalker.app"
WORK_DIR="/data/local/tmp/call_injector"
mkdir -p "$WORK_DIR"
MODEL=$(getprop ro.product.model | tr ' /' '__')
OUT="$WORK_DIR/probe_${MODEL}_$(date +%Y%m%d_%H%M%S).txt"

main() {

sec() { echo; echo "==== $* ===="; }
has() { [ -n "$1" ] && echo "YES" || echo "no"; }

sec "Device"
echo "model     : $(getprop ro.product.manufacturer) $(getprop ro.product.model) ($(getprop ro.product.device))"
echo "android   : API $(getprop ro.build.version.sdk) / $(getprop ro.build.version.release) / $(getprop ro.build.display.id)"
echo "platform  : $(getprop ro.board.platform)  soc: $(getprop ro.soc.manufacturer) $(getprop ro.soc.model)  hw: $(getprop ro.hardware)"
echo "selinux   : $(getenforce)   privapp: $(getprop ro.control_privapp_permissions)"
echo "audio mode: $(dumpsys audio 2>/dev/null | grep -m1 -iE '^ *mode|audio mode' )"
echo "in call   : $(dumpsys telephony.registry 2>/dev/null | grep -m1 -E 'mCallState')"

sec "A) Platform uplink injection (Android 13+)"
POLICY_FILES=$(ls /odm/etc/audio_policy_configuration*.xml /vendor/etc/audio/*/audio_policy_configuration*.xml \
    /vendor/etc/audio/audio_policy_configuration*.xml /vendor/etc/audio_policy_configuration*.xml \
    /system/etc/audio_policy_configuration*.xml 2>/dev/null)
echo "policy files:"; for f in $POLICY_FILES; do echo "  $f"; done
TX_DECL=$(grep -l -iE 'AUDIO_DEVICE_OUT_TELEPHONY_TX|Telephony Tx' $POLICY_FILES 2>/dev/null)
RX_DECL=$(grep -l -iE 'AUDIO_DEVICE_IN_TELEPHONY_RX|Telephony Rx' $POLICY_FILES 2>/dev/null)
echo "Telephony Tx declared in policy XML : $(has "$TX_DECL") $TX_DECL"
echo "Telephony Rx declared in policy XML : $(has "$RX_DECL") $RX_DECL"
for f in $TX_DECL; do
    echo "--- routes/devicePorts mentioning Telephony in $f"
    grep -n -iE 'telephony' "$f" | head -20
done
LIVE_TX=$(dumpsys media.audio_policy 2>/dev/null | grep -iE 'TELEPHONY_TX|Telephony Tx' | head -5)
echo "Telephony Tx live in audio policy    : $(has "$LIVE_TX")"
[ -n "$LIVE_TX" ] && echo "$LIVE_TX"
PERM=$(dumpsys package "$PKG" 2>/dev/null | grep -m1 'CALL_AUDIO_INTERCEPTION')
echo "app has CALL_AUDIO_INTERCEPTION      : ${PERM:-not requested/granted (needs new APK + allowlist)}"
echo "props:"
getprop | grep -iE 'incall_music|incall.music|call_music|telephonytx|voice.*music|call.*inject|interceptable' | sed 's/^/  /'

sec "B) Legacy ALSA mixer path (current module method)"
CTRLS=$(tinymix controls 2>/dev/null)
[ -z "$CTRLS" ] && CTRLS=$(tinymix 2>/dev/null)
echo "mixer controls total: $(echo "$CTRLS" | grep -c .)"
echo "MultiMedia front-end controls: $(echo "$CTRLS" | grep -c 'MultiMedia')"
echo "in-call candidates:"
echo "$CTRLS" | grep -iE 'incall|call_rec|call rec|voice.*music|voice.*playback|telephony|voip.*tx|call.*tx' | head -40 | sed 's/^/  /'
echo "--- /proc/asound/cards"; cat /proc/asound/cards 2>/dev/null
echo "--- /proc/asound/pcm";   cat /proc/asound/pcm 2>/dev/null
MP=$(ls /vendor/etc/mixer_paths*.xml /vendor/etc/audio/*/mixer_paths*.xml /odm/etc/mixer_paths*.xml 2>/dev/null)
echo "mixer_paths files: $MP"
for f in $MP; do
    echo "--- incall paths in $f"
    grep -n -iE 'path name="[^"]*(incall|voice|call)[^"]*"' "$f" | head -30
done
[ -f "$WORK_DIR/mixer_config.txt" ] && { echo "--- current module detection"; cat "$WORK_DIR/mixer_config.txt"; }

sec "C) Qualcomm AudioReach / PAL"
for f in /vendor/etc/card-defs.xml /vendor/etc/backend_conf.xml; do [ -f "$f" ] && echo "present: $f"; done
RM=$(ls /vendor/etc/resourcemanager*.xml /vendor/etc/audio/*/resourcemanager*.xml /odm/etc/resourcemanager*.xml 2>/dev/null)
echo "PAL resource manager files: $RM"
for f in $RM; do
    echo "--- in-call music in $f"
    grep -n -iE 'VOICE_CALL_MUSIC|INCALL_MUSIC|incall_music|PROXY' "$f" | head -20
done
for b in agmplay agmcap; do
    p=$(command -v $b 2>/dev/null || ls /vendor/bin/$b 2>/dev/null)
    echo "$b: ${p:-absent}"
done
ls /vendor/lib64/libagm*.so /vendor/lib64/libar-pal.so /vendor/lib64/hw/audio.primary.*.so 2>/dev/null | sed 's/^/  /'
for so in /vendor/lib64/hw/audio.primary.*.so /vendor/lib64/libar-pal.so; do
    [ -f "$so" ] || continue
    hits=$(grep -c -aE 'incall_music|INCALL_MUSIC|VOICE_CALL_MUSIC|TELEPHONY_TX' "$so" 2>/dev/null)
    echo "strings for in-call music in $(basename $so): $hits"
done

sec "Verdict (heuristic — confirm with a real call)"
if [ "$(getprop ro.build.version.sdk)" -ge 33 ] && { [ -n "$LIVE_TX" ] || [ -n "$TX_DECL" ]; }; then
    echo "A: LIKELY — platform uplink injection should work (new APK + allowlist)."
elif [ "$(getprop ro.build.version.sdk)" -ge 33 ]; then
    echo "A: Telephony Tx not exposed — try policy-XML overlay ONLY if HAL strings in C/B show in-call music support."
else
    echo "A: n/a (API < 33)."
fi
if echo "$CTRLS" | grep -qiE 'incall_music|call_rec|call_record'; then
    echo "B: LIKELY — legacy mixer controls exist (current module path)."
else
    echo "B: no legacy in-call mixer controls."
fi
[ -n "$RM" ] && echo "C: AudioReach/PAL device — legacy tinyplay path will not work here."
}

# Plain pipe to tee: process substitution is not available in Android mksh.
main 2>&1 | tee "$OUT"
echo
echo "Report saved: $OUT"
