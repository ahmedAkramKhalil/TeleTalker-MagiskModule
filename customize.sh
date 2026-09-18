#!/system/bin/sh
# Copyright (c) Teletalker Digital Solution. All rights reserved.
# Proprietary and confidential. Unauthorized copying or distribution prohibited.
# Enhanced installation script with streaming support

ui_print "********************************"
ui_print " TeleTalker Module v2.0"
ui_print " Installing with Streaming..."
ui_print "********************************"

# ⭐ FIXED: APK path using app-release.apk
APK_PATH="$MODPATH/system/priv-app/com.teletalker.app"
APK_FILE="$APK_PATH/app-release.apk"

# Detect architecture
ARCH=$(getprop ro.product.cpu.abi)
ui_print "- Architecture: $ARCH"

case "$ARCH" in
    "arm64-v8a"|"arm64")
        SRC_ARCH="arm64"
        LIB_DIR="lib64"
        ;;
    "armeabi-v7a"|"armeabi")
        SRC_ARCH="arm"
        LIB_DIR="lib"
        ;;
    *)
        ui_print "! Unknown arch $ARCH, using arm64"
        SRC_ARCH="arm64"
        LIB_DIR="lib64"
        ;;
esac

# Check for existing tinyalsa
ui_print "- Checking for tinyalsa..."
NEED_TINYALSA=true

if [ -f "/system/bin/tinymix" ] && /system/bin/tinymix -h >/dev/null 2>&1; then
    ui_print "  ✓ System tinyalsa found"
    ui_print "  → Installing module version for consistency"
fi

# Install tinyalsa binaries
ui_print "- Installing tinyalsa tools..."
mkdir -p "$MODPATH/system/bin"
mkdir -p "$MODPATH/system/$LIB_DIR"

for BIN in tinymix tinyplay tinypcminfo; do
    if [ -f "$MODPATH/libs/$SRC_ARCH/$BIN" ]; then
        cp "$MODPATH/libs/$SRC_ARCH/$BIN" "$MODPATH/system/bin/"
        chmod 755 "$MODPATH/system/bin/$BIN"
        ui_print "  ✓ $BIN"
    fi
done

# Install tinyalsa library
if [ -f "$MODPATH/libs/$SRC_ARCH/libtinyalsa.so" ]; then
    cp "$MODPATH/libs/$SRC_ARCH/libtinyalsa.so" "$MODPATH/system/$LIB_DIR/"
    chmod 644 "$MODPATH/system/$LIB_DIR/libtinyalsa.so"
    ui_print "  ✓ libtinyalsa.so"
fi

# Setup working directory
ui_print "- Setting up working directory..."
mkdir -p /data/local/tmp/call_injector
chmod 777 /data/local/tmp/call_injector

# Copy scripts
ui_print "- Installing scripts..."
for script in "$MODPATH/scripts/"*.sh; do
    if [ -f "$script" ]; then
        cp "$script" /data/local/tmp/call_injector/
        chmod 755 "/data/local/tmp/call_injector/$(basename "$script")"
        ui_print "  ✓ $(basename "$script")"
    fi
done

# Create config directory
mkdir -p "$MODPATH/config"
cat > "$MODPATH/config/module_info.conf" << EOF
# Module configuration
MODULE_VERSION="2.0"
INSTALL_DATE="$(date)"
ARCH="$SRC_ARCH"
TINYALSA_SOURCE="module"
EOF

# ⭐ FIXED: Setup system app structure with correct paths
ui_print "- Setting up as system privileged app..."

# Ensure directories exist - using com.teletalker.app
mkdir -p "$APK_PATH"
mkdir -p "$MODPATH/system/etc/permissions"
mkdir -p "$MODPATH/system/etc/sysconfig"
mkdir -p "$MODPATH/system/etc/default-permissions"


# Remove any old APK files first
ui_print "- Cleaning old APK files..."
rm -f "$APK_PATH"/*.apk.old 2>/dev/null
rm -f "$APK_PATH"/*.apk.bak 2>/dev/null

# If multiple APKs exist, keep only app-release.apk
FOUND_APKS=$(find "$APK_PATH" -name "*.apk" -type f 2>/dev/null | wc -l)
if [ "$FOUND_APKS" -gt 1 ]; then
    ui_print "! Multiple APKs found, keeping only app-release.apk"
    find "$APK_PATH" -name "*.apk" -type f ! -name "app-release.apk" -delete
fi



# Verify APK exists at correct location
if [ -f "$APK_FILE" ]; then
    APK_SIZE=$(du -h "$APK_FILE" | cut -f1)
    ui_print "  ✓ APK found: app-release.apk"
    ui_print "    Size: $APK_SIZE"
    ui_print "    Path: $APK_PATH"
else
    ui_print "! WARNING: APK not found!"
    ui_print "  Expected at: $APK_FILE"
    ui_print "  Please ensure APK is placed at:"
    ui_print "  $APK_PATH/app-release.apk"
fi




# Set permissions for system app files - using app-release.apk
chmod 644 "$APK_FILE" 2>/dev/null
chmod 644 "$MODPATH/system/etc/permissions/privapp-permissions-com.teletalker.app.xml" 2>/dev/null
chmod 644 "$MODPATH/system/etc/sysconfig/config-com.teletalker.app.xml" 2>/dev/null
chmod 644 "$MODPATH/system/etc/default-permissions/default-permissions-com.teletalker.app.xml" 2>/dev/null

ui_print "  ✓ System app structure ready"

# Clean up installation files
rm -rf "$MODPATH/libs" 2>/dev/null
rm -rf "$MODPATH/native" 2>/dev/null

ui_print "********************************"
ui_print " Installation Complete!"
ui_print "********************************"

# Set permissions
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm_recursive $MODPATH/system/bin 0 0 0755 0755