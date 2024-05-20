#!/usr/bin/env bash

set -ue
################################################################################
SKU=Standard_D2s_v3
VMIMAGE=Canonical:0001-com-ubuntu-server-focal:20_04-lts-gen2:20.04.202404080

VPNRG=nettovpn2
VPNVNET=nettovpn2vnet1
ADMINUSER=azureuser

REGION=eastus
CLOUDINITFILE="cloud-init-$$.yml"
# AUTOMATIONSCRIPT="https://raw.githubusercontent.com/marconetto/testbed/main/hello.sh"
AUTOMATIONSCRIPT="https://raw.githubusercontent.com/marconetto/proj-atlantis1/main/singlevm/ubuntu_atlantisvm_install.sh"
#################################################################################
create_resource_group() {

  az group create --location "$REGION" \
    --name "$RG"
}

create_cloud_init_file() {

  cat <<EOF >"$CLOUDINITFILE"
#cloud-config

EOF
}

append_script_exec_cloud_init_file() {

  numlines=$(wc -l <"$CLOUDINITFILE" | cut -d' ' -f1)
  if [ "$numlines" -eq 2 ]; then
    cat <<EOF >>"$CLOUDINITFILE"

runcmd:
EOF
  fi

  cat <<EOF >>"$CLOUDINITFILE"
    - echo "automation started at \$(date)" > /home/$ADMINUSER/automation_started
    - curl -o /tmp/automation.sh ${AUTOMATIONSCRIPT}
    - chmod +x /tmp/automation.sh
    - /tmp/automation.sh
    - echo "automation completed at \$(date)" > /home/$ADMINUSER/automation_done
    - chown $ADMINUSER:$ADMINUSER /home/$ADMINUSER/automation_*
EOF
}

append_disk_cloud_init_file() {

  cat <<EOF >>"$CLOUDINITFILE"
runcmd:
    - |
      alias apt-get='apt-get -o DPkg::Lock::Timeout=-1'
      DISK=\$(sudo lsblk -r --output NAME,MOUNTPOINT | awk -F \/ '/sd/ { dsk=substr(\$1,1,3);dsks[dsk]+=1 } END { for ( i in dsks ) { if (dsks[i]==1) print i } }')
      parted /dev/\$DISK --script mklabel gpt mkpart xfspart xfs 0% 100%
      partprobe /dev/\${DISK}1
      mkfs.xfs /dev/\${DISK}1
      mkdir /datadrive
      mount /dev/\${DISK}1 /datadrive
      chown -R $ADMINUSER:$ADMINUSER /datadrive
      sudo rsync -avzh /home/ /datadrive
      uid=\$(blkid | grep /dev/\${DISK}1 | awk '{print \$2}' | sed 's/"//g')
      echo "\$uid /home xfs defaults,nofail,discard 1 2" >> /etc/fstab
      mount /home
      umount /datadrive
EOF
}

create_vm() {

  set -x
  disksize=$1

  random_number=$((RANDOM % 9000 + 1000))

  VMNAME="vmatlantis_"${random_number}

  echo "Provisioning vm: $VMNAME"

  create_cloud_init_file

  disk_parameters=("")
  if [ "$disksize" -gt 0 ]; then
    append_disk_cloud_init_file
    disk_parameters="--data-disk-sizes-gb ${disksize}"
  fi

  append_script_exec_cloud_init_file

  cmd="az vm create -n $VMNAME \
    -g $RG \
    --image ${VMIMAGE} \
    --size ${SKU} \
    --vnet-name ${VMVNETNAME} \
    --subnet ${VMSUBNETNAME} \
    --security-type 'Standard' \
    --custom-data ${CLOUDINITFILE} \
    --admin-username ${ADMINUSER} \
    --admin-password "${VMPASSWORD}" \
    --generate-ssh-keys ${disk_parameters}"
  eval "$cmd"

  PRIVIP=$(az vm show -g "$RG" -n "$VMNAME" -d --query privateIps -otsv)
  PUBIP=$(az vm show -g "$RG" -n "$VMNAME" -d --query publicIps -otsv)
  echo "Private IP of $VMNAME: $PRIVIP"
  echo "Public IP of $VMNAME: $PUBIP"
  set +x
}

create_vnet_subnet() {

  az network vnet create -g "$RG" \
    -n "$VMVNETNAME" \
    --address-prefix "$VNETADDRESS"/16 \
    --subnet-name "$VMSUBNETNAME" \
    --subnet-prefixes "$VNETADDRESS"/24
}

peer_vpn() {

  echo "Pairing vpn network"

  curl https://raw.githubusercontent.com/marconetto/azadventures/main/chapter3/create_peering_vpn.sh -O

  vnetip="$VNETADDRESS"

  peername=$(az network vnet peering list --vnet-name "$VPNVNET" --resource-group "$VPNRG" | jq -r --arg vnetip "$vnetip" '.[] | select(.remoteAddressSpace.addressPrefixes[] | contains($vnetip)) | .name')

  if [ -z "$peername" ]; then
    echo "No peer found"
  else
    echo "Peer found: $peername. Deleting existing peering"
    az network vnet peering delete --name "$peername" --resource-group "$VPNRG" --vnet-name "$VPNVNET"
  fi

  bash ./create_peering_vpn.sh "$VPNRG" "$VPNVNET" "$RG" "$VMVNETNAME"
}

return_typed_password() {

  set +u
  appendtext=$1
  password=""
  echo -n ">> Enter VM admin password$appendtext: " >&2
  read -s password
  echo "$password"
}

get_password_manually() {

  while true; do
    password1=$(return_typed_password "")
    echo
    password2=$(return_typed_password "(confirm)")

    if [[ ${password1} != ${password2} ]]; then
      echo -e "\n>> Passwords do not match. Try again."
    else
      break
    fi
  done
  VMPASSWORD=$password1
  echo
}

usage() {
  echo "Usage: $0 -p <env|vm> -r <resourcegroup> -v <vnet> -s <subnet> [ -d <disksize> ] [ -a <ipaddress> ]"
  echo "  -p <env|vm>         Provision environment (env) or VM (vm)"
  echo "  -r <resourcegroup>  Specify resource group"
  echo "  -v <vnet>           Specify virtual network"
  echo "  -s <subnet>         Specify subnet"
  echo "  -d <disksize>       Specify disk size in GB (optional)"
  echo "  -a <ipaddress>      Specify ip address for vnet (e.g. 10.51.0.1)"
  exit
}

parse_arguments() {
  while getopts ":p:r:v:s:d:a:" opt; do
    case ${opt} in
    p)
      option_p=$OPTARG
      ;;
    r)
      option_r=$OPTARG
      ;;
    v)
      option_vnet=$OPTARG
      ;;
    s)
      option_subnet=$OPTARG
      ;;
    d)
      option_d=$OPTARG
      ;;
    a)
      option_a=$OPTARG
      ;;

    \?)
      echo "Invalid option: $OPTARG" 1>&2
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." 1>&2
      usage
      ;;
    esac
  done
  shift $((OPTIND - 1))

  if [ "$option_p" != "env" ] && [ "$option_p" != "vm" ]; then
    echo "Invalid option for -p. Must be 'env' or 'vm'"
    usage
  fi

  if [ "$option_p" == "env" ] && [ -z "${option_a+x}" ]; then
    echo "Missing option -a when provisioning (env)ironment"
    usage
  fi
}
##############################################################################
# MAIN
##############################################################################
parse_arguments "$@"

if [[ -z ${option_p+x} || -z ${option_r+x} || -z ${option_vnet+x} || -z ${option_subnet+x} ]]; then
  echo "Missing required options."
  usage
fi

disksize=${option_d:-0}
provision=$option_p
RG=$option_r
VMVNETNAME=$option_vnet
VMSUBNETNAME=$option_subnet
VNETADDRESS=${option_a:-""}

get_password_manually

if [ "$provision" == "env" ]; then
  echo "Provisioning environment"
  create_resource_group
  create_vnet_subnet
  # peer_vpn
fi

create_vm "$disksize"

rm -f "$CLOUDINITFILE"
