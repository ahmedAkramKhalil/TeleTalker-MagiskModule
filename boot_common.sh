# Copyright (c) Teletalker Digital Solution
# Proprietary — all rights reserved
#
# source "${0%/*}/boot_common.sh" <log file>

exec >"${1}" 2>&1

mod_dir=${0%/*}

header() {
    echo "----- ${*} -----"
}

module_prop() {
    grep "^${1}=" "${mod_dir}/module.prop" | cut -d= -f2
}

run_cli_apk() {
    CLASSPATH="${cli_apk}" app_process / "${@}" &
    pid=${!}
    # Bounded wait — NEVER hang boot if app_process stalls (e.g. the CLI
    # entrypoint blocks). Poll liveness for ~60s, then kill and move on.
    _i=0
    while kill -0 "${pid}" 2>/dev/null; do
        _i=$((_i + 1))
        if [ "${_i}" -ge 60 ]; then
            echo "run_cli_apk: timed out after ~60s — killing ${pid}"
            kill -9 "${pid}" 2>/dev/null
            break
        fi
        sleep 1
    done
    wait "${pid}" 2>/dev/null
    echo "Exit status: ${?}"
    echo "Logcat:"
    logcat -d --pid "${pid}" 2>/dev/null
}

app_id=$(module_prop id)
app_version=$(module_prop version)
cli_apk=$(echo "${mod_dir}"/system/priv-app/"${app_id}"/app-release.apk)

header Environment
echo "Timestamp: $(date)"
echo "Script: ${0}"
echo "App ID: ${app_id}"
echo "App version: ${app_version}"
echo "CLI APK: ${cli_apk}"
echo "UID/GID/Context: $(id)"

# ---------------------------------------------------------------------------
# Reliable, idempotent privilege acquisition.
#
# Runtime permissions and appops are granted here (from service.sh, at
# late_start) rather than in post-fs-data.sh, because the package manager is
# not up early in boot. Everything is bounded (never hangs boot) and verified
# (grant -> confirm -> retry). Signature|privileged perms are NOT granted here
# — they come from the privapp allowlist (install-time) plus the app's own
# root self-grant; pm grant can't set them anyway.
# ---------------------------------------------------------------------------

PKG_ID="com.teletalker.app"

# Runtime (dangerous) permissions — the only kind pm grant can set.
RUNTIME_PERMS="android.permission.RECORD_AUDIO
android.permission.POST_NOTIFICATIONS
android.permission.READ_PHONE_STATE
android.permission.READ_CONTACTS
android.permission.ANSWER_PHONE_CALLS
android.permission.CALL_PHONE"

# AppOps that gate call-audio capture.
APPOPS="RECORD_AUDIO RECORD_AUDIO_OUTPUT PHONE_CALL_MICROPHONE RECORD_AUDIO_HOTWORD"

# PM is usable once the package service answers AND our package resolves.
pm_ready() {
    cmd package list packages >/dev/null 2>&1 || return 1
    pm path "$PKG_ID" >/dev/null 2>&1 || return 1
    return 0
}

_grant_verified() {   # $1 = permission
    pm grant "$PKG_ID" "$1" 2>/dev/null || true
    dumpsys package "$PKG_ID" 2>/dev/null | grep -q "$1: granted=true"
}

_appop_verified() {   # $1 = op
    appops set "$PKG_ID" "$1" allow 2>/dev/null || true
    appops get "$PKG_ID" "$1" 2>/dev/null | grep -qi "allow"
}

ensure_privileges() {
    # 1) Bounded wait for the package manager (never hang boot).
    i=0
    until pm_ready; do
        i=$((i + 1))
        if [ "$i" -ge 30 ]; then
            header "PM not ready after $i tries — skipping (app self-grants anyway)"
            return 0
        fi
        sleep 2
    done

    # 2) Make sure PM sees it as the installed system app (idempotent).
    cmd package install-existing "$PKG_ID" >/dev/null 2>&1 || true

    # 3) Runtime perms: grant -> verify -> retry with capped backoff.
    for p in $RUNTIME_PERMS; do
        n=0
        back=1
        until _grant_verified "$p"; do
            n=$((n + 1))
            if [ "$n" -ge 5 ]; then
                echo "WARN: $p not granted after $n tries"
                break
            fi
            sleep "$back"
            back=$((back * 2))
            [ "$back" -gt 8 ] && back=8
        done
    done

    # 4) AppOps: set -> verify -> retry.
    for op in $APPOPS; do
        n=0
        until _appop_verified "$op"; do
            n=$((n + 1))
            if [ "$n" -ge 5 ]; then
                echo "WARN: appop $op not allowed after $n tries"
                break
            fi
            sleep 1
        done
    done

    # 5) Final verification snapshot for post-flash debugging.
    header "ensure_privileges final state"
    for p in $RUNTIME_PERMS; do
        dumpsys package "$PKG_ID" 2>/dev/null | grep "$p:" || echo "$p: (not found)"
    done
    for op in $APPOPS; do
        echo "$op: $(appops get "$PKG_ID" "$op" 2>/dev/null | head -1)"
    done
}
