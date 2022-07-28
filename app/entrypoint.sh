#!/bin/bash

source /home/app/utils.sh

log "Initializing environment...";

errored=false;

if ! env_var_is_set CRON; then log "CRON env variable is not set"; errored=true; fi;

if ! env_var_is_set BACKUP_PATH; then
  log "BACKUP_PATH env variable is not set, defaulting to /backup";
  export BACKUP_PATH=/backup;
fi;

if ! env_var_is_set ENGINE ; then
  log "ENGINE env variable is not set"; errored=true;
elif ! file_exists "/home/app/engines/$ENGINE.sh"; then
  log "Unknown ENGINE specified [$ENGINE]"; errored=true;
else
  # Source engine script so setup portion is run
  if ! source "/home/app/engines/$ENGINE.sh" ; then
    log "ENGINE $ENGINE failed setup"; errored=true;
  fi;
fi;

if [ "$errored" = true ]; then
  log "Environment initialization failed >>\n$(env)"
  exit 1;
fi
log "Environment initialization ok"

if [[ ! -d "$BACKUP_PATH" ]]; then
  mkdir -p "$BACKUP_PATH";
  log "Created backup directory $BACKUP_PATH";
fi

crontab="""$CRON /home/app/engines/$ENGINE.sh"""

# Setup cleaner
if env_var_is_set BACKUP_CLEANUP_KEEP_DAYS && env_var_is_positive BACKUP_CLEANUP_KEEP_DAYS; then
  crontab="$crontab && /home/app/cleanup.sh"
  log "Setting up cleaner. Cleaning up directories older than $BACKUP_CLEANUP_KEEP_DAYS days"
else
  log "BACKUP_CLEANUP_KEEP_DAYS env variable is invalid [$BACKUP_CLEANUP_KEEP_DAYS],
                   must be a positive integer. Not setting up cleaner";
fi;

echo "$crontab" >> /etc/crontabs/root
log "Generated crontab [ $crontab ]"
log "Starting cron daemon..."


crond -l 2 -f > /dev/stdout 2> /dev/stderr
