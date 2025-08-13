#!/bin/bash


if [ "$#" -ne 2 ]; then
    echo "$USAGE"
    exit 1
fi

src=$1
dest=$2

find "$src" -maxdepth 1 -mindepth 1 -type d ! -name "restor*" -print0 | while IFS= read -r -d $'\0' subdir; do

  subdir_name="${subdir#"$src"}"

  rsync_src="$subdir/"
  rsync_dest="$dest/$subdir_name"

  echo $rsync_src
  echo $rsync_dest

  run_rclone() {
    rclone sync "$rsync_src" "$rsync_dest" --transfers 8 --progress --links --no-update-modtime
  }

  while [[ $(pgrep -f "rclone" | wc -l) -ge 100 ]]; do
    sleep 10  # Wait
  done

  # Run rsync in the background.
  run_rclone &

done

echo "rclone job completed."

exit 0
#
