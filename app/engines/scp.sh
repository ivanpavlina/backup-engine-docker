#!/bin/bash

identifier="scp"
source /home/app/utils.sh

# If script is sourced (from entrypoint.sh) run environment check and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] ; then
  err=0;

  if ! env_var_is_set HOST; then log $identifier "HOST env variable is not set"; err=1; fi;
  if ! env_var_is_set SSH_USERNAME; then log $identifier "SSH_USERNAME env variable is not set"; err=1; fi;
  if ! env_var_is_set REMOTE_PATHS; then log $identifier "REMOTE_PATHS env variable is not set"; err=1; fi;

  if ! env_var_is_set SSH_KEY; then
    log $identifier "SSH_KEY env variable is not set, defaulting to /keys/id_rsa";
    export SSH_KEY=/keys/id_rsa;
  fi;
  if ! file_exists $SSH_KEY; then log $identifier "No key found on path $SSH_KEY"; err=1; fi;

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

atleast_one_success=false;

IFS='|' read -ra PATHS <<< "$REMOTE_PATHS"
for path in "${PATHS[@]}"; do
  mkdir -p "$staging_dir$path"
  if /usr/bin/scp \
      -r -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -i $SSH_KEY \
      "$SSH_USERNAME@$HOST:$path/" "$staging_dir$path"; then
    log $identifier "[$path] transferred successfully"
    atleast_one_success=true;
  else
    log $identifier "Some errors occurred while transferring [$path]"
    failed=true;
  fi
done

if [ $atleast_one_success = true ]; then
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
fi

if [ $failed = true ]; then
  log $identifier "Killing container due to errors";
  kill_container;
fi
