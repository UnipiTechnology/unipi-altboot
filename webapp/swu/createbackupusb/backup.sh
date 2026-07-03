#!/bin/sh
# Here must be /bin/sh (in altboot envirtonment)

set -e

. /scripts/init-premount/ledfunc.sh.in

setled_deploy_mode

# where the USB backup partition will be mounted
USB_MNT="/tmp/__usb"
# where the eMMC BTRFS partition will be mounted
BTRFS_MNT="/tmp/__root"
# extension appended to the name of the archived subvolume
CPIO_EXT="cpio.gz"
ARCHIVE_FILES=/tmp/archive.files
CLEARFS_FILE="${USB_MNT}/clearfs.sh"
SW_DESCRIPTION="${USB_MNT}/sw-description"
MAX_CHUNK_SIZE=3800
MAX_ZIP_SIZE=4000

# Cleanup fucntion called at the end of script IN ALL CASES
do_cleanup() {

    # try to delete temporary archive files (may be incomplete or corrupted in case of error, e.g. no free space)
    cd "$USB_MNT" || true
    { while IFS='' read -r f; do rm -f "$f" ; done; } < "$ARCHIVE_FILES"
    cd / || return
    rm -f "$ARCHIVE_FILES" /tmp/archive.description /tmp/fslist /tmp/partable
    if [ -f "$BTRFS_MNT/etc/fstab.__archive__" ]; then
        rm -f "$BTRFS_MNT/etc/fstab"
        mv "$BTRFS_MNT/etc/fstab.__archive__" "$BTRFS_MNT/etc/fstab"
    fi
    # revert machine-id
    if [ -r "$BTRFS_MNT/etc/machine-id.back" ]; then
        rm -f "$BTRFS_MNT/etc/machine-id"
        mv "$BTRFS_MNT/etc/machine-id.back" "$BTRFS_MNT/etc/machine-id"
    fi
    # remove previously created symlink from live system
    rm -f "$BTRFS_MNT/etc/systemd/system/sysinit.target.wants/regenerate_ssh_host_keys.service"
    sync
    sync
    umount "$BTRFS_MNT" || true
    umount "$USB_MNT" || true
    sync
    rmdir "$BTRFS_MNT" || true
    echo "USB storage ready to disconnect"
    # start flashing in normal fashion
    setled_web_mode
}

trap do_cleanup EXIT

get_free_space()
{
    df "$@" "$USB_MNT" | awk -e '/sd.*1/ {print $4}'
}

prepare_root_etc()
{
    # mount the top level BTRFS partition
    mkdir -p "$BTRFS_MNT"
    fstype=$(blkid -o export /dev/root0part | sed -n 's/^TYPE=//p')
    if [ "$fstype" = "btrfs" ]; then
        mount /dev/root0part -o subvol=/rootfs "$BTRFS_MNT" \
        || mount /dev/root0part "$BTRFS_MNT" || return 1
    else
        mount /dev/root0part "$BTRFS_MNT" || return 1
    fi
    # create symlink to enable the service on the next reboot
    ln -s /etc/systemd/system/regenerate_ssh_host_keys.service "$BTRFS_MNT/etc/systemd/system/sysinit.target.wants/" || true
    # check fstab
    if [ -f "$BTRFS_MNT/etc/fstab" ]; then
        rm -f "$BTRFS_MNT/etc/fstab.__archive__"
        #mv "$BTRFS_MNT/etc/fstab" "$BTRFS_MNT/etc/fstab.__archive__"
    fi
    # check machine-id
    if [ -f "$BTRFS_MNT/etc/machine-id" ]; then
        rm -f "$BTRFS_MNT/etc/machine-id.back"
        mv "$BTRFS_MNT/etc/machine-id" "$BTRFS_MNT/etc/machine-id.back"
    fi
}

mk_disc_part()
{
    ROOTDEV="$1"
    PARTABLE="$2"

    rm -f "${PARTABLE}"
    # save partition table of ROOTDEV into file
    printf "O\n%s\nq\n" "${PARTABLE}" | fdisk "${ROOTDEV}" >/dev/null 2>&1
    # drop lable-id, first-lba, last-lba from file
    sed '/^label-id:/d;/^first-lba:/d;/^last-lba:/d' -i "${PARTABLE}"
    # drop size of last partition - will by used max free space
    sed '$s/size=[^,]*,//' -i "${PARTABLE}"
}

mk_fslist()
{
    ROOTDEV="$1"
    PARTABLE="$2"
    grep "^${ROOTDEV}" "${PARTABLE}" | ( while read -r dev _; do
        fstype=$(blkid -o export "$dev" | sed -n 's/^TYPE=//p')
        echo "$dev|$fstype"
    done )
}

mkscript_fdisk()
{
    ROOTDEV="$1"
    PARTABLE="$2"
    echo "#!/bin/sh"
    echo ""
    echo "set -e"
    echo "cat >/tmp/partable <<EOF"
    cat "${PARTABLE}"
    echo "EOF"
    printf 'printf "I\n/tmp/partable\np\nw\n" | fdisk %s\n' "${ROOTDEV}"
    echo 'rm /tmp/partable'
    echo 'sync; sleep 1; sync'
}

mkscript_subvol()
{
    # write to stdout commands for creating btrfs subvolumes
    dev="${1}"
    MNT=/tmp/__mnt__
    tmpmount=/tmp/__mnt__
    mkdir -p "${MNT}"
    mount "${dev}" "${MNT}"
    echo "mkdir -p ${tmpmount}"
    echo "mount ${dev} ${tmpmount}"
    for subvol in $(btrfs subvolume list "${MNT}" | sed 's/^.* path //' | sort); do
        vdir=$(dirname "$subvol")
        if [ "$vdir" != "." ]; then
            echo "mkdir -p ${tmpmount}/${vdir}"
        fi
        echo "btrfs subvol create ${tmpmount}/${subvol}"
        if [ "${subvol}" = "rootfs" ]; then
            echo "mkdir -p ${tmpmount}/rootfs/usr/share"
            echo "btrfs property set ${tmpmount}/rootfs/usr/share compression zstd 2>/dev/null || btrfs property set ${tmpmount}/rootfs/usr/share compression zlib > /dev/null"
        fi
    done
    echo "umount ${tmpmount}"
    echo "rmdir ${tmpmount}"
    umount "${MNT}"
    rmdir "${MNT}"
}

mkscript_fs()
{
    # write to stdout commands for formating partitions
    ( while IFS='|' read -r dev fstype; do
        case "$fstype" in
            vfat)
                echo "mkdosfs $dev"
                ;;
            ext*)
                echo "mkfs.ext4 -F -q -t $fstype $dev"
                ;;
            btrfs)
                echo "mkfs.btrfs -f -q $dev"
                mkscript_subvol "${dev}"
                ;;
            *)
                echo "Unsupported filesystem ${fstype} on ${dev}" >&2
                exit 1
                ;;
        esac
    done ) < "$1"
}

list_fs()
{
    # create archive file $2 from filesystem on device $1
    dev="${1}"
    archive="${2}"
    result=0
    MNT=/tmp/__mnt__
    mkdir -p "${MNT}"
    mount "${dev}" "${MNT}"
    # switch to the directory, so the paths will be generated as absolute
    if cd "${MNT}"; then
        cpio-builder -o "$archive" -c "${MAX_CHUNK_SIZE}" 
    fi
    cd /
    umount "${MNT}"
    rmdir "${MNT}"
    return $result
}

archive_fs()
{
    # create archive file $2 from filesystem on device $1
    dev="${1}"
    archive="${2}"
    result=0
    MNT=/tmp/__mnt__
    mkdir -p "${MNT}"
    mount "${dev}" "${MNT}"
    # switch to the directory, so the paths will be generated as absolute
    if cd "${MNT}"; then
        # dump the content of the subvolume to the temporary archive on the USB
        echo "Packing fs $dev  ..."
        for i in $(cat "${archive}"); do
            basei=$(basename "$i")
            echo "        to $basei.$CPIO_EXT"
            cpio_with_crc -H crc -o < "$i" 2>/dev/null | pigz -p 4 > "${i}.${CPIO_EXT}" || result=1
            rm -f "${i}"
        done
        rm -f "${archive}"
    fi
    cd /
    umount "${MNT}"
    rmdir "${MNT}"
    return $result
}


################ MAIN #################

prepare_root_etc

#### analyze environment
MMC_PATH=$(readlink -f /dev/rootdev)
mk_disc_part "${MMC_PATH}" /tmp/partable
mk_fslist "${MMC_PATH}" /tmp/partable > /tmp/fslist

#### create script clearfs.sh
mkscript_fdisk "${MMC_PATH}" "/tmp/partable" > "${CLEARFS_FILE}"
mkscript_fs /tmp/fslist >> "${CLEARFS_FILE}"

#### create archive file list and archive description
: > /tmp/archive.description
: > /tmp/sizes
echo "sw-description" > "${ARCHIVE_FILES}"
echo "clearfs.sh"  >> "${ARCHIVE_FILES}"
volumes="$(awk '/|vfat$/ || /|ext[234]*$/ || /|btrfs$/ {print $1}' /tmp/fslist)"
volname=1
comma="{"
for def in ${volumes}; do
    # parse def (format dev|fstype) into variables
    dev=${def%|*}
    fstype=${def##*|}
    list_fs "${dev}" "${USB_MNT}/${volname}" >> /tmp/sizes || exit 1
    for i in $(cat "${USB_MNT}/${volname}"); do
        filename=$(basename "$i")
        cat >> /tmp/archive.description <<EOF
      ${comma}
            filename = "${filename}.${CPIO_EXT}";
            path = "/";
            preserve-attributes = true;
            type = "archive";
            device = "${dev}";
            filesystem = "${fstype}";
            compressed = "zlib";
            installed-directly = true;
EOF
        echo "${filename}.${CPIO_EXT}" >> "${ARCHIVE_FILES}"
        comma="},{"
    done
    volname=$((volname + 1))
done
echo "          }" >> /tmp/archive.description

reqsize=0; for i in $(cat /tmp/sizes); do reqsize=$((reqsize+i)); done
rm /tmp/sizes

# content of the sw-description file
PLATFORM=$(sed 's/[[:blank:]].*$//' /etc/hwrevision)
cat > "${SW_DESCRIPTION}" << EOF
software =
{
    version = "2.0.0";
    description = "Operating system backup for Unipi PLC";
    hardware-compatibility: [ "1.0", "2.0" ];
    ${PLATFORM} = {
        scripts: (
          {
            filename = "clearfs.sh";
            type = "preinstall";
            installed-directly = true;
          }
        );
        files: (
            $(cat /tmp/archive.description)
        );
    }
}
EOF

# get free space on the USB stick
FREE_SPACE=$(get_free_space -m)
FREE_SPACE_H=$(get_free_space -h)
echo "USB Storage free space:   ${FREE_SPACE} MB (${FREE_SPACE_H})"
echo "Size of OS data:          ${reqsize} MB"
echo "Estimated required space: $((reqsize+reqsize/2)) MB"

#echo "USB Storage has ${FREE_SPACE_H} ${FREE_SPACE}MB of free space."
#echo "Backuped data has ${reqsize}MB. Requires aprox. $((reqsize+reqsize/2))MB of free working space"

# check the remaining space on the USB flash. Assume that NEEDED_SPACE = SPACE_OCCUPIED_BY_GZ_ARCHS*2
if [ "$FREE_SPACE" -lt $((reqsize+reqsize/2)) ];then
    echo "Not enough space on USB storage (needed $((reqsize+reqsize/2))MB, got ${FREE_SPACE}MB)" >&2
    exit 1
fi

#### create archive files
volname=1
for def in ${volumes}; do
    # parse def (format dev|fstype) into variables
    dev=${def%|*}
    fstype=${def##*|}
    archive_fs "${dev}" "${USB_MNT}/${volname}" || exit 1
    volname=$((volname + 1))
done

# switch to the mounted USB and create the archive.swu containing all the neccessary files
# the USB is mounted in preceeding script called mount-usb.sh
cd "$USB_MNT" || exit 1
# clear old backups
find . -maxdepth 1 -name archive.z\* -exec rm \{\} \;
# check final size and use zip if greater than MAX_ZIP_SIZE
cpiosize=$(ls -l $(cat $ARCHIVE_FILES) | awk '{a+=$5;} END {printf("%4.0f", a/1024/1024)}')
if [ "$cpiosize" -lt "${MAX_ZIP_SIZE}" ];then
    echo "Creating final archive.swu..."
    cpio_with_crc -ov -H crc -L -R 0:0 <"$ARCHIVE_FILES" >archive.swu 2>/dev/null
else
    echo "Creating final archive.swu as MULTI ZIP archive.zip..."
    rm -f /tmp/archive.swu 2>/dev/null
    mkfifo /tmp/archive.swu
    cpio_with_crc -ov -H crc -L -R 0:0 <"$ARCHIVE_FILES" >/tmp/archive.swu 2>/dev/null &
    ( cd /tmp; zip "$USB_MNT/archive" -FI -0 -s "${MAX_ZIP_SIZE}m" archive.swu; )
    rm -f /tmp/archive.swu 2>/dev/null
    # clear old unzipped backup
    rm -f archive.swu 2>/dev/null
fi

# and remove the temporary files from the USB
{ while IFS='' read -r f; do rm -f "$f" ; done; } < "$ARCHIVE_FILES"

# copy files needed for booting to USB flash
bootdev="${bootdev:=}"
devtype=$(echo "$bootdev" | cut -f1 -d',')
device_no=$(echo "$bootdev" | cut -f2 -d',')
partition_id=$(echo "$bootdev" | cut -f3 -d',')

if [ "$devtype" = "mmc" ]; then
    if [ "${PLATFORM}" = "g1" ]; then
        [ "$device_no" = "1" ] && device_no=0 || device_no=1
    fi

    MNT=/tmp/__mnt__
    mkdir -p "$MNT"
    mount "/dev/mmcblk${device_no}p${partition_id}" "$MNT"

    if [ -d "$MNT/altboot" ] || [ -d "$MNT/boot/altboot" ]; then
        if [ -f "$MNT/altboot/boot.scr" ]; then
            cd "$MNT/altboot"
        else
            cd "$MNT/boot/altboot"
        fi
        cp initrd.img* ./*.dtb* vmlinu* boot.cmd boot.scr "$USB_MNT" || true
        #
        # Remove MAYBE INCOMPATIBLE uboot.swu from USB medium
        if [ -r "$USB_MNT/uboot.swu" ]; then
            rm -f "$USB_MNT/uboot.swu"
        fi
        find . -type f -name \*.compatible -exec cp \{\} "$USB_MNT" \; || true
    fi
    cd /
    umount "$MNT" && rmdir "$MNT"
fi
