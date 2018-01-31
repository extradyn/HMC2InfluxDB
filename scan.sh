#!/bin/bash
. config.cfg
listManaged=$(ssh $HMCuser@$HMCserver "lssyscfg -r sys -F name")
for managedServer in $listManaged; do
	ssh $HMCuser@$HMCserver "lssyscfg -r lpar -m $managedServer" >/tmp/$HMCserver.$managedServer.lssyscfg.tmp
	ssh $HMCuser@$HMCserver "lslparutil -m $managedServer -r all -h 2" >/tmp/$HMCserver.$managedServer.lslparutil.tmp
done

