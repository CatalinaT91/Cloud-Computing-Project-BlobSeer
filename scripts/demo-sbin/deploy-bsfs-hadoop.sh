#/bin/bash

HOST_LIST=$HOME/.nodes-list.txt
NMANAGER=$HOME/.nmanager.txt
TMP_CHECK=$HOME/.tmp-check.txt
TMP_CONFIG=/tmp/blobseer.cfg

printMessage(){
        echo "Usage of input parameters:";
	echo "-o, --hadoop-home                 : Location of Hadoop home folder (*obligatory*)."
	echo "-a, --nmanager			: Specify the Namespace Manager. 
					          (-a 5 means 5th node in available nodes list, default is the first node)"
        echo "-s, --snumber                     : Number of slaves in the MapReduce system."
	echo "-b, --block_size                  : Block size of the file system (power of 2)."
        echo "-t, --test                        : If automatic test is required, set this option to true."
        echo "-c, --cleanup                     : If automatic clean up is required, set this option to true."
        echo "-h, -?, --help                    : Display this help message.";
}

param_check(){
        if [ -z $HADOOP_BSFS_HOME ]; then
                echo "** ERROR: Please set the path to hadoop home folder in environment variable ($HADOOP_BSFS_HOME)."
                exit 0;
        fi
        if [ -z $snumber ]; then
                echo "Number of slaves will be set to the number of reserved nodes"
        fi
	if [ -z $r_nmanager ]; then
                echo "The Namespace Manager will be set to the first node."
		r_nmanager=1
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

retrieve_nodes(){
        if [ -f $HOST_LIST ]; then
                echo "List of nodes are available at $HOME/.nodes_list.txt."
        else
                echo "**ERROR: Nodes list file does not exist, please add nodes in $HOME/.nodes-list.txt."
                exit 1
        fi
        echo "Available nodes:"
        cat $HOST_LIST

	n_avail_nodes=`cat $HOST_LIST | wc -l`
	echo "Number of available nodes is ${n_avail_nodes}."
	if [[ $r_nmanager -gt $n_avail_nodes ]]; then
		echo "**ERROR: the specified Namespace Manager does not exist."
		bs-cleanup.sh	
		exit 1
	fi

	nmanager=`head -n $r_nmanager $HOST_LIST | tail -n 1`
	echo "Namespace Manager is $nmanager."
	echo "$nmanager" > $NMANAGER
	while read NODE
        do
		scp $NMANAGER demouser@${NODE}:
        done<${HOST_LIST}

	jobtracker=`head -n 1 $HOST_LIST`
	echo "JobTracker is $jobtracker."
}

check_cluster(){
	echo "Checking Namespace Manager ($nmanager)."
	rsh -n $nmanager "jps" > $TMP_CHECK
	NM_STATUS=`cat $TMP_CHECK | grep "NManager"`
        if [ -z $NM_STATUS ]; then
                echo "Namespace Manager check passed."
        else
                echo "**ERROR: NManager deployed on $nmanager, please shut it down before new deployment."
                exit 1
        fi
	echo "Checking JobTracker."
	rsh -n $jobtracker "jps" > $TMP_CHECK
	JT_STATUS=`cat $TMP_CHECK | grep "JobTracker"`
	if [ -z $JT_STATUS ]; then
		echo "JobTracker check passed."
        else
                echo "**ERROR: JobTracker deployed on $master, please shut it down before new deployment."
                exit 1
        fi
	echo "Checking Slaves."
	while read NODE
        do
                rsh -n $NODE "jps" > $TMP_CHECK
                TaskTracker_STATUS=`cat $TMP_CHECK | grep "TaskTracker" | wc -l`
                if [ $TaskTracker_STATUS -gt 0 ]; then
                        echo "TaskTracker deployed on $NODE, please shut it down before new deployment."
                        bs-cleanup.sh
                        exit 1
                fi
        done</$HADOOP_BSFS_HOME/conf/slaves
        echo "TaskTracker check passed"
	echo "All check passed, enable deployment."	
}

clean_tmp(){
	echo "Clean up logs."
	rm -rf $HADOOP_BSFS_HOME/logs/*
	echo "Logs cleaned."

	echo "Clean up temporary files on master $master."
	hadoop_tmp_repo=`ls /tmp | grep "hadoop-$USER" | wc -l`
	if [ $hadoop_tmp_repo -gt 0 ]; then
		rsh -n $jobtracker "rm -rf /tmp/hadoop-$USER*"
		rsh -n $jobtracker "rm -rf /tmp/hsperfdata_$USER*"
		echo "Temporary file cleaned."
	else
		echo "No temporary file to clean up."
	fi

	echo "Clean up temporary files on slaves."
        while read NODE
        do
                rsh -n $NODE "rm -rf /tmp/hadoop-$USER*"
		rsh -n $NODE "rm -rf /tmp/hsperfdata_$USER"
        done</$HADOOP_BSFS_HOME/conf/slaves
}

write_conf(){
	echo "Configure *hadoop-env.sh*"
	echo "export JAVA_HOME=$JAVA_HOME" > $HADOOP_BSFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_SLAVE_SLEEP=0.1" >> $HADOOP_BSFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_NAMENODE_OPTS=\"-Dcom.sun.management.jmxremote $HADOOP_NAMENODE_OPTS\"" >> $HADOOP_BSFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_SECONDARYNAMENODE_OPTS=\"-Dcom.sun.management.jmxremote $HADOOP_SECONDARYNAMENODE_OPTS\"" >> $HADOOP_BSFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_DATANODE_OPTS=\"-Dcom.sun.management.jmxremote $HADOOP_DATANODE_OPTS\"" >> $HADOOP_BSFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_BALANCER_OPTS=\"-Dcom.sun.management.jmxremote $HADOOP_BALANCER_OPTS\"" >> $HADOOP_BSFS_HOME/conf/hadoop-env.sh
	echo "export HADOOP_JOBTRACKER_OPTS=\"-Dcom.sun.management.jmxremote $HADOOP_JOBTRACKER_OPTS\"" >> $HADOOP_BSFS_HOME/conf/hadoop-env.sh

	echo "Configure *core-site.xml*"

	cp $HADOOP_BSFS_HOME/bsfs-conf/core-site.xml $HADOOP_BSFS_HOME/conf/core-site.xml
	sed "20 c\ \t\t<value>$TMP_CONFIG</value>" $HADOOP_BSFS_HOME/conf/core-site.xml > temp-core.xml
	mv temp-core.xml $HADOOP_BSFS_HOME/conf/core-site.xml
	sed "26 c\ \t\t<value>bsfs://$nmanager:9000</value>" $HADOOP_BSFS_HOME/conf/core-site.xml > temp-core.xml
	mv temp-core.xml $HADOOP_BSFS_HOME/conf/core-site.xml
        sed "37 c\ \t\t<value>${block_size}</value>" $HADOOP_BSFS_HOME/conf/core-site.xml > temp-core.xml
        mv temp-core.xml $HADOOP_BSFS_HOME/conf/core-site.xml

	echo "Configure *mapred-site.xml*"
	echo "<?xml version=\"1.0\"?>" > $HADOOP_BSFS_HOME/conf/mapred-site.xml
        echo "<?xml-stylesheet type=\"text/xsl\" href=\"configuration.xsl\"?>" >> $HADOOP_BSFS_HOME/conf/mapred-site.xml
        echo "<configuration>" >> $HADOOP_BSFS_HOME/conf/mapred-site.xml
	echo "<property> <name>mapred.job.tracker</name> <value>$jobtracker:9011</value> </property>" >> $HADOOP_BSFS_HOME/conf/mapred-site.xml
	echo "</configuration>" >> $HADOOP_BSFS_HOME/conf/mapred-site.xml

	echo "Configure *master*"
	echo "$jobtracker" > $HADOOP_BSFS_HOME/conf/masters

	echo "Configure *slaves*"
	if [ $snumber -lt 1 ]; then
		snumber=`cat $HOST_LIST | wc -l`
	else
		echo "Number of slaves is $snumber"
	fi
	tail -n $snumber $HOST_LIST > $HADOOP_BSFS_HOME/conf/slaves

	echo "Distribute configuration files."
	while read NODE
        do
		scp $HADOOP_BSFS_HOME/conf/hadoop-env.sh ${NODE}:$HADOOP_BSFS_HOME/conf/
		scp $HADOOP_BSFS_HOME/conf/core-site.xml ${NODE}:$HADOOP_BSFS_HOME/conf/
		scp $HADOOP_BSFS_HOME/conf/mapred-site.xml ${NODE}:$HADOOP_BSFS_HOME/conf/
		scp $HADOOP_BSFS_HOME/conf/masters ${NODE}:$HADOOP_BSFS_HOME/conf/
		scp $HADOOP_BSFS_HOME/conf/slaves ${NODE}:$HADOOP_BSFS_HOME/conf/
        done</${HOST_LIST}
}

hadoop_deploy(){
	echo "Launch Namespace Manager $nmanager"
	echo "Copy BlobSeer configuration file to Namespace Manager."
	scp $TMP_CONFIG $nmanager:$TMP_CONFIG
	rsh -n $nmanager "cd $BSFS_SERVER_HOME; java -Djava.library.path=$PATH:$LD_LIBRARY_PATH -cp build/:../build/classes/:lib/ NManager 9000 $TMP_CONFIG" &
	user_name=$USER
	echo "Retrieved user name: $user_name"
	rsh -n $nmanager "$HADOOP_BSFS_HOME/bin/hadoop fs -mkdir /tmp/hadoop-$user_name/mapred/system; $HADOOP_BSFS_HOME/bin/hadoop fs -chmod 700 /tmp/hadoop-$user_name/mapred/system "
	echo "Launch Trakcers"
	rsh -n $jobtracker "$HADOOP_BSFS_HOME/bin/start-mapred.sh"
	sleep 20
}

check_deployment(){

        rsh -n $nmanager "jps" > $TMP_CHECK
        NM_STATUS=`cat $TMP_CHECK | grep "NManager" | wc -l`
        if [[ $NM_STATUS -lt 1 ]]; then
                echo "*ERROR: NManager deployed on $nmanager is not properly launched."
		hadoop_clean
		exit 1
        else
                echo "Namespace Manager check passed."
        fi

	echo "Check JobTracker."
	rsh -n $jobtracker "jps" > $TMP_CHECK
	jobt_status=`cat $TMP_CHECK | grep "JobTracker" | wc -l`
        if [[ $jobt_status -lt 1 ]]; then
                echo "**ERROR: JobTracker is not properly launched."
		hadoop_clean
                exit 1
	else
		echo "JobTracker successfully launched."
        fi

	echo "Check slaves."
        while read NODE
        do
                rsh -n $NODE "jps" > $TMP_CHECK
                TaskTracker_STATUS=`cat $TMP_CHECK | grep "TaskTracker" | wc -l`
                if [ $TaskTracker_STATUS -lt 1 ]; then
                        echo "TaskTracker on $NODE is not deployed."
                        hadoop_clean
                        exit 1
		else
			echo "TaskTrackers successfully deployed."
                fi
        done</$HADOOP_BSFS_HOME/conf/slaves
        echo "All check passed, deployment verified." 
}

hadoop_test(){
	echo "Copy local file to BSFS."
	$HADOOP_BSFS_HOME/bin/hadoop fs -mkdir /test_dir
	$HADOOP_BSFS_HOME/bin/hadoop fs -copyFromLocal $HADOOP_BSFS_HOME/CHANGES.txt /test_dir/test_file.txt
	sleep 10
	echo "Run MapReduce wordcount example."
	rsh -n $jobtracker "$HADOOP_BSFS_HOME/bin/hadoop jar $HADOOP_BSFS_HOME/hadoop*examples*.jar wordcount /test_dir/test_file.txt /output"
}

hadoop_clean(){
	echo "Stop Namespace Manager $nmanager"
	rsh -n $nmanager "pkill java"
	rm $NMANAGER

	echo "Stop Trackers."
	echo "JobTracker is $jobtracker"
        rsh -n $jobtracker "$HADOOP_BSFS_HOME/bin/stop-mapred.sh"

	echo "Clean intermediate files."
#	if [ -f $HOST_LIST ]; then
#		rm $HOST_LIST
#	fi
        if [ -f $TMP_CHECK ]; then
                rm $TMP_CHECK
        fi
}

# Entry of the program

args=$#
HADOOP_BSFS_HOME=""
snumber=0
rnumber=0
block_size=0
autotest=""
autoclean=""
r_nmanager=""

while [ $args -gt 0 ]
do
        case $1 in
        "--hadoop-home"|"-o")
                if [ -d "$2" ]; then
                        echo "Hadoop home folder found."
                        HADOOP_BSFS_HOME=$2;
                else
                        echo "** ERROR: Hadoop home folder not found. Please check the path.";
                        exit 1;
                fi
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

        "--nmanager"|"-a")
                if [ $2 -gt 0 ]; then
                        r_nmanager=$2
                        echo "Namespace Manager is the ${r_nmanager}th node."
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






