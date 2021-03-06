#!/bin/bash
set -ex

# Based on:
# http://wiki.macchiatobin.net/tiki-index.php?page=Build+from+source+-+UEFI+EDK+II

if [ "$(uname -m)" != 'x86_64' ]; then
  echo "ERR: This script only supports 86_64 arch."
  exit 1
fi

export ARCH=AARCH64
export CROSS_COMPILE=aarch64-linux-gnu-

# Build multiple firmware images, with different MACs in embedded DTB
DTB_DIR=$(readlink -f "../../kernel/linux-marvell/arch/arm64/boot/dts/marvell")
MCBIN_DTB="armada-8040-mcbin.dtb"
DTS_DIR=$(readlink -f "dts")

# Final MACs will be "${MAC_PREFIX} NN XX", NN="${MAC_START}"...${MAC_END}"
# We have 12 boards in our lab, so we build 12 firmware images
MAC_PREFIX="02 50 43 00"
MAC_START=1
MAC_END=12

# DSC
MCBIN_DSC="Platforms/Marvell/Armada/Armada80x0McBin.dsc"
DSC_MAC_BEFORE="0x22, 0x22, 0x33, 0x33, 0x44"
DSC_MAC_PREFIX="0x$(echo ${MAC_PREFIX} | sed 's/ /, 0x/g')"

if [ ! -f "${DTB_DIR}/${MCBIN_DTB}" ]; then
  echo "ERR: This script requires the kernel to be built first."
  exit 2
fi

mkdir -p "${DTS_DIR}"

# Setup cross-gcc toolchain
source ../../toolchain/gcc_linaro_install.sh

# If missing, install ACPI tables compiler, device tree compiler:
# sudo apt-get install uuid-dev iasl device-tree-compiler

EDK2_REPO=https://github.com/tianocore/edk2
EDK2_DIR=$(readlink -f $(basename "${EDK2_REPO}"))
EDK2_BRANCH=master
EDK2_COMMITS_TO_REVERT='3380a59 1894a7c'

EDK2_OPEN_PLATFORM_REPO=https://github.com/MarvellEmbeddedProcessors/edk2-open-platform
EDK2_OPEN_PLATFORM_DIR=$(readlink -f $(basename "${EDK2_OPEN_PLATFORM_REPO}"))
EDK2_OPEN_PLATFORM_BRANCH=marvell-armada-wip
EDK2_OPEN_PLATFORM_PICO_BRANCH=marvell-armada-picopod

ATF_REPO=https://github.com/MarvellEmbeddedProcessors/atf-marvell
ATF_DIR=$(readlink -f $(basename "${ATF_REPO}"))
ATF_BRANCH=atf-v1.3-armada-17.08

MV_DDR_REPO=https://github.com/MarvellEmbeddedProcessors/mv-ddr-marvell
MV_DDR_DIR=$(readlink -f $(basename "${MV_DDR_REPO}"))
MV_DDR_BRANCH=mv_ddr-armada-17.08

OUT_DIR=$(readlink -f .)

export BL33=${EDK2_DIR}/Build/Armada80x0McBin-AARCH64/RELEASE_GCC5/FV/ARMADA_EFI.fd

if [ ! -d "${EDK2_DIR}" ]; then
  git clone -b "${EDK2_BRANCH}" "${EDK2_REPO}"
  for commit in ${EDK2_COMMITS_TO_REVERT}; do
    git -C "${EDK2_DIR}" revert "${commit}" --no-edit
  done
fi

if [ ! -d "${EDK2_OPEN_PLATFORM_DIR}" ]; then
  git clone -b "${EDK2_OPEN_PLATFORM_BRANCH}" "${EDK2_OPEN_PLATFORM_REPO}"

  # PicoPod specifics: allow UEFI MAC override, switch 10G SFI to 1G SGMII
  git -C "${EDK2_OPEN_PLATFORM_DIR}" \
    checkout "${EDK2_OPEN_PLATFORM_PICO_BRANCH}"
  git -C "${EDK2_OPEN_PLATFORM_DIR}" \
    checkout -b "${EDK2_OPEN_PLATFORM_BRANCH}-picopod"
  git -C "${EDK2_OPEN_PLATFORM_DIR}" rebase "${EDK2_OPEN_PLATFORM_BRANCH}"
  git -C "${EDK2_OPEN_PLATFORM_DIR}" am -3 --ignore-whitespace "$(pwd)/"*.patch

  # Save DSC from edk2-open-platform
  cp "${EDK2_OPEN_PLATFORM_DIR}/${MCBIN_DSC}" "${DTS_DIR}"
fi

if [ ! -d "${ATF_DIR}" ]; then
  git clone -b "${ATF_BRANCH}" "${ATF_REPO}"
fi

if [ ! -d "${MV_DDR_DIR}" ]; then
  git clone -b "${MV_DDR_BRANCH}" "${MV_DDR_REPO}"
fi

# Set up EDK2 common tools
cd "${EDK2_DIR}"
ln -sf "${EDK2_OPEN_PLATFORM_DIR}" OpenPlatformPkg
make -C BaseTools
source edksetup.sh

# Copy DTB from kernel build, customize MACs for each build
cp "${DTB_DIR}/${MCBIN_DTB}" "${DTS_DIR}"
dtc -I dtb -O dts "${DTS_DIR}/${MCBIN_DTB}" 2> /dev/null > \
  "${DTS_DIR}/${MCBIN_DTB%dtb}dts"

export ARCH=arm64
for idx in $(seq -f "%02g" "${MAC_START}" "${MAC_END}"); do
  cd "${DTS_DIR}"
  # Hack: replacing the reference in DTB is *extremely* fragile, but quick
  sed -e "s/mac-address = \[00 00 00 00 00/mac-address = \[${MAC_PREFIX} ${idx}/g" \
      -e "s/0x90fc/0x20fc/g" -e "s/sfi/sgmii/g" \
    "${MCBIN_DTB%dtb}dts" > "${MCBIN_DTB%dtb}${idx}.dts"
  dtc -I dts -O dtb "${MCBIN_DTB%dtb}${idx}.dts" 2> /dev/null > \
    "${EDK2_OPEN_PLATFORM_DIR}/Platforms/Marvell/Armada/${MCBIN_DTB}"

  sed "s/${DSC_MAC_BEFORE}/${DSC_MAC_PREFIX}, 0x${idx}/g" \
    "${DTS_DIR}/$(basename ${MCBIN_DSC})" > \
    "${EDK2_OPEN_PLATFORM_DIR}/${MCBIN_DSC}"

  cd "${EDK2_DIR}"
  build -a AARCH64 -t GCC5 -b RELEASE -p "OpenPlatformPkg/${MCBIN_DSC}"

  cd "${ATF_DIR}"
  make distclean # can't be included in below `make` call
  make USE_COHERENT_MEM=0 LOG_LEVEL=20 MV_DDR_PATH="${MV_DDR_DIR}" \
    PLAT=a80x0_mcbin all fip

  cp "${ATF_DIR}/build/a80x0_mcbin/release/flash-image.bin" \
     "${OUT_DIR}/flash-image-uefi.${idx}.bin"
done
