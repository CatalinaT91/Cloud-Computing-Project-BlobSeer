#!/bin/bash

echo "Execute wdf"

# arguments: test script home folder,  number of nodes should launch the test, 
# ip_address of logging server, hadoop source folder

SCRIPT_HOME=$1
totalist=$HOME/.nodes-list.txt
nodeslist=$SCRIPT_HOME/node-list.txt
nodes=$2
data_size=$3
ip_address=$4
HADOOP_HOME=$5

tail -n $nodes $totalist > $nodeslist

#taktuk -s -f $nodeslist broadcast exec [ "tail -n $nodes $totalist > $nodeslist" ]

while read NODE
do
	scp $nodeslist demouser@${NODE}:${nodeslist}
done<${nodeslist}

taktuk -s -f $nodeslist broadcast exec [ "source /usr/games/env; export HADOOP_HOME=$HADOOP_HOME; echo ${HADOOP_HOME}; $SCRIPT_HOME/wdf.sh 20 $nodeslist ${data_size} $ip_address $HADOOP_HOME" ]
echo "Done, now sleeping for 30 secs..."
sleep 30
