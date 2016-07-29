#!/bin/bash

#
# Helper script for creating a service principal
#

# Parse the parameters
subscriptionName=$1
servicePrincipalName=$2
servicePrincipalIdUri='http://'$2
servicePrincipalPwd=$3

echo '----------------------------------------'
echo 'Running with parameters:'
echo 'subscription = ' $subscriptionName
echo 'servicePrincipalName = ' $servicePrincipalName
echo 'servicePrincipalIdUri = ' $servicePrincipalIdUri
echo '----------------------------------------'


# Login and select the subscription
echo ''
echo '----------------------------------------'
echo 'Logging into Azure...'
echo '----------------------------------------'

azure config mode arm
azure login

echo ''
echo '----------------------------------------'
echo 'Selecting Subscription / Account...'
echo '----------------------------------------'

accountsJson=$(azure account list --json)
subId=$(echo $accountsJson | jq --raw-output --arg pSubName $subscriptionName '.[] | select(.name == $pSubName) | .id')
tenantId=$(echo $accountsJson | jq --raw-output --arg pSubName $subscriptionName '.[] | select(.name == $pSubName) | .tenantId')

azure account set $subId

echo 'Selected Subscription $subscriptionName with id=$subId and tenantId=$tenantId!'

echo ''
echo '----------------------------------------'
echo 'Creating service principal'
echo '----------------------------------------'

echo 'Creating the app...'

azure ad app create --name "$servicePrincipalName" \
                    --home-page "$servicePrincipalIdUri" \
                    --identifier-uris "$servicePrincipalIdUri" \
                    --password $servicePrincipalPwd

if [ $? = "0" ]; then

    echo ''
    echo 'Getting the created appId...'

    createdAppJson=$(azure ad app show --identifierUri $servicePrincipalIdUri --json)
    echo $createdAppJson
    createdAppId=$(echo $createdAppJson | jq --raw-output '.[0].appId')

    if [ $? = "0" ]; then

        echo 'Creating a Service Principal on the App...'
        azure ad sp create $createdAppId

        if [ $? = "0" ]; then

            echo 'Getting the Service Principal Object Id...'

            createdSpJson=$(azure ad sp show --spn $servicePrincipalIdUri --json)
            echo $createdSpJson
            createSpObjectId=$(echo $createdSpJson | jq --raw-output '.[0].objectId')

            echo 'Assigning Subscription Read permissions to the Service Principal...'

            azure role assignment create --objectId $createSpObjectId \
                                         --roleName Reader \
                                         --subscription $subId 

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

        else 

            echo ''
            echo 'ERROR'
            echo 'Failed creating the service principal on the app... cancelling service principal setup...'

        fi

    else

            echo ''
            echo 'ERROR'
                    echo 'Failed creating the service principal - cancelling service principal setup...'
    fi

else

    echo ''
    echo 'ERROR'
    echo 'Failed creating the app - cancelling service principal setup...'

fi