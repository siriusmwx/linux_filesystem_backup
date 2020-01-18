#!/bin/bash
if [ $UID -ne 0 ]
then
    echo "Program must be run as root" 1>&2
    exit 1
fi

usage(){
cat << EOF
Usage: $(basename $0) [options]

Options:
EOF

cat << EOF | column -s\& -t
-s|--source & File path of root filesystem backup,example:/media/mount_point/backup.tgz
-c|--config & File path of "/etc/fstab" in root filesystem which needs to backup
-h|--help & Display help
EOF

cat << EOF

Examples:
$(basename $0) -c /media/root_partition/etc/fstab -s /media/mount_partition/backup.tgz
EOF
}

Root_Filesystem_Mount(){
    cat ${config_fstab} | while read line;do
        if echo $line | grep -i "^UUID=.*[ ]/[ a-z]" &> /dev/null;then
            uuid_origin=$(echo $line | cut -d " " -f 1)
            mount_point=$(echo $line | cut -d " " -f 2)
            mount_num=$(echo ${mount_point} | tr "/" " " | wc -w)
            uuid_num=${uuid_origin##*=}
            mount_part=$(blkid | grep ${uuid_num} | cut -d ":" -f 1)
            echo ${mount_num}:${mount_part}:${mount_point}
        fi
    done | sort -n | while read line;do
        mount_part=$(echo $line | cut -d ":" -f 2)
        mount_point=$(echo $line | cut -d ":" -f 3)
        umount ${mount_part} &> /dev/null
        mount ${mount_part} ${mount_root}${mount_point} || exit 1
    done
}

while true;do
    case $1 in
        -s|--source)
        if [ -d ${2%/*} ];then
            backup_file=$2
        else
            echo "Can't find ${2%/*},folder ${2%/*} don't exist" 1>&2
            echo "Option $1 must be an exiting file path" 1>&2
        fi
        shift;;
        -c|--config)
        if [ -r $2 ];then
            config_fstab=$2
        else
            echo "Can't find $2,file $2 don't exist" 1>&2
            echo "Option $1 must be an exiting fstab file" 1>&2
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

if [[ -n ${backup_file} && -n ${config_fstab} ]];then
    mount_root='/mnt'
    Root_Filesystem_Mount
    cd ${mount_root}
    tar -cvpzf ${backup_file} *
else
    usage
fi
