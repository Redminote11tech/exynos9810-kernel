#!/bin/bash
# Minimal Samsung-style build stub. For real builds use ./apollo.sh, which
# handles the toolchain, KernelSU, SELinux mode and packaging.

export ARCH=arm64
export ANDROID_MAJOR_VERSION=q
make crownlte_defconfig
make -j"$(nproc)"
