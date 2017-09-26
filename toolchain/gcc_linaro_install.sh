#!/bin/bash
set -ex

# Based on:
# http://wiki.macchiatobin.net/tiki-index.php?page=Toolchain+Installation

if [ "$(uname -i)" != 'x86_64' ]; then
  echo "ERR: This script only supports 86_64 arch."
  exit 1
fi

TOOLCHAIN_URL=https://releases.linaro.org/components/toolchain/binaries/5.3-2016.05/aarch64-linux-gnu/gcc-linaro-5.3.1-2016.05-x86_64_aarch64-linux-gnu.tar.xz
TOOLCHAIN_ARCHIVE=$(basename "${TOOLCHAIN_URL}")
TOOLCHAIN_SUBDIR=${TOOLCHAIN_ARCHIVE%.tar*}
TOOLCHAIN_SCRIPT=$(readlink -f "$BASH_SOURCE")
TOOLCHAIN_DIR=$(dirname "${TOOLCHAIN_SCRIPT}")

cd "${TOOLCHAIN_DIR}"
if [ ! -f "${TOOLCHAIN_ARCHIVE}" ]; then
  wget "${TOOLCHAIN_URL}"
fi
if [ ! -d "${TOOLCHAIN_SUBDIR}" ]; then
  tar xvf $(basename "${TOOLCHAIN_URL}")
fi
cd -

export PATH=$PATH:"${TOOLCHAIN_DIR}/${TOOLCHAIN_SUBDIR}/bin"
export GCC5_AARCH64_PREFIX="${TOOLCHAIN_DIR}/${TOOLCHAIN_SUBDIR}/bin/aarch64-linux-gnu-"
