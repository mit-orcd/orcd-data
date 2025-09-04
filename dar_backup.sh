#!/bin/bash
# Change to a directory with sufficient space (adjust if /tmp is too small)

cd /tmp || exit 1

# Function to backup a single user
backup_user() {
    local USER="$1"
    local MODE="$2"  # full or inc
    local TS=$(date +%Y%m%d-%H%M%S)
    local BASENAME="${USER}-${MODE}-${TS}"
    local CAT_NAME="${USER}-latest-cat"
    local REF=""
    local DAR_OPTS="-zlz4 -s 5G -E \"/tmp/upload-slice.sh ${USER} %b %n %e\""

    echo "Starting ${MODE} backup for user: ${USER}"

    if [ "${MODE}" = "inc" ]; then
        # Check for previous catalogue
        if aws s3 ls "s3://orcd-home3/${USER}/${CAT_NAME}.1.dar" > /dev/null 2>&1; then
            # Download latest catalogue
            aws s3 cp "s3://orcd-home3/${USER}/${CAT_NAME}.1.dar" .
            REF="-A ${CAT_NAME}"
            echo "Using reference catalogue for incremental: ${CAT_NAME}"
        else
            echo "No previous backup found for ${USER}. Falling back to full mode."
            MODE="full"
            BASENAME="${USER}-${MODE}-${TS}"
        fi
    fi

    # Run DAR for this user (use sudo if needed for access)
    eval "dar -c \"${BASENAME}\" -R \"/home/${USER}\" ${REF} ${DAR_OPTS}" > "/tmp/${USER}-backup.log" 2>&1

    if [ $? -ne 0 ]; then
        echo "Backup failed for user: ${USER}. Check /tmp/${USER}-backup.log"
        rm -f "${CAT_NAME}.1.dar"  # Cleanup downloaded cat if any
        return 1
    fi

    # Create isolated catalogue (downloads only last slice if needed)
    local TEMP_CAT="${BASENAME}-temp-cat"
    local DOWNLOAD_SCRIPT="/tmp/download-slice.sh ${USER} %b %n %e"
    dar --sequential-read -C "${TEMP_CAT}" -A "${BASENAME}" -F "${DOWNLOAD_SCRIPT}" > "/tmp/${USER}-cat.log" 2>&1

    if [ $? -ne 0 ]; then
        echo "Catalogue creation failed for ${USER}. Check /tmp/${USER}-cat.log"
        rm -f "${BASENAME}."*.dar  # Cleanup any downloaded slices
        rm -f "${CAT_NAME}.1.dar"
        return 1
    fi

    # Upload specific and latest catalogues
    aws s3 cp "${TEMP_CAT}.1.dar" "s3://orcd-home3/${USER}/${BASENAME}-cat.1.dar"
    aws s3 cp "${TEMP_CAT}.1.dar" "s3://orcd-home3/${USER}/${CAT_NAME}.1.dar"  # Overwrite latest

    # Cleanup
    rm -f "${TEMP_CAT}.1.dar"
    rm -f "${BASENAME}."*.dar  # Remove any downloaded slices
    rm -f "${CAT_NAME}.1.dar"  # Remove local ref cat if inc

    echo "Backup and catalogue completed for user: ${USER}"
}

# Export the function (good practice for subshells)
export -f backup_user

# Determine mode from argument
if [ "$1" = "--incremental" ]; then
    MODE="inc"
else
    MODE="full"
fi

# List user directories (assumes all subdirs under /home are users)
users=$(find /home -maxdepth 1 -type d -printf '%f\n' | tail -n +2)

# Concurrency limit
MAX_JOBS=100
running=0

for user in $users; do
    # Start backup in background
    backup_user "$user" "$MODE" &

    # Increment counter
    ((running++))

    # If at limit, wait for one job to finish
    if ((running >= MAX_JOBS)); then
        wait -n
        ((running--))
    fi
done

# Wait for all remaining jobs to finish
wait

echo "All backups completed."