#!/bin/bash

#
# Helper script for creating a service principal
#

# Parse the parameters
subscriptionName=$1
servicePrincipalName=$2
servicePrincipalIdUri='http://'$2
servicePrincipalPwd=$3
skipLogin=$4

echo ''
echo '----------------------------------------'
echo 'Running with parameters:'
echo '----------------------------------------'
echo 'subscription = ' $subscriptionName
echo 'servicePrincipalName = ' $servicePrincipalName
echo 'servicePrincipalIdUri = ' $servicePrincipalIdUri


# Login and select the subscription
echo ''
echo '----------------------------------------'
echo 'Logging into Azure...'
echo '----------------------------------------'
echo ''

azure config mode arm
if [[ -z "$skipLogin" ]]; then
  azure login
fi

echo ''
echo '----------------------------------------'
echo 'Selecting Subscription / Account...'
echo '----------------------------------------'
echo ''

accountsJson=$(azure account list --json)
subId=$(echo $accountsJson | jq --raw-output --arg pSubName $subscriptionName '.[] | select(.name == $pSubName) | .id')
tenantId=$(echo $accountsJson | jq --raw-output --arg pSubName $subscriptionName '.[] | select(.name == $pSubName) | .tenantId')

azure account set $subId

echo 'Selected Subscription $subscriptionName with id=$subId and tenantId=$tenantId!'

echo ''
echo '----------------------------------------'
echo 'Creating service principal'
echo '----------------------------------------'

echo ''
echo 'Creating the app...'

azure ad app create --name "$servicePrincipalName" \
                    --home-page "$servicePrincipalIdUri" \
                    --identifier-uris "$servicePrincipalIdUri" \
                    --reply-urls "$servicePrincipalIdUri" \
                    --password $servicePrincipalPwd

if [ $? != "0" ]; then
    echo 'Failed creating the app in Azure AD... cancelling setup!'
    exit 10
fi

echo ''
echo 'Getting the created appId...'

# Had to do a sleep to make sure previous operations were completed on the backend...
sleep 20

# Execute Azure CLI with JSON response and feed into jq
createdAppJson=$(azure ad app show --identifierUri "$servicePrincipalIdUri" --json)
if [[ $? != "0" ]] || [[ $createdAppJson == "*No matching*" ]]; then
    echo 'Failed retrieving the app from Azure AD... cancelling setup!'
    exit 10
fi
echo $createdAppJson

createdAppId=$(echo $createdAppJson | jq --raw-output '.[0].appId')
if [ $? != "0" ]; then
    echo 'Failed parsing Azure CLI JSON response... cancelling setup!'
    exit 10
fi

echo ''
echo 'Creating a Service Principal on the App...'

# Had to do a sleep to make sure previous operations were completed on the backend...
sleep 20

# Create the actual SP on-top of the app with Azure CLI
azure ad sp create --applicationId "$createdAppId"
if [ $? != "0" ]; then
    echo 'Failed creating Service Principal on Azure AD App created earlier... cancelling setup!'
    exit 10
fi

echo ''
echo 'Getting the Service Principal Object Id...'

# Had to do a sleep to make sure previous operations were completed on the backend...
sleep 20

# Again, execute Azure CLI and then parse the response with JQ
createdSpJson=$(azure ad sp show --spn "$servicePrincipalIdUri" --json)
if [[ $? != "0" ]] || [[ $createdSpJson == "*No matching*" ]]; then
    echo 'Failed getting Service Principal from Azure AD... cancelling setup!'
    exit 10
fi 
echo $createdSpJson

createSpObjectId=$(echo $createdSpJson | jq --raw-output '.[0].objectId')
if [ $? != "0" ]; then
    echo 'Failed parsing Azure CLI JSON response... cancelling setup!'
    exit 10
fi

echo ''
echo 'Assigning Subscription Read permissions to the Service Principal...'

# Again the sleep to make sure the previous operations were completed on the backend...
sleep 20

# Finally perform the role assignment
azure role assignment create --objectId "$createSpObjectId" \
                                --roleName Reader \
                                --subscription "$subId" 
if [ $? != "0" ]; then
    echo 'Failed assigning roles to created service principal! You could still create the role assignment and continue from there...'
    exit 10
fi 

echo ''
echo '----------------------------------------'
echo 'Summary'
echo '----------------------------------------'
echo ''
echo 'Created the following App & Service Principal:'
echo 'App Name = '$servicePrincipalName
echo 'App ID URI = '$servicePrincipalIdUri
echo 'SP Object ID = '$createSpObjectId
echo 'SPN = '$servicePrincipalIdUri
echo ''
echo 'Update the following parameters in the armdeploy.parameters.json as follows:'
echo 'azureAdTenantId='$tenantId
echo 'azureAdAppId='$createdAppId
echo 'azureAdAppSecret=<<the password you have passed in>>'
echo ''
echo 'You can test the service principal as follows:'
echo "azure login --username $appId --service-principal --tenant $tenantId --password <<password passed in as parameter>>"
echo ''

exit 0