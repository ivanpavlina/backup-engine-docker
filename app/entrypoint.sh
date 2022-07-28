#!/bin/bash

name="entrypoint"
source /home/app/utils.sh

log $name "Initializing environment...";

errored=false;

if ! env_var_is_set CRON; then log $name "CRON env variable is not set"; errored=true; fi;

if ! env_var_is_set BACKUP_PATH; then
  log $name "BACKUP_PATH env variable is not set, defaulting to /backup";
  export BACKUP_PATH=/backup;
fi;

if ! env_var_is_set ENGINE ; then
  log $name "ENGINE env variable is not set"; errored=true;
elif ! file_exists "/home/app/engines/$ENGINE.sh"; then
  log $name "Unknown ENGINE specified [$ENGINE]"; errored=true;
else
  # Source engine script so setup portion is run
  if ! source "/home/app/engines/$ENGINE.sh" ; then
    log $name "ENGINE $ENGINE failed setup"; errored=true;
  fi;
fi;

if [ "$errored" = true ]; then
  log $name "Environment initialization failed >>\n$(env)"
  exit 1;
fi
log $name "Environment initialization ok"

if [[ ! -d "$BACKUP_PATH" ]]; then
  mkdir -p "$BACKUP_PATH";
  log $name "Created backup directory $BACKUP_PATH";
fi

crontab="""$CRON /home/app/engines/$ENGINE.sh"""

# Setup cleaner
if env_var_is_set BACKUP_CLEANUP_KEEP_DAYS && env_var_is_positive BACKUP_CLEANUP_KEEP_DAYS; then
  crontab="$crontab && /home/app/cleanup.sh"
  log $name "Setting up cleaner. Cleaning up directories older than $BACKUP_CLEANUP_KEEP_DAYS days"
else
  log $name "BACKUP_CLEANUP_KEEP_DAYS env variable is invalid [$BACKUP_CLEANUP_KEEP_DAYS],
                   must be a positive integer. Not setting up cleaner";
fi;

echo "$crontab" >> /etc/crontabs/root
log $name "Generated crontab [ $crontab ]"
log $name "Starting cron daemon..."


crond -l 2 -f > /dev/stdout 2> /dev/stderr
