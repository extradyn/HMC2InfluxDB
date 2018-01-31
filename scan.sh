#!/bin/bash
. config.cfg
listManaged=$(ssh HMC "lssyscfg -r sys -F name")
for i in $listManaged; do
	lssyscfg -m $i
done

