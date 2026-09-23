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

# create build folders
mkdir -p out dist

# export toolchain path and core variables
export PATH="${HOME}/toolchains/arm-linux-androideabi-4.9/bin:${PATH}"
export KBUILD_BUILD_USER="@ravindu644"

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
    
    # make default configuration.
    make "${BUILD_OPTIONS[@]}" gta2slte_sea_open_defconfig

    # menuconfig
    make "${BUILD_OPTIONS[@]}" menuconfig

    # Build the kernel
    make "${BUILD_OPTIONS[@]}" || exit 1

    # Copy the built kernel to the build directory
    cp "${KERNEL_ROOT}/out/arch/arm/boot/Image" "${KERNEL_ROOT}/dist/Image"
}

build_kernel
