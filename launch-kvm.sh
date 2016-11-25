#!/bin/bash -eux
# Launch a KVM instance with specified user-data
#
# Copyright 2016 Canonical Ltd.
# Joshua Powers <josh.powers@canonical.com>

CLI="false"
IMG_DIR="images"
IMG_SEED="seed.img"
RELEASE="$(distro-info --lts)"
USER_DATA="user-data.yaml"

while getopts cdr: opt
do
  case "$opt" in
    c)  CLI="true";;
    r)  RELEASE="$OPTARG";;
    \?)	# unknown flag
      	echo >&2 \
	"usage: $0 [-c] [-r release]"
	exit 1;;
  esac
done
shift $((OPTIND-1))

IMG="$RELEASE.qcow2"
IMG_TEMPLATE="$RELEASE.qcow2.orig"

if [ ! -e "$IMG_DIR/$IMG_TEMPLATE" ]; then
  echo "No image found, please run download-img.sh. Exiting."
  exit 1
fi

if [ ! -e "$USER_DATA" ]; then
  echo "No user-data file found. Exiting."
  exit 1
fi

if [ -e "$IMG_DIR/$IMG" ]; then
  rm "$IMG_DIR/$IMG"
fi

if [ -e "$IMG_DIR/$IMG_SEED" ]; then
  rm "$IMG_DIR/$IMG_SEED"
fi

qemu-img create -f qcow2 -b "$IMG_TEMPLATE" "$IMG_DIR/$IMG"
cloud-localds "$IMG_SEED" "$USER_DATA"
ssh-keygen -f "/home/$USER/.ssh/known_hosts" -R \[localhost\]:2222

qemu-system-x86_64 -enable-kvm \
   -drive file="$IMG_DIR/$IMG",format=qcow2,if=virtio \
   -drive file="$IMG_SEED",format=raw,if=virtio \
   -device virtio-net-pci,netdev=net00 \
   -netdev type=user,id=net00,hostfwd=tcp::2222-:22 \
   -m 1024 &

sleep 5
timeout 120s ssh -oStrictHostKeyChecking=no -p 2222 ubuntu@localhost cat /var/lib/cloud/instance/boot-finished 2>/dev/null

if [ ! "$?" ]; then
  echo "$0: $IMG took too long to boot. Exiting."
  exit 1
fi

if [ "$CLI" == "true" ]; then
  ssh -p 2222 ubuntu@localhost
else
  echo "To access the system:"
  echo "$ ssh -p 2222 ubuntu@localhost"
fi

exit 0
