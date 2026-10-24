<div align="center">

# DS-ACK

**Linux 4.9.337 for the Exynos Galaxy S9 · S9+ · Note9**

![Kernel](https://img.shields.io/badge/Linux-4.9.337-3178c6)
![Root](https://img.shields.io/badge/KernelSU--Next-33314_%C2%B7_UAPI_5-45a163)
![SUSFS](https://img.shields.io/badge/SUSFS-2.2.0-9565d0)

[Releases](../../releases) · [Report a bug](../../issues) · [Compatibility notes](docs/root-and-rom-compatibility.md)

</div>

## Devices

| Device | International | Korean | Codename |
| --- | --- | --- | --- |
| Galaxy S9 | SM-G960F | SM-G960N | `starlte` |
| Galaxy S9+ | SM-G965F | SM-G965N | `star2lte` |
| Galaxy Note9 | SM-N960F | SM-N960N | `crownlte` |

Exynos 9810 only; Snapdragon models are unsupported.

## Inside

- **KernelSU Next + SUSFS 2.2.0**, included in every build.
- **Enforcing and Permissive** SELinux variants.
- **Built-in EROFS** with LZ4, xattrs and SELinux labels.
- One installer for all six device variants; separate build outputs per target.

KernelSU Next is pinned to upstream [`legacy` at `465490a2`](https://github.com/KernelSU-Next/KernelSU-Next/commit/465490a26667ba4cf00b3be975a7e28e53978829),
including the recent **3.4.2 backports** for older kernels. It reports **33314**
using upstream's version formula; the old forced `33214` value is removed.
The latest tagged legacy release is `v3.4.0-legacy`; this pin includes later fixes.
Use the official [v3.4.2 Manager](https://github.com/KernelSU-Next/KernelSU-Next/releases/tag/v3.4.2)
with this UAPI **5** driver. The SM-G960F test boots and detects KernelSU/SUSFS;
broader module testing remains in progress.

## Compatibility

| ROM | Current status |
| --- | --- |
| **NobleROM 5.2 / One UI 7** | SM-G960F `uapi5fix` reported booting with Manager and SUSFS detected. Module behaviour is still being validated. |
| **Unofficial Un1ca / One UI 8** | SM-G960F EROFS boots Enforcing. KernelSU/SUSFS startup verified after reboot with the Un1ca daemon compatibility module. Other models and Permissive await device testing. |

**V3.2.2-susfs2** updates KernelSU Next, fixes native 4.9 file I/O and Manager
discovery, removes duplicate root hooks, fixes Permissive boot handling, and
adds EROFS DT fstabs. See the [validation notes](docs/root-and-rom-compatibility.md).

## Install

1. Back up your current boot image and DTBO in recovery.
2. Select a device-compatible ZIP whose **filesystem and SELinux mode** match your ROM.
3. Flash in TWRP, then reboot. Restore the backup if boot or root fails.
4. Install the matching KernelSU Next Manager and verify root before enabling modules.

**Un1ca:** install `DS-ACK-Un1ca-ksud-compat-v1.1.zip` through Manager and reboot.
It prevents the ROM's bundled UAPI 4 daemon from replacing the required UAPI 5
daemon. This was verified across an S9 reboot with SELinux Enforcing. The SUSFS
userspace module is installed separately; available features do not enable every
hiding/spoofing option automatically. [Details and removal](docs/root-and-rom-compatibility.md#un1ca-daemon-overwrite-confirmed-on-device).

Keep a working recovery and backup: flashing custom images can prevent boot and
may permanently trip Knox. Permissive reduces SELinux protection and cannot be
switched back to enforcing at runtime in that build. `SEANDROIDENFORCE` is a
bootloader marker; check actual mode with `getenforce`.

## Build

Linux host, Git submodules, `bsdiff`, `zip`, and sufficient disk space required.
The script downloads its Clang toolchain on first use.

```bash
git clone --recurse-submodules https://github.com/Redminote11tech/exynos9810-kernel.git
cd exynos9810-kernel
./apollo.sh                       # EROFS DT fstabs (default)
CR_FS_TYPE=ext4 ./apollo.sh        # ext4 ROMs, including the NobleROM test
```

Option **7** produces an all-device ZIP; **8** produces Enforcing and Permissive
release ZIPs for the selected filesystem. EROFS artifacts include `EROFS` in their
names. `CR_PARALLEL=2` controls simultaneous device builds; logs go to `logs/`.
Release builds preserve previous outputs and seed new variants from completed
builds using copy-on-write where supported. Installed `ccache` is used automatically
with a local 30 GB limit; ThinLTO caches stay in each output tree. Use
`CR_USE_CCACHE=0` or `CR_SEED_OUTPUTS=0` to disable either optimisation.
Release builds omit full DWARF debug data to reduce linking time; set
`CR_RELEASE_DEBUG_INFO=1` if you need that host-side debugging information.

For a single-device G960F EROFS test, `python3 scripts/package-s9-erofs-test.py <built-image.img>`
creates a recovery ZIP that preserves the installed ROM ramdisk and checks the
actual DTB filesystems. Use that ZIP after installing Un1ca.

The pinned [upstream KernelSU Next legacy branch](https://github.com/KernelSU-Next/KernelSU-Next/tree/legacy)
uses manual hooks with a local SUSFS/4.9 integration patch. `scripts/apply-ksu-fixes.sh` applies the tracked local patch
once before builds; this intentionally leaves the submodule modified. Its
Kbuild also makes compatibility edits to kernel sources. Review both diffs when
updating the submodule.

## Credits & license

Based on [duhansysl's kernel](https://github.com/duhansysl/exynos9810-kernel) and
[ananjaser1211's Apollo](https://github.com/ananjaser1211).
Thanks to [KernelSU Next](https://github.com/KernelSU-Next/KernelSU-Next),
[simonpunk](https://gitlab.com/simonpunk/susfs4ksu), gavdoc38, cyberc3dr and sidex15.

[GPL-2.0](COPYING).
