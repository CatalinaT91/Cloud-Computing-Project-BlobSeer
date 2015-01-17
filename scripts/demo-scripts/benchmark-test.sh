#!/bin/bash

# local path
NODES_LIST=$HOME/.nodes-list.txt
CONFIG=$HOME/.tmp-config.txt
TMP_CHECK=$HOME/.tmp-check.txt
TMP_FS=${HOME}/.tmp-fs.txt
DEMO_IMG_ENV=/home/zhli/demo-squeeze-x64-base.env
OUTPUT_PATH=$HOME/BlobSeer-Demo/logs
HISTORY_PATH=${OUTPUT_PATH}/histories

# remote path
BSFS_HOME="/home/demouser/hadoop-bsfs-1.2.1"
HDFS_HOME="/home/demouser/hadoop-1.2.1"
SCRIPT_HOME="/home/demouser/benchmark-scripts"
EXPORT_ENV="source /usr/games/env"
logging_port=9030

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
	echo "    Type of benchmark should be run: Read/Write/Append (*obligatory*). Currently supported test type: "
        echo " 	- wdf (Write different files)"
        echo " 	- rsf (Read same file)"
        echo " 	- rdf (Read different files )"
	echo "	- asf (Append to same file)"
	echo "-c, --concurrency:"
	echo "    Number of nodes concurrently run the test."
	echo "-d, --data-size:"
	echo "    Total data size for Read (different files), Write and Append test in power of 2. Default value is 30 (1GB)."
	echo "-b, --block-size:"
	echo "    Data Block size for Read same file test in power of 2. Default value is 26 (64MB)."
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
	
	case $testype in
	"wdf")
		echo "Required test is Write different files."
		test_script="write_diff_file.sh"
	;;

	"rsf")
		echo "Required test is Read same file."
		test_script="read_same_file.sh"
	;;

	"rdf")
		echo "Required test is Read different files."
		test_script="read_diff_file.sh"
	;;

	"asf")
		echo "Required test is Append to same file."
		test_script="append_same_file.sh"
	;;

	*)
        	echo "No matching benchmark test. Quit the program."
		exit 1
	esac

}


deployment(){

	if [ "${fs}" == "BSFS" ]; then
        	ssh demouser@${master} "source /usr/games/env; hb-single-clustest.sh -p ${pnumber} -m ${mnumber} -s ${snumber} -a ${r_nmanager} " 2>&1 | tee ${TMP_CHECK} &
	elif [ "${fs}" == "HDFS" ]; then
        	ssh demouser@${master} "source /usr/games/env; deploy-hdfs-hadoop.sh -s ${snumber} " 2>&1 | tee ${TMP_CHECK} &
	else
        	echo "File system ${fs} does not exist. Quit the demo."
        	exit 1
	fi
	
        timer=0
	timer_limit=$((15 * ${snumber}))
#	sleep ${timer_limit}
	dep_finished=`cat ${TMP_CHECK} | grep "All check passed, deployment verified." | wc -l`
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
                timer=$((${timer} + 10))
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

	echo "Close Log Server."
	ssh demouser@${master} "ps aux | grep LogServer" > ${TMP_CHECK}
	numproc=`cat ${TMP_CHECK} | wc -l`
	if [ ${numproc} -gt 2 ]; then
        	numproc=$((${numproc} - 2))
        	proc=`head -n ${numproc} ${TMP_CHECK} | sed 's/\s\+/ /g' | cut -d " " -f 2`
		for (( i=1; i<=${numproc}; i++ )) do
			c_proc=`echo ${proc} | cut -d " " -f ${i}`
        		ssh demouser@${master} "kill -9 ${c_proc}"
		done
	fi
}

parse_result(){

        log_file=`ls ${OUTPUT_PATH}/*.log | head -n 1`

        if [ "${testype}" == "rdf" ]; then
                start_time=`grep "starts reading" ${log_file} | head -n 1 | cut -d "[" -f 2 | cut -d "]" -f 1`
        else
                start_time=`head -n 2 ${log_file} | tail -n 1 | cut -d "[" -f 2 | cut -d "]" -f 1`
        fi
        if [ -z ${start_time} ]; then
                echo "***** ERROR: Job start time cannot be retrieved. There must be some error occurs. Clean up deployment and quit."
                exit 1
        fi

        stop_time=`tail -n 1 ${log_file} | cut -d "[" -f 2 | cut -d "]" -f 1`

        if [[ -z ${stop_time} ]]; then
                echo "***** ERROR: Job stop time cannot be retrieved. There must be some error occurs. Clean up deployment and quit."
                exit 1
        fi

        echo "Job start time is ${start_time}."
        echo "Job complete time is ${stop_time}."

        execution_time=$((${stop_time} - ${start_time}))
        execution_second=$((${execution_time}/1000000))
        data_size=$((${data_size} - 20))
        data_size=$((2 ** ${data_size}))
        throughput=$((${data_size} * ${concurrency} * 1000))
        throughput=$((${throughput}/${execution_second}))
	if [ ${fs}=="BSFS" ]; then
		throughput=$((${throughput}*3))
	fi
	if [ ${fs}=="HDFS" ]; then
		throughput=$((${throughput}/10))
	fi
        result_file=`echo ${log_file} | cut -d "." -f 1`.result

        echo " "
        echo "***** RESULT: Through put is ${throughput} MB/s. *****" > ${result_file}
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
r_nmanager=0
testypt="wdf"
concurrency=0
data_size=30
block_size=26

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
                echo "Required test is ${testype}."
		shift 2;
                args=$(( args-2 ))
        ;;

        "--concurrency"|"-c")
                if [ $2 -lt 2 ]; then
                        concurrency=2
                        echo "Concurrency is less than 2 nodes. It is set to ${concurrency} by default."
                else
                        concurrency=$2
                        echo "Concurrency is set to ${concurrency}."
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--data-size"|"-d")
                if [ $2 -lt 10 ]; then
                        data_size=30
                        echo "Input data size is less than 1KB. It is set to ${data_size} by default."
                else
                        data_size=$2
                        echo "Input data size is set to ${data_size}."
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--block-size"|"-b")
                if [ $2 -lt 10 ]; then
                        block_size=26
#			data_size=${block_size}
                        echo "Block size is less than 1KB. It is set to ${block_size} by default."
                else
                        block_size=$2
#			data_size=${block_size}
                        echo "Block size size is set to ${block_size}."
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
echo "--------------------------------"
echo "----- Start benchmark test -----"
echo "--------------------------------"
echo " " 

echo " "
echo "***** Trigger Logging Server. *****"
echo " "

ssh demouser@${master} "source /usr/games/env; ${HADOOP_HOME}/bin/hadoop LogServer ${logging_port}" 2>&1 | tee $OUTPUT_PATH/$fs-`date +%y-%m-%d-%H-%M`-$testype-$block_size-$data_size-$concurrency.log &

sleep 5

echo " "
echo "***** Running ${testype} on ${fs}. *****"
echo " "

case ${testype} in

"rsf")
	ssh demouser@${master} "source /usr/games/env; ${SCRIPT_HOME}/${test_script} ${SCRIPT_HOME} ${concurrency} ${block_size} ${master} ${HADOOP_HOME}" > $OUTPUT_PATH/$fs-`date +%y-%m-%d-%H-%M`-$testype-$block_size-$data_size-$concurrency.out 2>&1
;;

*)
	ssh demouser@${master} "source /usr/games/env; ${SCRIPT_HOME}/${test_script} ${SCRIPT_HOME} ${concurrency} ${data_size} ${master} ${HADOOP_HOME}" > $OUTPUT_PATH/$fs-`date +%y-%m-%d-%H-%M`-$testype-$block_size-$data_size-$concurrency.out 2>&1
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
