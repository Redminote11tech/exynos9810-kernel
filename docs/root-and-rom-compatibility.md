# Root and ROM compatibility

These findings track the V3.2.1-susfs2 investigation and SM-G960F tests.
The corrected ext4 build boots on NobleROM 5.2 with Manager/SUSFS detection.
The EROFS build also boots Un1ca Enforcing; its separate daemon overwrite
problem and the limited module-stage verification are described below.

## KernelSU Next detection and modules

The report describes SM-N960F / crownlte on NobleROM 5.2: boot succeeds but Manager
recognition and Zygisk Next fail, including after reboot. Restoring V1.12 restores
root. This is consistent with a kernel integration regression; it does not prove
that every reported symptom has one cause.

## KernelSU Next source update

The old submodule tracked `Redminote11tech/KernelSU-Next` on
`v2.2.0-legacy-susfs` at `debe8e88`. Its older legacy driver forcibly reported
33214. That was a reporting override, not an update to the corresponding API.

It now tracks the official [KernelSU-Next/KernelSU-Next legacy branch](https://github.com/KernelSU-Next/KernelSU-Next/tree/legacy),
pinned to [`465490a26667ba4cf00b3be975a7e28e53978829`](https://github.com/KernelSU-Next/KernelSU-Next/commit/465490a26667ba4cf00b3be975a7e28e53978829).
The latest regular release inspected is [v3.4.2](https://github.com/KernelSU-Next/KernelSU-Next/releases/tag/v3.4.2).
The latest legacy tag is `v3.4.0-legacy`; the selected legacy commit includes
subsequent fixes and 3.4.2 backports. The regular release uses a different hook
path; this 4.9 kernel retains the upstream legacy manual hook implementation.

The reported version is now upstream's `30000 + 3025 commits + 289 = 33314`.
There is no local forced version number. `scripts/ksu-version.sh` reads the same
formula for build status output. The official v3.4.2 Manager is the next retest
target, rather than continuing to recommend v3.0.1.

Upstream changes now included cover policy mutation/locking, deferred package
notifications, Manager certificate parsing, root descriptor permissions,
userspace root sessions and shell root restrictions. The subsequent upstream
preinit commit raises the interface to UAPI 6 and is intentionally excluded:
the released Manager v3.4.2 supports UAPI 5.

Local integration retained or adapted:

- Preserve SUSFS 2.2.0 Kconfig, supercalls, SELinux SIDs, process-unmount flags,
  work scheduling and the sdcard monitor without replacing upstream's current
  Manager authentication or ioctl permission checks.
- Dispatch reboot supercalls once. The previous duplicate allocated an extra
  root-driver descriptor and could run SUSFS commands twice.
- Remove the obsolete three-UID `kernel/sys.c` hook. Upstream now accepts
  `(old_uid, new_uid)` through its registered setuid LSM hook, after normal UID
  validation. Calling both paths would duplicate processing and misinterpret UIDs.
- Use upstream deferred fsnotify package notifications; remove the redundant
  rename LSM scan, which could open files while the rename directory lock is held.
  Scan for an installed Manager at post-fs-data and boot completion as well.
- Connect the native `newfstat` and legacy `fstat64` size-return hooks to match
  init.rc content injection, including upstream's optional module rc content.
- Use the driver's `is_ksu_transition()` for the init transition exception;
  the old kernel code hardcoded `su` although the driver's domain is `ksu`.
- Guard policy-reset sequence handling on the presence of `selinux_state`,
  which the native 4.9 SELinux implementation does not have.
- Select manual kernel hook call sites using `CONFIG_KSU_MANUAL_HOOK` rather
  than assuming the presence or absence of generic kprobes selects a KSU mode.

The version pin is in the submodule gitlink and
`scripts/ksu-patches/base-revision`. Local changes are preserved in
`scripts/ksu-patches/0001-exynos9810-susfs-integration.patch` and applied once by
`scripts/apply-ksu-fixes.sh` before parallel builds. The script rejects a wrong
base revision or conflicting changes and accepts an already-applied patch.
Direct kbuild users must run `bash scripts/apply-ksu-fixes.sh` first too.

Authentication checks remain enabled. A missing shell `su` alone is inconclusive:
shell root still requires authorization and working userspace setup. The first S9 kernel build exposed the runtime issue below; Manager and modules
were not compiled by this workflow.

## Follow-up: unsupported Manager on the S9 test image

ADB verified the phone was running the 24 October SM-G960F test kernel with
SELinux Enforcing and Manager v3.4.2 (33355). The installed APK's v2 signing
certificate is 998 bytes, SHA-256
`79e590113c4c4c0c222978e413a5faa801666957b1212a328e46c00c69821bf7`, matching the
kernel's configured certificate. Kernel logs were unavailable to the shell.

The remaining defect was a file-I/O ABI mismatch. Native 4.9 declares
`kernel_read(file, offset, buffer, count)`, while several new upstream paths
called `kernel_read(file, buffer, count, &offset)`. Compilation allowed these
pointer/integer conversions because the driver suppresses that diagnostic.
The package-list reader and APK certificate reader therefore cannot reliably
read their inputs, so Manager authentication/discovery fails. Allowlist loading
and optional module rc reads have the same mismatch.

All driver callers now use `ksu_kernel_read_compat()` and
`ksu_kernel_write_compat()`, throughout the selected driver. The wrappers
already select the native 4.9 ABI or the newer backported ABI, updating file
positions correctly. Regression tests execute the actual wrappers against both
API signatures and reject direct native calls outside the compatibility layer.
The corrected test build is labelled `managerfix1`. Device root/Manager
recognition must still be checked after flashing it; no successful recognition
has yet been claimed.

## Follow-up: released Manager UAPI compatibility

After `managerfix1`, the Manager recognized the driver, but warned that its UAPI
5 was older than the driver's UAPI 6. This was an integration selection error:
upstream legacy HEAD had advanced past the released Manager v3.4.2 interface.

The driver pin is now `465490a26667ba4cf00b3be975a7e28e53978829`, the immediately
preceding UAPI-5 revision. It includes the recent policy-locking fix and 3.4.2
backports, while excluding the unreleased UAPI-6 preinit/symbol-lookup change.
This is an actual source revision change, not a forced lower interface number.
SUSFS and all local 4.9 file-I/O fixes are retained. The source-derived driver
version is now 33314; its nearest legacy tag remains `v3.4.0-legacy`.

A regression check compares the selected driver's UAPI version, ioctl values
and command structure layouts against the official v3.4.2 release headers.
The next SM-G960F Enforcing/ext4 image is labelled `uapi5fix`. Successful
recognition and module service operation still need a device check after flashing.

## Permissive boot

`CONFIG_ALWAYS_PERMISSIVE` previously clamped writes to selinuxfs, but boot
parameter handling still accepted `enforcing=1`. It now clamps that parameter
and the SELinux initialization path to zero. The option requires SELinux develop
support so the enforcing state is writable. This fixes the configuration
contract; permissive mode cannot solve unrelated mount, ramdisk or driver bugs.

## Un1ca: EROFS is only part of the requirement

Sources inspected:

- [Project README](https://github.com/Eend15/Unofficial-Un1ca-9810#readme): Android 16 /
  One UI 8; system/vendor/odm use EROFS by default, with an ext4 debug option.
- [Platform config](https://github.com/Eend15/Unofficial-Un1ca-9810/blob/Android-16/platform/exynos9810/config.sh):
  EROFS default and non-dynamic partitions.
- [Installer configuration](https://github.com/Eend15/Unofficial-Un1ca-9810/blob/Android-16/platform/exynos9810/installer/customize.sh):
  selects bundled DS-ACK V1.12 payloads, including filesystem-specific DTBs,
  and checks the boot ramdisk. It is not evidence of V3.2.1 compatibility.

This tree already enables the EROFS driver, but its six device trees specified
`ext4` for all three early-mounted partitions. A kernel can therefore support
EROFS and still fail to mount an EROFS ROM during first-stage init.

`CONFIG_EXYNOS9810_EROFS_FSTAB=y` now selects EROFS for system/vendor/odm in all six
DTBs. `CR_FS_TYPE=erofs ./apollo.sh` enables it and separates output directories
and artifact names from ext4 builds. The default remains ext4 for existing ROMs.
This switch assumes all three partitions use the same filesystem, as in Un1ca's
documented layout. Mixed layouts need their own DT fstab configuration.

Do not infer boot compatibility from SELinux mode or EROFS support alone. Match
the ROM's ramdisk, partition layout and DTBs, and collect first-stage mount and
SELinux logs if either mode still fails. No ROM-specific kernel binary was copied
into this source tree.

## Device retest checklist

1. Preserve the working V1.12 boot/DTBO backup and record the ROM build, device,
   ZIP, Manager version and enabled modules.
2. For NobleROM, test the ext4 Enforcing build with modules disabled first.
   Confirm Manager recognition after two cold boots before adding modules.
3. Explicitly authorize shell root in Manager before checking `adb shell su -c id`.
   Check `/data/adb/ksud` and ksud/module logs through an authorized root shell.
4. Enable modules one at a time, then retest Zygisk Next service connectivity.
5. For Un1ca EROFS images, test the EROFS DTB variant with the ROM's matching
   ramdisk. Capture recovery `/proc/last_kmsg` or `/sys/fs/pstore` if available
   after a failed boot; inspect mount errors before attributing it to SELinux.
6. On a permissive test build, verify `getenforce` immediately after boot and
   after init has finished. On Enforcing, retain enforcing mode while testing root.

Read-only diagnostics, where available and permitted:

```sh
adb shell uname -a
adb shell getenforce
adb shell cat /proc/mounts
adb shell logcat -b all -d > logcat.txt
```

Kernel logs often require recovery or authorized root. Collect KernelSU/ksud
startup, package-scan and SELinux messages; redact private information before
posting logs. A successful `uname` check proves which kernel booted, not that its
root daemon, modules or filesystem setup work.

## EROFS S9 test packaging

The user reported that the ext4 `uapi5fix` boots and the Manager detects KernelSU
Next and SUSFS 2.2.0. This confirms discovery on that test setup; it does not
validate every SUSFS setting or module service.

The EROFS test booted default Un1ca on SM-G960F with Enforcing retained.
`scripts/package-s9-erofs-test.py` extracts the compiled kernel and Samsung DTBH
payload from the test boot image and checks every packed DTB's system/vendor/odm
fstab type is EROFS. It packages those payloads with the existing Apollo recovery
installer, restricted to G960F and with command failures made fatal. The installer
unpacks the phone's current boot image and replaces kernel/DTB, preserving the
ROM's ramdisk. Install the Un1ca ROM before this test ZIP and retain a recovery
Boot backup. The standalone image contains Apollo's bundled ramdisk and is not
the recommended artifact for the Un1ca test.

## Un1ca daemon overwrite confirmed on device

ADB on 24 October verified the running `uapi5fix` EROFS kernel, Android 16,
KernelSU driver 33314/UAPI 5 and actual `/sys/fs/selinux/enforce=1`.
SUSFS reports 2.2.0; its post-fs-data log confirms successful non-root-process
mount hiding. However, the module's service and boot-completed stages were absent.

The ROM's `/system/etc/init/unica_ksunext_installer.rc` copies
`/system/bin/ksud` to `/data/adb/ksud` at post-fs-data, **after** KernelSU has
finished its own post-fs-data stage. `/system/bin/unica_ksunext_installer.sh`
copies it again at boot completion. That bundled daemon is 3.4.0/UAPI 4.
Logs explicitly record `kernel=5, ksud=4`, skipping both later stages.
The Manager subsequently restores the correct 3.4.2/UAPI 5 daemon, but the
missed boot events do not automatically rerun.

Running `ksud services` and `ksud boot-completed` with the compatible daemon
restored the module's stage markers and `status: SuS` description without
changing SELinux mode. This verifies startup and command dispatch, not every
possible hiding rule or third-party module.

The persistent workaround is a separate KernelSU module:

```sh
python3 scripts/package-un1ca-ksud-compat.py /path/to/official-v3.4.2.apk
```

It packages the SHA-256-verified official arm64 daemon. Its post-fs-data hook
checks the running kernel is UAPI 5, selects a compatible installed daemon,
then bind mounts a **separate copy** over the ROM's `/system/bin/ksud` in init's
mount namespace. Both later ROM copies therefore use a compatible source.
EROFS contents and manager authentication remain untouched. The module does
not enable hiding options or change SELinux. Five host tests execute the hook
with compatible/incompatible daemons, future kernel UAPI and mount failure.

KernelSU's module safety check required physical volume-down confirmation;
the user installed the module and rebooted. That test exposed a packaging issue:
the installer normalizes files to 0644, so the bundled daemon could not execute
and the initial hook silently skipped its interface check. Version 1.1 explicitly
restores its executable permission before checking UAPI and logs skipped checks.
The host tests now start with that same 0644 permission.

The corrected hook was installed and executed over ADB. Both daemon paths then
reported 3.4.2/UAPI 5, and init's mountinfo confirmed the bind over the ROM path.
SELinux remained Enforcing. The corrected ZIP is
`DS-ACK-Un1ca-ksud-compat-v1.1.zip` in `Apollo/Product`; it is already patched on
the test phone. A subsequent reboot verified automatic startup: both daemon paths reported
UAPI 5, SELinux stayed Enforcing, and service/boot-completed markers appeared
without manual intervention. Un1ca also replayed post-fs-data; the hook now
skips an already-compatible ROM source to avoid replacing an active bind
payload or stacking another mount. The replay guard was checked live and in
the host tests. Removing/disabling
the module and rebooting restores the ROM's original daemon source. The ROM-side
permanent fix is to stop unconditionally overwriting a compatible installed
daemon and ship a daemon matching its kernel interface.

The WebUI's older “auto hide default/bind mounts” controls are gated on the
`CONFIG_KSU_SUSFS_AUTO_ADD_*` feature strings. This SUSFS 2.2.0 integration
does not expose those legacy options; their absence is not an initialization
failure. “Hide sus_mounts for all/non-su processes” is the relevant available
setting, and its saved value was already 1 with a successful kernel command.
