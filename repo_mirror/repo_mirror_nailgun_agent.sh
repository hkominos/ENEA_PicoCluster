#!/bin/bash
set -ex

REPO_DIR=/var/www/nailgun/mirrors/nailgun-agent
ENEA_REPO=https://linux.enea.com/mos-repos/ubuntu/10.0/pool/main
ENEA_PKG=n/nailgun-agent/nailgun-agent_10.0.1-1+amos1~u16.04+mos190_all.deb

mkdir -p "${REPO_DIR}"
cd "${REPO_DIR}"
wget "${ENEA_REPO}/${ENEA_PKG}"
yum install -y dpkg-dev

# create the package index
dpkg-scanpackages -m . > Packages
cat Packages | gzip -9c > Packages.gz

# create the Release file
PKGS=$(wc -c Packages)
PKGS_GZ=$(wc -c Packages.gz)
cat <<EOF > Release
Origin: Armband
Label: Armband
Archive: armband
Component: nailgun-agent
Architectures: all
Date: $(date -R)
MD5Sum:
 $(md5sum Packages  | cut -d" " -f1) $PKGS
 $(md5sum Packages.gz  | cut -d" " -f1) $PKGS_GZ
SHA1:
 $(sha1sum Packages  | cut -d" " -f1) $PKGS
 $(sha1sum Packages.gz  | cut -d" " -f1) $PKGS_GZ
SHA256:
 $(sha256sum Packages | cut -d" " -f1) $PKGS
 $(sha256sum Packages.gz | cut -d" " -f1) $PKGS_GZ
EOF
