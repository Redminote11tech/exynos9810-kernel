<div align="center">

# DS-ACK Kernel

### Root that actually hides, for the Galaxy S9 · S9+ · Note 9

[![Kernel](https://img.shields.io/badge/kernel-4.9.337-blue)](https://kernel.org)
[![KernelSU-Next](https://img.shields.io/badge/KernelSU--Next-33214-brightgreen)](https://github.com/KernelSU-Next/KernelSU-Next)
[![SUSFS](https://img.shields.io/badge/SUSFS-v2.2.0-brightgreen)](https://gitlab.com/simonpunk/susfs4ksu)
[![SoC](https://img.shields.io/badge/SoC-Exynos%209810-orange)](#supported-devices)
[![License](https://img.shields.io/badge/license-GPL--2.0-lightgrey)](COPYING)

**One ZIP. Six device variants. Modern root hiding on hardware from 2018.**

[Download](../../releases) · [Install](#-install) · [Which build?](#-which-build-do-i-want) · [Build it yourself](#-building-from-source)

</div>

---

> [!CAUTION]
> **Read this before you flash anything.**
> A custom kernel can leave your phone unbootable, and flashing one trips Knox
> **permanently** — that is irreversible and kills Samsung Pay, Secure Folder and
> warranty service. Take a full TWRP backup of `boot` and `dtbo` first, and know
> how to get back to stock with Odin. Nobody but you is responsible for your device.

> [!WARNING]
> **On the Un1ca One UI 8 port, the Enforcing build does not boot.** It
> bootloops. Use the **Permissive** ZIP on that ROM. This is a property of the
> ROM's policy, not a kernel bug — see [Which build do I want?](#-which-build-do-i-want)
>
> V3.2.1 includes a fix that may change this: SELinux policy injection now
> runs under the intended rwlock path on 4.9 instead of a fallback, and the
> bootloop is suspected to be policy-injection related. If you try **Enforcing**
> on Un1ca with V3.2.1 and it boots clean, please report it in
> [Issues](../../issues) so this guidance can be retired.

## ✨ What you get

|  | |
| --- | --- |
| 🔓 **Root** | KernelSU-Next, reporting version **33214** — a version the stable manager accepts |
| 🫥 **Root hiding** | **SUSFS v2.2.0** integrated in-tree — sus paths, sus mounts, sus kstat, sus maps, open-redirect, uname and cmdline spoofing |
| 🛡️ **SELinux** | Enforcing *and* Permissive builds shipped, so you can match your ROM |
| 🌐 **eBPF** | BPF verifier, cgroup-bpf and sockmap backported from upstream Apollo, for One UI 8 era userspace |
| 📁 **EROFS** | EROFS built into the kernel — One UI 8 / Un1ca system images mount natively, SELinux contexts included |
| 📦 **One installer** | A single ZIP carries all six variants and picks the right one at flash time |
| 🔧 **Reproducible** | Out-of-tree parallel builds, pinned submodule, no hidden state |

## 📱 Supported devices

| Model | Codename | Build target |
| --- | --- | --- |
| SM-G960F / G960N | `starlte` | 1 / 4 (KOR) |
| SM-G965F / G965N | `star2lte` | 2 / 5 (KOR) |
| SM-N960F / N960N | `crownlte` | 3 / 6 (KOR) |

Snapdragon variants (G960**U**, G965**U**, N960**U**) are **not** supported and
never will be — this is an Exynos tree and the hardware differs fundamentally.

## 🚀 Install

**You need:** unlocked bootloader · TWRP · a One UI 7 or One UI 8 ROM.

1. **Pick your ZIP** — see [below](#-which-build-do-i-want). On Un1ca One UI 8, take **Permissive**.
2. Reboot to TWRP and **back up `boot` and `dtbo`**.
3. Flash the ZIP.
4. Reboot. *If it loops, restore your backup from TWRP — no harm done.*
5. Install the [KernelSU-Next Manager](https://github.com/KernelSU-Next/KernelSU-Next/releases) and open it. It should report the kernel as installed.
6. For root hiding, install the SUSFS module and reboot.

## 🎯 Which build do I want?

| Your ROM | Flash this | Why |
| --- | --- | --- |
| **Un1ca (One UI 8 port)** | **Permissive** | Enforcing bootloops on this ROM — confirmed by testing |
| **NobleROM (One UI 7)** | **Enforcing** | Root works with SELinux left on; no reason to weaken it |
| Anything else | **Enforcing first** | Fall back to Permissive only if it won't boot |

**Enforcing** leaves SELinux exactly as your ROM intends. Rooting this kernel
does *not* require turning SELinux off — KernelSU-Next and SUSFS both work with
enforcement on. Verify with:

```bash
adb shell getenforce      # -> Enforcing
```

**Permissive** is built with `CONFIG_ALWAYS_PERMISSIVE`, which clamps every write
to `/sys/fs/selinux/enforce` to `0`. The device **cannot** be returned to
enforcing at runtime — not by an app, not by a script. It is a real, device-wide
reduction in security. Use it when a ROM genuinely needs it (Un1ca), not by habit.

> [!NOTE]
> Every image has `SEANDROIDENFORCE` appended, Permissive ones included. That is
> a Samsung **bootloader** marker that suppresses the red boot warning — it says
> nothing about SELinux mode. Don't read it as proof you're Enforcing; use `getenforce`.

## 🔬 How the root hiding works

SUSFS v2.2.0 is patched directly into the kernel — not a module, not a shim.
Userspace talks to it through the KernelSU supercall on `sys_reboot`
(magic `0xDEADBEEF` / `0xFAFAFAFA`), which is the ABI SUSFS v2.0.0+ tooling
prefers and probes for first.

| Capability | Config |
| --- | --- |
| Hide paths from stat/readdir | `CONFIG_KSU_SUSFS_SUS_PATH` |
| Hide mounts from non-root processes | `CONFIG_KSU_SUSFS_SUS_MOUNT` |
| Spoof inode metadata | `CONFIG_KSU_SUSFS_SUS_KSTAT` |
| Hide mappings in `/proc/*/maps` | `CONFIG_KSU_SUSFS_SUS_MAP` |
| Redirect opens | `CONFIG_KSU_SUSFS_OPEN_REDIRECT` |
| Spoof `uname` | `CONFIG_KSU_SUSFS_SPOOF_UNAME` |
| Spoof `/proc/cmdline` | `CONFIG_KSU_SUSFS_SPOOF_CMDLINE_OR_BOOTCONFIG` |
| Hide `ksu_`/`susfs_` symbols from kallsyms | `CONFIG_KSU_SUSFS_HIDE_KSU_SUSFS_SYMBOLS` |

## 📁 EROFS support

The kernel ships an EROFS driver compiled in (`CONFIG_EROFS_FS=y` in every
release variant), backported from the 5.x-era mainline code: LZ4 decompression,
big-pcluster, XATTR + POSIX ACL + `security.selinux` support, plus an ARM64
NEON LZ4 fast path.

This matters for One UI 8-era ROMs: [Un1ca](https://github.com/Eend15/Unofficial-Un1ca-9810)
builds `system`/`vendor`/`odm` as EROFS images, and this kernel mounts them
natively. Verified against Un1ca's actual image settings
(`mkfs.erofs -z lz4hc,9 -b 4096` — no fragments, no ztailpacking, no
chunk-based files), which sit squarely inside the driver's supported feature
set.

To verify on a running device:

```bash
# as root, with a Un1ca system.img pushed to /data/local/tmp
mkdir -p /mnt/erofs_test
losetup /dev/loop0 /data/local/tmp/system.img
mount -t erofs /dev/loop0 /mnt/erofs_test
ls /mnt/erofs_test                       # files listed
getfattr -n security.selinux /mnt/erofs_test/bin   # SELinux context intact
umount /mnt/erofs_test && losetup -d /dev/loop0
```

> [!NOTE]
> If a future Un1ca build starts passing `--fragment` or `--ztailpacking` to
> mkfs.erofs, the driver would need another backport round — today's format
> does not use them.

## 🛠️ Building from source

**Host:** Linux · `bsdiff` and `zip` (the script offers to install them) · ~40 GB free.
`apollo.sh` downloads its own Clang toolchain on first run.

```bash
git clone --recurse-submodules https://github.com/Redminote11tech/exynos9810-kernel.git
cd exynos9810-kernel
./apollo.sh
```

Already cloned without submodules? `git submodule update --init --recursive`

`apollo.sh` prompts for device, compiler, SELinux mode, KernelSU and clean/dirty,
then drops a flashable ZIP in `Apollo/Product`. Option **7** builds the
all-device ZIP; option **8** builds the four release ZIPs in one run.

### Parallel builds

Builds are out-of-tree — each target compiles into its own `out/<variant>-<selinux>-<ksu>/`,
so the source tree stays clean and targets never share a `.config`:

```bash
CR_PARALLEL=3 ./apollo.sh      # 3 devices at once
```

Each concurrent build gets `nproc / CR_PARALLEL` jobs, so total threads stay
constant. Default is **2** — keep it low, ThinLTO linking is memory hungry and
several simultaneous links will swap a 16 GB machine. Per-target logs land in
`logs/build-<pid>/`.

> [!TIP]
> Because each target keeps its own output dir, rebuilding one device — or just
> flipping SELinux mode — is incremental, not a full rebuild.

> **Coming from an older checkout?** kbuild refuses out-of-tree builds while the
> source tree holds in-tree output. `apollo.sh` detects this and prints the fix:
> `make ARCH=arm64 mrproper`

### Submodule and hooks

The KernelSU-Next submodule tracks
[`Redminote11tech/KernelSU-Next`](https://github.com/Redminote11tech/KernelSU-Next)
branch `v2.2.0-legacy-susfs`, which carries the SUSFS v2 driver and pins
`KSU_VERSION` to 33214.

KernelSU is built with `CONFIG_KSU_MANUAL_HOOK`, not kprobes. The hook lives in
the kernel tree at `kernel/reboot.c` (`ksu_handle_sys_reboot`) — Kbuild greps for
it, and the build stops with *"No hooks were defined"* if it goes missing.

> [!NOTE]
> The KernelSU Kbuild **rewrites kernel sources in place** at build time with
> `sed`, touching ~two dozen paths (`fs/namespace.c`, `include/linux/seccomp.h`,
> `security/selinux/*`, `kernel/cred.c` …). The edits are idempotent, but it is
> why a tree can look dirty after a build.

## ⚠️ Known issues

- **Enforcing bootloops on the Un1ca One UI 8 port.** Use Permissive there.
- **SUSFS on-device behaviour is still being validated.** v2.2.0 builds, links
  and reports correctly, and its ABI matches what current SUSFS tooling probes
  for — but broad on-device confirmation across ROMs is ongoing. Report what you
  find in [Issues](../../issues).
- **KernelSU-Next lineage.** This tree runs a `v3.0.1-legacy`-based driver
  carrying SUSFS v2 support, with the reported version pinned to 33214. Upstream
  KernelSU-Next is separately at v3.3.0; the two version lines are not directly
  comparable.
- Permissive builds cannot be returned to enforcing at runtime — by design.

## 🤝 Contributing

Bug reports are genuinely useful, especially with a `/proc/last_kmsg` or a TWRP
dmesg capture if something fails to boot. Say which **device**, which **ROM**,
and which **ZIP** you flashed — that combination is almost always the answer.

## 🧭 Upstream

Forked from [duhansysl/exynos9810-kernel](https://github.com/duhansysl/exynos9810-kernel)
(`duhan-(4.9.337)`), itself based on ananjaser1211's Apollo.

```bash
git fetch upstream && git merge upstream/'duhan-(4.9.337)'
```

## 💛 Credits

- [@duhansysl](https://github.com/duhansysl) — kernel source and the Apollo build system
- [@ananjaser1211](https://github.com/ananjaser1211) — original Apollo kernel base
- [@RifsxD](https://github.com/rifsxd) — KernelSU-Next
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) — SUSFS
- [@gavdoc38](https://github.com/gavdoc38) — SUSFS v2 driver pairing for Exynos 9810
- [cyberc3dr](https://github.com/cyberc3dr/nGKI_Kernel_Build) — SUSFS v2.2.0 patch set for 4.9
- [sidex15](https://github.com/sidex15) — SUSFS module and binaries

## 📄 License

GPL-2.0, inherited from the Linux kernel. See [COPYING](COPYING).

<div align="center">
<sub>Your warranty is now void. Flash responsibly.</sub>
</div>
