#!/bin/bash

# Copyright 2013 National Institute of Informatics.
#
#    Licensed under the Apache License, Version 2.0 (the "License"); you may
#    not use this file except in compliance with the License. You may obtain
#    a copy of the License at
#
#         http://www.apache.org/licenses/LICENSE-2.0
#
#    Unless required by applicable law or agreed to in writing, software
#    distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
#    WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
#    License for the specific language governing permissions and limitations
#    under the License.

PARTED=`which parted`
SMARTCTL=`which smartctl`
GREP=`which grep`
DD=`which dd`
RM=`which rm`
MKDIR=`which mkdir`
MOUNT=`which mount`
UMOUNT=`which umount`
RSYNC=`which rsync`
SED=`which sed`
WC=`which wc`

logfile="/etc/dodai-compute-os-duper.log"
logterm="/dev/tty2"

function logging {
  RETVAL=$?
  [[ -n "$1" ]] && \
    echo $1 > $logterm && \
    echo $1 >> $logfile
  while read line; do
    [[ -n "$line" ]] && \
      echo $line > $logterm && \
      echo $line >> $logfile
  done
  return $RETVAL
}

function err_check {
  RETVAL=0
  [[ 0 -ne $1 ]] && \
    logging "ERROR: $2(): $3" && \
    RETVAL=1
  return $RETVAL
}

function except {
  logging "FAIL: $1"
  [[ -e "$agent_config/dodai.json" ]] && \
    $SED -i -e 's/deleting/delete failed/' "$agent_config/dodai.json"
  exit 1
}

function env_check {
  RETVAL=0
  [[ -z "$PARTED" ]] && \
    logging "parted: command not found" && \
    RETVAL=1
  [[ -z "$SMARTCTL" ]] && \
    logging "smartctl: command not found" && \
    RETVAL=1
  [[ -z "$GREP" ]] && \
    logging "grep: command not found" && \
    RETVAL=1
  [[ -z "$DD" ]] && \
    logging "dd: command not found" && \
    RETVAL=1
  [[ -z "$RM" ]] && \
    logging "rm: command not found" && \
    RETVAL=1
  [[ -z "$MKDIR" ]] && \
    logging "mkdir: command not found" && \
    RETVAL=1
  [[ -z "$MOUNT" ]] && \
    logging "mount: command not found" && \
    RETVAL=1
  [[ -z "$UMOUNT" ]] && \
    logging "umount: command not found" && \
    RETVAL=1
  [[ -z "$RSYNC" ]] && \
    logging "rsync: command not found" && \
    RETVAL=1
  [[ -z "$SED" ]] && \
    logging "sed: command not found" && \
    RETVAL=1
  [[ -z "$WC" ]] && \
    logging "wc: command not found" && \
    RETVAL=1

  [[ 0 -eq $( $GREP sda /proc/partitions | $WC -l ) ]] && \
    logging "disk /dev/sda not found" && \
    RETVAL=1
  return $RETVAL
}

function disk_delete {
  echo "Starting disk delete"
  $DD if=/dev/zero of=/dev/sda |& logging
  err_check "$?" "$FUNCNAME" "$DD if=/dev/zero of=/dev/sda" || return 1
}

function health_check {
  echo "Start health check"
  $SMARTCTL -l error /dev/sda |& logging
  err_check "$?" "$FUNCNAME" "$SMARTCTL -l error /dev/sda" || return 1
}

function create_json {
  nic=`ifconfig -a | grep -i ${prov_mac_address} | awk '{print $1}'` |& logging
  err_check "$?" "$FUNCNAME" "ifconfig -a | grep -i ${prov_mac_address} | awk '{print $1}'" || return 1
  dodai='{"bind_port":"'$agent_bind_port'","state":"deleting","interfaces":[{"name":"'$nic'","mac_address":"'$prov_mac_address'","ip_addresses":["'$prov_ip_address'"],"subnet":"'$prov_subnet'","role":"system"}]}'
  $MKDIR -p $agent_config
  echo $dodai > "$agent_config/dodai.json" |& logging
  err_check "$?" "$FUCNAME" "$CAT $dodai > $agent_config/dodai.json" || return 1

  if [ 1 -eq `uname -a | grep -i ubuntu | wc -l` ]; then
    name='ubuntu'
    case `uname -r` in
      "2.6.32"*) version="10.04" ;;
      "2.6.35"*) version="10.10" ;;
      "2.6.38"*) version="11.04" ;;
      "3.0."*) version="11.10" ;;
      "3.2."*) version="12.04" ;;
      "3.5."*) version="12.10" ;;
      "3.8."*) version="13.04" ;;
    esac
  else
    echo "Not found os name and version"
    name="ubuntu"
    version="12.04"
  fi
  echo "uninstall OS:$name version:$version"

  rsync_uri="$injection_scripts_path/linux/$name/$version/"
  $RSYNC -HSa $rsync_uri/mnt/ /mnt/ |& logging
  err_check "$?" "$FUNCNAME" "$RSYNC -PHSa $rsync_uri/mnt/ /mnt/" || return 1

  cd  /mnt/.dodai/
  source .bashrc
  cd /
  LD_LIBRARY_PATH=/lib:/mnt/.dodai/lib ruby /mnt/.dodai/bin/dodai-instance-agent.rb &

}

env_check || except "env_check"
create_json || except "create_json"
disk_delete || except "disk_delete"
health_check || except "health_check"

$SED -i -e 's/deleting/delete complete/' "$agent_config/dodai.json"
echo "Initialization finished."
