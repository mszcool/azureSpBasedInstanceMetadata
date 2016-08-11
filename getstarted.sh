#
# Script that reads all needed data from the end user and 
# executes the main script in order!
#

echo ''
echo '-----------------------------------------------'
echo 'Welcome to the little Instance-Metadata-Sample!'
echo '-----------------------------------------------'
echo ''

azure config mode arm
azure login

echo '**** 1 ****'
echo 'First we need to create the Service Principal:'
echo '**** 1 ****'

read -p "Subscription Name: " subscriptionName
read -p "Service Principal Name: " servicePrincipalName
read -p "Service Principal Password: " servicePrincipalPwd

echo ''
echo 'Launching Service Principal creation...'

./createsp.sh $subscriptionName $servicePrincipalName $servicePrincipalPwd skipLogin

echo ''
echo '**** 2 ****'
echo 'Now we create the actual VM and use it to read metadata from within the VM!'
echo '**** 2 ****'
read -p "Resource Group Name: " resGroupName
read -p "Region: " location
read -p "Deployment Name: " deploymentName
read -p "Public DNS Name: " publicDnsName
read -p "Storage Account Name: " storageAccountName
read -p "Root User Name: " rootUserName
read -p "Root User Password: " rootUserPwd

accountsJson=$(azure account list --json)
subId=$(echo $accountsJson | jq --raw-output --arg pSubName $subscriptionName '.[] | select(.name == $pSubName) | .id')
tenantId=$(echo $accountsJson | jq --raw-output --arg pSubName $subscriptionName '.[] | select(.name == $pSubName) | .tenantId')

appIdUri="http://$servicePrincipalName"
appJson=$(azure ad app show --identifierUri "$appIdUri" --json)
appId=$(echo $appJson | jq --raw-output '.[0].appId')

echo ''
echo 'Launch VM Creation script...'
./deploy.sh "$resGroupName" "$location" "$deploymentName" "$publicDnsName" "$storageAccountName" "$rootUserName" "$rootUserPwd" "$tenantId" "$appId" "$servicePrincipalPwd"  

echo ''
echo '**** Now SSH into the VM, here is the public IP: ****'
echo ''
azure network public-ip show --resource-group $resGroupName myPublicIP
echo ''