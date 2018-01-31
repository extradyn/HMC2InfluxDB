#!/bin/bash
. config.cfg
listManaged=$(ssh $HMCuser@$HMCserver "lssyscfg -r sys -F name")
for i in $listManaged; do
	ssh $HMCuser@$HMCserver "lssyscfg -m $i"
done

