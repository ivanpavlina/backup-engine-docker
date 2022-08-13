#!/bin/bash

identifier="tasmota"
source /home/app/utils.sh

# If script is sourced (from entrypoint.sh) run environment check and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] ; then
  err=0;
  if ! env_var_is_set TARGETS; then log $identifier "TARGETS env variable is not set"; err=1; fi;
  if ! env_var_is_set USERNAME; then log $identifier "USERNAME env variable is not set"; err=1; fi;
  if ! env_var_is_set PASSWORD; then log $identifier "PASSWORD env variable is not set"; err=1; fi;

  return $err;
fi;

######################################################################

log $identifier "Running..."

current_date=$(date +%Y_%m_%d)

failed=false;

oldIFS=$IFS
export IFS="|"
for target in $TARGETS; do
  TARGET_BACKUP_DIR="$BACKUP_PATH/$target"
  mkdir -p "$TARGET_BACKUP_DIR";

  if /usr/bin/wget -q --user "$USERNAME" --password "$PASSWORD" -O "$TARGET_BACKUP_DIR"/"$current_date".backup http://"$target"/dl; then
      log $identifier "Successfully download configuration for $target";
  else
      log $identifier "Failed to download configuration for $target";
      failed=true;
  fi
done
IFS=$oldIFS

if [ $failed = true ]; then
  log $identifier "Killing container due to errors";
  kill_container;
fi
