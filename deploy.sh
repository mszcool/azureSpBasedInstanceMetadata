resgroup=$1
location=$2
deploymentname=$3
publicdnsname=$4
storageaccount=$5
adminuser=$6
adminpassword=$7
aadTenantId=$8
aadAppId=$9
aadAppSecret=$10

if [[ -z $resgroup ]] || [[ -z $location ]] || [[ -z $deploymentname ]] || \
   [[ -z $publicdnsname ]] || [[ -z $storageaccount ]] || [[ -z $adminuser ]] || \
   [[ -z $adminpassword ]] || [[ -z $aadTenantId ]] || [[ -z $aadAppId ]] || [[ -z aadAppSecret ]]; then

   echo 'Missing parameters'
   echo 'Usage: deploy.sh resourcegroupname azureregion deploymentname publicdnsname storageaccountname adminusername adminuserpassword aadTenantId aadAppId aadAppPassword'
   exit 10
fi 

#
# Prepare an ARM parameters file
#
cat azuredeploy.parameters.json \
| sed -e "s/--storageaccountname--/$storageaccount/" \
| sed -e "s/--adminusername--/$adminuser/" \
| sed -e "s/--password--/$adminpassword/" \
| sed -e "s/--azuread-tenantid--/$aadTenantId/" \
| sed -e "s/--azuread-appid--/$aadAppId/" \
| sed -e "s/--azuread-app-password--/$aadAppSecret/" \
| sed -e "s/--publicdnsname--/$publicdnsname/" \
| sed -e "s/--region--/$location/" \
| azuredeploy.real.parameters.json

#
# Create the resource group
#
azure group create --location "$location" "$resgroup"

#
# Create the storage account and get the keys for uploading the custom script
#

echo ''
echo 'Creating storage account...'
azure storage account create --location "$location" \
                             --resource-group "$resgroup" \
                             --sku-name "LRS" \
                             "$storageaccount"

echo ''
echo 'Getting Storage Account Keys...'
storageKey=$(azure storage account keys list --resource-group "$resgroup" "$storageaccount" --json | jq --raw-output '.[0].value')

echo ''
echo 'Creating container and uploading custom script...'
azure storage container create --account-name "$storageaccount" \
                               --account-key "$storageKey" \
                               --permission Blob \
                               "customscript"

azure storage blob upload --file "readmeta.sh" --blob "readmeta.sh" --container "customscript" \
                          --account-name "$storageaccount" --account-key "$storageKey"

#
# Create the actual deployment
#
echo ''
echo 'Starting deployment of VM...'
azure group deployment create --resource-group "$resgroup" \
                              --name "$deploymentname" \
                              --template-file azuredeploy.json \
                              --parameters-file azuredeploy.real.parameters.json

echo ''
echo '--------------------------------------------------'
echo 'Finished!!'
echo '--------------------------------------------------'