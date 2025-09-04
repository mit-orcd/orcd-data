#!/bin/bash

TMP=/data1/orcd/001/tmp

LOG=${TMP}/logs

mkdir -p ${LOG}

cd ${TMP} || exit 1

PASS_FILE="$HOME/.backup_pass"

COMPRESSION="auto"

SOURCE="/data1/orcd/001/home3-backup/home"

RUN=false

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  -z <level>          Set compression level (auto|off|fastest|better|max, default: auto)"
    echo "  -s|--source <dir>   Set source directory to backup (default: ${SOURCE})"
    echo "  -r|--run            Set to execute the backup "
    exit 1
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        -z|--compress)
            COMPRESSION="$2"
            shift 2
            ;;
        -s|--source)
            SOURCE="$2"
            shift 2
            ;;
        -r|--run)
            RUN=true
            shift
            ;;
        *)
            usage
            ;;
    esac
done

if ! $RUN; then
    usage
fi

backup_user() {
    local USER="$1"
    local TS=$(date +%Y%m%d-%H%M%S)
    local TAG="backup-${TS}"
    local REPO="/mnt/backup_home/home3/${USER}"
    local RESTIC_OPTS="--compression ${COMPRESSION} --verbose --password-file ${PASS_FILE} --skip-if-unchanged"

    echo "Starting backup for user: ${USER} with compression: ${COMPRESSION}"

    cd "${SOURCE}" || { echo "Failed to cd to ${SOURCE} for user ${USER}"; return 1; }

    /usr/local/bin/restic snapshots --repo "${REPO}" --password-file "${PASS_FILE}" &> /dev/null
    if [ $? -ne 0 ]; then

        /usr/local/bin/restic init --repo "${REPO}" --password-file "${PASS_FILE}" > "${LOG}/${USER}-init.log" 2>&1
        if [ $? -ne 0 ]; then
            echo "Repo init failed for ${USER}. Check ${LOG}/${USER}-init.log"
            return 1
        fi
    fi

    /usr/local/bin/restic backup --repo "${REPO}" --tag "${TAG}" "./${USER}" ${RESTIC_OPTS} > "${LOG}/${USER}-backup.log" 2>&1

    if [ $? -ne 0 ]; then
        echo "Backup failed for user: ${USER}. Check ${LOG}/${USER}-backup.log"
        return 1
    fi

    echo "Backup completed for user: ${USER}. Tag: ${TAG}"
}

export -f backup_user

users=$(find ${SOURCE} -maxdepth 1 -type d ! -name "restor-home*" -printf '%f\n' | tail -n +2)

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
