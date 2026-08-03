# DS-ACK Kernel — Exynos 9810

Custom Linux 4.9.337 kernel for the Galaxy S9, S9+ and Note 9, built around
KernelSU-Next and SUSFS. Developed against **NobleROM (One UI 7 / Android 15)**,
and actively maintained.

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

- **Boots on One UI 7.** Confirmed working on NobleROM (Android 15).
- **Root:** KernelSU-Next v3.2.0-legacy, wired up with manual syscall hooks
  rather than kprobes.
- **Root hiding:** SUSFS v1.5.5 integrated in-tree, including the SUSFS command
  dispatcher on `prctl`.
- **SELinux Enforcing:** the default, and fully supported — root works with
  SELinux left enforcing. See [SELinux modes](#selinux-modes).
- **eBPF:** BPF verifier, cgroup-bpf and sockmap infrastructure backported from
  upstream Apollo, for userspace that expects a newer BPF surface.
- **One installer:** a single ZIP carries all three devices — the S9 image plus
  bsdiff patches for S9+ and Note 9 — and picks the right one at flash time.

Upstream KernelSU-Next is at **v3.3.0** (July 2026); this tree is on v3.2.0.
See [Known issues](#known-issues).

## Installing

**You need:** an unlocked bootloader, TWRP installed, and a One UI 7 ROM
(NobleROM is what this is developed and tested against).

1. Download a ZIP from the [Releases page](../../releases).
2. Reboot to TWRP and back up `boot` and `dtbo`.
3. Flash the ZIP.
4. Reboot. If it doesn't boot, restore your backup from TWRP.
5. Install the [KernelSU-Next Manager APK](https://github.com/KernelSU-Next/KernelSU-Next/releases)
   and open it — it should report the kernel as installed.

Match the manager version to the kernel: this tree ships KernelSU-Next
**v3.2.0-legacy**, so use a v3.2.x manager.

### Which build to pick

Each release ships four ZIPs, from two independent choices:

| | Enforcing | Permissive |
| --- | --- | --- |
| **KernelSU** | Root, SELinux intact. **Start here.** | Root, SELinux off |
| **No KernelSU** | Clean kernel | SELinux off, no root |

### SELinux modes

**Enforcing is the default and is fully supported.** Rooting this kernel does
not require turning SELinux off: KernelSU-Next and SUSFS both work with
enforcement left on, and that is the build you should be running. Permissive
builds still exist, but they are a debugging fallback, not a feature. Verify
after flashing with:

```
adb shell getenforce      # -> Enforcing
```

**Permissive** is a separate build, selected at compile time by
`CONFIG_ALWAYS_PERMISSIVE`. That option makes the kernel clamp every write to
`/sys/fs/selinux/enforce` to `0`, so the device cannot be put back into
enforcing mode at runtime — not even by an app or script that asks nicely. It
exists for diagnosing a misbehaving module or ROM combination, and it is a real,
device-wide reduction in security. Reach for it only when an Enforcing build
actually fails you, and go back afterwards.

Enforcing builds simply don't set that option, so SELinux behaves exactly as the
ROM intends.

> Every image has `SEANDROIDENFORCE` appended, Permissive ones included. That is
> a marker the Samsung bootloader looks for to suppress the red boot warning —
> it has nothing to do with which SELinux mode the kernel runs in. Don't read it
> as proof you're on an Enforcing build; use `getenforce`.

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

`apollo.sh` prompts for device, compiler, SELinux mode (defaults to Enforcing),
KernelSU and clean/dirty,
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
- **Behind upstream KernelSU-Next.** This tree carries v3.2.0-legacy; upstream
  released v3.3.0 in July 2026. Moving up means re-applying the legacy SUSFS
  v1.5.5 patches and the `prctl` dispatcher onto the new base, so it is not a
  drop-in submodule bump.
- **SUSFS manager module support is unverified.** Earlier versions of this
  README claimed compatibility with the sidex15 Universal SUSFS module. That
  claim was not backed by testing and has been removed. The in-kernel SUSFS
  side is real; whether that module drives it correctly on this kernel is
  currently unconfirmed.
- Permissive builds disable SELinux device-wide and cannot be switched back to
  enforcing at runtime — flash the Enforcing build unless you have a specific
  reason not to.

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
