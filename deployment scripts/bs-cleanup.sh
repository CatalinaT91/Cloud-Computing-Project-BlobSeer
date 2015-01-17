#!/bin/bash

HOST_LIST=host-list.txt
TMP_LIST=tmp-list.txt
TMP_CHECK=tmp-check.txt
TMP_CONFIG=blobseer.cfg

printMessage() {
        echo "Usage of input parameters:";
        echo "-e, --env-file                    : File set environment variables *obligatory*."
        echo "-h, -?, --help                    : Display this help message.";
}

param_check(){
        if [ -z $ENVFILE ]; then
                echo "** ERROR: Please enter the file to configure environment variables."
                exit 0;
        fi
}

expo_env(){
        source $ENVFILE
        if [ -z $BLOBSEER_HOME ]; then
                echo "Set environment variable failed. BLOBSEER_HOME=$BLOBSEER_HOME"
        else
                echo "BLOBSEER_HOME successfully set to $BLOBSEER_HOME"
        fi
}

bs_clean(){
	vmanager=`cat $BLOBSEER_HOME/scripts/vmgr.txt`
	echo "Version manager is: $vmanager."
	pmanager=`cat $BLOBSEER_HOME/scripts/pmgr.txt`
	echo "Provider manager is: $pmanager."
        $BLOBSEER_HOME/scripts/blobseer-deploy.py --vmgr=$vmanager --pmgr=$pmanager --dht=$BLOBSEER_HOME/scripts/dht.txt --providers=$BLOBSEER_HOME/scripts/providers.txt --kill
	if [ -f $HOST_LIST ]; then
	        rm $HOST_LIST
	fi
        if [ -f $TMP_CONFIG ]; then
                rm $TMP_CONFIG
        fi
	if [ -f $TMP_LIST ]; then
        	rm tmp-list.txt
	fi
	if [ -f $TMP_CHECK ]; then
	        rm tmp-check.txt
	fi
}


args=$#

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

        "-h"|"-?"|"--help")
                printMessage
                exit 0;
        ;;
        *)
                echo "parametre $1 is invalid : please use option -h for help !";
                exit 1;
                ;;
	esac

done

param_check
echo " "

echo "***** Export enviroment variables *****"
expo_env
echo " "

echo "***** Clean up BlobSeer *****"
bs_clean
echo " "
