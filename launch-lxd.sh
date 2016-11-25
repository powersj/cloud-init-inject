#!/bin/bash -eux
# Launch a LXD instance with specified user-data
#
# Copyright 2016 Canonical Ltd.
# Joshua Powers <josh.powers@canonical.com>

CLI="false"
DAILY=""
NAME="lxd-"
RELEASE=$(distro-info --lts)
REMOTE="ubuntu"
USER_DATA="user-data.yaml"

while getopts cdr: opt
do
  case "$opt" in
    c)  CLI="true";;
    d)  DAILY="-daily";;
    r)  RELEASE="$OPTARG";;
    \?)	# unknown flag
      	echo >&2 \
	"usage: $0 [-c] [-d] [-r release]"
	exit 1;;
  esac
done
shift $((OPTIND-1))

NAME="$NAME""$RELEASE""$DAILY"

if [ ! -e "$USER_DATA" ]; then
  echo "$0: Cannot find $USER_DATA file. Exiting."
  exit 1
fi

if [ "$(lxc list --columns n | grep -c " $NAME ")" -ne "0" ]; then
  lxc delete --force "$NAME"
fi

lxc init "$REMOTE""$DAILY":"$RELEASE"/amd64 "$NAME"
lxc config set "$NAME" user.user-data - < "$USER_DATA"
lxc start "$NAME"

attempts=0
timeout=24
while [ ! "$(lxc exec "$NAME" -- cat /var/lib/cloud/instance/boot-finished 2>/dev/null)" ]; do
  if [ "$attempts" -gt "$timeout" ]; then
    echo "$0: $NAME took too long to boot. Exiting."
    exit 1
  fi

  sleep 5
  attempts=$((attempts+1))
done

lxc exec "$NAME" -- cat /var/log/cloud-init-output.log
lxc exec "$NAME" -- cat /run/cloud-init/status.json

if [ "$CLI" == "true" ]; then
  lxc exec "$NAME" bash
fi

exit 0
