#!/bin/bash

identifier="rsync"
source /home/app/utils.sh

# If script is sourced (from entrypoint.sh) run environment check and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] ; then
  err=0;

  if ! env_var_is_set HOST; then log $identifier "HOST env variable is not set"; err=1; fi;
  if ! env_var_is_set SSH_USERNAME; then log $identifier "SSH_USERNAME env variable is not set"; err=1; fi;
  if ! env_var_is_set REMOTE_PATH; then log $identifier "REMOTE_PATH env variable is not set"; err=1; fi;

  if ! env_var_is_set SSH_KEY; then
    log $identifier "SSH_KEY env variable is not set, defaulting to /keys/id_rsa";
    export SSH_KEY=/keys/id_rsa;
  fi;
  if ! file_exists $SSH_KEY; then log $identifier "No key found on path $SSH_KEY"; err=1; fi;

  # Write exclude to file so its easier to use with rsync exclude-from
  touch /rsync-exclude
  if env_var_is_set RSYNC_EXCLUDE; then
    echo "$RSYNC_EXCLUDE" | tr , \\n >> /rsync-exclude
    log $identifier "Rsync exclude patterns initialized [$RSYNC_EXCLUDE]";
  fi;

  if env_var_is_set RSYNC_FLAGS; then
    log $identifier "Rsync will be run with requested flags [$RSYNC_FLAGS]";
  fi

  if env_var_is_set ARCHIVE_BACKUP; then
    log $identifier "Backup will be archived";
  fi

  return $err;
fi;

######################################################################

log $identifier "Running..."

current_date=$(date +%Y_%m_%d)
target_backup_dir="$BACKUP_PATH/$current_date"
mkdir -p "$target_backup_dir";

if /usr/bin/rsync \
    $RSYNC_FLAGS --exclude-from=/rsync-exclude \
    -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
    "$SSH_USERNAME@$HOST:$REMOTE_PATH/" "$target_backup_dir/"; then
  log $identifier "Transferred successfully"

  if [ "$ARCHIVE_BACKUP" = "true" ]; then
    if tar -czf "$target_backup_dir.tar.gz" -C "$target_backup_dir" .; then
      rm -rf "$target_backup_dir"
      log $identifier "Backup archived and original backup directory removed"
    else
      log $identifier "Error in archiving process"
      kill_container;
    fi
  fi

else
  log $identifier "Some errors occurred while transferring from $SSH_USERNAME@$HOST:$REMOTE_PATH to $target_backup_dir
                   key:[$SSH_KEY] exclude:[$(cat /rsync-exclude)]"
  log $identifier "Killing container due to errors";
  kill_container;
fi
