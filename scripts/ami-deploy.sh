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
GREP=`which grep`
CUT=`which cut`
WC=`which wc`
EXPR=`which expr`
SLEEP=`which sleep`
MKDIR=`which mkdir`
MOUNT=`which mount`
WGET=`which wget`
RSYNC=`which rsync`
UMOUNT=`which umount`
RM=`which rm`
SED=`which sed`
CHMOD=`which chmod`
CHROOT=`which chroot`
NTPDATE=`which ntpdate`
HWCLOCK=`which hwclock`
CURL=`which curl`
RSYNC=`which rsync`
CAT=`which cat`
IP=`which ip`
PING=`which ping`

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
  exit 1
}

function env_check {
  RETVAL=0
  [[ -z "$PARTED" ]] && \
    logging "parted: command not found" && \
    RETVAL=1
  [[ -z "$GREP" ]] && \
    logging "grep: command not found" && \
    RETVAL=1
  [[ -z "$CUT" ]] && \
    logging "cut: command not found" && \
    RETVAL=1
  [[ -z "$WC" ]] && \
    logging "wc: command not found" && \
    RETVAL=1
  [[ -z "$EXPR" ]] && \
    logging "expr: command not found" && \
    RETVAL=1
  [[ -z "$SLEEP" ]] && \
    logging "sleep: command not found" && \
    RETVAL=1
  [[ -z "$MKDIR" ]] && \
    logging "mkdir: command not found" && \
    RETVAL=1
  [[ -z "$MOUNT" ]] && \
    logging "mount: command not found" && \
    RETVAL=1
  [[ -z "$WGET" ]] && \
    logging "wget: command not found" && \
    RETVAL=1
  [[ -z "$RSYNC" ]] && \
    logging "rsync: command not found" && \
    RETVAL=1
  [[ -z "$UMOUNT" ]] && \
    logging "umount: command not found" && \
    RETVAL=1
  [[ -z "$RM" ]] && \
    logging "rm: command not found" && \
    RETVAL=1
  [[ -z "$SED" ]] && \
    logging "sed: command not found" && \
    RETVAL=1
  [[ -z "$CHMOD" ]] && \
    logging "chmod: command not found" && \
    RETVAL=1
  [[ -z "$CHROOT" ]] && \
    logging "chroot: command not found" && \
    RETVAL=1
  [[ -z "$NTPDATE" ]] && \
    logging "ntpdate: command not found" && \
    RETVAL=1
  [[ -z "$HWCLOCK" ]] && \
    logging "hwclock: command not found" && \
    RETVAL=1
  [[ -z "$CURL" ]] && \
    logging "curl: command not found" && \
    RETVAL=1
  [[ -z "$RSYNC" ]] && \
    logging "rsync: command not found" && \
    RETVAL=1
  [[ -z "$CAT" ]] && \
    logging "cat: command not found" && \
    RETVAL=1
  [[ -z "$IP" ]] && \
    logging "ip: command not found" && \
    RETVAL=1

  [[ 0 -eq $( $GREP sda /proc/partitions | $WC -l ) ]] && \
    logging "disk /dev/sda not found" && \
    RETVAL=1
  return $RETVAL
}

function partition_and_format {
  $PARTED /dev/sda unit GB
  $PARTED -s /dev/sda mklabel gpt |& logging
  err_check "$?" "$FUNCNAME" "$PARTED -s /dev/sda mklabel gpt" || return 1

  for i in `seq 5`
  do
    $PARTED /dev/sda $RM $i |& logging
    err_check "$?" "$FUNCNAME" "$PARTED /dev/sda $RM $i" || return 1
  done

  total_size_mb=`$PARTED /dev/sda -s unit MB print | $GREP Disk | $CUT -f3 -d " " | $CUT -f1 -d "M"`

  sda2_end=$root_size
  sda3_end=`$EXPR $sda2_end + $swap_size`
  sda4_end=`$EXPR $sda3_end + $kdump_size`

  if [ $ephemeral_size -eq 0 ]; then
    sda5_end=`$EXPR $total_size_mb`
  else
    sda5_end=`$EXPR $sda4_end + $ephemeral_size`
  fi

  $PARTED -a minimal /dev/sda mkpart primary 0 5 |& logging
  err_check "$?" "$FUNCNAME" "$PARTED /dev/sda mkpart primary 0 5" || return 1
  $PARTED /dev/sda mkpart primary 5 $sda2_end |& logging
  err_check "$?" "$FUNCNAME" "$PARTED /dev/sda mkpart primary 5 $sda2_end" || return 1
  $PARTED /dev/sda mkpartfs primary linux-swap $sda2_end $sda3_end |& logging
  err_check "$?" "$FUNCNAME" "$PARTED /dev/sda mkpartfs primary linux-swap $sda2_end $sda3_end" || return 1
  $PARTED /dev/sda mkpart primary $sda3_end $sda4_end |& logging
  err_check "$?" "$FUNCNAME" "$PARTED /dev/sda mkpart primary $sda3_end $sda4_end" || return 1
  $PARTED /dev/sda mkpart primary $sda4_end $sda5_end |& logging
  err_check "$?" "$FUNCNAME" "$PARTED /dev/sda mkpart primary $sda4_end $sda5_end" || return 1
  $PARTED /dev/sda set 2 boot on 
  err_check "$?" "$FUNCNAME" "$PARTED /dev/sda set 2 boot on" || return 1
  $SLEEP 5

  MKFS="mkfs.ext3"
  $MKFS /dev/sda4
  err_check "$?" "$FUNCNAME" "$MKFS /dev/sda4" || return 1
  MKFS="mkfs."$root_fs_type
  $MKFS /dev/sda5 |& logging
  err_check "$?" "$FUNCNAME" "$MKFS /dev/sda5" || return 1
  $PARTED /dev/sda print
}

function fs_type_check {
  case "`echo $1 | tr '[A-Z]' '[a-z]'`" in
     *ext2* ) echo `which mkfs.ext2` ;;
     *ext3* ) echo `which mkfs.ext3` ;;
     *ext4* ) echo `which mkfs.ext4` ;;
     *btrfs* ) echo `which mkfs.btrfs` ;;
     *reiserfs* ) echo "`which mkfs.reiserfs` -q" ;;
     *jfs2* ) echo "`which mkfs.jfs` -q" ;;
     *xfs* ) echo `mkfs.xfs` ;;
     * ) echo `mkfs.ext3` ;;
  esac
}

function copy_fs {
  image_dev=sda4

  $MKDIR /mnt/$image_dev
  err_check "$?" "$FUNCNAME" "$MKDIR /mnt/$image_dev" || return 1
  $MOUNT /dev/$image_dev /mnt/$image_dev |& logging
  err_check "$?" "$FUNCNAME" "$MOUNT /dev/$image_dev /mnt/$image_dev" || return 1

  $WGET -O /mnt/$image_dev/image http://$cobbler/cobbler/images/$image_id |& logging
  err_check "$?" "$FUNCNAME" "$WGET -O /mnt/$image_dev/image http://$cobbler/cobbler/images/$image_id" || return 1
  $MKDIR /mnt/image
  err_check "$?" "$FUNCNAME" "$MKDIR /mnt/image" || return 1
  $MOUNT -o loop -t ext4 /mnt/$image_dev/image /mnt/image |& logging
  err_check "$?" "$FUNCNAME" "$MOUNT -o loop /mnt/$image_dev/image /mnt/image" || return 1

  fs_type=`file /mnt/$image_dev/image`
  MKFS=`fs_type_check "$fs_type"`

  $MKFS /dev/sda1 |& logging
  err_check "$?" "$FUNCNAME" "$MKFS /dev/sda1" || return 1
  $MKFS /dev/sda2 |& logging
  err_check "$?" "$FUNCNAME" "$MKFS /dev/sda2" || return 1

  $MKDIR /mnt/sda2 |& logging
  err_check "$?" "$FUNCNAME" "$MKDIR /mnt/sda2" || return 1
  $MOUNT /dev/sda2 /mnt/sda2 |& logging
  err_check "$?" "$FUNCNAME" "$MOUNT /dev/sda2 /mnt/sda2" || return 1

  $RSYNC -PavHS /mnt/image/ /mnt/sda2 |& logging
  err_check "$?" "$FUNCNAME" "$RSYNC -PavHS /mnt/image/ /mnt/sda2" || return 1

  fs_type=`$GREP '/mnt' /mnt/sda2/etc/fstab`
  MKFS=`fs_type_check "$fs_type"`

  $MKFS /dev/sda5 |& logging
  err_check "$?" "$FUNCNAME" "$MKFS /dev/sda5" || return 1

  $UMOUNT /mnt/image |& logging
  err_check "$?" "$FUNCNAME" "$UMOUNT /mnt/image" || return 1
  $RM -rf /mnt/$image_dev/image
  err_check "$?" "$FUNCNAME" "$RM -rf /mnt/$image_dev/image" || return 1
  $UMOUNT /mnt/$image_dev |& logging
  err_check "$?" "$FUNCNAME" "$UMOUNT /mnt/$image_dev" || return 1
}

function set_hostname {
  echo "$host_name" > /mnt/sda2/etc/hostname
  $SED -i -e "s/HOST/$host_name/" /mnt/sda2/etc/hosts |& logging
  err_check "$?" "$FUNCNAME" "$SED -i -e 's/HOST/$host_name/'" || return 1
}

function create_files {
  $MKDIR /mnt/sda2/etc/dodai

  echo $prov_ip_address > /mnt/sda2/etc/dodai/pxe_ip
  echo $prov_mac_address > /mnt/sda2/etc/dodai/pxe_mac
  echo $storage_ip > /mnt/sda2/etc/dodai/storage_ip
  echo $storage_mac > /mnt/sda2/etc/dodai/storage_mac

  $CHMOD +x /mnt/sda2/usr/local/src/dodai-deploy/others/auto_register_node/setup.sh |& logging
  err_check "$?" "$FUNCNAME" "$CHMOD +x /mnt/sda2/usr/local/src/dodai-deploy/others/auto_register_node/setup.sh" || return 1
  /mnt/sda2/usr/local/src/dodai-deploy/others/auto_register_node/setup.sh /mnt/sda2 $image_type |& logging
}

function grub_install {
  $MOUNT -o bind /dev/ /mnt/sda2/dev |& logging
  err_check "$?" "$FUNCNAME" "$MOUNT -o bind /dev/ /mnt/sda2/dev" || return 1
  $MOUNT -t proc none /mnt/sda2/proc |& logging
  err_check "$?" "$FUNCNAME" "$MOUNT -t proc none /mnt/sda2/proc" || return 1
  echo I | $CHROOT /mnt/sda2 $PARTED /dev/sda set 1 bios_grub on |& logging
  err_check "$?" "$FUNCNAME" "echo I | $CHROOT /mnt/sda2 $PARTED /dev/sda set 1 bios_grub on" || return 1
  $CHROOT /mnt/sda2 grub-install /dev/sda 
}

function setup_network {
  add_a_nic "eth0" $prov_ip_address "$prov_subnet"
  MATCHADDR="$prov_mac_address" INTERFACE="eth0" MATCHDEVID="0x0" MATCHIFTYPE="1"  $CHROOT /mnt/sda2 /lib/udev/write_net_rules |& logging
  err_check "$?" "$FUNCNAME" "/lib/udev/write_net_rules" || return 1

  add_interface=1
  for mac_address in `ifconfig -a | grep -i HWAddr | awk '{print $5}' | tr [A-Z] [a-z] | sort`
  do
    if [ $mac_address != $prov_mac_address ]; then
      MATCHADDR="$mac_address" INTERFACE="eth"$add_interface MATCHDEVID="0x0" MATCHIFTYPE="1"  $CHROOT /mnt/sda2 /lib/udev/write_net_rules |& logging
      err_check "$?" "$FUNCNAME" "eth$add_interface /lib/udev/write_net_rules" || return 1
      add_interface=`expr $add_interface + 1`
    fi
  done

}

function add_a_nic() {
echo "
auto $1
iface $1 inet static
         address $2
         netmask $3

" >> /mnt/sda2/etc/network/interfaces
}

function sync_time {
  $NTPDATE $cobbler |& logging
  err_check "$?" "$FUNCNAME" "$NTPDATE $cobbler" || return 1
  $HWCLOCK --systohc |& logging
  err_check "$?" "$FUNCNAME" "$HWCLOCK --systohc" || return 1
}

function sync_target_machine_time {
  $CHROOT /mnt/sda2 $NTPDATE $cobbler |& logging
  err_check "$?" "$FUNCNAME" "$CHROOT /mnt/sda2 $NTPDATE $cobbler" || return
}

function notify {
  $CURL http://$cobbler:$monitor_port/$instance_id/$1 |& logging
  err_check "$?" "$FUNCNAME" "$CURL http://$cobbler:$monitor_port/$instance_id/$1" || return 1
}

function rsync {
  rsync_cmd=$(echo "$ami_path" | cut -d'/' -f 1-3)

  MKFS="mkfs."$root_fs_type
  $MKFS /dev/sda2
  $MKDIR /mnt/sda2

  $MOUNT -t $root_fs_type /dev/sda2 /mnt/sda2 |& logging
  err_check "$?" "$FUNCNAME" "$MOUNT /dev/sda2 /mnt/sda2 |& logging" || return 1
  $RSYNC -HSa $ami_path /mnt/sda2/ |& logging
  err_check "$?" "$FUNCNAME" "$RSYNC -HSa $ami_path /mnt/sda2/" || return 1
}

function create_json {
  nic=`ifconfig -a | grep -i ${prov_mac_address} | awk '{print $1}'` |& logging
  err_check "$?" "$FUNCNAME" "ifconfig -a | grep -i ${prov_mac_address} | awk '{print $1}'" || return 1
  dodai='{"bind_port":"'$agent_bind_port'","state":"deploying","interfaces":[{"name":"'$nic'","mac_address":"'$prov_mac_address'","ip_addresses":["'$prov_ip_address'"],"subnet":"'$prov_subnet'","role":"system"}]}'
  $MKDIR -p $agent_config
  echo $dodai > "$agent_config/dodai.json" |& logging
  err_check "$?" "$FUCNAME" "$CAT $dodai > $agent_config/dodai.json" || return 1

  lsb_release="/mnt/sda2/etc/lsb-release"
  redhat_release="/mnt/sda2/etc/redhat-release"
  gentoo_release="/mnt/sda2/etc/gentoo-release"

  if [ -a $lsb_release ]; then
    name=`grep '^DISTRIB_ID=' $lsb_release | cut -d'=' -f2 | tr 'A-Z' 'a-z'`
    version=`grep '^DISTRIB_RELEASE=' $lsb_release | cut -d'=' -f2`
  elif [ -a $redhat_release ]; then 
    if [ 1 -eq `grep '^Red Hat Enterprise Linux' $redhat_release | wc -l` ]; then
      name='rhel'
      version=`sed -e "s|^Red Hat Enterprise Linux[^0-9]*\([0-9.]*\).*|\1|" $redhat_release`
    elif [ 1 -eq `grep '^CentOS release' $redhat_release | wc -l` ]; then
      name='centos'
      version=`sed -e "s|^CentOS release[^0-9]*\([0-9.]*\).*|\1|" $redhat_release`
    fi
  elif [ -a $gentoo_release ]; then
    if [ 1 -eq `grep '^Gentoo Base System release' $gentoo_release | wc -l` ]; then
      name='gentoo'
      version=`sed -e "s|^Gentoo Base System release[^0-9]*\([0-9.]*\).*|\1|" $gentoo_release`
    fi
  else
    echo "Not found os name and version"
    echo "Starting troubleshooting shell."
    bash
  fi
  echo "Install OS:$name version:$version"

  rsync_cmd=$(echo "$ami_path" | cut -d':' -f 1-2)":$agent_bind_subport/scripts/linux/$name/$version"
  $RSYNC -HSa $rsync_cmd/usr /mnt/sda2/ |& logging
  err_check "$?" "$FUNCNAME" "$RSYNC -PHSa $rsync_cmd/usr /mnt/sda2/" || return 1
  $RSYNC -HSa $rsync_cmd/mnt/ /mnt/ |& logging
  err_check "$?" "$FUNCNAME" "$RSYNC -PHSa $rsync_cmd/mnt/ /mnt/" || return 1

  cd  /mnt/.dodai/
  source .bashrc 
  cd /
  LD_LIBRARY_PATH=/lib:/mnt/.dodai/lib ruby /mnt/.dodai/bin/dodai-instance-agent.rb &
}

function file_umount {
  $UMOUNT /mnt/sda2/proc |& logging
  err_check "$?" "$FUNCNAME" "$UMOUNT /mnt/sda2/proc" || return 1
  $UMOUNT /mnt/sda2/dev |& logging
  err_check "$?" "$FUNCNAME" "$UMOUNT /mnt/sda2/dev" || return 1
  $UMOUNT /mnt/sda2 |& logging
  err_check "$?" "$FUNCNAME" "$UMOUNT /mnt/sda2" || return 1
}

#notify "install"
env_check || except "env_check"
#sync_time || except "sync_time"
partition_and_format || except "partition_and_format"
rsync || except "rsync"
create_json || except "create_json"
#copy_fs || except "copy_fs"
set_hostname || except "set_hostname"
#create_files || except "create_files"
grub_install || except "grub_install"
setup_network || except "setup_network"
#sync_target_machine_time || except "sync_target_machine_time"
file_umount || except "file_umount"

$SED -i -e 's/deploying/deploy complete/' "$agent_config/dodai.json"
echo "Initialization finished."
