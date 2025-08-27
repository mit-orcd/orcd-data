#!/bin/sh
# Arguments: $1 = user, $2 = %b (basename), $3 = %n (slice number), $4 = %e (extension)

USER="$1"
BASENAME="$2"
NUMBER="$3"
EXTENSION="$4"
SLICE_FILE="${BASENAME}.${NUMBER}.${EXTENSION}"

aws s3 cp "${SLICE_FILE}" "s3://orcd-backup-home3/${USER}/${SLICE_FILE}"

if [ $? -eq 0 ]; then
    rm -f "${SLICE_FILE}"
    echo "Uploaded and deleted ${SLICE_FILE} for user ${USER}"
else
    echo "Upload failed for ${SLICE_FILE} for user ${USER}. Not deleting."
    exit 1
fi