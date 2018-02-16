#!/bin/bash
. config.cfg
echo "Get Managed Systems List"
hmcList=$(echo $HMCserver | cut -d\= -f2)
IFS="," read -r -a hmcArray <<< "$hmcList"
curl --data-binary "q=DELETE FROM lssyscfg" -X POST "http://localhost:8086/query?db=hmc&u=root&p=root"
curl --data-binary "q=DELETE FROM lshwres" -X POST "http://localhost:8086/query?db=hmc&u=root&p=root"
for hmcServer in "${hmcArray[@]}"; do
	listManaged=$(ssh $HMCuser@$hmcServer "lssyscfg -r sys -F name")
	echo "Process Managed Server on HMC $hmcServer"
	for managedServer in $listManaged; do
		echo "Processing : $managedServer"
		ssh $HMCuser@$hmcServer "lssyscfg -r sys -m $managedServer -F name:type_model:serial_num:state:dynamic_platform_optimization_capable:lpar_proc_compat_modes" | IFS=":" awk -F ":" '{print "lssyscfg,type=sys,managedSystem="$1",type_model="$2",serial_num="$3",state="$4",dpo="$5",lpar_proc_compat_modes=tbd found=1"}' >/tmp/$hmcServer.$managedServer.lssyscfg.out

		ssh $HMCuser@$hmcServer "lssyscfg -r lpar -m $managedServer -F lpar_id:name:lpar_env:state:os_version:logical_serial_num:default_profile:curr_profile:rmc_state:rmc_ipaddr:lpar_avail_priority:desired_lpar_proc_compat_mode:curr_lpar_proc_compat_mode" | tr ' ' '_' | IFS=":" awk -v managedServer="$managedServer" -F ":" '{ OFS=FS;  print "lssyscfg,managedSystem="managedServer",lpar_id="$1",lpar_name="$2",lpar_env="$3",state="$4",os_version="$5",logical_serial_num="$6",default_profile=_"$7",curr_profile="$8",rmc_state="$9",rmc_ipaddr=ip_"$10",lpar_avail_priority="$11",desired_lpar_proc_compat_mode="$12",curr_lpar_proc_compat_mode="$13" found=1"}' >>/tmp/$hmcServer.$managedServer.lssyscfg.out

		ssh $HMCuser@$hmcServer "lslparutil -r sys -m $managedServer -F resource_type,primary_state,configurable_sys_proc_units,configurable_sys_mem,curr_avail_sys_proc_units,curr_avail_sys_mem,sys_firmware_mem,proc_cycles_per_second" | awk -v managedServer="$managedServer" -F "," '{print "lslparutil,managedSystem="managedServer",resource_type="$1",primary_state="$2" configurable_sys_proc_units="$3",configurable_sys_mem="$4",curr_avail_sys_proc_units="$5",curr_avail_sys_mem="$6",sys_firmware_mem="$7",proc_cycles_per_second="$8}' >>/tmp/$hmcServer.$managedServer.lssyscfg.out

		echo lshwres,managedSystem=$managedServer,level=sys\ $(ssh $HMCuser@$hmcServer "lshwres -r proc -m $managedServer --level sys") >>/tmp/$hmcServer.$managedServer.lssyscfg.out
		ssh $HMCuser@$hmcServer "lshwres -r procpool -m $managedServer -F name:max_pool_proc_units:curr_reserved_pool_proc_units:pend_reserved_pool_proc_units:lpar_names"  | sed s/null/0/g | while read poolLine; do
			name=$(echo $poolLine | cut -d: -f1)
			max_pool_proc_units=$(echo $poolLine | cut -d: -f2)	
			curr_reserved_pool_proc_units=$(echo $poolLine | cut -d: -f3)
			pend_reserved_pool_proc_units=$(echo $poolLine | cut -d: -f4)
			lpar_names=$(echo $poolLine | cut -d: -f5)
			echo "lshwres,type=procpool,managedSystem=$managedServer,pool_name=$name max_pool_proc_units=$max_pool_proc_units,curr_reserved_pool_proc_units=$curr_reserved_pool_proc_units,pend_reserved_pool_proc_units=$pend_reserved_pool_proc_units" >>/tmp/$hmcServer.$managedServer.lssyscfg.out

			IFS="," 
			for lpar in $lpar_names; do
				echo "lshwres,type=procpool_assoc,managedSystem=$managedServer,pool_name=$name,lpar_name=$lpar active=1" >>/tmp/$hmcServer.$managedServer.lssyscfg.out
			done
			
		done

		curl --data-binary "@/tmp/$hmcServer.$managedServer.lssyscfg.out" -X POST "http://localhost:8086/write?db=hmc&u=root&p=root"
		#cat /tmp/$hmcServer.$managedServer.lssyscfg.out
		rm /tmp/$hmcServer.$managedServer.lssyscfg.out
		
	done
done
