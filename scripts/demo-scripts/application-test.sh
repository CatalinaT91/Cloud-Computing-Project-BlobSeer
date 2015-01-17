#!/bin/bash

#local path
NODES_LIST=$HOME/.nodes-list.txt
CONFIG=$HOME/.tmp-config.txt
TMP_CHECK=$HOME/.tmp-check.txt
TMP_FS=$HOME/.tmp-fs.txt
DEMO_IMG_ENV=/home/zhli/demo-squeeze-x64-base.env
OUTPUT_PATH=$HOME/BlobSeer-Demo/logs
HISTORY_PATH=${OUTPUT_PATH}/histories

#remote path
BSFS_HOME="/home/demouser/hadoop-bsfs-1.2.1"
HDFS_HOME="/home/demouser/hadoop-1.2.1"
EXPORT_ENV="source /usr/games/env"
HADOOP_HOME=""

printMessage() {
	echo " "
        echo "-f, --file-system:"
	echo "    Set it to 'HDFS' to deploy Hadoop File System. Default setting is BSFS."
        echo "-m, --m-number:"
	echo "    Number of meta-data storage providers."
        echo "-p, --p-number:"
	echo "    Number of storage providers."
	echo "-s, --s-number:"
	echo "    Number of Hadoop slaves."
        echo "-a, --nmanager:"
	echo "    Specify the Namespace Manager. (-a 5 means 5th node in available nodes list, default is the first node)"
        echo "-t, --test-type:"
	echo "    Type of application should be run (*obligatory*). Currently supported test type: "
        echo "	  - wordcount"
        echo "	  - sort"
        echo "	  - FASTA"
	echo "-c, --concurrency:"
	echo "     Number of concurrent Map tasks (between 2 and 128). The default value is 2."
        echo "-h, -?, --help:"
	echo "    Display this help message.";
	echo " "
}

param_check(){

        case ${fs} in
        "HDFS")
                echo "File system set to ${fs}."
		echo ${fs} > ${TMP_FS}
                HADOOP_HOME=${HDFS_HOME}
        ;;
        "BSFS")
                echo "File system set to ${fs}."
		echo ${fs} > ${TMP_FS}
                HADOOP_HOME=${BSFS_HOME}
        ;;
        *)
                echo "No matching file system. Quit the program."
        esac
}

get_block_size(){

	if [ ${concurrency} -gt 0 ] && [ ${concurrency} -lt 5 ]; then
		block_size=67108864
	elif [ ${concurrency} -gt 4 ] && [ ${concurrency} -lt 9 ]; then
		block_size=65536
	elif [ ${concurrency} -gt 8 ] && [ ${concurrency} -lt 17 ]; then
		block_size=32768
	elif [ ${concurrency} -gt 16 ] && [ ${concurrency} -lt 33 ]; then
		block_size=16384
	elif [ ${concurrency} -gt 32 ] && [ ${concurrency} -lt 65 ]; then
		block_size=8192
	elif [ ${concurrency} -gt 64 ] && [ ${concurrency} -lt 129 ]; then
		block_size=4096
	else
		block_size=67108864
	fi		
	
	echo "Block size is ${block_size}"	
}

deployment(){

	if [ "${fs}" == "BSFS" ]; then
        	ssh demouser@${master} "source /usr/games/env; hb-single-clustest.sh -p ${pnumber} -m ${mnumber} -s ${snumber} -a ${r_nmanager} -b ${block_size} " 2>&1 | tee ${TMP_CHECK} &
	elif [ "${fs}" == "HDFS" ]; then
        	ssh demouser@${master} "source /usr/games/env; deploy-hdfs-hadoop.sh -s ${snumber} -b ${block_size} " 2>&1 | tee ${TMP_CHECK} &
	else
        	echo "File system ${fs} does not exist. Quit the demo."
        	exit 1
	fi
	
        dep_finished=`cat ${TMP_CHECK} | grep "All check passed, deployment verified." | wc -l`
        timer=0
	timer_limit=$((15 * ${snumber}))
        while [ ${dep_finished} -lt 1 ] 
        do
                occur_error=`cat ${TMP_CHECK} | grep ERROR | wc -l`
                if [ ${occur_error} -gt 0 ]; then
                        echo "***** Error occured during the deployment. Clean up everything and quit."
			clean_up
                        exit 0;
                fi
                sleep 10
                dep_finished=`cat ${TMP_CHECK} | grep "All check passed, deployment verified." | wc -l`
                timer=$((${timer} + 1))
                if [ ${timer} -gt ${timer_limit} ]; then
                        echo "***** Deployment process is dead. Clean up everything and quit."
			clean_up
                        exit 0;
                fi
        done

}

log_manage(){

        if [ ! -d ${HISTORY_PATH} ]; then
                mkdir ${HISTORY_PATH}
        fi
        echo "Logging directory: ${OUTPUT_PATH}"
        exist_log_file=`ls -l ${OUTPUT_PATH} | grep .log | wc -l`
        echo "There are ${exist_log_file} existing log file(s)."
        if [ ${exist_log_file} -gt 0 ]; then
                mv ${OUTPUT_PATH}/*.log ${HISTORY_PATH}
        fi
        exist_out_file=`ls -l ${OUTPUT_PATH} | grep .out | wc -l`
        echo "There are ${exist_out_file} existing output file(s)."
        if [ ${exist_out_file} -gt 0 ]; then
                mv ${OUTPUT_PATH}/*.out ${HISTORY_PATH}
        fi
        exist_result_file=`ls -l ${OUTPUT_PATH} | grep .result | wc -l`
        echo "There are ${exist_result_file} existing result file(s)."
        if [ ${exist_result_file} -gt 0 ]; then
                mv ${OUTPUT_PATH}/*.result ${HISTORY_PATH}
        fi
}

clean_up(){
	case ${fs} in
        	"HDFS")
                	ssh demouser@${master} "source /usr/games/env; clean-hdfs-hadoop.sh"
        	;;

        	"BSFS")
                	ssh demouser@${master} "source /usr/games/env; hb-clean.sh"
        	;;
	esac

}

parse_result(){

	log_file=`ls ${OUTPUT_PATH}/*.log | head -n 1`

	start_time=`cat ${log_file} | grep "Running job" | cut -d "I" -f 1`
	start_second=`date -d "20${start_time}" +%s`

	if [[ -z ${start_time} ]]; then
		echo "***** ERROR: Job start time cannot be retrieved. There must be some error occurs. Clean up deployment and quit."
		exit 1
	fi

	stop_time=`cat ${log_file} | grep "Job complete" | cut -d "I" -f 1`
	stop_second=`date -d "20${stop_time}" +%s`

        if [[ -z ${stop_time} ]]; then
                echo "***** ERROR: Job stop time cannot be retrieved. There must be some error occurs. Clean up deployment and quit."
                exit 1
        fi

	echo "Job start time is ${start_second}"
	echo "Job complete time is ${stop_second}"

	execution_second=$((${stop_second} - ${start_second}))
	result_file=`echo ${log_file} | cut -d "." -f 1`.result

	echo " "
	echo "***** RESULT: Execution duration is ${execution_second} second. *****" > ${result_file}
	if [ ${execution_second} -gt 0 ]; then
		cat ${result_file}
	else
		echo "Abnormal execution duration ${execution_second} is obtained."
		echo "Test failed!!!"
	fi

}

args=$#
deploy="true"
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
r_nmanager=1
testypt="wordcount"
concurrency=0
block_size=67108864

echo " " > ${TMP_CHECK}

while [ $args -gt 0 ]
do
        case $1 in

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

        "--test-type"|"-t")
                testype=$2
                echo "Required application is ${testype}."
		shift 2;
                args=$(( args-2 ))
        ;;

        "--concurrency"|"-c")
                if [ $2 -gt 128 ] || [ $2 -lt 1 ]; then
                        concurrency=1
                        echo "Number of mapper is set to ${concurrency} by default."
                else
                        concurrency=$2
                        echo "Number of mapper is set to ${concurrency}."
                fi
                shift 2;
                args=$(( args-2 ));
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

echo " "
echo "***** Set FS block size according to the concurrency. *****"
get_block_size
echo " "

echo " "
echo "----------------------------"
echo "----- Start deployment -----"
echo "----------------------------"
echo " "

master=`head -n 1 ${NODES_LIST}`
deployment

echo " "
echo "--------------------------"
echo "----- Log management -----"
echo "--------------------------"
echo " "
log_manage

echo " "
echo "---------------------------------"
echo "----- Start Map Reduce Task -----"
echo "---------------------------------"
echo " " 

case $testype in
	"wordcount")
        echo "${testype} test running on ${fs}."
	rsh -n demouser@${master} "${EXPORT_ENV}; ${HADOOP_HOME}/bin/hadoop fs -copyFromLocal ${HADOOP_HOME}/CHANGES.txt test.txt"
	rsh -n demouser@${master} "${EXPORT_ENV}; ${HADOOP_HOME}/bin/hadoop jar ${HADOOP_HOME}/hadoop*examples*.jar wordcount -D mapred.map.tasks=$concurrency test.txt /output" 2>&1 | tee $OUTPUT_PATH/$fs-`date +%y-%m-%d-%H-%M`-$testype-$concurrency.log
	;;

        "sort")
        echo "${testype} test running on ${fs}."
	rsh -n demouser@${master} "${EXPORT_ENV}; ${HADOOP_HOME}/bin/hadoop fs -copyFromLocal ${HADOOP_HOME}/CHANGES.txt test.txt"	
	rsh -n demouser@${master} "${EXPORT_ENV}; ${HADOOP_HOME}/bin/hadoop jar ${HADOOP_HOME}/hadoop*examples*.jar sort -D mapred.map.tasks=$concurrency -inFormat org.apache.hadoop.mapred.KeyValueTextInputFormat -outFormat org.apache.hadoop.mapred.TextOutputFormat -outKey org.apache.hadoop.io.Text -outValue org.apache.hadoop.io.Text test.txt /output" 2>&1 | tee $OUTPUT_PATH/$fs-`date +%y-%m-%d-%H-%M`-$testype-$concurrency.log
        ;;
	
*)
	echo "No matching application"
esac

echo " " 
echo "-----------------------------------"
echo "----- Clean up the deployment -----"
echo "-----------------------------------"
echo " "

clean_up

echo " "
echo "------------------------"
echo "----- Parse result -----"
echo "------------------------"
echo " "

parse_result

echo " "
echo "Test finished."
echo " "

exit 0
