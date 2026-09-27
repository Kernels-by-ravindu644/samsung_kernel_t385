#!/bin/bash
# Copyright (c) 2026 ravindu644 <droidcasts@protonmail.com>
# SPDX-License-Identifier: GPL-2.0-or-later
#
# Linux 3.18 arm64 kernel build script for SM-T385

set -euo pipefail

# cd to the repo root
KERNEL_ROOT="$(dirname "$(readlink -f "$0")")"
cd "${KERNEL_ROOT}"

# init submodules
git submodule update --init --recursive || true

# generate localversion
BUILD_VERSION=$(git log -1 --pretty=%h 2>/dev/null)
if [ -z "$BUILD_VERSION" ]; then
    export BUILD_VERSION="dev"
fi
cat << EOF > "${KERNEL_ROOT}/arch/arm/configs/version.config"
CONFIG_LOCALVERSION_AUTO=n
CONFIG_LOCALVERSION="-ravindu644-${BUILD_VERSION}"
EOF

# create build folders
mkdir -p out dist

# export toolchain path and core variables
export PATH="${HOME}/toolchains/arm-linux-androideabi-4.9/bin:${PATH}"
export KBUILD_BUILD_USER="@ravindu644"
MAGISKBOOT="${KERNEL_ROOT}/prebuilts/magiskboot"
STOCK_BOOT="${KERNEL_ROOT}/prebuilts/boot.img"

# download the toolchain if it isn't there yet
download_toolchains(){
    local base="https://github.com/ravindu644/Android-Kernel-Tutorials/releases/download/toolchains"
    if [ ! -x "${HOME}/toolchains/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-gcc" ]; then
        echo "[INFO]: downloading arm-linux-androideabi-4.9..."
        mkdir -p "${HOME}/toolchains"
        wget -q --show-progress -O- "${base}/arm-linux-androideabi-4.9.tar.xz" | tar -xJ -C "${HOME}/toolchains"
    fi
}

# build options for the kernel
BUILD_OPTIONS=(
    -C "${KERNEL_ROOT}"
    O="${KERNEL_ROOT}/out"
    -j"$(nproc)"
    ARCH=arm
    CROSS_COMPILE=arm-linux-androideabi-
    KCFLAGS=-mno-android
)

build_kernel(){
    # cleanup
    # make "${BUILD_OPTIONS[@]}" clean && make "${BUILD_OPTIONS[@]}" mrproper
    
    # stock SM-T385L configuration (extracted from the OEM boot.img via extract-ikconfig)
    make "${BUILD_OPTIONS[@]}" t385l_defconfig version.config custom.config droidspaces.config

    # menuconfig
    [ -t 0 ] && make "${BUILD_OPTIONS[@]}" menuconfig

    # Build the kernel
    make "${BUILD_OPTIONS[@]}" || exit 1

    # Copy the built kernel to the build directory
    cp "${KERNEL_ROOT}/out/arch/arm/boot/Image" "${KERNEL_ROOT}/dist/Image"
}

build_boot(){
    # unpack stock boot.img, swap in our kernel, repack.
    # magiskboot re-wraps the raw Image in the stock gzip zImage stub and
    # re-appends the stock DTBs; the SEANDROID footer is preserved.
    local work="${KERNEL_ROOT}/dist/boot_work"
    rm -rf "${work}" && mkdir -p "${work}" && cd "${work}"
    "${MAGISKBOOT}" unpack "${STOCK_BOOT}"
    cp "${KERNEL_ROOT}/dist/Image" kernel
    "${MAGISKBOOT}" repack "${STOCK_BOOT}" "${KERNEL_ROOT}/dist/boot.img"
    cd "${KERNEL_ROOT}" && rm -rf "${work}"
}

build_tar(){
    # Odin-flashable tar
    cd "${KERNEL_ROOT}/dist"
    tar -cvf "SM-T385L-kernel-${BUILD_VERSION}.tar" boot.img && \
        echo -e "\n[INFO]: TAR BUILT SUCCESSFULLY..!\n"
    cd "${KERNEL_ROOT}"
}

download_toolchains
build_kernel
build_boot
build_tar
