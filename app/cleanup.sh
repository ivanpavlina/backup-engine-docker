#!/bin/bash

identifier="cleanup"
source /home/app/utils.sh

delete_count=$(find $BACKUP_PATH/* -maxdepth 0 -type d -mtime "+$BACKUP_CLEANUP_KEEP_DAYS" | wc -l);

if [[ $delete_count -gt 0 ]]; then
  log $identifier "Cleaning up $delete_count directories older than $BACKUP_CLEANUP_KEEP_DAYS days";
  find $BACKUP_PATH/* -maxdepth 0 -type d -mtime "+$BACKUP_CLEANUP_KEEP_DAYS" -exec rm -rv {} +;
else
  log $identifier "Nothing to cleanup";
fi
