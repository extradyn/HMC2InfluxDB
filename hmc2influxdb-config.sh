#!/bin/bash
. config.cfg

echo "Get Managed Systems List"
hmcList=$(echo $HMCserver | cut -d\= -f2)
IFS="," read -r -a hmcArray <<< "$hmcList"
for hmcServer in "${hmcArray[@]}"; do
	listManaged=$(ssh $HMCuser@$hmcServer "lssyscfg -r sys -F name")
	echo "Process Managed Server on HMC $hmcServer"
	for managedServer in $listManaged; do
		echo "Processing : $managedServer"
		ssh $HMCuser@$hmcServer "lssyscfg -r lpar -m $managedServer -F lpar_id,name,lpar_env,state,os_version,logical_serial_num,default_profile,curr_profile,rmc_state,rmc_ipaddr,lpar_avail_priority,desired_lpar_proc_compat_mode,curr_lpar_proc_compat_mode" | tr ' ' '_' | awk -v managedServer="$managedServer" -F "," '{ OFS=FS;  print "lssyscfg,managedSystem="managedServer",lpar_id="$1",lpar_name="$2",lpar_env="$3",state="$4",os_version="$5",logical_serial_num="$6",default_profile=_"$7",curr_profile="$8",rmc_state="$9",rmc_ipaddr=ip_"$10",lpar_avail_priority="$11",desired_lpar_proc_compat_mode="$12",curr_lpar_proc_compat_mode="$13" found=1"}' >/tmp/$hmcServer.$managedServer.lssyscfg.out
		curl --data-binary "@/tmp/$hmcServer.$managedServer.lssyscfg.out" -X POST "http://localhost:8086/write?db=hmc&u=root&p=root"
		
	done
done
