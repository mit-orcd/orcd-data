#!/bin/bash

cd /data1/orcd/001/tmp || exit 1

backup_user() {
    local USER="$1"
    local WDIR="/data1/orcd/001"
    echo "Starting backup for user: ${USER}"

    dar -c `date -I`_${USER}-backup -R "${WDIR}/home3-backup/home/${USER}" -m 512 -zlz4 -s 5G -E "${WDIR}/tmp/dar_slice_up.sh ${USER} %b %n %e" > "${WDIR}/tmp/log/${USER}_fullbackup.log" 2>&1

    if [ $? -eq 0 ]; then
        echo "Backup completed for user: ${USER}"
    else
        echo "Backup failed for user: ${USER}. Check ${USER}_fullbackup.log"
    fi
}

export -f backup_user

users=$(find /data1/orcd/001/home3-backup/home -maxdepth 1 -type d -printf '%f\n' | tail -n +2)

MAX_JOBS=100
running=0

for user in $users; do

    backup_user "$user" &

    ((running++))

    if ((running >= MAX_JOBS)); then
        wait -n
        ((running--))
    fi
done

wait

echo "All backups completed."