# DS-ACK Kernel — Exynos 9810

Custom Linux 4.9.337 kernel for the Galaxy S9, S9+ and Note 9, built around
KernelSU-Next and SUSFS. Developed against **NobleROM (One UI 7 / Android 15)**.

Source version: **V3.2.0** · KernelSU-Next **v3.2.0-legacy** · SUSFS **v1.5.5**

> [!WARNING]
> Flashing a custom kernel can leave your device unbootable and trips Knox
> permanently. Take a full TWRP backup of `boot` and `dtbo` before you start,
> and make sure you know how to get back to stock with Odin. Nobody but you is
> responsible for what happens to your phone.

## Supported devices

| Model | Codename | Build target |
| --- | --- | --- |
| SM-G960F / G960N | `starlte` | 1 / 4 (KOR) |
| SM-G965F / G965N | `star2lte` | 2 / 5 (KOR) |
| SM-N960F / N960N | `crownlte` | 3 / 6 (KOR) |

Snapdragon variants (G960U, G965U, N960U) are **not** supported and never will
be — this is an Exynos tree.

## Features

- **Root:** KernelSU-Next v3.2.0-legacy, wired up with manual syscall hooks
  rather than kprobes.
- **Root hiding:** SUSFS v1.5.5 integrated in-tree, including the SUSFS command
  dispatcher on `prctl`.
- **Module support:** works with the sidex15 Universal SUSFS module, with the
  auto-hide settings unlocked.
- **eBPF:** BPF verifier, cgroup-bpf and sockmap infrastructure backported from
  upstream Apollo, for userspace that expects a newer BPF surface.
- **Display:** driver-level brightness scaling fix for One UI 7.
- **SELinux:** both Enforcing and Permissive builds are produced; Enforcing is
  the default. See [Which build to pick](#which-build-to-pick).
- **One installer:** a single ZIP carries all three devices — the S9 image plus
  bsdiff patches for S9+ and Note 9 — and picks the right one at flash time.

## Installing

**You need:** an unlocked bootloader, TWRP installed, and a One UI 7 ROM
(NobleROM is what this is developed and tested against).

1. Download a ZIP from the [Releases page](../../releases).
2. Reboot to TWRP and back up `boot` and `dtbo`.
3. Flash the ZIP.
4. Reboot. If it doesn't boot, restore your backup from TWRP.
5. Install the [KernelSU-Next Manager APK](https://github.com/KernelSU-Next/KernelSU-Next/releases)
   and open it — it should report the kernel as installed.
6. In the manager, install the sidex15 Universal SUSFS module, then reboot.

### Which build to pick

Each release ships four ZIPs, from two independent choices:

| | Enforcing | Permissive |
| --- | --- | --- |
| **KernelSU** | Root, SELinux intact. **Start here.** | Root, SELinux off |
| **No KernelSU** | Clean kernel | SELinux off, no root |

Permissive disables SELinux enforcement device-wide. It fixes some misbehaving
modules and ROM combinations, but it is a real reduction in your device's
security — only reach for it if an Enforcing build actually fails you.

## Building from source

**Host requirements:** Linux, `bsdiff` (the script offers to install it via
apt/dnf/pacman), and roughly 40 GB free. `apollo.sh` downloads its own Clang
toolchain on first run.

This repo uses a git submodule for KernelSU-Next, so clone recursively:

```bash
git clone --recurse-submodules https://github.com/Redminote11tech/exynos9810-kernel.git
cd exynos9810-kernel
./apollo.sh
```

Already cloned without it?

```bash
git submodule update --init --recursive
```

`apollo.sh` prompts for device, compiler, SELinux mode, KernelSU and clean/dirty,
then drops a flashable ZIP in `Apollo/Product`. Option **7** builds the
all-device ZIP; option **8** builds the four release ZIPs in one run.

> The multi-device ZIP is assembled with `starlte` as the base image and bsdiff
> patches for the others, so it only comes out of options 7 and 8. Building a
> single non-`starlte` target gives you an image, not a universal package.

#### Output layout and parallel builds

Builds are out-of-tree. Each target compiles into its own directory under
`out/`, named `<variant>-<selinux>-<ksu>`, e.g. `out/G960F-enforcing-ksu`. The
source tree stays clean, and because no two targets share a `.config` or an
object file, multi-target builds compile several devices at once:

```bash
CR_PARALLEL=3 ./apollo.sh      # 3 devices at a time
```

Each concurrent build gets `nproc / CR_PARALLEL` make jobs, so total thread
count stays constant. The default is 2 — keep it low, since ThinLTO linking is
memory hungry and several simultaneous links will swap a 16 GB machine. Compiles
run in parallel; packaging always runs sequentially afterwards. Per-target
output goes to `logs/build-<pid>/target-N.log`.

Because each target keeps its own output dir, a rebuild after changing one
device (or just flipping SELinux mode) is incremental instead of a full rebuild.

> **Coming from an older checkout:** kbuild refuses out-of-tree builds while the
> source tree still holds in-tree build output. `apollo.sh` detects this and
> tells you; the one-time fix is
> `make ARCH=arm64 mrproper && rm -f KernelSU-Next/kernel/*.o KernelSU-Next/kernel/*/*.o`.

### The KernelSU-Next submodule

The submodule tracks [`Redminote11tech/KernelSU-Next`](https://github.com/Redminote11tech/KernelSU-Next),
branch `v3.2.0-legacy-susfs-patched` — a fork of KernelSU-Next carrying the
legacy SUSFS v1.5.5 patches and the `prctl` SUSFS dispatcher.

KernelSU's version number is computed from that submodule's commit count, so its
`.git` directory has to be present at build time or you get a fallback version
baked into the kernel.

### Manual hooks

KernelSU-Next is built with `CONFIG_KSU_MANUAL_HOOK`, not kprobes. `apollo.sh`
sets this for every device variant. The hooks themselves live in the kernel tree:

| Hook | Location |
| --- | --- |
| `ksu_handle_sys_reboot` | `kernel/reboot.c` |
| `ksu_handle_prctl` (SUSFS commands) | `kernel/sys.c` |

Kbuild greps for these. If you rebase onto a new kernel base and lose either
call site, the build stops with *"No hooks were defined"*.

## Known issues

- **No V3.2.0 release is published yet.** The Releases page currently tops out
  at V2.0; this README documents the source tree.
- Permissive builds disable SELinux device-wide — deliberate, but understand the
  tradeoff before flashing one.

<!-- Add device-level issues here as they're reported: what's broken, on which
     variant, and whether there's a workaround. -->

## Upstream

Forked from [duhansysl/exynos9810-kernel](https://github.com/duhansysl/exynos9810-kernel)
(branch `duhan-(4.9.337)`), itself based on ananjaser1211's Apollo. To pull in
new Apollo work:

```bash
git fetch upstream
git merge upstream/'duhan-(4.9.337)'
```

## Credits

- [@duhansysl](https://github.com/duhansysl) — kernel source and the Apollo build system
- [@ananjaser1211](https://github.com/ananjaser1211) — original Apollo kernel base
- [@RifsxD](https://github.com/rifsxd) — KernelSU-Next
- [simonpunk](https://gitlab.com/simonpunk/susfs4ksu) — SUSFS
- sidex15 — Universal SUSFS module and the KSU-Next SUSFS work

## License

GPL-2.0, inherited from the Linux kernel. See [COPYING](COPYING).
