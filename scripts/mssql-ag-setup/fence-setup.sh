#!/bin/sh

# fence-setup.sh - any fencing resource agent settings should go here.
#                  with baremetal you can enable a watchdog and skip the complexity

source ./params.sh
source ./initvars.sh
source ./functions.sh

# Verify that we have a cluster in place to support RHEL HA Add-On
if [ $CLUSTER_TYPE != "EXTERNAL" ]
then
    echo "Cluster type is $CLUSTER_TYPE" >&2
    echo "Skipping RHEL HA Add-on configuration"
    exit 0
fi

echo "Turn on fencing. A watchdog timer is all you need for barmetal/KVM"
# Enable fencing, on baremetal or KVM we just use a watchdog timer
if [ $FENCING_TYPE = "baremetal" ]
then
    echo "Configuring fencing for a baremetal or Red Hat Virtualization cluster"
    runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" pcs property set stonith-watchdog-timeout=10s
    runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" pcs stonith sbd enable

elif [ $FENCING_TYPE = "vmware" ]
then
   echo "Configuring fencing for VMware/ESXi"
   runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" pcs stonith create vmfence fence_vmware_soap pcmk_host_map="$VMWARE_HOSTMAP" ipaddr="$VMWARE_IP_ADDRESS" ssl=1 login="$VMWARE_LOGIN" passwd="$VMWARE_PASSWORD"
    runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" pcs property set stonith-enabled=true

elif [ $FENCING_TYPE = "azure" ]
then
    echo "Configuring fencing for Azure VM"  
    echo "Before proceeding be sure to follow Microsoft guidelines for creating a custom role for the fence agent in Azure" 
    runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" pcs property set stonith-timeout= 900
    runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" pcs stonith create rsc_st_azure fence_azure_arm login="$AZURE_APPLICATION_ID" \
	   passwd="$AZURE_SP_PASSWORD" resourceGroup="$AZURE_RESOURCE_GROUP_NAME" tenantId="$AZURE_TENANT_ID" \
	   subscriptionId="$AZURE_SUBSCRIPTION_ID" power_timeout=240 pcmk_reboot_timeout=900
    runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" pcs property set stonith-enabled=true
   
else
   echo "Unknown fencing type: $FENCING_TYPE" >&2
   exit 1
fi
echo "Restarting the cluster now"
runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" pcs cluster stop --all
runsshcmd "$PRIMARY_SERVER" "${ALL_SERVERS_PASS[$PRIMARY_SERVER]}" pcs cluster start --all
