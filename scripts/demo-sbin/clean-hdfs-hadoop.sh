#!/bin/bash

printMessage(){
        echo "Usage of input parameters:";
        echo "-o, --hadoop-home                 : Location of Hadoop home folder (*obligatory*)."
        echo "-h, -?, --help                    : Display this help message.";
}

param_check(){
        if [ -z $HADOOP_HDFS_HOME ]; then
                echo "** ERROR: Please enter the path to hadoop home folder."
                exit 0;
        fi
}

expo_env(){
        export HADOOP_PREFIX=$HADOOP_HDFS_HOME
        if [ -z $HADOOP_HDFS_HOME ]; then
                echo "Set environment variable failed. HADOOP_HDFS_HOME=$HADOOP_HDFS_HOME"
        else
                echo "HADOOP_HDFS_HOME successfully set to $HADOOP_HDFS_HOME"
        fi
        if [ -z $JAVA_HOME ]; then
                echo "Set environment variable failed. JAVA_HOME=$JAVA_HOME"
        else
                echo "JAVA_HOME successfully set to $JAVA_HOME"
        fi
}

hadoop_clean(){
	master=`cat $HADOOP_HDFS_HOME/conf/masters`
        echo "Master is $master."
        echo "Clean master."
        rsh -n $master "$HADOOP_HDFS_HOME/bin/stop-mapred.sh"
        echo "Clean slaves."
        rsh -n $master "$HADOOP_HDFS_HOME/bin/stop-dfs.sh"

        echo "Clean intermediate files."
#        if [[ -f $HOST_LIST ]]; then
#                rm $HOST_LIST
#        fi
        if [[ -f ${TMP_CHECK} ]]; then
                rm ${TMP_CHECK}
        fi
}

args=$#
HOST_LIST=$HOME/.nodes-list.txt
TMP_CHECK=$HOME/.tmp-check.txt

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

echo "Export environment variables."
expo_env

echo "Clean up Hadoop deployment"
hadoop_clean
echo " "
