#!/bin/bash
. config.cfg
echo "Get Managed Systems List"
listManaged=$(ssh $HMCuser@$HMCserver "lssyscfg -r sys -F name")
echo "Process Managed Systems"
for managedServer in $listManaged; do
    echo "Processing : $managedServer"
	ssh $HMCuser@$HMCserver "lssyscfg -r lpar -m $managedServer" >/tmp/$HMCserver.$managedServer.lssyscfg.tmp
	ssh $HMCuser@$HMCserver "lslparutil -m $managedServer -r all -h 2" >/tmp/$HMCserver.$managedServer.lslparutil.tmp
done
echo "Done"
