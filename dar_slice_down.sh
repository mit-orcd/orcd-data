#!/bin/sh
# Arguments: $1 = user, $2 = %b (basename), $3 = %n (slice number), $4 = %e (extension)

USER="$1"
BASENAME="$2"
NUMBER="$3"
EXTENSION="$4"
SLICE_FILE="${BASENAME}.${NUMBER}.${EXTENSION}"

aws s3 cp "s3://orcd-backup-home3/${USER}/${SLICE_FILE}" "${SLICE_FILE}"

if [ $? -eq 0 ]; then
    echo "Downloaded ${SLICE_FILE} for user ${USER}"
    exit 0
else
    echo "Download failed for ${SLICE_FILE} for user ${USER}"
    exit 1
fi