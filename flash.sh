#!/bin/bash
set -euo pipefail

IMG=boatputer.img

if [ ! -f "$IMG" ]; then
    echo "error: $IMG not found, run ./build.sh first"
    exit 1
fi

find_removable() {
    for dev in /sys/block/*/removable; do
        devname=$(basename "$(dirname "$dev")")
        if [ "$(cat "$dev")" != "1" ]; then
            echo "  skipping $devname: not removable" >&2
            continue
        fi
        devpath=$(readlink -f "/sys/block/$devname")
        if [[ "$devname" != mmcblk* ]] && [[ "$devpath" != *usb* ]]; then
            echo "  skipping $devname: not mmcblk or USB" >&2
            continue
        fi
        if [ "$(cat "/sys/block/$devname/size" 2>/dev/null)" = "0" ]; then
            echo "  skipping $devname: no media" >&2
            continue
        fi
        echo "/dev/$devname"
    done
}

if [ -z "${1:-}" ]; then
    mapfile -t candidates < <(find_removable)
    if [ "${#candidates[@]}" -eq 0 ]; then
        echo "error: no removable devices found"
        echo "usage: $0 <device>  (e.g. $0 /dev/sdX)"
        exit 1
    elif [ "${#candidates[@]}" -eq 1 ]; then
        DEVICE="${candidates[0]}"
        echo "Found removable device: $DEVICE"
    else
        echo "Multiple removable devices found:"
        for d in "${candidates[@]}"; do echo "  $d"; done
        echo "usage: $0 <device>"
        exit 1
    fi
else
    DEVICE=$1

    if [ ! -b "$DEVICE" ]; then
        echo "error: $DEVICE is not a block device"
        exit 1
    fi

    DEVNAME=$(basename "$DEVICE")
    DEVPATH=$(readlink -f "/sys/block/$DEVNAME")
    REMOVABLE=$(cat "/sys/block/${DEVNAME}/removable" 2>/dev/null || echo "0")
    if [ "$REMOVABLE" != "1" ] || { [[ "$DEVNAME" != mmcblk* ]] && [[ "$DEVPATH" != *usb* ]]; }; then
        echo "error: $DEVICE does not appear to be removable media"
        exit 1
    fi
fi

echo "WARNING: this will overwrite $DEVICE"
read -r -p "Type YES to continue: " confirm
[ "$confirm" = "YES" ] || exit 1

sudo dd if="$IMG" of="$DEVICE" bs=4M status=progress conv=fsync
sync

echo "Done. You can remove the SD card."
