#!/bin/bash

DEMO_HOME=$HOME/BlobSeer-Demo
DEMO_SCRIPTS=${DEMO_HOME}/demo-scripts
OUTPUT_PATH=${DEMO_HOME}/logs
HISTORY_PATH=${OUTPUT_PATH}/histories
chain_indicator=${OUTPUT_PATH}/.chain-res-location.txt
app_script="application-test.sh"
ben_script="benchmark-test.sh"

printMessage() {
	echo " "
        echo "Usage of input parameters:";
	echo "-t, --type:" 
	echo "    Type of benchmark should be run. Currently supported test types: "
	echo "    - app-wordcount"
	echo "    - app-sort"
	echo "    - app-FASTA"
	echo "    - bench-wdf (Write different files)"
	echo "    - bench-rsf (Read same file)"
	echo "    - bench-rdf (Read different files)"
	echo "    - bench-asf (Append to same file)"
        echo "-m, --mnumber:"
	echo "    Number of meta-data storage providers."
        echo "-p, --pnumber:"
	echo "    Number of storage providers."
	echo "-s, --snumber:"
	echo "    Number of Hadoop slaves."
        echo "-c, --concurrency:"
        echo "    Maximum number of nodes concurrently run the test for benchmark tests."
	echo "    Maximum number of map tasks in power of 2 for application tests. Valid value 1:7."        
	echo "-d, --data-size:"
        echo "    Total data size for Read (different files), Write and Append test in power of 2. Default value is 30 (1GB)."
        echo "-b, --block-size:"
        echo "    Data Block size for Read same file test in power of 2. Default value is 26 (64MB)."
	echo "-g, --granu"
	echo "    Augmentation granularity in term of concurrency."
	echo "-r, --run:"
	echo "    Number of repeat times for each test."
        echo "-h, -?, --help:"
	echo "    Display this help message.";
	echo " "
}

#check parameters
check_param(){

	
        case $test_name in
        "app-wordcount")
                echo "Required test is wordcount application."
                test_script=${app_script}
		testype="wordcount"
        ;;

	"app-sort")
		echo "Required test is sort application."
		test_script=${app_script}
		testype="sort"
	;;

	"app-FASTA")
		echo "Required test is FASTA application."
		test_script=${app_script}
		testype="FASTA"
	;;

	"bench-wdf")
		echo "Required test is Write different file."
		test_script=${ben_script}
		testype="wdf"
	;;

        "bench-rsf")
                echo "Required test is Read same file."
                test_script=${ben_script}
		testype="rsf"
        ;;

        "bench-rdf")
                echo "Required test is Read different files."
                test_script=${ben_script}
		testype="rdf"
        ;;

        "bench-asf")
                echo "Required test is Append to same file."
                test_script=${ben_script}
		testype="asf"
        ;;

        *)
                echo "No matching benchmark test. Quit the program."
                exit 1
        esac        

	if [ ${test_script} == ${app_script} ]; then
		if [ ${concurrency} -lt 1 ] || [ ${concurrency} -gt 7 ]; then
			echo "Number of concurrent map tasks is out of range. Quit the program."
			exit 1
		fi
	fi

	if [ $granu -lt 1 ]; then
                granu=1
                echo "The augmentation granularity is set to $granu by default"
		if [ $granu -gt $concurrency ]; then
			echo "** ERROR: Granularity is larger than the limitation of the concurrency, please reset the value  **"
			exit 1 
		fi
        fi

        if [ $runs -lt 1 ]; then
                runs=1
                echo "Each test will repeat $runs time by default"
        fi
}

chain_log(){

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
	exist_chain_dir=`ls -l ${OUTPUT_PATH} | grep chain- | wc -l`
	echo "There are ${exist_chain_dir} existing chain test result directory(ies)."
	if [ ${exist_chain_dir} -gt 0 ]; then
		mv ${OUTPUT_PATH}/chain-* ${HISTORY_PATH}
	fi

	chain_log="chain"-${concurrency}-${granu}-${runs}-${test_name}-`date +%y-%m-%d-%H-%M`
	chain_log_dir=${OUTPUT_PATH}/${chain_log}
	mkdir ${chain_log_dir}
	echo ${chain_log} > ${chain_indicator}
}

res_management(){

        exist_result_file=`ls -l ${OUTPUT_PATH} | grep .result | wc -l`
        echo "${exist_result_file} result file(s) generated."
        if [ ${exist_result_file} -gt 0 ]; then
                 mv ${OUTPUT_PATH}/*.result ${chain_log_dir}
                 echo "Moved to the chain test result directory."
                 echo " "
        fi
}

startchain(){

	case ${testype} in
	"rsf")
		fs_to_test=1
		echo "Test will run only over BSFS."
	;;
	"asf")
		fs_to_test=1
		echo "Test will run only over BSFS."
	;;
	*)
		fs_to_test=2
		echo "Test will run first over BSFS, then HDFS."
	;;
	esac

	for (( fs_test=1; fs_test<=${fs_to_test}; fs_test++ )) do
	if [ ${fs_test} == 1 ]; then
		fs=BSFS
	else
		fs=HDFS
	fi
	echo " "
	echo "Chained test running over ${fs}."

	curr_concurr=0
	app_concurr=1
	last_round=0
	while [ ${curr_concurr} -le ${concurrency} ]; do

	for (( cr=1; cr<=$runs; cr++ )) do # main loop of the test
		echo " "
		echo "***** Execute round $cr *****"
		echo " "
		echo "------------------------"
		echo "----- Execute Test -----"
		echo "------------------------"

		echo " "
		echo "Concurrency in this round is ${curr_concurr}."

		if [ ${test_script} == ${app_script} ]; then
			${DEMO_SCRIPTS}/${test_script} -f ${fs} -m ${mnumber} -p ${pnumber} -s ${snumber} -a ${r_nmanager} -t ${testype} -c ${app_concurr}
		else
			${DEMO_SCRIPTS}/${test_script} -f ${fs} -m ${mnumber} -p ${pnumber} -s ${snumber} -a ${r_nmanager} -t ${testype} -c ${curr_concurr} -d ${data_size} -b ${block_size}
		fi
		res_management

	done # main while loop

	echo "***** One set of test is finished. *****"
	echo " "
        curr_concurr=$((${curr_concurr}+${granu}))
	app_concurr=$((2**${curr_concurr}))
	mod_res=$((${concurrency}%${runs}))
        if [ ${curr_concurr} -gt ${concurrency} ]; then
		if [ ${last_round} == 0 ] && [ ${mod_res} != 0 ]; then
	                curr_concurr=${concurrency}
			app_concurr=$((2**${curr_concurr}))
			last_round=1
		fi
        fi
	if [ ${curr_concurr} -le ${concurrency} ]; then
		echo "Augmentation granularity is $granu"
	else	
		if [ ${fs_test} -eq ${fs_to_test} ]; then
			echo "All tests finished. Program terminates."
		fi
	fi

	done # for loop of each run

	done # for loop for different file system
}

args=$#
mnumber=0
pnumber=0
snumber=1
r_nmanager=1
fs="BSFS"
concurrency=0
data_size=30
block_size=26
granu=0
runs=0
test_name=""
testype=""
test_script=""
chain_log_dir=""


while [ $args -gt 0 ]
do
        case $1 in

        "--file-system"|"-f")
                fs=$2
                echo "The required file system is ${fs}."
                shift 2;
                args=$(( args-2 ))
        ;;

        "--test-type"|"-t")
                test_name=$2
                echo "Required test is ${test_name}."
                shift 2;
                args=$(( args-2 ))
        ;;

        "--m-number"|"-m")
                if [ $2 -gt 0 ]; then
                        mnumber=$2
                        echo "Meta-data storage provider number is set to $mnumber"
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--p-number"|"-p")
                if [ $2 -gt 0 ]; then
                        pnumber=$2
                        echo "Data storage provider number is set to $pnumber"
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "--s-number"|"-s")
                if [ $2 -gt 0 ]; then
                        snumber=$2
                        echo "Hadoop slave number is set to $snumber"
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
                        data_size=${block_size}
                        echo "Block size is less than 1KB. It is set to ${block_size} by default."
                else
                        block_size=$2
                        data_size=${block_size}
                        echo "Block size size is set to ${block_size}."
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--granu"|"-g")
                if [ $2 -gt 0 ]; then
                        granu=$2
                        echo "The augmentation granularity is $granu"
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "--runs"|"-r")
                if [ $2 -gt 0 ]; then
                        runs=$2
                        echo "Number of runs for each test is $runs"
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "-h"|"-?"|"--help")
                printMessage
                exit 0;
        ;;
        *)
                echo "parametre $1 invalide : -h pour afficher l'aide !";
                exit 1;
                ;;
        esac
done

echo " "
echo "***** Check input parameters *****"
check_param
echo " "

echo " "
echo "***** Chain test log management *****"
chain_log
echo " " 

echo "***** Start evaluation *****"
startchain
echo " "



exit 0
