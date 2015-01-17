#!/bin/bash

NODES_LIST=$HOME/.nodes-list.txt
CONFIG=$HOME/.tmp-config.txt
TMP_CHECK=$HOME/.tmp-check.txt
DEMO_IMG_ENV=/home/zhli/demo-squeeze-x64-base.env

printMessage() {
	echo " "
	echo "===== G5K configuration ====="
	echo "-j, --job-submit:"
	echo "    Set it to 'true' to submit a G5K job. Default setting is false."
	echo "-i, --job-id:"
	echo "    Please either enter the job ID or submit a new job."
	echo "-n, --n-number:"
	echo "    Number of wanted G5K nodes (3 nodes as minimum)."
	echo "-r, --run-time:"
	echo "    Job runing time (unit is hour, 2 hours is default)."
	echo "-d, --deploy:"
	echo "    Set it to 'true' to deploy working environment. Default setting is false."
        echo "-h, -?, --help:"
	echo "    Display this help message."
	echo " "
}

param_check(){

	 if [ "${submit}" == "true" ] && [ ${jobid} -gt 0 ]; then
        	echo "**ERROR: Submission is required with a given job ID."
		echo "**ERROR: Please either submit a new job or give an ID."
		exit 1
	fi
	if [ "${submit}" != "true" ] && [ ${jobid} -eq 0 ]; then
                echo "**ERROR: Submission is not required and job ID is not given."
                echo "**ERROR: Please either submit a new job or give an ID."
                exit 1
        fi

	case $fs in 
	"HDFS")
		echo "HDFS will be used."	
	;;

	"BSFS")
		echo "BSFS will be used."
	;;
	*)
		echo "${fs} does not exist. Please choose either BSFS or HDFS."
		exit 1
	;;
	esac		
}

job_submit(){

	curr_day=`date +%Y-%m-%d`
	curr_time=`date +%H:%M:%S`
	oarsub -r "${curr_day} ${curr_time}" -l nodes=${vnumber},walltime="${runtime}" -n "BlobSeer-demo" -t deploy 2>&1 | tee ${TMP_CHECK} &
	echo "Request has been sent, waiting ..."
	sleep 10
	job_start=`cat ${TMP_CHECK} | grep OK | wc -l`
	timer=0
	while [ ${job_start} -lt 1 ] 
	do
		postponed=`cat ${TMP_CHECK} | grep KO | wc -l`
		if [ ${postponed} -gt 0 ]; then
                        echo "No resource available on G5K, please try the demo later."
                        exit 0;
		fi
		sleep 10
		job_start=`cat ${TMP_CHECK} | grep Start | wc -l`
		timer=$((${timer} + 1))
		if [ ${timer} -gt 60 ]; then
			echo "No resource available on G5K, please try the demo later."
			exit 0;
		fi
	done

	echo " "
	echo "Submission accepted, wait another 2 mins."
	sleep 120
}

write_config(){

	if [ "${submit}" == "true" ]; then
        	echo "Retrieve job ID and register it in configuration file."
		cat ${TMP_CHECK} | grep OAR_JOB_ID | cut -d "=" -f 2 > ${CONFIG}
		cat ${CONFIG}
	else
		echo "Register job ID ${jobid} in configuration file."
		echo ${jobid} > ${CONFIG}
		cat ${CONFIG}
	fi
}

retrieve_nodes(){
        job_id=`cat $CONFIG`
	echo ${job_id}
        if [ -z $job_id ]; then
                echo "**ERROR: Job not found, please check configuration file $HOME/.tmp-config.txt"
                exit 1
        fi
        echo "Job id is $job_id"
        host_list=`oarstat -fj $job_id | grep "assigned_hostnames" | cut -d "=" -f 2`
        echo -e ${host_list//+/"\n"} > ${NODES_LIST}
        if [ -f ${NODES_LIST} ]; then
                echo "Temporary file to store available nodes is created."
        else
                echo "**ERROR: Cannot create the temporary file to store available nodes."
                exit 1
        fi
        if [ -z $host_list ]; then
                echo "**ERROR: Not nodes available."
                exit 1
        fi
        echo "Available nodes:"
        cat ${NODES_LIST}
}

deploy_nodes(){

	kadeploy3 -f ${NODES_LIST} -a ${DEMO_IMG_ENV} -k 2>&1 | tee ${TMP_CHECK} &

        suc_dep=`cat ${TMP_CHECK} | grep "Nodes correctly deployed on cluster" | wc -l`
        timer=0
        while [ ${suc_dep} -lt 1 ] 
        do
                sleep 10
                suc_dep=`cat ${TMP_CHECK} | grep "Nodes correctly deployed on cluster" | wc -l`
                timer=$((${timer} + 1))
                if [ ${timer} -gt 180 ]; then
                	echo "**ERROR: failed to deploy environment on nodes. Quit the program."
                	exit 1
                fi
        done
}

pre_config(){

	echo " "
	echo "SSH and network configuration on each node."
	while read NODE
        do
                rsh -n root@${NODE} "cp -r .ssh /home/demouser/; chown -R demouser /home/demouser/.ssh; chgrp -R demouser /home/demouser/.ssh"
		scp -r $HOME/.ssh/ demouser@${NODE}:
		rsh -n demouser@${NODE} "echo 'Host *' > .ssh/config"
		rsh -n demouser@${NODE} "echo '  StrictHostKeyChecking no' >> .ssh/config"
		rsh -n demouser@${NODE} "echo '  HashKnownHosts no' >> .ssh/config"
		rsh -n demouser@${NODE} "rm .ssh/known_hosts"
		scp ${NODES_LIST} demouser@${NODE}:
        done<${NODES_LIST}

}

args=$#
submit="false"
deploy="false"
jobid=0
runtime=0
vnumber=0
fs="BSFS"
mnumber=0
pnumber=0
snumber=0
vmanager=""
pmanager=""
dht=""
providers=""
r_nmanager=""

while [ $args -gt 0 ]
do
        case $1 in
        "--job-submit"|"-j")
                if [ "$2" == "true" ]; then
                        submit="true"
                        echo "Job submission is required."
                else
                        echo "Job exists, please offer job ID.";
                fi
                shift 2;
                args=$(( args-2 ))
        ;;              

        "--deploy"|"-d")
                if [ "$2" == "true" ]; then
                        deploy="true"
                        echo "Kadeploy is required."
                else
                        echo "Kadeploy is already done.";
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "--job-id"|"-i")
                if [ $2 -gt 0 ]; then
                        jobid=$2
                        echo "Job ID is set to ${jobid}."
		else
			echo "No job id provided, please submit a new job."
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--n-number"|"-n")
                if [ $2 -gt 0 ]; then
                        vnumber=$2
                        echo "Nodes number is set to ${vnumber}."
		else 
			vnumber=3
			echo "Nodes number is set to ${vnumber} by default."
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--run-time"|"-r")
                if [ $2 -gt 0 ]; then
                        runtime=$2
                        echo "Job runtime is set to ${runtime}."
                else
                        runtime=2
                        echo "Job runtime is set to ${runtime} by default."
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--file-system"|"-f")
                fs=$2
                echo "The required file system is ${fs}."
                shift 2;
                args=$(( args-2 ))
        ;;

        "--m-number"|"-m")
                if [ $2 -gt 0 ]; then
                        mnumber=$2
                        echo "Meta-data storage provider number is set to ${mnumber}."
		else
			mnumber=1
			echo "Meta-data storage provider number is set to ${mnumber} by default."
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--p-number"|"-p")
                if [ $2 -gt 0 ]; then
                        pnumber=$2
                        echo "Data storage provider number is set to ${pnumber}."
		else
			pnumber=1
			echo "Data storage provider number is set to ${pnumber} by default."
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "--s-number"|"-s")
                if [ $2 -gt 0 ]; then
                        snumber=$2
                        echo "Hadoop slave number is set to ${snumber}."
		else
			snumber=${vnumber}
			echo "Hadoop slave number is set to ${snumber} (number of VMs) by default."
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "--nmanager"|"-a")
                if [ $2 -gt 0 ]; then
                        r_nmanager=$2
                        echo "Namespace Manager is the ${r_nmanager}th node."
		else
			r_nmanager=1
			echo "Namespace Manager is set to the ${r_nmanager}th node by default."
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--test"|"-t")
                echo $2
                if [ "$2" == "true" ]; then
                        autotest="true"
                        echo "Automatic test is required."
                else
                        echo "Test will not be executed automatically.";
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "-h"|"-?"|"--help")
                printMessage
                exit 0;
        ;;
        *)
                echo "parameter $1 invalide : -h for help !";
                exit 1;
                ;;
        esac
done

echo " "
echo "***** Check input parameters *****"
param_check

if [ ${submit} == "true" ]; then
	echo "----------------------"
	echo "----- Submit job -----"
	echo "----------------------"
	job_submit
	echo " "
	echo "***** Write configuration file. *****"
	write_config		
        echo " "
        echo "***** Retrieve available nodes. *****"
	retrieve_nodes
        echo " "
        echo "***** Deploy environment on nodes. *****"
	deploy_nodes
        echo " "
        echo "***** Pre-configuration on nodes. *****"
	pre_config
else
	echo " "
        echo "***** Write configuration file. *****"
        write_config
        echo " "
        echo "***** Retrieve available nodes. *****"
        retrieve_nodes
	if [ ${deploy} == "true" ]; then
       		echo " "
        	echo "***** Deploy environment on nodes. *****"
	        deploy_nodes
	fi
        echo " "
        echo "***** Pre-configuration on nodes. *****"
        pre_config	
fi

echo " " 
echo "Wait for another 1 minutes to confirm that nodes are up."

sleep 60

echo " "
echo "Clean temporary files."
if [ -f ${TMP_CHECK} ]; then
        rm ${TMP_CHECK}
fi

exit 0
