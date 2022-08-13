#!/bin/bash

identifier="cleanup"
source /home/app/utils.sh

log $identifier "Running..."

items_count=$(find $BACKUP_PATH/* -maxdepth 0 | wc -l)
delete_count=$(find $BACKUP_PATH/* -maxdepth 0 -mtime "+$BACKUP_CLEANUP_KEEP_DAYS" | wc -l);

if [[ $delete_count -gt 0 ]]; then
  if [[ $items_count -gt 1 ]]; then
    log $identifier "Cleaning up $delete_count items older than $BACKUP_CLEANUP_KEEP_DAYS days";
    find $BACKUP_PATH/* -maxdepth 0 -mtime "+$BACKUP_CLEANUP_KEEP_DAYS" -exec rm -rv {} +;
    log $identifier "Finished";
  else
    log $identifier "Not deleting last file";
  fi
else
  log $identifier "Nothing to clean up";
fi
