#!/bin/bash

name="entrypoint"
source /home/app/utils.sh

# Skip setup if already ran
if grep -q ' : && : &&' /etc/crontabs/root; then echo "Container restarted"; log $name "Starting cron daemon..."; run; exit 0; fi

log $name "Initializing environment...";

errored=false;

if ! env_var_is_set CRON; then log $name "CRON env variable is not set"; errored=true; fi;

if ! env_var_is_set BACKUP_PATH; then
  log $name "BACKUP_PATH env variable is not set"; errored=1;
fi;

if ! env_var_is_set ENGINE ; then
  log $name "ENGINE env variable is not set"; errored=true;
elif [ "$ENGINE" = "CLEANUP_ONLY" ]; then
  log $name "Setting up without engine, only cleanup will be enabled";
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

crontab="""$CRON : && : &&"""

if [ "$ENGINE" != "CLEANUP_ONLY" ]; then
  crontab="$crontab /home/app/engines/$ENGINE.sh"""
fi

# Setup cleaner
if env_var_is_set BACKUP_CLEANUP_KEEP_DAYS && env_var_is_positive BACKUP_CLEANUP_KEEP_DAYS; then
  if [ "$ENGINE" != "CLEANUP_ONLY" ]; then crontab="$crontab &&"; fi
  crontab="$crontab /home/app/cleanup.sh"
  log $name "Setting up cleaner. Cleaning up directories older than $BACKUP_CLEANUP_KEEP_DAYS days"
else
  log $name "BACKUP_CLEANUP_KEEP_DAYS env variable is invalid [$BACKUP_CLEANUP_KEEP_DAYS],
                   must be a positive integer. Not setting up cleaner";
  errored=true;
fi;

if [ "$errored" = true ]; then
  log $name "Environment setup failed >>\n$(env)"
  exit 1;
fi
log $name "Environment setup ok"

echo "$crontab" >> /etc/crontabs/root
log $name "Generated crontab [ $crontab ]"
log $name "Starting cron daemon..."

run
