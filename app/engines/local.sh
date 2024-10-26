#!/bin/bash

identifier="local"
source /home/app/utils.sh

# If script is sourced (from entrypoint.sh) run environment check and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] ; then
  err=0;

  if ! env_var_is_set SOURCE_PATH; then log $identifier "SOURCE_PATH env variable is not set"; err=1; fi;

  # Write exclude to file so its easier to use with rsync exclude-from
  touch /rsync-exclude
  if env_var_is_set RSYNC_EXCLUDE; then
    echo "$RSYNC_EXCLUDE" | tr , \\n >> /rsync-exclude
    log $identifier "Rsync exclude patterns initialized [$RSYNC_EXCLUDE]";
  fi;

  if env_var_is_set RSYNC_FLAGS; then
    log $identifier "Local rsync will be run with requested flags [$RSYNC_FLAGS]";
  fi

  if env_var_is_set ARCHIVE_BACKUP && [ "$ARCHIVE_BACKUP" = "true" ]; then
    log $identifier "Backup will be archived";
    if env_var_is_set ARCHIVE_STAGING_DIRECTORY ; then
      log $identifier "Archive will be staged to [$ARCHIVE_STAGING_DIRECTORY]";
    fi
  fi

  return $err;
fi;

######################################################################

log $identifier "Running..."

current_date=$(date +%Y_%m_%d)
target_backup_dir="$BACKUP_PATH/$current_date"

failed=false;

if env_var_is_set ARCHIVE_BACKUP && [ "$ARCHIVE_BACKUP" = "true" ] && env_var_is_set ARCHIVE_STAGING_DIRECTORY; then
  staging_dir="$ARCHIVE_STAGING_DIRECTORY"
else
  staging_dir="$target_backup_dir"
fi

mkdir -p "$staging_dir"

if /usr/bin/rsync \
    $RSYNC_FLAGS --exclude-from=/rsync-exclude \
    "$SOURCE_PATH/" "$staging_dir/"; then
  log $identifier "Transferred successfully"

  if env_var_is_set ARCHIVE_BACKUP && [ "$ARCHIVE_BACKUP" = "true" ]; then
    log $identifier "Archiving backup..."
    if tar -czf "$target_backup_dir.tar.gz" -C "$staging_dir" .; then
      rm -rf "$staging_dir"
      log $identifier "Backup archived"
    else
      log $identifier "Error occurred while archiving backup, original backup directory will persist"
      failed=true;
    fi
  fi

else
  log $identifier "Some errors occurred while transferring from $SOURCE_PATH to $target_backup_dir exclude:[$(cat /rsync-exclude)]"
  failed=true;
fi

if [ $failed = true ]; then
  log $identifier "Killing container due to errors";
  kill_container;
fi
