#!/usr/bin/env bash

set -ue
################################################################################
RG=nettonoaa20240514v1
FULL=False
SKU=Standard_D2s_v3
VMIMAGE=Canonical:0001-com-ubuntu-server-focal:20_04-lts-gen2:20.04.202404080

VNETADDRESS=10.56.0.0

VPNRG=nettovpn2
VPNVNET=nettovpn2vnet1
VMNAME=nettovm1

VMVNETNAME="$RG"VNET
VMSUBNETNAME="$RG"SUBNET
ADMINUSER=azureuser
DISKSIZE="100"

REGION=eastus
ADDDISK=False
CLOUDINITFILE="cloud-init-$$.yml"
# AUTOMATIONSCRIPT="https://raw.githubusercontent.com/marconetto/testbed/main/hello.sh"
AUTOMATIONSCRIPT="https://raw.githubusercontent.com/marconetto/proj-atlantis1/main/singlevm/ubuntu_atlantisvm_install.sh"
#################################################################################

function create_resource_group() {

  az group create --location "$REGION" \
    --name "$RG"
}

function append_script_exec_cloud_init_file() {

  if [ "$ADDDISK" == "False" ]; then
    cat <<EOF >>"$CLOUDINITFILE"

runcmd:
EOF
  fi

  cat <<EOF >>"$CLOUDINITFILE"
    - curl -o /tmp/automation.sh ${AUTOMATIONSCRIPT}
    - chmod +x /tmp/automation.sh
    - /tmp/automation.sh
EOF
}

function create_cloud_init_file() {

  cat <<EOF >"$CLOUDINITFILE"
#cloud-config

EOF
}

function append_disk_cloud_init_file() {

  cat <<EOF >"$CLOUDINITFILE"
runcmd:
    - sudo parted /dev/sdb --script mklabel gpt mkpart xfspart xfs 0% 100%
    - sudo partprobe /dev/sdb
    - sudo mkfs.xfs /dev/sdb1
    - sudo mkdir /datadrive
    - sudo mount /dev/sdb1 /datadrive
    - sudo chown -R azureuser:azureuser /datadrive
EOF
}

function create_vm() {

  random_number=$((RANDOM % 9000 + 1000))

  VMNAME="vmnetto_"${random_number}
  echo "creating $VMNAME"

  create_cloud_init_file

  disk_parameters=("")
  if [ "$ADDDISK" == "True" ]; then
    append_disk_cloud_init_file
    disk_parameters="--data-disk-sizes-gb ${DISKSIZE}"
  fi

  append_script_exec_cloud_init_file

  cmd="az vm create -n $VMNAME \
    -g $RG \
    --image ${VMIMAGE} \
    --size ${SKU} \
    --vnet-name ${VMVNETNAME} \
    --subnet ${VMSUBNETNAME} \
    --security-type 'Standard' \
    --public-ip-address '' \
    --custom-data ${CLOUDINITFILE} \
    --admin-username ${ADMINUSER} \
    --admin-password "${VMPASSWORD}" \
    --generate-ssh-keys ${disk_parameters}"
  eval "$cmd"

  PRIVIP=$(az vm show -g "$RG" -n "$VMNAME" -d --query privateIps -otsv)
  echo "Private IP of $VMNAME: $PRIVIP"
}

function create_vnet_subnet() {

  az network vnet create -g "$RG" \
    -n "$VMVNETNAME" \
    --address-prefix "$VNETADDRESS"/16 \
    --subnet-name "$VMSUBNETNAME" \
    --subnet-prefixes "$VNETADDRESS"/24
}

function peer_vpn() {

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

##############################################################################
# Support functions for acquiring user password and public ssh key
##############################################################################
function return_typed_password() {

  set +u
  password=""
  echo -n ">> Enter password: " >&2
  read -s password
  echo "$password"
}

function get_password_manually() {

  while true; do
    password1=$(return_typed_password)
    echo
    password2=$(return_typed_password)

    if [[ ${password1} != ${password2} ]]; then
      echo ">> Passwords do not match. Try again."
    else
      break
    fi
  done
  VMPASSWORD=$password1
  echo
}
##############################################################################
# MAIN
##############################################################################

if [ "$#" -ne 1 ]; then
  echo "Usage: $0 [full|vm]"
  exit 1
fi

if [ "$1" == "full" ]; then
  FULL=True
elif [ "$1" == "vm" ]; then
  FULL=False
else
  echo "Usage: $0 [full|vm]"
  exit 1
fi

get_password_manually

if [ "$FULL" == "True" ]; then
  create_resource_group
  create_vnet_subnet
  peer_vpn
fi

create_vm

# rm -f $CLOUDINITFILE
