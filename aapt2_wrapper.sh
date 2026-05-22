#!/data/data/com.termux/files/usr/bin/bash
# AAPT2 wrapper - uses qemu-x86_64 to run the x86_64 binary
# This intercepts Gradle's attempts to use the x86_64 AAPT2

# Find the actual aapt2 binary (the one Gradle would try to run)
# We search in the Gradle cache transforms
for dir in /data/data/com.termux/files/home/.gradle/caches/*/transforms/*/transformed/aapt2-*-linux/; do
    if [ -f "${dir}aapt2" ] && [ ! -f "${dir}aapt2.real" ]; then
        mv "${dir}aapt2" "${dir}aapt2.real"
        ln -sf /data/data/com.termux/files/usr/opt/android-sdk/build-tools/35.0.0/aapt2 "${dir}aapt2"
    fi
done

# If called directly as aapt2, run the SDK ARM64 version
exec /data/data/com.termux/files/usr/opt/android-sdk/build-tools/35.0.0/aapt2 "$@"
