#!/usr/bin/env bash
# Keep local KernelSU fixes reproducible without an unpublished submodule commit.
set -euo pipefail

kernel_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ksu_root="$kernel_root/KernelSU-Next"
patch_file="$kernel_root/scripts/ksu-patches/0001-exynos9810-susfs-integration.patch"
base_revision=$(cat "$kernel_root/scripts/ksu-patches/base-revision")

if [ ! -f "$ksu_root/kernel/runtime/boot_event.c" ]; then
    echo "KernelSU-Next is missing; run git submodule update --init --recursive" >&2
    exit 1
fi

if [ "$(git -C "$ksu_root" rev-parse HEAD)" != "$base_revision" ]; then
    echo "KernelSU-Next revision mismatch; restore the pinned submodule before applying fixes." >&2
    exit 1
fi

if git -C "$ksu_root" apply --reverse --check "$patch_file" 2>/dev/null; then
    exit 0
fi

if ! git -C "$ksu_root" apply --check "$patch_file"; then
    echo "KernelSU fixes conflict with the current submodule; review local changes." >&2
    exit 1
fi

git -C "$ksu_root" apply "$patch_file"
