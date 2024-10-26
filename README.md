# Backup Engine

## Dockerhub
docker pull exithub/backup-engine:latest

https://hub.docker.com/repository/docker/exithub/backup-engine


## Configuration
Following environment variables are configurable independent of engine.

### Global variables
| Variable                 | Type    | Required | Default value | Description                                                                                                                              |
|--------------------------|---------|----------|---------------|------------------------------------------------------------------------------------------------------------------------------------------|
| CRON                     | String  | True     |               | Crontab expression with 5 fields.                                                                                                        |
| BACKUP_PATH              | String  | True     |               | Output directory for backups. Should be mounted as volume.                                                                               |
| ENGINE                   | String  | True     |               | Backup engine name which will be run, see below for details. <br/>Must be a name of a script contained in app/engines without extension. |
| BACKUP_CLEANUP_KEEP_DAYS | Integer | False    |               | If set cleanup of directories older than n days will be run after backup job.                                                            |

---
#### Mikrotik engine specific configuration

| Variable               | Type    | Required | Default value | Description                                                                              |
|------------------------|---------|----------|---------------|------------------------------------------------------------------------------------------|
| TARGETS                | String  | True     |               | IP addresses separated by &#124;                                                         |
| SSH_USERNAME           | String  | True     |               | SSH username                                                                             |
| SSH_KEY                | String  | True     |               | Path to id_rsa key for authorization to targets                                          |
| BACKUP_PASSWORD        | String  | False    |               | If set backup file will be encrypted                                                     |
| EXPORT_CONFIG          | Boolean | False    | False         | If set to true in addition to binary config, configuration export will be performed      |
| FILE_GENERATE_MAX_WAIT | Integer | True     |               | Max time engine will wait for router to generate backup file. Must be a positive integer |

---
#### Tasmota engine specific configuration

| Variable | Type   | Required | Default value | Description                                                                        |
|----------|--------|----------|---------------|------------------------------------------------------------------------------------|
| TARGETS  | String | True     |               | IP addresses separated by &#124; Also supports ranges on last octet separated by - |
| USERNAME | String | True     |               | HTTP username                                                                      |
| PASSWORD | String | True     |               | HTTP password                                                                      |

---
#### Rsync engine specific configuration

| Variable                  | Type    | Required | Default value | Description                                                   |
|---------------------------|---------|----------|---------------|---------------------------------------------------------------|
| HOST                      | String  | True     |               | IP addresses                                                  |
| SSH_USERNAME              | String  | True     |               | SSH username                                                  |
| SSH_KEY                   | String  | True     |               | Path to id_rsa key for authorization to targets               |
| REMOTE_PATH               | String  | True     |               | Path on remote address                                        |
| RSYNC_EXCLUDE             | String  | False    |               | List of rsync exclude patterns separated by ,                 |
| RSYNC_FLAGS               | String  | False    |               | List of rsync flags                                           |
| ARCHIVE_BACKUP            | Boolean | False    | False         | Creates .tar.gz archive of backup folder                      |
| ARCHIVE_STAGING_DIRECTORY | String  | False    |               | Uses staging folder to copy files before archiving to .tar.gz |
---
#### Local engine specific configuration

| Variable                  | Type    | Required | Default value | Description                                                   |
|---------------------------|---------|----------|---------------|---------------------------------------------------------------|
| SOURCE_PATH               | String  | True     |               | Source path to backup                                         |
| RSYNC_EXCLUDE             | String  | False    |               | List of rsync exclude patterns separated by ,                 |
| RSYNC_FLAGS               | String  | False    |               | List of rsync flags                                           |
| ARCHIVE_BACKUP            | Boolean | False    | False         | Creates .tar.gz archive of backup folder                      |
| ARCHIVE_STAGING_DIRECTORY | String  | False    |               | Uses staging folder to copy files before archiving to .tar.gz |

## docker-compose example
```
services:
  mikrotik:
    image: exithub/backup-engine:latest
    restart: unless-stopped      
    environment:
      - CRON=50 1 * * *
      - BACKUP_PATH=/backup
      - BACKUP_CLEANUP_KEEP_DAYS=7
      
      - ENGINE=mikrotik
      - TARGETS=192.168.88.1|192.168.88.2
      - SSH_USERNAME=backup
      - SSH_KEY=/keys/id_rsa
      - EXPORT_CONFIG=true
    volumes:
      - /share/docker/mikrotik-backup:/keys
      - /share/Backup/mikrotik:/backup

  tasmota:
    image: exithub/backup-engine:latest
    restart: unless-stopped      
    environment:
      - CRON=15 1 * * *
      - BACKUP_PATH=/backup
      - BACKUP_CLEANUP_KEEP_DAYS=2
      
      - ENGINE=tasmota
      - TARGETS=192.168.88.10-15|192.168.88.99
      - USERNAME=admin
      - PASSWORD=admin
    volumes:
      - /share/Backup/tasmota:/backup
      
  local:
    image: exithub/backup-engine:latest
    restart: unless-stopped      
    environment:
      - CRON=15 1 * * *
      - BACKUP_PATH=/backup
      - BACKUP_CLEANUP_KEEP_DAYS=2
      
      - ENGINE=local
      - RSYNC_FLAGS=-a --partial
      - SOURCE_PATH=/source
    volumes:
      - /share/source:/source
      - /share/Backup/localbkp:/backup
```


---
## Custom engine

To support new types of backups, new engine script can be defined in app/engines/*.sh script.

Engine script should contain following header:
```
#!/bin/bash

identifier=<< Engine name >>
source /home/app/utils.sh

# If script is sourced (from entrypoint.sh) run environment check and return
if [[ "${BASH_SOURCE[0]}" != "${0}" ]] ; then
  err=0;
  << Setup portion of engine, check env variables, ... Returns error code which will be checked in entrypoint >>
  return $err;
fi;

######################################################################

log $identifier "Running..."

<< Backup portion of engine, this part is run through cron >>

```
