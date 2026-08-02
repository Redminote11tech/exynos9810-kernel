# DS-ACK V3.2.0 Kernel for Exynos 9810 (Galaxy S9 / S9+ / Note 9)

A highly optimized, actively updated custom Linux kernel (4.9.337) specifically designed for **NobleROM OneUI 7 (Android 15)**.

My goal with this fork is to provide the Exynos 9810 community with a completely modern, reliable, and up-to-date root environment. We have fully bridged the gap between legacy hardware and modern Android 15 root-hiding standards.

### 🌟 Key Features
*   **Bleeding-Edge Root:** Powered by **KernelSU-Next v3.2.0-legacy-susfs** with manual (non-kprobes) syscall hooks.
*   **Ultimate Root Hiding:** Native integration of **Universal SUSFS v1.5.5**.
*   **Module Ready:** 100% compatible with the community-standard **sidex15 Universal SUSFS Module** (Auto-hide settings fully unlocked).
*   **eBPF Support:** Backported BPF verifier, cgroup-bpf and sockmap infrastructure from upstream Apollo, for modern userspace that expects it.
*   **Hardware Fixes:** Proper driver-level scaling and fixed auto-brightness.
*   **Universal Installer:** One ZIP automatically detects and flashes the correct kernel for S9 (`starlte`), S9+ (`star2lte`), and Note 9 (`crownlte`), including Korean variants.
*   **SELinux Permissive**

### 📦 Installation Guide
1. Download the latest `DS-ACK-V3.2.0` zip from the [Releases Page](../../releases/latest).
2. Boot into TWRP and flash the ZIP.
3. Reboot to system and install the [KernelSU-Next Manager APK](https://github.com/KernelSU-Next/KernelSU-Next/releases).
4. Open the manager, go to Modules, and install the **sidex15 Universal SUSFS Module**.
5. Reboot to enjoy a fully hidden, modern root environment!

### 🔨 Building from Source

This repository uses a **git submodule** for KernelSU-Next, so clone it recursively:

```bash
git clone --recurse-submodules https://github.com/Redminote11tech/exynos9810-kernel.git
cd exynos9810-kernel
./apollo.sh
```

If you already cloned without `--recurse-submodules`:

```bash
git submodule update --init --recursive
```

The submodule tracks [`Redminote11tech/KernelSU-Next`](https://github.com/Redminote11tech/KernelSU-Next)
branch `v3.2.0-legacy-susfs-patched` — our fork of KernelSU-Next carrying the
legacy SUSFS v1.5.5 patches and the `prctl` SUSFS command dispatcher. The
KernelSU version string is derived from that submodule's git history, so its
`.git` directory must be present for the correct version to be baked in.

`apollo.sh` walks you through device, compiler, SELinux mode and KernelSU
selection, then builds a flashable ZIP into `Apollo/Product`. Option **8**
builds the four release ZIPs (Enforcing/Permissive × KSU/No-KSU) in one run.

#### Hook integration

KernelSU-Next is built with `CONFIG_KSU_MANUAL_HOOK` rather than kprobes.
`apollo.sh` sets this for **every** device variant, and the manual hooks live in
the kernel tree itself:

| Hook | Location |
| --- | --- |
| `ksu_handle_sys_reboot` | `kernel/reboot.c` |
| `ksu_handle_prctl` (SUSFS commands) | `kernel/sys.c` |

If you rebase onto a new kernel base, keep those two call sites or the build
stops with *"No hooks were defined"*.

### 🧭 Relationship to upstream

This is a fork of [duhansysl/exynos9810-kernel](https://github.com/duhansysl/exynos9810-kernel)
(branch `duhan-(4.9.337)`), itself based on ananjaser1211's Apollo. The
`upstream` remote is configured for pulling in new Apollo work:

```bash
git fetch upstream
git merge upstream/'duhan-(4.9.337)'
```

### 🙏 Credits
*   [@duhansysl](https://github.com/duhansysl) for the amazing kernel source and Apollo build system.
*   [@ananjaser1211](https://github.com/ananjaser1211) for the original Apollo kernel base.
*   [@RifsxD](https://github.com/rifsxd) for KernelSU-Next v3.2.0-legacy-susfs.
*   [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) for creating the incredible SUSFS.
*   sidex15 for the SUSFS Universal Module and KSU-Next SUSFS commits.

---
*Disclaimer: Your warranty is now void. I am not responsible for bricked devices, dead SD cards, or thermonuclear war. Please do some research before flashing.*
