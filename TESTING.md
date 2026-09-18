# TeleTalker — On-Device Test Plan (one step at a time)

APK in module: `system/priv-app/com.teletalker.app/app-release.apk`
com.teletalker.app v20 (1.0), debug-signed, targetSdk 34.
Reference known-good device: Samsung, Android 12. Port target: Android >12 / other models.

Do these in order. Only move to the next step once the current one passes.

## 0. Pre-flight (before flashing)
- [ ] Uninstall any existing user-installed `com.teletalker.app` (avoids signature conflict with the system copy).
- [ ] Confirm Magisk installed + root working: `adb shell su -c id` → shows uid=0.

## 1. Flash the module
- [ ] Repackage the module dir into a zip, or use the exported `Teletalker-magisk.zip`.
- [ ] Flash via Magisk app → Modules → Install from storage → reboot.
- [ ] After reboot, module shows enabled in Magisk.

## 2. App present as system app
- [ ] `adb shell pm path com.teletalker.app` → path under `/system/priv-app/...`.
- [ ] App icon appears; launches without crash.

## 3. Permissions auto-granted (ensure_privileges)
- [ ] `adb shell dumpsys package com.teletalker.app | grep -A30 "runtime permissions"`
      → RECORD_AUDIO, POST_NOTIFICATIONS, READ_PHONE_STATE, READ_CONTACTS,
        ANSWER_PHONE_CALLS, CALL_PHONE all granted=true.
- [ ] No permission prompts shown on first launch.

## 4. Injection plumbing up (root side)
- [ ] `adb shell su -c sh /data/local/tmp/call_injector/diagnose.sh` → passes.
- [ ] FIFO exists: `adb shell ls -l /data/local/tmp/call_injector/audio_stream.pipe`.

## 5. Foreground mic service (Android 14 FGS)
- [ ] Start a call flow; check logcat for the mic FGS starting without
      `SecurityException`/`ForegroundServiceStartNotAllowed` (specialUse degrade).
- [ ] `adb logcat | grep -i teletalker` while testing.

## 6. Call recording (baseline flow)
- [ ] Place a normal outgoing call, talk both directions, hang up.
- [ ] Recording file produced; BOTH sides audible on playback.

## 7. AI inject into live call (the hard part)
- [ ] Trigger the AI outbound flow (booking push → app dials).
- [ ] Confirm ElevenLabs WS connects (logcat).
- [ ] Confirm the REMOTE party hears the AI voice (root FIFO → tinymix/tinyplay
      onto voice-call mixer), not just local speaker.

## Rollback if a step wedges the device
- Magisk safe mode: hold Vol-Down during boot, or
- `adb shell su -c 'rm -rf /data/adb/modules/com.teletalker.app'` then reboot.
