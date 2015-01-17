#!/bin/bash

HOST_LIST=$HOME/.nodes-list.txt
TMP_CONFIG=$HOME/.blobseer.cfg
TMP_CHECK=$HOME/.tmp-check.txt

printMessage() {
	echo "Usage of input parameters:";
	echo "-m, --mnumber			: Number of meta-data storage providers."
	echo "-p, --pnumber			: Number of storage providers."
	echo "-t, --test                        : If automatic test is required, set this option to true."
	echo "-c, --cleanup                     : If automatic clean up is required, set this option to true."
	echo "-h, -?, --help                 	: Display this help message.";
}

param_check(){
	if [ -z $mnumber ]; then
		mnumber=1
	        echo "Meta-data storage provider number is set to $mnumber by default"
	fi
	if [ -z $pnumber ]; then
		pnumber=1
	        echo "Data storage provider number is set to $pnumber by default"
	fi
        if [ "$autotest" != "true" ]; then
                echo "Test will not be executed automatically."
        fi
        if [ "$autoclean" != "true" ]; then
                echo "**ATTENTION: please clean up BlobSeer manually."
                sleep 1
        fi
}

retrieve_nodes(){
	if [ -f $HOST_LIST ]; then
		echo "List of nodes are available at $HOME/.nodes-list.txt"
	else 
		echo "**ERROR: Nodes list file does not exist, please add nodes in $HOME/.nodes-list.txt."
		exit 1
	fi
	echo "Available nodes:"
	cat $HOST_LIST
}

dispatch_jobs(){
	avail_nodes=`cat $HOST_LIST | wc -l`
	if [ $mnumber -gt $pnumber ]; then
		let "least_nodes=2+$mnumber"
	else
		let "least_nodes=2+$pnumber"
	fi

	if [ $least_nodes -gt $avail_nodes ]; then
		echo "** ERROR: No enough VMs available."
		exit 1;
	fi

	vmanager=`head -n 1 $HOST_LIST`
	echo "Version manager is:"; echo $vmanager; echo " "
	echo $vmanager > $BLOBSEER_HOME/scripts/vmgr.txt
	pmanager=`head -n 2 $HOST_LIST | tail -n 1`
	echo "Provider manager is:"; echo  $pmanager; echo " "
	echo $pmanager > $BLOBSEER_HOME/scripts/pmgr.txt
	head -n `expr 2 + $mnumber` $HOST_LIST | tail -n $mnumber > $BLOBSEER_HOME/scripts/dht.txt
	echo "Meta data storage providers are:"
	cat $BLOBSEER_HOME/scripts/dht.txt
	echo " "
	tail -n $pnumber $HOST_LIST > $BLOBSEER_HOME/scripts/providers.txt
	echo "Data storage providers are:"
	cat $BLOBSEER_HOME/scripts/providers.txt
	echo " "
}

bs_deploy(){
	echo "Deploying"
	$BLOBSEER_HOME/scripts/blobseer-deploy.py --vmgr=$vmanager --pmgr=$pmanager --dht=$BLOBSEER_HOME/scripts/dht.txt --providers=$BLOBSEER_HOME/scripts/providers.txt --launch=$BLOBSEER_HOME/scripts/blobseer-template.cfg
	echo " "

	echo "Retrieve configuration file"
	scp $vmanager:/tmp/blobseer.cfg $TMP_CONFIG
	echo " "

	sleep 2

	echo "Checking"
	rsh -n $vmanager "ps aux" > ${TMP_CHECK}
	VMGR_STATUS=`cat ${TMP_CHECK} | grep "$BLOBSEER_HOME/vmanager/vmanager" | wc -l`
	if [ $VMGR_STATUS -lt 1 ]; then
		echo "Version manager is not launched. Deploy failed. clean up the deployment."
		bs_clean
	        exit 1
	fi
	echo "vmanager checked"
 
	rsh -n $pmanager "ps aux" > ${TMP_CHECK}
        PMGR_STATUS=`cat ${TMP_CHECK} | grep "$BLOBSEER_HOME/pmanager/pmanager" | wc -l`
        if [ $PMGR_STATUS -lt 1 ]; then
                echo "Provider manager is not launched. Deploy failed. clean up the deployment."
                bs_clean
                exit 1
        fi
	echo "pmanager checked"

	while read NODE
	do
	        rsh -n $NODE "ps aux" > ${TMP_CHECK}
	        SDHT_STATUS=`cat ${TMP_CHECK} | grep "$BLOBSEER_HOME/provider/sdht" | wc -l`
        	if [ $SDHT_STATUS -lt 1 ]; then
                	echo "Meta-data storage on node *$NODE* is not launched. Deploy failed. clean up the deployment."
                	bs_clean
                	exit 1
        	fi
	done</$BLOBSEER_HOME/scripts/dht.txt
	echo "Meta-data storage providers checked"

        while read NODE
        do
                rsh -n $NODE "ps aux" > ${TMP_CHECK}
                PROV_STATUS=`cat ${TMP_CHECK} | grep "$BLOBSEER_HOME/provider/provider" | wc -l`
                if [ $PROV_STATUS -lt 1 ]; then
                        echo "Data storage on node *$NODE* is not launched. Deploy failed. clean up the deployment."
                        bs_clean
                        exit 1
                fi
        done</$BLOBSEER_HOME/scripts/providers.txt
	echo "Data storage providers checked"

	echo "All components are correctly deployed."
}

bs_test(){

	BASIC_TEST=`$BLOBSEER_HOME/test/basic_test $TMP_CONFIG | grep "All tests passed SUCCESSFULLY" | wc -l`
	if [ $BASIC_TEST -lt 1 ]; then
        	echo "Basic unaligned read test failed, clean up the deployment."
        	bs_clean
	        exit 8
	else
        	echo "Basic unalinged read test succeeded, pass to create test."
    	fi

	CREATE_TEST=`$BLOBSEER_HOME/test/create_blob $TMP_CONFIG 65536 1 | grep "Blob created successfully" | wc -l`
	if [ $CREATE_TEST -lt 1 ]; then
        	echo "Create BLOB failed, clean up the deployment."
	        bs_clean
	        exit 2
	else
        	echo "BLOB create test succeeded, pass to write test."
	fi

	WRITE_TEST=`$BLOBSEER_HOME/test/test W 2 $TMP_CONFIG | grep "End of test" | wc -l`
    	if [ $WRITE_TEST -lt 1 ]; then
        	echo "Write BLOB failed, clean up the deployment."
        	bs_clean
        	exit 3
    	else
        	echo "BLOB write test succeeded, pass to read test."
    	fi

    	READ_TEST=`$BLOBSEER_HOME/test/test R 2 $TMP_CONFIG | grep "End of test" | wc -l`
    	if [ $READ_TEST -lt 1 ]; then
        	echo "Read BLOB failed, clean up the deployment."
        	bs_clean
        	exit 4
    	else
        	echo "BLOB read test succeeded, pass to append test."
    	fi

    	APPEND_TEST=` $BLOBSEER_HOME/test/test A 2 $TMP_CONFIG | grep "End of test" | wc -l`
    	if [ $APPEND_TEST -lt 1 ]; then
        	echo "Append BLOB failed, clean up the deployment."
	        bs_clean
        	exit 5
    	else
        	echo "BLOB append test succeeded, pass to clone test."
    	fi

    	CLONE_TEST=` $BLOBSEER_HOME/test/clone_test $TMP_CONFIG | grep "Clone test completed" | wc -l`
    	if [ $CLONE_TEST -lt 1 ]; then
        	echo "Clone BLOB failed, clean up the deployment."
	        bs_clean
	        exit 6
    	else
        	echo "BLOB clone test succeeded, pass to file upload test."
    	fi

    	UPLOAD_TEST=`$BLOBSEER_HOME/test/file_uploader $BLOBSEER_HOME/README $TMP_CONFIG 2 1 | grep "Operation successful" | wc -l`
    	if [ $UPLOAD_TEST -lt 1 ]; then
        	echo "File upload failed, clean up the deployment."
	        bs_clean
	        exit 7
    	else
        	echo "File upload test succeeded."
    	fi

}

bs_clean(){
        vmanager=`cat $BLOBSEER_HOME/scripts/vmgr.txt`
        echo "Version manager is: $vmanager."
        pmanager=`cat $BLOBSEER_HOME/scripts/pmgr.txt`
        echo "Provider manager is: $pmanager."
        $BLOBSEER_HOME/scripts/blobseer-deploy.py --vmgr=$vmanager --pmgr=$pmanager --dht=$BLOBSEER_HOME/scripts/dht.txt --providers=$BLOBSEER_HOME/scripts/providers.txt --kill
        #if [ -f $HOST_LIST ]; then
        #        rm $HOST_LIST
        #fi
        if [ -f $TMP_CONFIG ]; then
                rm $TMP_CONFIG
        fi
        if [ -f $TMP_CHECK ]; then
                rm ${TMP_CHECK}
        fi
}

# Entry of the program

args=$#
mnumber=""
pnumber=""
job_id=""
JOB_NAME=""
host_list=""
vmanager=""
pmanager=""
block_size=""
dht=""
providers=""
autotest=""
autoclean=""

while [ $args -gt 0 ]
do
	case $1 in
	"--env-file"|"-e")
		if [ -f $2 ]; then
			echo "Environment variable file found."
			ENVFILE=$2;
		else
			echo "** ERROR: Environment file not found. Please check the path and file name.";
			exit 1;
		fi
		shift 2;
		args=$(( args-2 ));
	;;

	"--job-name"|"-n")
		if [ -z $2 ]; then
                        echo "** ERROR: Please enter the name of Grid5000 job.";
                        exit 1;
		else
                        JOB_NAME=$2
                        echo "Grid5000 job name is $JOB_NAME"
		fi;
		shift 2;
		args=$(( args-2 ));
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

        "--cleanup"|"-c")
                if [ "$2" == "true" ]; then
                        autoclean="true"
                        echo "Automatic clean up is required."
                else
                        echo "**Attention: BlobSeer should be cleaned up manually.";
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
param_check
echo " "

echo "***** Retrieve information of reserved nodes *****"
retrieve_nodes
echo " "

echo "****** Dispatch jobs to nodes ******"
dispatch_jobs
echo " "

echo "***** Deploy BlobSeer *****"
bs_deploy
echo " "

if [ "$autotest" == "true" ]; then
        echo "***** Test BlobSeer *****"
        bs_test
        echo " "
fi

if [ "$autoclean" == "true" ]; then
        echo "***** Clean up BlobSeer *****"
        bs_clean
        echo " "
fi

exit 0





