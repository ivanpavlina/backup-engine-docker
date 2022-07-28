#!/bin/bash

identifier="mikrotik"
source /home/app/utils.sh

# If script is sourced (from entrypoint.sh) run environment check and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] ; then
  err=0;
  if ! env_var_is_set TARGETS; then log $identifier "TARGETS env variable is not set"; err=1; fi;
  if ! env_var_is_set SSH_USERNAME; then log $identifier "SSH_USERNAME env variable is not set"; err=1; fi;

  if ! env_var_is_set SSH_KEY; then
    log $identifier "SSH_KEY env variable is not set, defaulting to /keys/id_rsa";
    export SSH_KEY=/keys/id_rsa;
  fi;

  if ! env_var_is_set FILE_GENERATE_MAX_WAIT || ! env_var_is_positive FILE_GENERATE_MAX_WAIT; then
    log $identifier "FILE_GENERATE_MAX_WAIT env variable is not set or invalid, defaulting to 30";
    export FILE_GENERATE_MAX_WAIT=30;
  fi;

  return $err;
fi;

log $identifier "Running..."

current_date=$(date +%Y_%m_%d)

scp_files=()

backup_command=""
if env_var_is_set BACKUP_PASSWORD ; then
  backup_command="$backup_command/system backup save dont-encrypt=no password=$BACKUP_PASSWORD name=backup.backup;"
else
  backup_command="$backup_command/system backup save dont-encrypt=yes name=backup.backup;"
fi
scp_files=("${scp_files[@]}" "backup.backup")

if [ "$EXPORT_CONFIG" = true ]; then
  backup_command="$backup_command/export file=backup.rsc;"
  scp_files=("${scp_files[@]}" "backup.rsc")
fi

oldIFS=$IFS
export IFS="|"
for target in $TARGETS; do
  TARGET_BACKUP_DIR="$BACKUP_PATH/$target/$current_date"
  mkdir -p "$TARGET_BACKUP_DIR";

  if ! ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USERNAME@$target" "$backup_command" > /dev/null; then
    log $identifier "$target" "Failed executing backup command";
    continue
  fi
  sleep 3

  success_files=()

  for file in "${scp_files[@]}"; do
    now=$(date +%s);
    deadline=$(( now + FILE_GENERATE_MAX_WAIT));

    # Check if file generation is still in progress
    file_generation_timed_out=true

    while [ "$now" -lt $deadline ]; do
      now=$(date +%s);
      res=$(ssh -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USERNAME@$target" "/file/print where name=$file.in_progress" | wc -l)

      if [ "$res" -gt 1 ]; then
        # Waiting for file to generate...
        log $identifier "$target" "... Waiting for $file to generate";
        sleep 2
        continue
      else
        # File generated
        if scp -o StrictHostKeyChecking=no -i "$SSH_KEY" "$SSH_USERNAME@$target:/$file" "$TARGET_BACKUP_DIR" > /dev/null; then
          success_files=("${success_files[@]}" "$file")
          file_generation_timed_out=false
          break
        else
          log $identifier "$target" "Could not retrieve $file";
          file_generation_timed_out=false
          break
        fi
      fi
    done

    if [ $file_generation_timed_out = true ]; then
        log $identifier "$target" "Giving up waiting for $file to generate";
    fi
  done

  if [ ${#success_files[@]} -eq 0 ]; then
    log $identifier "$target" "Failed retrieving files!";
  else
    export IFS=" "
    log $identifier "$target" "Successfully retrieved files [ ${success_files[*]} ]";
    export IFS="|"
  fi
done
export IFS=$oldIFS
#IFS=
