#!/bin/sh

# fence-setup.sh - any fencing resource agent settings should go here.
#                  with baremetal you can enable a watchdog and skip the complexity

# Bring in the configuration parameters
source ./params.sh

echo "Turn on fencing. A watchdog timer is all you need for barmetal/KVM"
# Enable fencing, on baremetal or KVM we just use a watchdog timer
if [ $FENCING_TYPE = "baremetal" ]
then
   echo "Configuring fencing for a baremetal or Red Hat Virtualization cluster" 
   ssh root@$PRIMARY_SERVER  pcs property set stonith-watchdog-timeout=10s
   ssh root@$PRIMARY_SERVER pcs stonith sbd enable
elif [ $FENCING_TYPE = "azure" ]
then
   echo "Configuring fencing for Azure VM"  
   echo "Before proceeding be sure to follow Microsoft guidelines for creating a custom role for the fence agent in Azure" 
   ssh root@PRIMARY_SERVER pcs property set stonith-timeout=900
   ssh root@PRIMARY_SERVER pcs stonith create rsc_st_azure fence_azure_arm login="$AZURE_APPLICATION_ID" \
	   passwd="$AZURE_SP_PASSWORD" resourceGroup="$AZURE_RESOURCE_GROUP_NAME" tenantId="$AZURE_TENANT_ID" \
	   subscriptionId="$AZURE_SUBSCRIPTION_ID" power_timeout=240 pcmk_reboot_timeout=900
   ssh root@PRIMARY_SERVER pcs property set stonith-enabled=true
   
else
   echo "Unknown fencing type: $FENCING_TYPE" >&2
   exit 1
fi
echo "Restarting the cluster now"
ssh root@$PRIMARY_SERVER pcs cluster stop --all
ssh root@$PRIMARY_SERVER pcs cluster start --all
