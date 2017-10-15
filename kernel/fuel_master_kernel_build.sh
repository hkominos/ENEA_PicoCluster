#!/bin/bash
set -ex

# Based on:
# http://wiki.macchiatobin.net/tiki-index.php?page=Build+from+source+-+Kernel

if [ "$(uname -m)" != 'x86_64' ]; then
  echo "ERR: This script only supports 86_64 arch."
  exit 1
fi

KERNEL_REPO=https://github.com/MarvellEmbeddedProcessors/linux-marvell
KERNEL_DIR=$(basename "${KERNEL_REPO}")
KERNEL_BRANCH=linux-4.4.52-armada-17.10

export ARCH=arm64
export CROSS_COMPILE=aarch64-linux-gnu-

# ENEA addition, align cross-build behavior with native build
export EXTRA_CFLAGS=-mstrict-align

# Setup cross-gcc toolchain
source ../toolchain/gcc_linaro_install.sh

if [ ! -d "${KERNEL_DIR}" ]; then
  git clone -b "${KERNEL_BRANCH}" "${KERNEL_REPO}"

  # ENEA: Cherry-pick missing upstream commit 6ff64f6f9242d7e50f3e99cb280f69d1927a5fa6
  # Subject: switchdev: Pass original device to port netdev driver
  MISSING_COMMIT=6ff64f6f9242d7e50f3e99cb280f69d1927a5fa6
  wget https://github.com/torvalds/linux/commit/${MISSING_COMMIT}.patch \
    -O /tmp/${MISSING_COMMIT}.patch
  git -C "${KERNEL_DIR}" am -3 /tmp/${MISSING_COMMIT}.patch
  rm /tmp/${MISSING_COMMIT}.patch
fi

cd "${KERNEL_DIR}"
if [ ! -f .config ]; then
  # ENEA: Instead of `make mvebu_v8_lsp_defconfig` we copy our predefined config
  # make mvebu_v8_lsp_defconfig
  cp ../fuel_master_kernel.config .config
fi

make -j"$(nproc)"
