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
		ssh $HMCuser@$hmcServer "lssyscfg -r lpar -m $managedServer" >/tmp/$hmcServer.$managedServer.lssyscfg.tmp
		ssh $HMCuser@$hmcServer "lslparutil -m $managedServer -r all -h 1 " >/tmp/$hmcServer.$managedServer.lslparutil.tmp
	done
done
echo "Done retrieving data."
echo "Now importing in InfluxDB"


for hmcServer in "${hmcArray[@]}"; do
        listManaged=$(ssh $HMCuser@$hmcServer "lssyscfg -r sys -F name")
        echo "Process Managed Server on HMC $hmcServer"
        for managedServer in $listManaged; do
                echo "Processing : $managedServer"
(	
	cat /tmp/$hmcServer.$managedServer.lslparutil.tmp | while read line; do
        	outputline="lslparutil"
        	tags=",managedSystem=$managedServer,hmc=$hmcServer"
        	metrics=""
        	timestamp=""
        	entitled_cycles=0
        	capped_cycles=0
        	uncapped_cycles=0
        	#echo $line
        	IFS="," read -r -a array <<< "$line"
        	for entry in "${array[@]}"; do
                	index=$(echo $entry | cut -d\= -f1)
                	element=$(echo $entry | cut -d\= -f2)
                	if [ "$index"x = "time"x ]; then
                        	#echo $index=$(date --date="$element" +%s)
                        	timestamp=$(date --date="$element" +%s)000000000
                	elif [ "$index"x = "sys_time"x ]; then
                        	#echo $index=$(date --date="$element" +%s)
                        	tags=$tags,$index=$(date --date="$element" +%s)000000000
                	elif [ "$(echo "$index" | grep -i cycle)"x = "x" ]; then
                        	tags=$tags,$index=$element
                	else

                        	if [ "$metrics"x = "x" ]; then
                                	metrics=$index=$element
                        	else
                                	metrics=$metrics,$index=$element
                        	fi
                	fi
        	done
        	outputline="$outputline$tags $metrics ${timestamp}"
		echo $outputline
		done >/tmp/$hmcServer.$managedServer.lslparutil.out
		wc -l /tmp/$hmcServer.$managedServer.lslparutil.out
		echo curl --data-binary "@/tmp/$hmcServer.$managedServer.lslparutil.out" -X POST "http://localhost:8086/write?db=hmc&u=root&p=root"
		curl --data-binary "@/tmp/$hmcServer.$managedServer.lslparutil.out" -X POST "http://localhost:8086/write?db=hmc&u=root&p=root"
) &		 
		#rm /tmp/$hmcServer.$managedServer.lslparutil.out
		#rm /tmp/$hmcServer.$managedServer.lslparutil.tmp

	done
done
wait

