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
		ssh $HMCuser@$hmcServer "lslparutil -r lpar -m $managedServer -h 1 -F time,sys_time,lpar_name,entitled_cycles,capped_cycles,uncapped_cycles,curr_proc_mode,curr_sharing_mode,curr_uncap_weight,curr_shared_proc_pool_name,mem_mode,curr_mem,curr_procs,curr_proc_units --filter \"event_types=sample\"" | awk -v managedServer="$managedServer" -F "," '{ OFS=FS; cmd="date -d\"" $1 "\" +%s"; cmd | getline $1; close(cmd) ; print "lslparutil,managedSystem="managedServer",lpar_name="$3",curr_proc_mode="$7",curr_sharing_mode="$8",curr_uncap_weight="$9",curr_shared_proc_pool_name="$10",mem_mode="$11" curr_mem="$12",curr_procs="$13",curr_proc_units="$14",entitled_cycles="$4",capped_cycles="$5",uncapped_cycles="$6" "$1"000000000"}' >/tmp/$hmcServer.$managedServer.lslparutil.out

		ssh $HMCuser@$hmcServer "lslparutil -r procpool -m $managedServer -h 1 -F time,sys_time,time_cycles,shared_proc_pool_name,total_pool_cycles,utilized_pool_cycles --filter \"event_types=sample\"" | awk -v managedServer="$managedServer" -F "," '{ OFS=FS; cmd="date -d\"" $1 "\" +%s"; cmd | getline $1; close(cmd) ; print "lslparutil,managedSystem="managedServer",resource_type=procpool,shared_proc_pool_name="$4" time_cycles="$3",total_pool_cycles="$5",utilized_pool_cycles="$6" "$1"000000000"}' >>/tmp/$hmcServer.$managedServer.lslparutil.out

		curl --data-binary "@/tmp/$hmcServer.$managedServer.lslparutil.out" -X POST "http://localhost:8086/write?db=hmc&u=root&p=root"
		
	done
done
