#!/bin/bash
if [ $UID -ne 0 ]
then
    echo "Program must be run as root" 1>&2
    exit 1
fi

CURRENT_DIR=$(cd `dirname $0`;pwd)
cd ${CURRENT_DIR}
MOUNT_ROOT='/mnt'

usage(){
cat << EOF
Usage: $(basename $0) [options]

Options:
EOF

cat << EOF | column -s\& -t
-c|--source & Source filesystem backup tar.gz to unzip to target drive
-d|--drive & Target drive to make partition and install filesystem
-h|--help & Display help
EOF

cat << EOF

Examples:
$(basename $0) -d /dev/sdc -c backup.tgz
EOF
}

System_Recovery(){
    EFI_GUID='409B13DF'
    SWAP_GUID='3EA3202C-4860-47E2-A9FF-AF844F6072FA'
    SYSTEM_GUID='109832CD-E0FE-4EA3-9FE0-336F15FF5BDA'
    EFI_PARTITION_IN_BYTES=536870912
    SWAP_PARTITION_IN_BYTES=2147483648

    # Make sure all partitions are not mounted
    umount ${DEV}* 2>/dev/null

    START_SECTOR=2048
    DEV_LOGICAL_BLOCK_SIZE_IN_BYTES=$(cat /sys/block/${DEV_ID}/queue/logical_block_size)
    # DEV_SIZE_IN_LOGICAL_BLOCKS=$(cat /sys/class/block/${DEV_ID}/size)

    if [ -d /sys/firmware/efi ]
    then
        GPT_Partition
    else
        MBR_Partition
    fi
    mount --bind "/dev" "${MOUNT_ROOT}/dev"
    mount --bind "/proc" "${MOUNT_ROOT}/proc"
    mount --bind "/sys" "${MOUNT_ROOT}/sys"
    chroot ${MOUNT_ROOT} /bin/sh << EOF
grub-install ${DEV}
update-grub
EOF
}

GPT_Partition(){
    sgdisk --zap-all ${DEV} 2>/dev/null 1>&2
    END_SECTOR=$(((EFI_PARTITION_IN_BYTES/DEV_LOGICAL_BLOCK_SIZE_IN_BYTES)-1+START_SECTOR))
    sgdisk --new=1:$START_SECTOR:$END_SECTOR --typecode=1:ef00 ${DEV}
    START_SECTOR=$((END_SECTOR+1))
    END_SECTOR=$(((SWAP_PARTITION_IN_BYTES/DEV_LOGICAL_BLOCK_SIZE_IN_BYTES)-1+START_SECTOR))
    sgdisk --new=2:$START_SECTOR:$END_SECTOR --typecode=2:8200 ${DEV}
    START_SECTOR=$((END_SECTOR+1))
    sgdisk --new=3:$START_SECTOR --typecode=3:8300 ${DEV}

    umount ${DEV}* 2>/dev/null
    echo y | mkfs.vfat "${DEV}1" -i ${EFI_GUID}
    echo y | mkswap "${DEV}2" -U ${SWAP_GUID}
    echo y | mkfs.ext4 "${DEV}3" -L "SYSTEM" -U ${SYSTEM_GUID}

    mount "${DEV}3" ${MOUNT_ROOT}
    tar -xvpzf ${backup_tgz} -C ${MOUNT_ROOT}
    mount "${DEV}1" "${MOUNT_ROOT}/boot/efi"
    cat > ${MOUNT_ROOT}/etc/fstab << EOF
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sda3 during installation
UUID=${SYSTEM_GUID,,} /               ext4    errors=remount-ro 0       1
# /boot/efi was on /dev/sda1 during installation
UUID=${EFI_GUID:0:4}-${EFI_GUID:4}  /boot/efi       vfat    umask=0077      0       1
# swap was on /dev/sda2 during installation
UUID=${SWAP_GUID,,} none            swap    sw              0       0
EOF
}

MBR_Partition(){
    END_SECTOR=$(((SWAP_PARTITION_IN_BYTES/DEV_LOGICAL_BLOCK_SIZE_IN_BYTES)-1+START_SECTOR))
    echo -e "o\nn\np\n1\n\n+${END_SECTOR}\nn\np\n2\n\n\nt\n1\n82\nt\n2\n83\na\n2\nw\n" | fdisk ${DEV} 2>/dev/null

    umount ${DEV}* 2>/dev/null
    echo y | mkswap "${DEV}1" -U ${SWAP_GUID}
    echo y | mkfs.ext4 "${DEV}2" -L "SYSTEM" -U ${SYSTEM_GUID}

    mount "${DEV}2" ${MOUNT_ROOT}
    tar -xvpzf ${backup_tgz} -C ${MOUNT_ROOT}
    cat > ${MOUNT_ROOT}/etc/fstab << EOF
# <file system> <mount point>   <type>  <options>       <dump>  <pass>
# / was on /dev/sda2 during installation
UUID=${SYSTEM_GUID,,} /               ext4    errors=remount-ro 0       1
# swap was on /dev/sda1 during installation
UUID=${SWAP_GUID,,} none            swap    sw              0       0
EOF
}

while true;do
    case $1 in
        -c|--source)
        if ls $2 &>/dev/null;then
            backup_tgz=$2
        else
            echo "Can't find $2,no such file" 1>&2
            echo "Option $1 must be an exiting file" 1>&2
        fi
        shift;;
        -d|--drive)
        if ls $2 &>/dev/null;then
            DEV=$2
            DEV_ID=${DEV##*/}
        else
            echo "Can't find $2,no such device" 1>&2
            echo "Option $1 must be an exiting device" 1>&2
        fi
        shift;;
        -h|--help)
        usage
        exit 0;;
        --)
        shift
        break;;
        *)
        shift
        break;;
    esac
    shift
done

if [[ -n ${backup_tgz} && -n ${DEV} ]];then
    # echo "$(basename $0) -d ${DEV} -c ${backup_tgz}"
    System_Recovery
else
    usage
fi
