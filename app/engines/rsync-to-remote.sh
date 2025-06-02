#!/bin/bash

identifier="rsync-to-remote"
source /home/app/utils.sh

# If script is sourced (from entrypoint.sh) run environment check and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] ; then
  err=0;

  if ! env_var_is_set SOURCE_PATH; then log $identifier "SOURCE_PATH not set, defaulting to /source"; SOURCE_PATH=/source; fi;
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
    log $identifier "Rsync-to-remote exclude patterns initialized [$RSYNC_EXCLUDE]";
  fi;

  if env_var_is_set RSYNC_FLAGS; then
    log $identifier "Rsync-to-remote will be run with requested flags [$RSYNC_FLAGS]";
  fi

  return $err;
fi;

######################################################################

log $identifier "Running..."

failed=false;

if /usr/bin/rsync \
    $RSYNC_FLAGS --exclude-from=/rsync-exclude \
    -e "ssh -o StrictHostKeyChecking=no -i $SSH_KEY" \
    "$SOURCE_PATH/" "${SSH_USERNAME}@${HOST}:${REMOTE_PATH}/"; then
  log $identifier "Transferred successfully"
else
  log $identifier "Some errors occurred while transferring from $SOURCE_PATH to $SSH_USERNAME@$HOST:$REMOTE_PATH
                   key:[$SSH_KEY] exclude:[$(cat /rsync-exclude)]"
  failed=true;
fi

if [ $failed = true ]; then
  log $identifier "Killing container due to errors";
  kill_container;
fi
