#!/bin/bash

HOST_LIST=$HOME/.nodes-list.txt
NMANAGER=$HOME/.nmanager.txt
TMP_CHECK=$HOME/.tmp-check.txt
TMP_CONFIG=$HOME/.blobseer.cfg

printMessage(){
        echo "Usage of input parameters:";
        echo "-h, -?, --help                    : Display this help message.";
}

param_check(){
        if [ -z $HADOOP_BSFS_HOME ]; then
                echo "** ERROR: Please enter the path to hadoop home folder."
                exit 0;
        fi
}

hadoop_clean(){
	nmanager=`cat $NMANAGER`
	echo "Namespace Manager is $nmanager."
	rsh -n $nmanager "pkill java"
        echo "Stop Trackers."
	jobtracker=`cat $HADOOP_BSFS_HOME/conf/masters`
	echo "JobTracker is $jobtracker"
	rsh -n $jobtracker "$HADOOP_BSFS_HOME/bin/stop-mapred.sh"

        echo "Clean intermediate files."
        if [[ -f $TMP_CHECK ]]; then
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
                echo "parametre $1 invalide : -h pour afficher l'aide !";
                exit 1;
                ;;
        esac
done

echo "Check Hadoop home folder"
param_check
echo " "

echo "Clean up Hadoop deployment"
hadoop_clean
echo " "
