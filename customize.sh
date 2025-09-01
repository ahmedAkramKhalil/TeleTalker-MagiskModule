#!/system/bin/sh
# Enhanced installation script with streaming support

ui_print "********************************"
ui_print " TeleTalker Module v2.0"
ui_print " Installing with Streaming..."
ui_print "********************************"

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

# Install native injection library if present
if [ -f "$MODPATH/native/$SRC_ARCH/libcall_audio_injector.so" ]; then
    ui_print "- Installing native library..."
    cp "$MODPATH/native/$SRC_ARCH/libcall_audio_injector.so" "$MODPATH/system/$LIB_DIR/"
    chmod 644 "$MODPATH/system/$LIB_DIR/libcall_audio_injector.so"
    ui_print "  ✓ libcall_audio_injector.so"
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

# Clean up installation files
rm -rf "$MODPATH/libs" 2>/dev/null
rm -rf "$MODPATH/native" 2>/dev/null

ui_print "********************************"
ui_print " Installation Complete!"
ui_print "********************************"

# Set permissions
set_perm_recursive $MODPATH 0 0 0755 0644
set_perm_recursive $MODPATH/system/bin 0 0 0755 0755