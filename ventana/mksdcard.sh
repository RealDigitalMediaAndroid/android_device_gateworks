#!/bin/bash

product=ventana
verbose=0
bootloader=1
minmb=1500
partoffset=1
mnt=/tmp/$(basename $0).$$
#LOG=$(basename $0).log

debug() {
  [ "$verbose" -gt 0 ] && echo "$@"
  echo "DEBUG: $@" >> $LOG
}

cleanup() {
  umount ${DEV}? 2>/dev/null
  rm -rf ${mnt}
}

error() {
  [ "$@" ] && echo "Error: $@"
  echo "ERROR: $@" >> $LOG
  cleanup
  exit 1
}

trap "cleanup; exit;" SIGINT SIGTERM

usage() {
  echo ""
  echo "Usage: $(basename 0) [OPTIONS] <blockdev>|<dist folder>"
  echo ""
  echo "Options:"
  echo " --force,-f     - force disk"
  echo " --verbose,-v   - increase verbosity"
  echo " --dist,-d      - make distribution folder"
}

# parse cmdline options
while [ "$1" ]; do
  case "$1" in
    --verbose|-v) verbose=$((verbose+1)); [ $verbose -gt 1 ] && LOG=1; shift;;
    --dist|-d) distribute=1; shift;;
    --help|-h) usage; exit 0;;
    *) DEV=$1; shift;;
  esac
done

[ "$DEV" ] || { usage; exit -1; }

echo "Gateworks Ventana Android disk imaging tool v1.03"
[ "$LOG" ] && { echo "Logging to $LOG"; rm -f $LOG; }
[ "$LOG" ] || LOG=/dev/null

# determine appropriate OUTDIR (where build artifacts are located)
# - can be passed in env via OUTDIR
# - could be in env via ANDROID_PRODUCT_OUT
# - will be out/target/product/$product if dir exists
# - else current dir
# if this script was copied using --dist|-d, always the dir containing
# this script
#####OUTDIR="$(dirname "$0")"
set_outdir() {
    [ -d "$OUTDIR" ] && return
    [ -d "$ANDROID_PRODUCT_OUT" ] && { OUTDIR="$ANDROID_PRODUCT_OUT"; return; }
    [ -d out/target/product/$product ] && { OUTDIR=out/target/product/$product; return; }
    OUTDIR=.
}
set_outdir
echo "Installing artifacts from $OUTDIR..."

# verify build artifacts
BUILD_ARTIFACTS="boot.img recovery.img userdata.img system.img SPL u-boot.img"
for i in $BUILD_ARTIFACTS ; do
   debug "  checking file: $OUTDIR/$i"
   [ -f "$OUTDIR/$i" ] || error "Missing file: $OUTDIR/$i"
done
[ "$(ls $OUTDIR/boot/boot/*dtb 2>/dev/null)" ] \
    || error 'Missing file(s): '"$OUTDIR"'/boot/boot/*dtb'
[ "$(ls $OUTDIR/boot/boot/*bootscript* 2>/dev/null)" ] \
    || error 'Missing file(s): '"$OUTDIR"'/boot/boot/*bootscript*'

[ "$distribute" ] && {
    # Install this script and the build artifacts into $DEV, a folder
    mkdir -p "$DEV"
    sed 's,^#####OUTDIR=,OUTDIR=,' < "$0" > "$DEV"/"$(basename "$0")"
    chmod a+x "$DEV"/"$(basename "$0")"
    ota_update="$(cd "$OUTDIR"; ls -1tr ventana-ota-*zip | tail -1)"
    [ -f "$OUTDIR/$ota_update" ] || error "Missing file: $OUTDIR/$ota_update"
    manifest="system/etc/manifest.xml"
    [ -f "$OUTDIR/$manifest" ] || error "Missing file: $OUTDIR/$manifest"
    for i in $BUILD_ARTIFACTS $ota_update $manifest; do
	cp -f "$OUTDIR"/$i "$DEV"
    done
    mkdir -p "$DEV"/boot/boot
    cp -f $OUTDIR/boot/boot/*dtb "$DEV"/boot/boot
    cp -f $OUTDIR/boot/boot/*bootscript* "$DEV"/boot/boot
    echo "All files copied to $DEV"
    exit 0
}

# verify root
[ $EUID -ne 0 ] && error "must be run as root"

# verify dependencies
for i in ls cat grep mount umount sfdisk parted sync mkfs.ext4 dd pv cp e2label e2fsck resize2fs rm awk; do
  which $i 2>&1 >/dev/null
  [ $? -eq 1 ] && error "missing '$i' - please install"
done

# verify output device
[ -b "$DEV" ] || error "$DEV is not a valid block device"
[ "$minmb" ] && {
  size="$(cat /sys/class/block/$(basename $DEV)/size)"
  size=$((size*512/1000/1000)) # convert to MB (512B blocks)
  debug "$DEV is ${size}MB"
  [ $size -lt $minmb ] && error "$DEV ${size}MB too small - ${minmb}MB required"
}
mounts="$(grep "^$DEV" /proc/mounts | awk '{print $1}')"
[ "$mounts" ] && error "$DEV has mounted partitions: $mounts"

echo "Installing on $DEV..." ;

# zero first 1MB of data
dd if=/dev/zero of=$DEV count=1 bs=1M oflag=sync status=none
sync

[ $bootloader ] && {
  echo "Installing bootloader..."

  # SPL (at 1KB offset)
  echo "  installing SPL@1K..."
  dd if=$OUTDIR/SPL of=$DEV bs=1K seek=1 oflag=sync status=none || error

  # UBOOT (at 69K offset)
  echo "  installing UBOOT@69K..."
  dd if=$OUTDIR/u-boot.img of=$DEV bs=1K seek=69 oflag=sync status=none || error

  # ENV (at 709KB offset)
  [ "$UBOOTENV" -a -r "$UBOOTENV" ] && {
    echo "  installing ENV@709K..."
    dd if=$UBOOTENV of=$DEV bs=1K seek=709 oflag=sync status=none || error
  }
  sync || error "sync failed"
}

echo "Partitioning..."
# Partitions:
# 1:BOOT     ext4 20MB
# 2:RECOVERY ext4 20MB
# 3:extended partition table
# 4:DATA     ext4 (remainder)
# 5:SYSTEM   ext4 512MB
# 6:CACHE    ext4 512MB
# 7:VENDOR   ext4 10MB
# 8:MISC     raw/emmc 10MB
#
# CACHE needs to be big enough to hold an over-the-air update
# zip file of SYSTEM, BOOT, and part of RECOVERY. If you never
# plan to use updates via recovery, you can reduce CACHE to
# something small.
#
# sfdisk's parser is garbage. It ignores the first partition
# start position when using MB units. We could try converting
# to sectors like this:
#     echo '8192,40960,L,*' | sfdisk ... -uS $DEV
# That works. However, when you add more partitions to that,
# it then complains about the 40960.
# So, I created the partitions manually using fdisk with a
# 1GB data partition. I saved the layout using sfdisk's
# dump format. It has no issues parsing that.
# After partitioning, we'll use parted to resize the data
# partition. All of this is because SD cards work
# best when partitions are aligned to 4MB boundaries.
#
# Before resizing, it will look like this:
#
# parted $DEV unit MiB print
#
# Number  Start    End      Size     Type      File system  Flags
#  1      4.00MiB  24.0MiB  20.0MiB  primary   fat32        boot
#  2      24.0MiB  44.0MiB  20.0MiB  primary
#  3      44.0MiB  1102MiB  1058MiB  extended
#  5      48.0MiB  560MiB   512MiB   logical
#  6      564MiB   1076MiB  512MiB   logical
#  7      1080MiB  1090MiB  10.0MiB  logical
#  8      1092MiB  1102MiB  10.0MiB  logical
#  4      1104MiB  2128MiB  1024MiB  primary
#
# After resizing on an 8GB SD card, data is 6475MiB.
#
sfdisk --force --no-reread -uS $DEV >>$LOG 2>&1 << EOF || error "sfdisk failed"
# partition table of /dev/sde
unit: sectors

/dev/sde1 : start=     8192, size=    40960, Id=83, bootable
/dev/sde2 : start=    49152, size=    40960, Id=83
/dev/sde3 : start=    90112, size=  2170880, Id= 5
/dev/sde4 : start=  2260992, size=  2097152, Id=83
/dev/sde5 : start=    98304, size=  1048576, Id=83
/dev/sde6 : start=  1155072, size=  1048576, Id=83
/dev/sde7 : start=  2211840, size=    20480, Id=83
/dev/sde8 : start=  2236416, size=    20480, Id=83
EOF
parted -- $DEV resizepart 4 -1 || error "parted resize data failed"
sync || error "sync failed"
mkdir $mnt

# sanity-check: verify partitions present
for n in `seq 1 8` ; do
   [ -e ${DEV}$n ] || error "  missing ${DEV}$n"
done
debug "  Partitioning complete"

echo "Formating partitions..."
mkfs.ext4 -q -L BOOT ${DEV}1 || error "mkfs BOOT"
mkfs.ext4 -q -L RECOVER ${DEV}2 || error "mkfs RECOVER"
mkfs.ext4 -q -L CACHE ${DEV}6 || error "mkfs CACHE"
mkfs.ext4 -q -L VENDOR ${DEV}7 || error "mkfs VENDOR"
# MISC is used as a raw place to pass bytes back
# and forth between android and recovery
dd if=/dev/zero of=${DEV}8 count=1 bs=1M oflag=sync status=none

echo "Mounting partitions..."
for n in 1 2 ; do
   mkdir ${mnt}/${n}
   debug "  mounting ${DEV}${n} to ${mnt}/${n}"
   mount -t ext4 ${DEV}${n} ${mnt}/${n} || error "mount ${DEV}${n}"
done

# BOOT: bootscripts, boot image, and device trees
echo "Writing BOOT partition..."
cp -rfv $OUTDIR/boot.img ${mnt}/1 >>$LOG || error
mkdir -p ${mnt}/1/boot >>$LOG || error
cp -rfv $OUTDIR/boot/boot/*dtb ${mnt}/1/boot >>$LOG || error
cp -rfv $OUTDIR/boot/boot/*bootscript* ${mnt}/1/boot >>$LOG || error
sync && umount ${DEV}1 || error "failed umount"

# RECOVERY: recovery image, and device trees
echo "Writing RECOVERY partition..."
cp -rfv $OUTDIR/recovery.img ${mnt}/2 >>$LOG || error
mkdir -p ${mnt}/2/boot >>$LOG || error
cp -rfv $OUTDIR/boot/boot/*dtb ${mnt}/2/boot >>$LOG || error
sync && umount ${DEV}2 || error "failed umount"

# DATA: user data
echo "Writing DATA partition..."
pv -petr $OUTDIR/userdata.img | dd of=${DEV}4 bs=4M oflag=sync status=none \
  || error "dd"
e2label ${DEV}4 DATA || error "e2label failed"
e2fsck -y -f ${DEV}4 >>$LOG 2>&1 || error "e2fsck failed"
resize2fs ${DEV}4 >>$LOG 2>&1 || error "resize2fs failed"
sync

# SYSTEM: system image
echo "Writing SYSTEM partition..."
pv -petr $OUTDIR/system.img | dd of=${DEV}5 bs=4M oflag=sync status=none \
  || error "dd"
e2label ${DEV}5 SYSTEM || error "e2label failed"
e2fsck -y -f ${DEV}5 >>$LOG 2>&1 || error "e2fsck failed"
resize2fs ${DEV}5 >>$LOG 2>&1 || error "resize2fs failed"
sync

cleanup

# VMware Fusion doesn't do sync and eject properly. So, add a 5 second sleep
# between to give it time to finish writing. The eject is so you can safely
# unplug the card reader after this scripts finishes.
sync
sleep 5
sync
eject ${DEV}
