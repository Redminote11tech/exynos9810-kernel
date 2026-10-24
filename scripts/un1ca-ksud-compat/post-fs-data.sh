#!/system/bin/sh
# Un1ca copies /system/bin/ksud over /data/adb/ksud AFTER KernelSU's
# post-fs-data stage, and once more at boot completion. Supply a compatible
# source for those copies without modifying the EROFS partition.
MODDIR=${0%/*}
ROM_DAEMON=/system/bin/ksud
DATA_DAEMON=/data/adb/ksud
BB=/data/adb/ksu/bin/busybox
LOG="$MODDIR/compat.log"
exec >> "$LOG" 2>&1

compatible() {
    [ -x "$1" ] && "$1" -V 2>/dev/null | grep -qE '^ksud .*\(uapi: 5\)$'
}

# This workaround is specific to the observed Un1ca installer, not other ROMs.
grep -q 'copy /system/bin/ksud /data/adb/ksud' \
    /system/etc/init/unica_ksunext_installer.rc || exit 0
[ -x "$BB" ] || exit 1
# KernelSU's installer normalizes archive files to 0644, including the daemon.
chmod 0755 "$MODDIR/ksud" || exit 1
# Refuse other kernel interfaces, including future UAPI 6 upgrades.
if ! "$MODDIR/ksud" debug info 2>/dev/null | grep -qx 'uapi_version: 5'; then
    echo 'Skipping: cannot confirm a UAPI 5 kernel'
    exit 0
fi

# Un1ca can replay post-fs-data from its boot-completed installer. Do not
# replace/unlink an already-bound payload or stack another mount on replay.
if compatible "$ROM_DAEMON"; then
    echo 'Un1ca ROM copy source already uses UAPI 5'
    exit 0
fi

# Pick up compatible Manager updates. Use a separate inode: binding the live
# /data/adb/ksud onto the ROM source would make init copy a file onto itself.
if compatible "$DATA_DAEMON"; then
    cp -f "$DATA_DAEMON" "$MODDIR/ksud.new" || exit 1
    chmod 0755 "$MODDIR/ksud.new" || exit 1
    mv -f "$MODDIR/ksud.new" "$MODDIR/ksud" || exit 1
fi
compatible "$MODDIR/ksud" || exit 1
chcon u:object_r:system_file:s0 "$MODDIR/ksud" || exit 1

# Init, rather than an app's private mount namespace, must see the replacement.
"$BB" nsenter -t 1 -m -- "$BB" mount -o bind "$MODDIR/ksud" "$ROM_DAEMON" || exit 1
echo "Un1ca ROM copy source: $("$ROM_DAEMON" -V)"
