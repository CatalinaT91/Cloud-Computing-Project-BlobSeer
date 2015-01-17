#!/bin/bash

HOST_LIST=$HOME/.nodes-list.txt
TMP_LIST=tmp-list.txt
TMP_CHECK=$HOME/.tmp-check.txt
TMP_CONFIG=$HOME/.blobseer.cfg

printMessage() {
        echo "Usage of input parameters:";
        echo "-h, -?, --help                    : Display this help message.";
}

bs_clean(){
	vmanager=`cat $BLOBSEER_HOME/scripts/vmgr.txt`
	echo "Version manager is: $vmanager."
	pmanager=`cat $BLOBSEER_HOME/scripts/pmgr.txt`
	echo "Provider manager is: $pmanager."
        $BLOBSEER_HOME/scripts/blobseer-deploy.py --vmgr=$vmanager --pmgr=$pmanager --dht=$BLOBSEER_HOME/scripts/dht.txt --providers=$BLOBSEER_HOME/scripts/providers.txt --kill
        if [ -f $TMP_CONFIG ]; then
                rm $TMP_CONFIG
        fi
	if [ -f $TMP_CHECK ]; then
	        rm $TMP_CHECK
	fi
}


args=$#

while [ $args -gt 0 ]
do
        case $1 in

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

echo "***** Clean up BlobSeer *****"
bs_clean
echo " "
