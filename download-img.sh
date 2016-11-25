#!/bin/bash -eux
# Download daily cloud images
#
# Copyright 2016 Canonical Ltd.
# Joshua Powers <josh.powers@canonical.com>

DISK_1=""
IMG_DIR="images"
RELEASE="${1:-$(distro-info --lts)}"
URL="https://cloud-images.ubuntu.com/daily/server/$RELEASE/current"

if [ "$RELEASE" == "xenial" ] || [ "$RELEASE" == "trusty" ]; then
  DISK_1="-disk1"
fi

IMG="$RELEASE-server-cloudimg-$(dpkg --print-architecture)$DISK_1.img"

if [ ! -d "$IMG_DIR" ]; then
  mkdir "$IMG_DIR"
fi

cd "$IMG_DIR"

function download_img {
  wget -nv "$URL/$IMG"
  if [ -e "$RELEASE.qcow2.orig" ]; then
      rm "$RELEASE".qcow2.orig
  fi
}

if [ -e "$IMG" ]; then
  md5=($(md5sum "$IMG"))
  wget -nv "$URL"/MD5SUMS
  if [ "$(grep -c "${md5[0]}" MD5SUMS)" -eq "0" ]; then
    rm "$IMG"
    download_img
  fi
  rm MD5SUMS
else
  download_img
fi

if [ ! -e "$RELEASE.qcow2.orig" ]; then
  qemu-img convert -O qcow2 "$IMG" "$RELEASE".qcow2.orig
fi

exit 0
