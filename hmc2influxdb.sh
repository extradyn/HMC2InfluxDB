#!/bin/bash
. config.cfg


>/tmp/HMC2InfluxDB.data

echo "Get Managed Systems List"
hmcList=$(echo $HMCserver | cut -d\= -f2)
IFS="," read -r -a hmcArray <<< "$hmcList"
for hmcServer in "${hmcArray[@]}"; do
	listManaged=$(ssh $HMCuser@$hmcServer "lssyscfg -r sys -F name")
	echo "Process Managed Server on HMC $hmcServer"
	for managedServer in $listManaged; do
		echo "Processing : $managedServer"
		ssh $HMCuser@$hmcServer "lslparutil -r lpar -m $managedServer -h 1 -F time,sys_time,lpar_name,entitled_cycles,capped_cycles,uncapped_cycles --filter \"event_types=sample\"" | awk -v managedServer="$managedServer" -F "," '{ OFS=FS; cmd="date -d\"" $1 "\" +%s"; cmd | getline $1; close(cmd) ; print "lslparutil,managedSystem="managedServer",lpar_name="$3" entitled_cycles="$4",capped_cycles="$5",uncapped_cycles="$6" "$1"000000000"}' >/tmp/$hmcServer.$managedServer.lslparutil.out

		curl --data-binary "@/tmp/$hmcServer.$managedServer.lslparutil.out" -X POST "http://localhost:8086/write?db=hmc&u=root&p=root"
		
	done
done
