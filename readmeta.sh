#!/bin/bash
# 
# Extracts Custom Metadata for the VM and saves it to a file in 
# ~/vmmetadatalist.json, ~/vmmetadatadetails.json and ~/vnetmetadata.json
# 

sudo mkdir /home/script
export HOME=/home/marioszp

#
# Install the pre-requisites using apt-get
#
sudo apt-get -y update
sudo apt-get -y install jq
sudo apt-get -y install nodejs-legacy
sudo apt-get -y install npm
sudo npm install -g azure-cli

#
# Set the parameters needed for this based on script-parameters
#
tenantId=$1
appId=$2
pwd=$3

#
# azure CLI log-in using service principal
#
azure telemetry --disable
azure config mode arm
azure login --username "$appId" --service-principal --tenant "$tenantId" --password "$pwd"

#
# Get the instance ID and crack it based on the guidance/doc due to big endian encoding
#
vmIdLine=$(sudo dmidecode | grep UUID)
echo "---- VMID ----"
echo $vmIdLine
vmId=${vmIdLine:6:37}
echo "---- VMID ----"
echo $vmId

# For the first 3 sections of the GUID, the hex codes need to be reversed
vmIdCorrectParts=${vmId:20}
vmIdPart1=${vmId:0:9}
vmIdPart2=${vmId:10:4}
vmIdPart3=${vmId:15:4}
vmId=${vmIdPart1:7:2}${vmIdPart1:5:2}${vmIdPart1:3:2}${vmIdPart1:1:2}-${vmIdPart2:2:2}${vmIdPart2:0:2}-${vmIdPart3:2:2}${vmIdPart3:0:2}-$vmIdCorrectParts
vmId=${vmId,,}
echo "---- VMID fixed ----"
echo $vmId

#
# Now that we have the correct vmId, get the high-level details of the VM
#
vmJson=$(azure vm list --json | jq --arg pVmId "$vmId" 'map(select(.vmId == $pVmId))')
echo $vmJson > /home/vmmetadatalist.json
echo "---- VM JSON ----"
echo $vmJson

vmResGroup=$(echo $vmJson | jq -r '.[0].resourceGroupName')
vmName=$(echo $vmJson | jq -r '.[0].name')
vmDetailedJson=$(azure vm show --json -n "$vmName" -g "$vmResGroup")
echo $vmDetailedJson > /home/script/vmmetadatadetails.json
echo "---- vm Detail JSON ---"
echo $vmDetailedJson

#
# Next get the networking details for the VM
#
vmNetworkResourceName=$(echo $vmJson | jq -r '.[0].networkProfile.networkInterfaces[0].id')
netJson=$(azure network nic list -g $vmResGroup --json | jq --arg pVmNetResName "$vmNetworkResourceName" '.[] | select(.id == $pVmNetResName)')
echo $netJson > /home/script/vmnetworkdetails.json
echo "---- Net JSON ----"
echo $netJson

#
# Note: this can go on and on with any other kinds of resources...
#
netIpConfigsForVm=$(echo $netJson | jq '{ "ipCfgs": .ipConfigurations }')
echo $netIpConfigsFromVm > /home/vmipconfigs.json
netIpPublicResourceName=$(echo $netJson | jq -r '.ipConfigurations[0].publicIPAddress.id')
netIpPublicJson=$(azure network public-ip list -g $vmResGroup  --json | jq --arg ipid $netIpPublicResourceName '.[] | select(.id == $ipid)')
echo $netIpPublicJson > /home/script/vmipconfigspublicip.json
echo "---- Net Public IP JSON ----"
echo $netIpPublicJson