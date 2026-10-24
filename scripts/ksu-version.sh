#!/usr/bin/env bash
# Report the same version as the pinned upstream Kbuild, without invoking make.
set -euo pipefail

kernel_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
ksu_root="$kernel_root/KernelSU-Next"

if [ -n "${KSU_VERSION_OVERRIDE:-}" ]; then
    [[ "$KSU_VERSION_OVERRIDE" =~ ^[0-9]+$ ]] || exit 1
    echo "$KSU_VERSION_OVERRIDE"
    exit 0
fi

revision_count=$(git -C "$ksu_root" rev-list --count HEAD)
version_offset=$(grep -oP 'expr 30000 \+ \$\(KSU_GIT_VERSION\) \+ \K[0-9]+' "$ksu_root/kernel/Kbuild")
[[ "$revision_count" =~ ^[0-9]+$ && "$version_offset" =~ ^[0-9]+$ ]] || exit 1
echo "$((30000 + revision_count + version_offset))"
