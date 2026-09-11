#!/bin/bash
#
# Apollo Build Script V3.5
# For Exynos9810
# Forked from Exynos8890 Script
# Coded by AnanJaser1211 @ 2019-2022
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
# Main Dir
CR_DIR=$(pwd)
# Compiler Dir. Must be absolute: out-of-tree builds re-exec make with
# -C <output dir>, so a relative path would resolve against the output dir and
# silently drop the toolchain off PATH, leaving the build to pick up whatever
# clang the host happens to have.
CR_TC=$(dirname "$CR_DIR")/compiler
# Target ARCH
CR_ARCH=arm64
# Define proper arch and dir for dts files
CR_DTS=arch/$CR_ARCH/boot/dts/exynos
# Define boot.img out dir
CR_OUT=$CR_DIR/Apollo/Out
CR_PRODUCT=$CR_DIR/Apollo/Product
# Kernel Zip Package
CR_ZIP=$CR_DIR/Apollo/kernelzip
CR_OUTZIP=$CR_OUT/kernelzip
# Presistant A.I.K Location
CR_AIK=$CR_DIR/Apollo/A.I.K
# Main Ramdisk Location
CR_RAMDISK=$CR_DIR/Apollo/Ramdisk
# Root for per-target kbuild output dirs (make O=...). Each target builds into
# its own tree, so targets never share a .config or object file and can run
# concurrently. CR_KERNEL/CR_DTB are set per target by BUILD_TARGET_ID.
CR_OUT_ROOT=$CR_DIR/out
CR_KERNEL=
CR_DTB=
# defconfig dir
CR_DEFCONFIG=$CR_DIR/arch/$CR_ARCH/configs
# Kernel Name and Version
CR_VERSION=V3.2.1-susfs2
CR_NAME=DS-ACK
# Thread count. Plain nproc respects CPU affinity and cgroup limits;
# --all ignores both and oversubscribes in containers or under taskset.
CR_JOBS=$(nproc)
# How many device targets to compile at once during a multi-target build.
# Each concurrent build gets CR_JOBS/CR_PARALLEL make jobs, so the total thread
# count stays at CR_JOBS. Keep this low: ThinLTO linking is memory hungry and
# several concurrent links will swap a 16 GB machine to death. Override with
# CR_PARALLEL=n ./apollo.sh
CR_PARALLEL=${CR_PARALLEL:-2}
# Target Android version
CR_ANDROID=q
CR_PLATFORM=13.0.0
# Current Date
CR_DATE=$(date +%d.%m.%Y)
# General init
export KSU_MANUAL_HOOK=y
export CONFIG_KSU_MANUAL_HOOK=y
export ANDROID_MAJOR_VERSION=$CR_ANDROID
export PLATFORM_VERSION=$CR_PLATFORM
export $CR_ARCH
##########################################
# Device specific Variables [SM-G960X]
CR_CONFIG_G960=starlte_defconfig
CR_VARIANT_G960F=G960F
CR_VARIANT_G960N=G960N
# Device specific Variables [SM-G965X]
CR_CONFIG_G965=star2lte_defconfig
CR_VARIANT_G965F=G965F
CR_VARIANT_G965N=G965N
# Device specific Variables [SM-N960X]
CR_CONFIG_N960=crownlte_defconfig
CR_VARIANT_N960F=N960F
CR_VARIANT_N960N=N960N
# Common configs
CR_CONFIG_9810=exynos9810_defconfig
CR_CONFIG_SPLIT=NULL
CR_CONFIG_APOLLO=apollo_defconfig
CR_CONFIG_INTL=eur_defconfig
CR_CONFIG_KOR=kor_defconfig
CR_SELINUX="2"
# KernelSU (and SUSFS with it) is always built; the no-KSU variant was
# removed — it shipped neither root nor root hiding.
CR_KSU="y"
CR_CLEAN="n"
# Default Compilation
DEFAULT_TARGET=3   # crownlte
DEFAULT_COMPILER=3 # clang18
DEFAULT_SELINUX=2  # enforce
DEFAULT_KSU=y      # enabled
DEFAULT_CLEAN=n    # dirty
#####################################################

# Compiler Selection
BUILD_COMPILER()
{

# Auto download and setup compilers
# For manually adding compiler, add it under
# Apollo/toolchain/clang-custom and select option 7

# Clang Versions and features

if [ $CR_COMPILER = "1" ]; then
CR_CLANG_URL=https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/llvm-r416183/clang-r416183.tar.gz
CR_CLANG=$CR_TC/clang-12.0.4-r416183
fi
if [ $CR_COMPILER = "2" ]; then
CR_CLANG_URL=https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/llvm-r450784/clang-r450784b.tar.gz
CR_CLANG=$CR_TC/clang-14.0.4-r450784
fi
if [ $CR_COMPILER = "3" ]; then
CR_CLANG_URL=https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/llvm-r522817/clang-r522817.tar.gz
CR_CLANG=$CR_TC/clang-18.0.1-r522817
fi
if [ $CR_COMPILER = "4" ]; then
CR_CLANG_URL=https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86/+archive/refs/heads/main/clang-r547379.tar.gz
CR_CLANG=$CR_TC/clang-20.0.0-r547379
fi
if [ $CR_COMPILER = "5" ]; then
CR_CLANG_URL=https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/05012024/neutron-clang-05012024.tar.zst
CR_CLANG=$CR_TC/neutron-clang-18.0.0
fi
if [ $CR_COMPILER = "6" ]; then
CR_CLANG_URL=https://github.com/Neutron-Toolchains/clang-build-catalogue/releases/download/10032024/neutron-clang-10032024.tar.zst
CR_CLANG=$CR_TC/neutron-clang-19.0.0
fi
if [ $CR_COMPILER = "7" ]; then
CR_CLANG=$CR_TC/neutron-clang-20.0.0
fi
if [ $CR_COMPILER = "8" ]; then
CR_CLANG=$CR_TC/clang-custom
fi

if [ $CR_COMPILER != "8" ]; then
	if [ ! -d "$CR_CLANG/bin" ] || [ ! -d "$CR_CLANG/lib" ]; then
		echo " "
		echo " $CR_CLANG compiler is missing"
		echo " "
		echo " "
		read -p "Download Toolchain ? (y/n) > " TC_DL
		if [ $TC_DL = "y" ]; then
			echo "Checking URL validity..."
			URL=$CR_CLANG_URL
			if curl --output /dev/null --silent --head --fail "$URL"; then
				echo "URL exists: $URL"
				echo "Downloading $CR_CLANG"
				if [ ! -e $CR_TC ]; then
					mkdir $CR_TC
				fi
				if [ ! -e $CR_CLANG ]; then
					mkdir $CR_CLANG
				else
					# Remove incomplete
					rm -rf $CR_CLANG
					mkdir $CR_CLANG
				fi
				wget -qO- $URL | tar --use-compress-program=unzstd -xv -C $CR_CLANG
				if [ $? -ne 0 ]; then
					echo "Download failed or was incomplete"
					echo "Setup Compiler and try again"
					exit 1;
				fi
				# Neutron Needs patches
				if [ $CR_COMPILER = "5" ] || [ $CR_COMPILER = "6" ]; then
					cd $CR_CLANG
					bash <(curl -s "https://raw.githubusercontent.com/Neutron-Toolchains/antman/main/antman") --patch=glibc
					cd $CR_DIR
				fi
				echo "Compiler Downloaded."
			else
				echo "Invalid URL: $URL"
				exit 1;
			fi
		else
			echo " Aborting "
			echo " Setup Compiler and try again"
			exit 1;
		fi
	fi
else
    if [ ! -d "$CR_CLANG/bin" ] || [ ! -d "$CR_CLANG/lib" ]; then
        echo "clang-custom compiler is missing in $CR_TC/clang-custom"
        exit 1;
    fi
fi

# Clang Features (18 and higher)
if [ $CR_COMPILER -ge 3 ]; then
export CONFIG_THINLTO=y
export CONFIG_UNIFIEDLTO=y
export CONFIG_LLVM_MLGO_REGISTER=y
export CONFIG_LLVM_POLLY=y
export CONFIG_LLVM_DFA_JUMP_THREAD=y
fi

# BUILD_COMPILER runs once per target (24 times in a full release build), so
# guard against prepending the same entries to PATH over and over.
if [ -z "$CR_BASE_PATH" ]; then
	CR_BASE_PATH="$PATH"
fi
export PATH=$CR_CLANG/bin:$CR_CLANG/lib:$CR_BASE_PATH
export CC=$CR_CLANG/bin/clang
export REAL_CC=$CR_CLANG/bin/clang
export LD=$CR_CLANG/bin/ld.lld
export AR=$CR_CLANG/bin/llvm-ar
export NM=$CR_CLANG/bin/llvm-nm
export OBJCOPY=$CR_CLANG/bin/llvm-objcopy
export OBJDUMP=$CR_CLANG/bin/llvm-objdump
export READELF=$CR_CLANG/bin/llvm-readelf
export STRIP=$CR_CLANG/bin/llvm-strip
export LLVM=1
export KALLSYMS_EXTRA_PASS=1
export ARCH=arm64 && export SUBARCH=arm64
compile="make ARCH=arm64 CC=clang"
CR_COMPILER_ARG="$CR_CLANG"

# The build calls plain 'clang' and relies on PATH. Confirm that resolves to the
# toolchain we just selected: a host clang picked up by mistake will reject this
# tree's -mfloat-abi=hard and fail deep into the build for no obvious reason.
CR_CLANG_RESOLVED=$(command -v clang)
case "$CR_CLANG_RESOLVED" in
	"$CR_CLANG"/bin/clang) ;;
	*)
		echo "----------------------------------------------"
		echo " Wrong clang on PATH."
		echo " expected: $CR_CLANG/bin/clang"
		echo " found:    ${CR_CLANG_RESOLVED:-none}"
		echo "----------------------------------------------"
		exit 1;
		;;
esac
}

# Out-of-tree builds refuse to run if the source tree still holds output from
# an older in-tree build. Detect that once, up front, with the fix spelled out,
# rather than letting kbuild fail in the middle of a six-target run.
BUILD_CHECK_SRCTREE()
{
	if [ -e $CR_DIR/.config ] || [ -e $CR_DIR/built-in.o ] || [ -e $CR_DIR/vmlinux.o ]; then
		echo "----------------------------------------------"
		echo " This tree contains output from an older in-tree build."
		echo " apollo.sh now builds out-of-tree (make O=), which kbuild"
		echo " refuses to do until the source tree is clean."
		echo " "
		echo " Run this once, then build again:"
		echo " "
		echo "     make ARCH=arm64 mrproper"
		echo "     rm -f KernelSU-Next/kernel/*.o KernelSU-Next/kernel/*/*.o"
		echo " "
		echo " Your out/ directories and Apollo/Product are not affected."
		echo "----------------------------------------------"
		exit 1;
	fi

	# mrproper does not remove firmware blobs generated from .ihex/.HEX/.H16
	# sources. Left behind in the source tree they satisfy make's prerequisite
	# through VPATH, so the blob is never generated into the output dir - and
	# the .incbin in the generated .gen.S is a relative path resolved against
	# that output dir, so the assembler then cannot find it. Regenerating them
	# is free, so clear them rather than making this the user's problem.
	local stale
	stale=$(find $CR_DIR/firmware -type f \( -name '*.bin' -o -name '*.fw' \) 2>/dev/null | \
		while read -r f; do
			for ext in .ihex .HEX .H16; do
				[ -e "$f$ext" ] && echo "$f"
			done
		done)
	if [ -n "$stale" ]; then
		echo " Removing stale generated firmware blobs:"
		echo "$stale" | while read -r f; do
			echo "   ${f#$CR_DIR/}"
			rm -f "$f"
		done
	fi
}

# Per-target identity: output dir, artifact paths and defconfig name.
# Every target gets its own kbuild output tree and its own generated defconfig,
# which is what makes concurrent builds safe.
BUILD_TARGET_ID()
{
	local sel ksu
	if [ "$CR_SELINUX" = "1" ]; then sel=permissive; else sel=enforcing; fi
	ksu=ksu # KernelSU is always built
	CR_TAG=$CR_VARIANT-$sel-$ksu
	CR_OUTDIR=$CR_OUT_ROOT/$CR_TAG
	CR_TMPCONFIG=tmp_${CR_TAG}_defconfig
	CR_KERNEL=$CR_OUTDIR/arch/$CR_ARCH/boot/Image
	CR_DTB=$CR_OUTDIR/arch/$CR_ARCH/boot/dtb.img
}

# Clean-up Function
#
# With out-of-tree builds a clean is just removing the target's output dir, so
# it no longer disturbs other targets or the source tree. Dirty builds keep the
# output dir and let kbuild do incremental work, which is the whole point of
# giving each target its own.

BUILD_CLEAN()
{
if [[ "$CR_CLEAN" =~ ^[yY]$ ]]; then
     rm -rf $CR_OUTDIR
     rm -rf $CR_OUT/*.img
     rm -rf $CR_OUT/*.zip
fi
}

# Kernel Name Function

BUILD_IMAGE_NAME()
{
	CR_IMAGE_NAME=$CR_NAME-$CR_VERSION-$CR_VARIANT-$CR_DATE
	zver=$CR_NAME-$CR_VERSION-$CR_DATE
    
}

# Build options
BUILD_OPTIONS()
{
	# KSU Version - mirrors drivers/kernelsu/Kbuild. That Kbuild pins
	# KSU_VERSION_OVERRIDE so the driver reports a version the stable
	# KernelSU-Next manager accepts; honour it when present, otherwise fall
	# back to the computed 30000 + rev-count + 200.
	KSU_VERSION=$(grep -oP '^KSU_VERSION_OVERRIDE\s*:=\s*\K[0-9]+' KernelSU-Next/kernel/Kbuild 2>/dev/null)
	if [ -z "$KSU_VERSION" ]; then
		KSU_REV=$(cd KernelSU-Next 2>/dev/null && git rev-list --count HEAD 2>/dev/null)
		[ -n "$KSU_REV" ] && KSU_VERSION=$(( 30000 + KSU_REV + 200 ))
	fi
	echo "----------------------------------------------"
	echo " Apollo Kernel Build Options "
	echo " "
	echo " Kernel		- $CR_IMAGE_NAME"
	echo " Device		- $CR_VARIANT"
	echo " Compiler	- $CR_COMPILER_ARG"
	if [[ "$CR_CLEAN" =~ ^[yY]$ ]]; then
		echo " Env		- Clean Build"
	else
		echo " Env		- Dirty Build"
	fi
	if [ $CR_SELINUX = "1" ]; then
		echo " SELinux	- Permissive"
	else
		echo " SELinux	- Enforcing"
	fi
	if [[ "$CR_KSU" =~ ^[yY]$ ]]; then
		if [ -n "$KSU_VERSION" ]; then
		echo " KernelSU	- Version: $KSU_VERSION"
		else
		echo " KernelSU	- Enabled"
		fi
	else
		echo " KernelSU	- Disabled"
	fi
	echo " "
}

# Config Generation Function

BUILD_GENERATE_CONFIG()
{
  # Only use for devices that are unified with 2 or more configs
  echo "----------------------------------------------"
  echo " Generating defconfig for $CR_VARIANT"
  echo " "
  # Respect CLEAN build rules
  BUILD_CLEAN
  if [ -e $CR_DEFCONFIG/$CR_TMPCONFIG ]; then
    echo " Clean-up old config "
    rm -rf $CR_DEFCONFIG/$CR_TMPCONFIG
  fi
  echo " Base	- $CR_CONFIG "
  cp -f $CR_DEFCONFIG/$CR_CONFIG $CR_DEFCONFIG/$CR_TMPCONFIG
  # Split-config support for devices with unified defconfigs (Universal + device)
  if [ $CR_CONFIG_SPLIT = NULL ]; then
    echo " No split config support! "
  else
    echo " Device - $CR_CONFIG_SPLIT "
    cat $CR_DEFCONFIG/$CR_CONFIG_SPLIT >> $CR_DEFCONFIG/$CR_TMPCONFIG
  fi
  # Regional Config
  echo " Region	- $CR_CONFIG_REGION "
  cat $CR_DEFCONFIG/$CR_CONFIG_REGION >> $CR_DEFCONFIG/$CR_TMPCONFIG
  # Apollo Custom defconfig
  echo " Apollo	- $CR_CONFIG_APOLLO "
  cat $CR_DEFCONFIG/$CR_CONFIG_APOLLO >> $CR_DEFCONFIG/$CR_TMPCONFIG
  # Selinux Never Enforce all targets
  if [ $CR_SELINUX = "1" ]; then
    echo " Building SELinux Permissive Kernel"
    echo "CONFIG_ALWAYS_PERMISSIVE=y" >> $CR_DEFCONFIG/$CR_TMPCONFIG
    CR_IMAGE_NAME=$CR_IMAGE_NAME-Permissive
    zver=$zver-Permissive
  else
    echo " Building SELinux Enforced Kernel"
  fi
  if [[ "$CR_KSU" =~ ^[yY]$ ]]; then
    echo " Building KernelSU"
    echo "CONFIG_KSU=y" >> $CR_DEFCONFIG/$CR_TMPCONFIG
    # KSU-Next needs an explicit hook mode or Kbuild aborts with "No hooks were
    # defined". The export at the top of this script satisfies the Kbuild check;
    # this makes the symbol real in .config for every variant, not just starlte.
    echo "CONFIG_KSU_MANUAL_HOOK=y" >> $CR_DEFCONFIG/$CR_TMPCONFIG
    CR_IMAGE_NAME=$CR_IMAGE_NAME-KSU
    zver=$zver-KernelSU
  else
    echo "# CONFIG_KSU is not set" >> $CR_DEFCONFIG/$CR_TMPCONFIG
  fi
  echo " $CR_VARIANT config generated "
  echo " "
  CR_CONFIG=$CR_TMPCONFIG
}

# Kernel information Function
BUILD_OUT()
{
# KSU Version - mirrors drivers/kernelsu/Kbuild. That Kbuild pins
# KSU_VERSION_OVERRIDE so the driver reports a version the stable
# KernelSU-Next manager accepts; honour it when present, otherwise fall
# back to the computed 30000 + rev-count + 200.
	KSU_VERSION=$(grep -oP '^KSU_VERSION_OVERRIDE\s*:=\s*\K[0-9]+' KernelSU-Next/kernel/Kbuild 2>/dev/null)
	if [ -z "$KSU_VERSION" ]; then
		KSU_REV=$(cd KernelSU-Next 2>/dev/null && git rev-list --count HEAD 2>/dev/null)
		[ -n "$KSU_REV" ] && KSU_VERSION=$(( 30000 + KSU_REV + 200 ))
	fi
  echo "----------------------------------------------"
  echo " Kernel		- $CR_IMAGE_NAME"
  echo " Device		- $CR_VARIANT"
  echo " Compiler	- $CR_COMPILER_ARG"
	if [[ "$CR_CLEAN" =~ ^[yY]$ ]]; then
		echo " Env		- Clean Build"
	else
		echo " Env		- Dirty Build"
	fi
	if [ $CR_SELINUX = "1" ]; then
		echo " SELinux	- Permissive"
	else
		echo " SELinux	- Enforcing"
	fi
  echo " KernelSU	- Version: $KSU_VERSION"
  echo "----------------------------------------------"
  echo "$CR_VARIANT kernel build finished."
  echo "Compiled DTB Size = $sizdT Kb"
  echo "Kernel Image Size = $sizT Kb"
  echo "Boot Image   Size = $sizkT Kb"
  echo "$CR_PRODUCT/$CR_IMAGE_NAME.img Ready"
  echo "Press Any key to end the script"
  echo "----------------------------------------------"
}

# Kernel Compile Function
BUILD_ZIMAGE()
{
	echo "----------------------------------------------"
	echo " "
	echo "Building zImage for $CR_VARIANT"
	export LOCALVERSION=-$CR_IMAGE_NAME
	mkdir -p $CR_OUTDIR
	echo "Make $CR_CONFIG"
	if ! $compile O=$CR_OUTDIR $CR_CONFIG; then
		echo "Failed to generate .config from $CR_CONFIG"
		echo " Abort "
		exit 1;
	fi
	echo "Make Kernel with $CR_COMPILER_ARG ($CR_MAKE_JOBS jobs)"
	if ! $compile O=$CR_OUTDIR -j$CR_MAKE_JOBS; then
		echo "Image Failed to Compile"
		echo " Abort "
		exit 1;
	fi
	if [ ! -e $CR_KERNEL ]; then
		echo "Image Failed to Compile"
		echo " Abort "
		exit 1;
	fi
	sizT=$(du -k "$CR_KERNEL" | cut -f1)
	echo " "
	echo "----------------------------------------------"
}

# Device-Tree compile Function
BUILD_DTB()
{
	echo "----------------------------------------------"
	echo " "
	echo "Checking DTB for $CR_VARIANT"
	# This source does compiles dtbs while doing Image
	if [ ! -e $CR_DTB ]; then
        echo "DTB Failed to Compile"
        echo " Abort "
        exit 1;
	else
        echo "DTB Compiled at $CR_DTB"
	fi
	sizdT=$(du -k "$CR_DTB" | cut -f1)
	echo " "
	echo "----------------------------------------------"
}

# Ramdisk Function
PACK_BOOT_IMG()
{
	echo "----------------------------------------------"
	echo " "
	echo "Building Boot.img for $CR_VARIANT"
	# Copy Ramdisk
	cp -rf $CR_RAMDISK/* $CR_AIK
	# Move Compiled kernel and dtb to A.I.K Folder
	mv $CR_KERNEL $CR_AIK/split_img/boot.img-zImage
	mv $CR_DTB $CR_AIK/split_img/boot.img-dtb
	# Create boot.img
	$CR_AIK/repackimg.sh
	if [ ! -e $CR_AIK/image-new.img ]; then
        echo "Boot Image Failed to pack"
        echo " Abort "
        exit 1;
	fi
	# Remove red warning at boot
	echo -n "SEANDROIDENFORCE" >> $CR_AIK/image-new.img
	# Copy boot.img to Production folder
	if [ ! -e $CR_PRODUCT ]; then
        mkdir $CR_PRODUCT
	fi
	cp $CR_AIK/image-new.img $CR_PRODUCT/$CR_IMAGE_NAME.img
	# Move boot.img to out dir
	if [ ! -e $CR_OUT ]; then
        mkdir $CR_OUT
	fi
	mv $CR_AIK/image-new.img $CR_OUT/$CR_IMAGE_NAME.img
	sizkT=$(du -k "$CR_OUT/$CR_IMAGE_NAME.img" | cut -f1)
	echo " "
	$CR_AIK/cleanup.sh
	# Respect CLEAN build rules
	BUILD_CLEAN
}

# Map a numeric target onto its device, configs and machine symbol.
# Split out of BUILD so the parallel driver can resolve a target's identity
# without compiling it.
BUILD_SELECT_TARGET()
{
	# arch/arm64/boot/dts/Makefile keys dtb-y off these, and they come from the
	# environment rather than .config. Clear all six before selecting one, or a
	# leftover from an earlier target makes dtb.img contain the wrong devices.
	unset CONFIG_MACH_EXYNOS9810_STARLTE_EUR_OPEN
	unset CONFIG_MACH_EXYNOS9810_STAR2LTE_EUR_OPEN
	unset CONFIG_MACH_EXYNOS9810_CROWNLTE_EUR_OPEN
	unset CONFIG_MACH_EXYNOS9810_STARLTE_KOR
	unset CONFIG_MACH_EXYNOS9810_STAR2LTE_KOR
	unset CONFIG_MACH_EXYNOS9810_CROWNLTE_KOR
	if [ "$CR_TARGET" = "1" ]; then
		echo " Galaxy S9 INTL"
		CR_CONFIG_SPLIT=$CR_CONFIG_G960
		CR_CONFIG_REGION=$CR_CONFIG_INTL
		CR_VARIANT=$CR_VARIANT_G960F
		export "CONFIG_MACH_EXYNOS9810_STARLTE_EUR_OPEN=y"
	fi
	if [ "$CR_TARGET" = "2" ]; then
		echo " Galaxy S9+ INTL"
		CR_CONFIG_SPLIT=$CR_CONFIG_G965
		CR_CONFIG_REGION=$CR_CONFIG_INTL
		CR_VARIANT=$CR_VARIANT_G965F
		export "CONFIG_MACH_EXYNOS9810_STAR2LTE_EUR_OPEN=y"
	fi
	if [ "$CR_TARGET" = "3" ]
	then
		echo " Galaxy Note9 INTL"
		CR_CONFIG_SPLIT=$CR_CONFIG_N960
		CR_CONFIG_REGION=$CR_CONFIG_INTL
		CR_VARIANT=$CR_VARIANT_N960F
		export "CONFIG_MACH_EXYNOS9810_CROWNLTE_EUR_OPEN=y"
	fi
	if [ "$CR_TARGET" = "4" ]; then
		echo " Galaxy S9 KOR"
		CR_CONFIG_SPLIT=$CR_CONFIG_G960
		CR_CONFIG_REGION=$CR_CONFIG_KOR
		CR_VARIANT=$CR_VARIANT_G960N
		export "CONFIG_MACH_EXYNOS9810_STARLTE_KOR=y"
	fi
	if [ "$CR_TARGET" = "5" ]; then
		echo " Galaxy S9+ KOR"
		CR_CONFIG_SPLIT=$CR_CONFIG_G965
		CR_CONFIG_REGION=$CR_CONFIG_KOR
		CR_VARIANT=$CR_VARIANT_G965N
		export "CONFIG_MACH_EXYNOS9810_STAR2LTE_KOR=y"
	fi
	if [ "$CR_TARGET" = "6" ]
	then
		echo " Galaxy Note9 KOR"
		CR_CONFIG_SPLIT=$CR_CONFIG_N960
		CR_CONFIG_REGION=$CR_CONFIG_KOR
		CR_VARIANT=$CR_VARIANT_N960N
		export "CONFIG_MACH_EXYNOS9810_CROWNLTE_KOR=y"
	fi
	CR_CONFIG=$CR_CONFIG_9810
	BUILD_TARGET_ID
}

# Compile one target into its own output dir. Safe to run concurrently with
# other targets: nothing outside $CR_OUTDIR and the target's own defconfig is
# written, and the CONFIG_MACH_* export stays inside this shell.
BUILD_COMPILE_ONE()
{
	BUILD_SELECT_TARGET
	BUILD_CLEAN
	BUILD_IMAGE_NAME
	BUILD_GENERATE_CONFIG
	# Print build options
	BUILD_OPTIONS
	BUILD_ZIMAGE
	BUILD_DTB
}

# Turn one already-compiled target into a boot.img or fold it into the ZIP.
# Always sequential: A.I.K and the ZIP staging dir are shared state.
BUILD_PACKAGE_ONE()
{
	BUILD_SELECT_TARGET
	BUILD_IMAGE_NAME
	# Re-apply the name suffixes BUILD_GENERATE_CONFIG would have added, without
	# regenerating the defconfig.
	if [ "$CR_SELINUX" = "1" ]; then
		CR_IMAGE_NAME=$CR_IMAGE_NAME-Permissive
		zver=$zver-Permissive
	fi
	if [[ "$CR_KSU" =~ ^[yY]$ ]]; then
		CR_IMAGE_NAME=$CR_IMAGE_NAME-KSU
		zver=$zver-KernelSU
	fi
	if [ "$CR_MKZIP" = "y" ]; then # Allow Zip Package for mass compile only
		echo " Start Build ZIP Process "
		PACK_KERNEL_ZIP
	else
		PACK_BOOT_IMG
		BUILD_OUT
	fi
}

# Single Target Build Function
BUILD()
{
	BUILD_COMPILER
	CR_MAKE_JOBS=$CR_JOBS
	BUILD_COMPILE_ONE
	BUILD_PACKAGE_ONE
}

# Multi-Target Build Function
#
# Two phases. Compiles are independent once each target has its own output dir,
# so they run CR_PARALLEL at a time. Packaging is strictly sequential and in
# target order, because PACK_KERNEL_ZIP uses target 1 as the bsdiff base and
# target 6 as the signal to close the ZIP.
BUILD_ALL(){
echo "----------------------------------------------"
echo " Compiling ALL targets "
echo " Concurrency: $CR_PARALLEL targets x $(( CR_JOBS / CR_PARALLEL )) jobs "
echo "----------------------------------------------"

BUILD_COMPILER
# Round up, not down: with floor division an 8-core box at CR_PARALLEL=3 would
# run 3x2=6 jobs and leave two cores idle. Rounding up slightly oversubscribes,
# which is what fills the serial gaps (configure, link, kallsyms, dtbtool).
CR_MAKE_JOBS=$(( (CR_JOBS + CR_PARALLEL - 1) / CR_PARALLEL ))
[ "$CR_MAKE_JOBS" -lt 1 ] && CR_MAKE_JOBS=1

local logdir=$CR_DIR/logs/build-$$
mkdir -p $logdir
local all_targets="1 2 3 4 5 6"
local queue=($all_targets)
local failed=()
local i=0

while [ $i -lt ${#queue[@]} ]; do
	local pids=() tags=() n=0
	while [ $n -lt $CR_PARALLEL ] && [ $i -lt ${#queue[@]} ]; do
		local t=${queue[$i]}
		echo " [target $t] compiling -> $logdir/target-$t.log"
		( CR_TARGET=$t; BUILD_COMPILE_ONE ) > $logdir/target-$t.log 2>&1 &
		pids+=($!)
		tags+=($t)
		n=$(( n + 1 ))
		i=$(( i + 1 ))
	done
	local k=0
	while [ $k -lt ${#pids[@]} ]; do
		if wait ${pids[$k]}; then
			echo " [target ${tags[$k]}] OK"
		else
			echo " [target ${tags[$k]}] FAILED - see $logdir/target-${tags[$k]}.log"
			tail -20 $logdir/target-${tags[$k]}.log
			failed+=(${tags[$k]})
		fi
		k=$(( k + 1 ))
	done
done

if [ ${#failed[@]} -ne 0 ]; then
	echo "----------------------------------------------"
	echo " Build FAILED for targets: ${failed[*]}"
	echo " Logs in $logdir"
	echo "----------------------------------------------"
	exit 1;
fi

echo "----------------------------------------------"
echo " All targets compiled. Packaging "
echo "----------------------------------------------"
for t in $all_targets; do
	CR_TARGET=$t
	BUILD_PACKAGE_ONE
done
}

# Preconfigured Debug build
BUILD_DEBUG(){
echo "----------------------------------------------"
echo " DEBUG : Debug build initiated "
CR_TARGET=5
CR_COMPILER=3
CR_SELINUX=0
CR_KSU="y"
CR_CLEAN="n"
echo " DEBUG : Set Build options "
echo " DEBUG : Variant  : $CR_VARIANT_N960F"
echo " DEBUG : Compiler : Clang 18"
echo " DEBUG : Selinux  : $CR_SELINUX Enforcing"
echo " DEBUG : Clean    : $CR_CLEAN"
echo "----------------------------------------------"
BUILD
echo "----------------------------------------------"
echo " DEBUG : build completed "
echo "----------------------------------------------"
exit 0;
}

# Automated GitHub Release Function
BUILD_GITHUB_RELEASE(){
echo "----------------------------------------------"
echo " Initiating Automated GitHub Release Build "
echo " This will compile 2 ZIPs (Enforcing/Permissive, both with KernelSU + SUSFS)"
echo " Note: Performing 1 initial clean, then using dirty builds to save time."
echo "----------------------------------------------"

CR_MKZIP="y"
CR_CLEAN="n"

echo "=== [0/2] Initial Workspace Cleanup ==="
rm -r -f $CR_DTB
rm -r -f $CR_KERNEL
rm -rf $CR_DTS/.*.tmp
rm -rf $CR_DTS/.*.cmd
rm -rf $CR_DTS/*.dtb
rm -rf $CR_DIR/.config
rm -rf $CR_DIR/.version
rm -rf out/
rm -rf $CR_OUTZIP
echo " Cleanup done. Starting fast incremental builds..."
echo "----------------------------------------------"

# 1. Enforcing, KernelSU + SUSFS
echo "=== [1/2] Building Enforcing - KernelSU ==="
CR_SELINUX=2
CR_KSU="y"
BUILD_ALL

# 2. Permissive, KernelSU + SUSFS
echo "=== [2/2] Building Permissive - KernelSU ==="
CR_SELINUX=1
CR_KSU="y"
BUILD_ALL

echo "----------------------------------------------"
echo " GitHub Release Builds Completed Successfully! "
echo " Check $CR_PRODUCT directory for your 2 new ZIP files."
echo "----------------------------------------------"
exit 0;
}

# Pack All Images into ZIP
PACK_KERNEL_ZIP() {
echo "----------------------------------------------"
echo " Packing ZIP "

# Variables
CR_BASE_KERNEL=$CR_OUTZIP/floyd/G960F-kernel
CR_BASE_DTB=$CR_OUTZIP/floyd/G960F-dtb

# Check packages. Both are needed to produce a flashable ZIP, and 'zip' is only
# reached at the very end of a six-target build - so check for it here, before
# an hour of compiling, rather than failing after it.
for CR_PKG in bsdiff zip; do
if ! command -v $CR_PKG >/dev/null 2>&1; then
        echo "$CR_PKG is missing and is required for ZIP Packaging."
        read -p "Do you want to install $CR_PKG? This requires sudo privileges. (y/n) > " INSTALL_PKG
        if [ "$INSTALL_PKG" = "y" ]; then
                echo "installing $CR_PKG."
                if command -v dnf >/dev/null; then sudo dnf install -y $CR_PKG;
                elif command -v apt >/dev/null; then sudo apt update && sudo apt install -y $CR_PKG;
                elif command -v pacman >/dev/null; then sudo pacman -S --noconfirm $CR_PKG;
                fi
                if ! command -v $CR_PKG >/dev/null 2>&1; then
                        echo "Failed to install $CR_PKG. Please try installing it manually."
                        exit 1;
                fi
        else
                echo "Please install $CR_PKG manually and try again."
                exit 1;
        fi
fi
done

# Initalize with base image (Starlte)
if [ "$CR_TARGET" = "1" ]; then # Always must run ONCE during BUILD_ALL otherwise fail. Setup directories
	echo " "
	echo " Kernel Zip Packager "
	echo " Base Target "
	echo " Clean Out directory "
	echo " "
	rm -rf $CR_OUTZIP
	cp -r $CR_ZIP $CR_OUTZIP
	echo " "
	echo " Copying $CR_BASE_KERNEL "
	echo " Copying $CR_BASE_DTB "
	echo " "
	if [ ! -e $CR_KERNEL ] || [ ! -e $CR_DTB ]; then
        echo " Kernel not found!"
        echo " Abort "
        exit 1;
	else
        cp $CR_KERNEL $CR_BASE_KERNEL
        cp $CR_DTB $CR_BASE_DTB
	fi
	# Set kernel version
fi
if [ ! "$CR_TARGET" = "1" ]; then # Generate patch files for non starlte kernels
	echo " "
	echo " Kernel Zip Packager "
	echo " "
	echo " Generating Patch kernel for $CR_VARIANT "
	echo " "
	if [ ! -e $CR_KERNEL ] || [ ! -e $CR_DTB ]; then
        echo " Kernel not found! "
        echo " Abort "
        exit 1;
	else
		bsdiff $CR_BASE_KERNEL $CR_KERNEL $CR_OUTZIP/floyd/$CR_VARIANT-kernel
		if [ ! -e $CR_OUTZIP/floyd/$CR_VARIANT-kernel ]; then
			echo "ERROR: bsdiff $CR_BASE_KERNEL $CR_KERNEL $CR_OUTZIP/floyd/$CR_VARIANT-kernel Failed!"
			exit 1;
		fi
		bsdiff $CR_BASE_DTB $CR_DTB $CR_OUTZIP/floyd/$CR_VARIANT-dtb
		if [ ! -e $CR_OUTZIP/floyd/$CR_VARIANT-dtb ]; then
			echo "ERROR: bsdiff $CR_BASE_DTB $CR_DTB $CR_OUTZIP/floyd/$CR_VARIANT-dtb Failed!"
			exit 1;
		fi
	fi
fi
if [ "$CR_TARGET" = "6" ]; then # Final kernel build
	echo " Generating ZIP Package for $CR_NAME-$CR_VERSION-$CR_DATE"
	sed -i "s/fkv/$zver/g" $CR_OUTZIP/META-INF/com/google/android/update-binary
	rm -f $CR_PRODUCT/$zver.zip
	( cd $CR_OUTZIP && zip -r $CR_PRODUCT/$zver.zip * )
	if [ ! -e $CR_PRODUCT/$zver.zip ]; then
		echo "ERROR: failed to create $CR_PRODUCT/$zver.zip"
		echo " Abort "
		exit 1;
	fi
	sizdz=$(du -k "$CR_PRODUCT/$zver.zip" | cut -f1)
	echo " "
	echo "----------------------------------------------"
	echo "$CR_NAME kernel build finished."
	echo "Compiled Package Size = $sizdz Kb"
	echo "$zver.zip Ready"
	echo "Press Any key to end the script"
	echo "----------------------------------------------"
fi
}

# Main Menu
clear
echo "----------------------------------------------"
echo "$CR_NAME $CR_VERSION Build Script $CR_DATE"
BUILD_CHECK_SRCTREE
if [ "$1" = "-d" ]; then
BUILD_DEBUG
fi
echo ""
echo ""
echo "1) starlte"
echo "2) star2lte"
echo "3) crownlte"
echo "4) starltekor"
echo "5) star2ltekor"
echo "6) crownltekor"
echo  ""
echo "7) Build ZIP for all devices"
echo ""
echo "8) Build GitHub Release ZIPs (2 ZIPs)"
echo ""
echo "9) Abort"
echo "----------------------------------------------"
read -p "Please select your build target (1-9) > " CR_TARGET
echo "----------------------------------------------"

if [ "$CR_TARGET" = "9" ]; then
echo "Build Aborted"
exit
fi

# If GitHub Release is selected, bypass the manual inputs and jump straight to compiler selection
if [ "$CR_TARGET" = "8" ]; then
echo " "
echo "1) Google Clang 12 (LLVM +LTO)"
echo "2) Google Clang 14 (LLVM +LTO)"
echo "3) Google Clang 18 (LLVM +LTO PGO Bolt MLGO Polly)"
echo "4) Google Clang 20 (LLVM +LTO PGO Bolt MLGO Polly)"
echo "5) Neutron Clang 18 (^)"
echo "6) Neutron Clang 19 (^)"
echo "7) Neutron Clang 20 (BETA)"
echo "8) Other (Apollo/toolchain/clang-custom)"
echo " "
read -p "Please select your compiler (1-8) > " CR_COMPILER
echo " "
BUILD_GITHUB_RELEASE
exit
fi

echo " "
echo "1) Google Clang 12 (LLVM +LTO)"
echo "2) Google Clang 14 (LLVM +LTO)"
echo "3) Google Clang 18 (LLVM +LTO PGO Bolt MLGO Polly)"
echo "4) Google Clang 20 (LLVM +LTO PGO Bolt MLGO Polly)"
echo "5) Neutron Clang 18 (^)"
echo "6) Neutron Clang 19 (^)"
echo "7) Neutron Clang 20 (BETA)"
echo "8) Other (Apollo/toolchain/clang-custom)"
echo " "
read -p "Please select your compiler (1-8) > " CR_COMPILER
echo " "
echo "1) SELinux Permissive "  "2) SELinux Enforcing"
echo " "
read -p "Please select your SElinux mode (1-2) > " CR_SELINUX
echo " "
# KernelSU (and SUSFS with it) is always built; the no-KSU variant was removed.
CR_KSU="y"
echo " "
read -p "Clean Builds? (y/n) > " CR_CLEAN
echo " "

# Validate options
if ! [[ "$CR_TARGET" =~ ^[1-9]$ ]]; then
    CR_TARGET=$DEFAULT_TARGET
    echo " No target selected, defaulting to star2ltekor"
fi

if ! [[ "$CR_COMPILER" =~ ^[1-8]$ ]]; then
    CR_COMPILER=$DEFAULT_COMPILER
fi

if ! [[ "$CR_SELINUX" =~ ^[1-2]$ ]]; then
    CR_SELINUX=$DEFAULT_SELINUX
fi

if ! [[ "$CR_CLEAN" =~ ^[yYnN]$ ]]; then
    CR_CLEAN=$DEFAULT_CLEAN
fi

# Call functions
if [ "$CR_TARGET" = "7" ]; then
echo " "
read -p "Build Flashable ZIP ? (y/n) > " CR_MKZIP
echo " "
BUILD_ALL
else
BUILD
fi
