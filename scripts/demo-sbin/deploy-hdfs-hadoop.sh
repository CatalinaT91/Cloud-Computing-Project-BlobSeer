#bin/bash

HOST_LIST=$HOME/.nodes-list.txt
TMP_CHECK=$HOME/.tmp-check.txt

printMessage(){
        echo "Usage of input parameters:";
        echo "-s, --snumber                     : Number of slaves in the MapReduce system."
	echo "-r, --rnumber                     : Number of replications in HDFS."
	echo "-b, --block-size			: Block size of the file system (power of 2)."
        echo "-t, --test                        : If automatic test is required, set this option to true."
        echo "-c, --cleanup                     : If automatic clean up is required, set this option to true."
        echo "-h, -?, --help                    : Display this help message.";
}

param_check(){
        if [ -z $HADOOP_HDFS_HOME ]; then
                echo "** ERROR: Please enter the path to hadoop home folder."
                exit 0;
        fi
        if [ -z $snumber ]; then
                echo "Number of slaves will be set to the number of reserved nodes"
        fi
        if [ -z $rnumber ]; then
                echo "Number of replications will be set to 1."
		rnumber=1
        fi
        if [ -z $block_size ]; then
                echo "File system block size is set to 67108864 bytes by default."
                block_size=67108864
        fi 
        if [ "$autotest" != "true" ]; then
                echo "Test will not be executed automatically."
        fi
        if [ "$autoclean" != "true" ]; then
                echo "**ATTENTION: please shutdown Hadoop manually."
                sleep 1
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

retrieve_nodes(){
        if [ -f $HOST_LIST ]; then
                echo "List of nodes are available at $HOME/.nodes-list.txt."
        else
                echo "**ERROR: Nodes list file does not exist, please add nodes in $HOME/.nodes-list.txt."
                exit 1
        fi
        echo "Available nodes:"
        cat $HOST_LIST

        if [ -z $master ]; then
                master=`head -n 1 $HOST_LIST`
        fi
        echo "The JobTracker is $master"
}

check_cluster(){
	echo "Checking master $master."
        rsh -n $master "jps" > ${TMP_CHECK}
        namenode=`cat ${TMP_CHECK} | grep "NameNode"`
	if [[ -z $namenode ]]; then
		echo "NameNode check passed."
	else
                echo "**ERROR: NameNode or SecondaryNameNode already deployed, please shut it down before new deployment."
                exit 1
        fi
	jobtracker=`cat ${TMP_CHECK} | grep "JobTracker"`
        if [[ -z $jobtracker ]]; then
                echo "JobTracker check passed."
        else
                echo "**ERROR: JobTracker already deployed, please shut it down before new deployment."
                exit 1
        fi

	echo "Checking slaves"
        while read NODE
        do
                rsh -n $NODE "jps" > ${TMP_CHECK}
                DataNode_STATUS=`cat ${TMP_CHECK} | grep "DataNode" | wc -l`
                if [ $DataNode_STATUS -gt 0 ]; then
                        echo "DataNode deployed on $NODE, please shut it down before new deployment."
                        exit 1
                fi
        done</$HADOOP_HDFS_HOME/conf/slaves
        echo "DataNode check passed"

	while read NODE
        do
                rsh -n $NODE "jps" > ${TMP_CHECK}
                TaskTracker_STATUS=`cat ${TMP_CHECK} | grep "TaskTracker" | wc -l`
                if [ $TaskTracker_STATUS -gt 0 ]; then
                        echo "TaskTracker deployed on $NODE, please shut it down before new deployment."
                        exit 1
                fi
        done</$HADOOP_HDFS_HOME/conf/slaves
        echo "TaskTracker check passed"
	echo "All check passed, enable deployment."	
}

clean_tmp(){
	echo "Clean up HDFS storage."
	hdfs_storage="$HOME/hdfs-storage"
        while read NODE
        do
                rsh -n $NODE "rm -rf ${hdfs_storage}"
        done<$HOST_LIST

	echo "Clean up logs."
	rm -rf $HADOOP_HDFS_HOME/logs/*
	echo "Logs cleaned."

	echo "Clean up temporary files on master $master."
	hadoop_tmp_repo=`ls /tmp | grep "hadoop-$USER" | wc -l`
	if [ $hadoop_tmp_repo -gt 0 ]; then
		rsh -n $master "rm -rf /tmp/hadoop-$USER*"
		rsh -n $master "rm -rf /tmp/hsperfdata_$USER*"
		rsh -n $master "rm -rf /tmp/Jetty*"
		echo "Temporary file cleaned."
	else
		echo "No temporary file to clean up."
	fi

	echo "Clean up temporary files on slaves."
        while read NODE
        do
                rsh -n $NODE "rm -rf /tmp/hadoop-$USER*"
		rsh -n $NODE "rm -rf /tmp/hsperfdata_$USER"
		rsh -n $NODE "rm -rf /tmp/Jetty*"
        done</$HADOOP_HDFS_HOME/conf/slaves
}

write_conf(){
	echo "Configure *hadoop-env.sh*"
	echo "export JAVA_HOME=$JAVA_HOME" > $HADOOP_HDFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_SLAVE_SLEEP=0.1" >> $HADOOP_HDFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_NAMENODE_OPTS=\"-Dcom.sun.management.jmxremote \$HADOOP_NAMENODE_OPTS\"" >> $HADOOP_HDFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_SECONDARYNAMENODE_OPTS=\"-Dcom.sun.management.jmxremote \$HADOOP_SECONDARYNAMENODE_OPTS\"" >> $HADOOP_HDFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_DATANODE_OPTS=\"-Dcom.sun.management.jmxremote \$HADOOP_DATANODE_OPTS\"" >> $HADOOP_HDFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_BALANCER_OPTS=\"-Dcom.sun.management.jmxremote \$HADOOP_BALANCER_OPTS\"" >> $HADOOP_HDFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_JOBTRACKER_OPTS=\"-Dcom.sun.management.jmxremote \$HADOOP_JOBTRACKER_OPTS\"" >> $HADOOP_HDFS_HOME/conf/hadoop-env.sh

	echo "Configure *core-site.xml*"
	echo "<?xml version=\"1.0\"?>" > $HADOOP_HDFS_HOME/conf/core-site.xml
	echo "<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>" >> $HADOOP_HDFS_HOME/conf/core-site.xml 
	echo "<configuration>" >> $HADOOP_HDFS_HOME/conf/core-site.xml
	echo "<property> <name>hadoop.tmp.dir</name> <value>$hdfs_storage</value> </property>" >> $HADOOP_HDFS_HOME/conf/core-site.xml
	echo "<property> <name>fs.default.name</name> <value>hdfs://$master:9010</value> </property>" >> $HADOOP_HDFS_HOME/conf/core-site.xml 
	echo "</configuration>" >> $HADOOP_HDFS_HOME/conf/core-site.xml

	echo "Configure *mapred-site.xml*"
	echo "<?xml version=\"1.0\"?>" > $HADOOP_HDFS_HOME/conf/mapred-site.xml
        echo "<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>" >> $HADOOP_HDFS_HOME/conf/mapred-site.xml
        echo "<configuration>" >> $HADOOP_HDFS_HOME/conf/mapred-site.xml
	echo "<property> <name>mapred.job.tracker</name> <value>$master:9011</value> </property>" >> $HADOOP_HDFS_HOME/conf/mapred-site.xml
	echo "</configuration>" >> $HADOOP_HDFS_HOME/conf/mapred-site.xml

        echo "Configure *hdfs-site.xml*"
        echo "<?xml version=\"1.0\"?>" > $HADOOP_HDFS_HOME/conf/hdfs-site.xml
        echo "<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>" >> $HADOOP_HDFS_HOME/conf/hdfs-site.xml
        echo "<configuration>" >> $HADOOP_HDFS_HOME/conf/hdfs-site.xml
	echo "<property> <name>dfs.block.size</name> <value>${block_size}</value> </property>" >> $HADOOP_HDFS_HOME/conf/hdfs-site.xml
        echo "<property> <name>dfs.replication</name> <value>$rnumber</value> </property>" >> $HADOOP_HDFS_HOME/conf/hdfs-site.xml
	echo "<property> <name>dfs.data.dir</name> <value>/tmp/hadoop-$USER-hdfs-data-repo</value> </property>" >> $HADOOP_HDFS_HOME/conf/hdfs-site.xml
        echo "</configuration>" >> $HADOOP_HDFS_HOME/conf/hdfs-site.xml

	echo "Configure *master*"
	echo "$master" > $HADOOP_HDFS_HOME/conf/masters

	echo "Configure *slaves*"
	if [ -z $snumber ]; then
		snumber=`cat $HOST_LIST | wc -l`
	else
		echo "Number of slaves is $snumber"
	fi
	tail -n $snumber $HOST_LIST > $HADOOP_HDFS_HOME/conf/slaves

        echo "Distribute configuration files."
        while read NODE
        do
                scp $HADOOP_HDFS_HOME/conf/hadoop-env.sh ${NODE}:$HADOOP_HDFS_HOME/conf/
                scp $HADOOP_HDFS_HOME/conf/core-site.xml ${NODE}:$HADOOP_HDFS_HOME/conf/
                scp $HADOOP_HDFS_HOME/conf/mapred-site.xml ${NODE}:$HADOOP_HDFS_HOME/conf/
		scp $HADOOP_HDFS_HOME/conf/hdfs-site.xml ${NODE}:$HADOOP_HDFS_HOME/conf/
                scp $HADOOP_HDFS_HOME/conf/masters ${NODE}:$HADOOP_HDFS_HOME/conf/
                scp $HADOOP_HDFS_HOME/conf/slaves ${NODE}:$HADOOP_HDFS_HOME/conf/
        done</${HOST_LIST}	
}

hadoop_deploy(){
	echo "Format namenode."
	rsh -n $master " $HADOOP_HDFS_HOME/bin/hadoop namenode -format"
	echo "Launch HDFS."	
	rsh -n $master "$HADOOP_HDFS_HOME/bin/start-dfs.sh"
	echo "Launch Trakcers"
	rsh -n $master "$HADOOP_HDFS_HOME/bin/start-mapred.sh"
	sleep 20
}

check_deployment(){
	echo "Check master $master."
	namenode=""
	rsh -n $master "jps" > ${TMP_CHECK}
	namenode=`cat ${TMP_CHECK} | grep "NameNode" | wc -l`
        if [ $namenode -lt 2 ]; then
                echo "**ERROR: NameNode, SecondaryNameNode are not properly launched."
		hadoop_clean
                exit 1
	else
		echo "NameNode successfully launched."
        fi
        jobtracker=`cat ${TMP_CHECK} | grep "JobTracker" | wc -l`
        if [ $jobtracker -lt 1 ]; then
                echo "**ERROR: JobTracker is not properly launched."
		hadoop_clean
                exit 1
	else
		echo "JobTracker successfully launched."
        fi

	echo "Check slaves."
        while read NODE
        do
                rsh -n $NODE "jps" > ${TMP_CHECK}
                DataNode_STATUS=`cat ${TMP_CHECK} | grep "DataNode" | wc -l`
                if [ $DataNode_STATUS -lt 1 ]; then
                        echo "**ERROR: DataNode on $NODE is not deployed."
                        hadoop_clean
                        exit 1
		else
			echo "DataNode $NODE successfully deployed."
                fi
                rsh -n $NODE "jps" > ${TMP_CHECK}
                TaskTracker_STATUS=`cat ${TMP_CHECK} | grep "TaskTracker" | wc -l`
                if [ $TaskTracker_STATUS -lt 1 ]; then
                        echo "TaskTracker on $NODE is not deployed."
                        hadoop_clean
                        exit 1
		else
			echo "TaskTracker $NODE successfully deployed."
                fi
        done</$HADOOP_HDFS_HOME/conf/slaves
        echo "All check passed, deployment verified." 
}

hadoop_test(){
	echo "Copy local file to HDFS."
	rsh -n $master "$HADOOP_HDFS_HOME/bin/hadoop dfs -mkdir /test_dir"
	rsh -n $master "$HADOOP_HDFS_HOME/bin/hadoop dfs -copyFromLocal $HADOOP_HDFS_HOME/CHANGES.txt /test_dir/test_file.txt"
	sleep 10
	echo "Run MapReduce wordcount example."
	rsh -n $master "$HADOOP_HDFS_HOME/bin/hadoop jar $HADOOP_HDFS_HOME/hadoop*examples*.jar wordcount /test_dir/test_file.txt /output"
	echo "Clean HDFS to run user's application."
	$HADOOP_HDFS_HOME/bin/hadoop dfs -rmr /test_dir
	$HADOOP_HDFS_HOME/bin/hadoop dfs -rmr /output
}

hadoop_clean(){
	echo "Clean trackers."
	rsh -n $master "$HADOOP_HDFS_HOME/bin/stop-mapred.sh"
	echo "Clean data nodes."
	rsh -n $master "$HADOOP_HDFS_HOME/bin/stop-dfs.sh"

	echo "Clean intermediate files."
#	if [ -f $HOST_LIST ]; then
#		rm $HOST_LIST
#	fi
        if [ -f ${TMP_CHECK} ]; then
                rm ${TMP_CHECK}
        fi
}

args=$#
master=""
snumber=""
rnumber=""
block_size=""
autotest=""
autoclean=""

while [ $args -gt 0 ]
do
        case $1 in

        "--master"|"-m")
                if [ -z $2 ]; then
                        echo "Master is not given, the first node in the node list will take the role.";
                fi;
                shift 2;
                args=$(( args-2 ));
        ;;

        "--s-number"|"-s")
                if [ $2 -gt 0 ]; then
                        snumber=$2
                        echo "Slave number is set to $snumber"
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--r-number"|"-r")
                if [ $2 -gt 0 ]; then
                        rnumber=$2
                        echo "Replication number is set to $rnumber"
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--block-size"|"-b")
                if [ $2 -gt 0 ]; then
                        block_size=$2
                        echo "File system block size is set to ${block_size}"
                else
                        block_size=67108864
                        echo "The block size is invalid, it will be set to 64MB."
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "--test"|"-t")
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
                        echo "**Attention: Hadoop should be shutdown manually.";
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "-h"|"-?"|"--help")
                printMessage
                exit 0;
        ;;
        *)
                echo "parameter $1 invalid : use -h to get help !";
                exit 1;
                ;;
        esac
done

echo " "
echo "***** Check input parameters *****"
param_check
echo " "

echo "***** Export enviroment variables *****"
expo_env
echo " "

echo "***** Retrieve information of reserved nodes *****"
retrieve_nodes
echo " "

echo "***** Check previous deployment of Hadoop in cluster *****"
check_cluster
echo " "

echo "***** Clean up temporary repositories for Hadoop deployment *****"
clean_tmp
echo " "

echo "***** Write configuration file *****"
write_conf
echo " "

echo "***** Preperation finished, start the deployment *****"
hadoop_deploy
echo " "

echo "***** Check the deployment *****"
check_deployment
echo " "

if [ "$autotest" == "true" ]; then
        echo "***** Run example test *****"
        hadoop_test
        echo " "
fi

if [ "$autoclean" == "true" ]; then
        echo "***** Clean up Hadoop Deployment *****"
        hadoop_clean
        echo " "
fi

exit 0






