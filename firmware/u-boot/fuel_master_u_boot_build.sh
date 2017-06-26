#!/bin/bash
set -ex

# Based on:
# http://wiki.macchiatobin.net/tiki-index.php?page=Build+from+source+-+Bootloader

if [ "$(uname -i)" != 'x86_64' ]; then
  echo "ERR: This script only supports 86_64 arch."
  exit 1
fi

UBOOT_REPO=https://github.com/MarvellEmbeddedProcessors/u-boot-marvell
UBOOT_DIR=$(readlink -f $(basename "${UBOOT_REPO}"))
UBOOT_BRANCH=u-boot-2015.01-armada-17.04

ATF_REPO=https://github.com/MarvellEmbeddedProcessors/atf-marvell
ATF_DIR=$(readlink -f $(basename "${ATF_REPO}"))
ATF_BRANCH=atf-v1.3-17.04

MV_DDR_REPO=https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell
MV_DDR_DIR=$(readlink -f $(basename "${MV_DDR_REPO}"))
MV_DDR_BRANCH=mv_ddr-armada-17.04

export CROSS_COMPILE=aarch64-linux-gnu-

# Setup cross-gcc toolchain
source ../../toolchain/gcc_linaro_install.sh

if [ ! -d "${UBOOT_DIR}" ]; then
  git clone -b "${UBOOT_BRANCH}" "${UBOOT_REPO}"
fi

# If missing, install 32-bit deps:
# sudo dpkg --add-architecture i386 && \
#   sudo apt-get update && \
#   sudo apt-get install libc6:i386 libncurses5:i386 libstdc++6:i386

cd "${UBOOT_DIR}"
if [ ! -f .config ]; then
  make mvebu_armada80x0_customer0_mcbin_defconfig
fi

make -j"$(nproc)"
cd -
export BL33="${UBOOT_DIR}/u-boot.bin"

# If missing, install libssl-dev:
# sudo apt-get install libssl-dev

if [ ! -d "${ATF_DIR}" ]; then
  git clone -b "${ATF_BRANCH}" "${ATF_REPO}"
fi

if [ ! -d "${MV_DDR_DIR}" ]; then
  git clone -b "${MV_DDR_BRANCH}" "${MV_DDR_REPO}"
fi

cd "${ATF_DIR}"
make USE_COHERENT_MEM=0 LOG_LEVEL=20 MV_DDR_PATH="${MV_DDR_DIR}" \
  PLAT=a80x0_cust all fip
cd -

cp "${ATF_DIR}/build/a80x0_cust/release/flash-image.bin" flash-image-u-boot.bin