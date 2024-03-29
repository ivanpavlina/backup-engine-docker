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

download_configuration() {
  output=$(/usr/bin/wget --user "$USERNAME" --password "$PASSWORD" -O "$target_backup_dir"/"$1".backup http://"$1"/dl 2>&1)
  if [ $? -ne 0 ]; then
      log $identifier "Failed to download configuration for $1\n$output";
      failed=true;
  else
    log $identifier "Successfully download configuration for $1";
  fi
}

log $identifier "Running..."

current_date=$(date +%Y_%m_%d)
target_backup_dir="$BACKUP_PATH/$current_date"
mkdir -p "$target_backup_dir";

failed=false;

IFS='|' read -ra IPS <<< "$TARGETS"
for ip_range in "${IPS[@]}"; do
  if [[ $ip_range =~ "-" ]]; then
    IFS='-' read -ra IP_RANGE <<< "$ip_range"
    start_ip="${IP_RANGE[0]}"
    end_ip="${IP_RANGE[1]}"

    ip_prefix="${start_ip%.*}"
    start_octet="${start_ip##*.}"
    end_octet="${end_ip##*.}"

    for ((octet = start_octet; octet <= end_octet; octet++)); do
      ip_address="$ip_prefix.$octet"
      download_configuration $ip_address
    done
  else
    download_configuration $ip_range
  fi
done

if [ $failed = true ]; then
  log $identifier "Killing container due to errors";
  kill_container;
fi
