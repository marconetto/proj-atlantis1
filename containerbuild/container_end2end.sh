RG=netto240607v4
ACR="$RG"acr
REGION=eastus
APPNAME=myapp
ACRIDENTITY="$ACR"id

VNETADDRESS=10.23.0.0
VNETNAME="$RG"VNET
VSUBNETNAME="$RG"SUBNET
DNSZONENAME="privatelink.azurecr.io"
ACRSUBNETNAME="$RG"ACRSUBNET
IPFILES=myips.txt

set -x

get_random_code() {

  random_number=$((RANDOM % 9000 + 1000))
  echo "$random_number"
}

create_resource_group() {
  az group create --name "$RG" --location "$REGION"
}

create_acr() {

  az acr create --resource-group "$RG" \
    --name "$ACR" \
    --sku Premium \
    --admin-enabled false \
    --public-network-enabled false \
    --allow-trusted-services true

}

create_useridentity() {
  az identity create --resource-group $RG --name "$ACRIDENTITY"
}

enable_ips() {
  public_ip=$(curl -s -4 ifconfig.co)
  az acr network-rule add --resource-group $RG --name $ACR --ip-address "$public_ip"

  if [ -f "$IPFILES" ]; then
    while IFS= read -r line; do
      az acr network-rule add --resource-group $RG --name $ACR --ip-address "$line"
    done <"$IPFILES"
  fi
}

login_acr() {

  az acr network-rule list --resource-group $RG --name $ACR
  az acr login --name "$ACR"
}

assign_identity_acr() {

  userid=$(az identity show --resource-group "$RG" --name "$ACRIDENTITY" --query id --output tsv)

  spid=$(az identity show --resource-group "$RG" --name "$ACRIDENTITY" --query principalId --output tsv)

  acrid=$(az acr show -n "$ACR" -g "$RG" --query "id" -o tsv)

  az acr identity assign \
    --name "$ACR" \
    --resource-group "$RG" \
    --identities "$userid"

  az role assignment create \
    --assignee "$spid" \
    --role AcrPull \
    --scope "$acrid"
}

push_image() {
  acrserver=$(az acr show --name "$ACR" --query loginServer --output tsv)
  docker tag "$APPNAME" "$acrserver"/"$APPNAME":latest
  docker push "$acrserver"/"$APPNAME":latest
}

increament_ip() {
  local ip=$1
  local increament=$2
  IFS='.' read -r -a octets <<<"$ip"
  octets[2]=$((${octets[2]} + $increament))
  new_ip="${octets[0]}.${octets[1]}.${octets[2]}.${octets[3]}"
  echo "$new_ip"
}

create_vnet_subnet() {

  subnet1="$(increament_ip "$VNETADDRESS" 1)/24"
  subnet2="$(increament_ip "$VNETADDRESS" 2)/24"

  az network vnet create -g "$RG" \
    -n "$VNETNAME" \
    --address-prefix "$VNETADDRESS"/16 \
    --subnet-name "$VSUBNETNAME" \
    --subnet-prefixes "$subnet1"

  az network vnet subnet create --name "$ACRSUBNETNAME" --resource-group "$RG" --vnet-name "$VNETNAME" --address-prefixes "$subnet2"
}

get_subnetid() {

  subnetid=$(az network vnet subnet show \
    --resource-group "$RG" --vnet-name "$VNETNAME" \
    --name "$VSUBNETNAME" \
    --query "id" -o tsv)

  echo "$subnetid"
}

create_acr_endpoint() {

  acr_id=$(az acr show -n "$ACR" -g "$RG" --query "id" -o tsv)
  subnetid=$(get_subnetid)
  vnetid=$(az network vnet show \
    --resource-group "$RG" \
    --name "$VNETNAME" \
    --query "id" -o tsv)

  endpointname="acr-privendpoint"
  endpoint=$(az network private-endpoint create \
    --resource-group $RG --name $endpointname \
    --location $REGION \
    --subnet "$subnetid" \
    --private-connection-resource-id "${acr_id}" \
    --group-id "registry" \
    --connection-name "acr-connection" \
    --query "id" -o tsv)

  dns_zone=$(az network private-dns zone create \
    --resource-group "$RG" \
    --name "$DNSZONENAME" \
    --query "id" -o tsv)

  az network private-dns link vnet create \
    --resource-group "$RG" \
    --zone-name "$DNSZONENAME" \
    --name "acr-DnsLink" \
    --virtual-network "$vnetid" \
    --registration-enabled false

  az network private-endpoint dns-zone-group create \
    --resource-group "$RG" \
    --endpoint-name "$endpointname" \
    --name myzonegroup \
    --private-dns-zone "$DNSZONENAME" \
    --zone-name "$DNSZONENAME"
}

create_container() {
  acrserver=$(az acr show --name "$ACR" --query loginServer --output tsv)
  acridentity=$(az identity show --resource-group "$RG" --name "$ACRIDENTITY" --query id --output tsv)
  subnetid=$(get_subnetid)

  containername=container$(get_random_code)

  az container create --name "$containername" \
    --resource-group "$RG" \
    --acr-identity "$acridentity" \
    --assign-identity "$acridentity" \
    --image "$acrserver"/"$APPNAME":latest \
    --subnet "$subnetid"

  az container list --output table
  az container logs -g $RG -n "$containername"

}

create_resource_group
create_acr
create_useridentity
assign_identity_acr
enable_ips
login_acr
create_vnet_subnet
create_acr_endpoint
push_image
create_container
