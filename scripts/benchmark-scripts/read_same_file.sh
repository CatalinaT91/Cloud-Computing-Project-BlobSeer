#!/bin/bash

echo "Execute rsf"

# arguments: evaluation script home folder,  number of nodes should launch the test, 
# ip_address of logging server (front-end), hadoop source folder, file size

SCRIPT_HOME=$1
totalist=$HOME/.nodes-list.txt
nodeslist=$SCRIPT_HOME/node-list.txt
nodes=$2
chunk_size=$3
ip_address=$4
HADOOP_HOME=$5
test_file="MyBigFile"

tail -n $nodes $totalist > $nodeslist
while read NODE
do
        scp $nodeslist demouser@${NODE}:${nodeslist}
done<${nodeslist}

dest=`head -n 1 $nodeslist`

ssh $dest "source /usr/games/env; $HADOOP_HOME/bin/hadoop WriteBigFile $test_file 20 $chunk_size"

taktuk -s -f $nodeslist broadcast exec [ "source /usr/games/env; $SCRIPT_HOME/rsf.sh 20 $nodeslist $ip_address $HADOOP_HOME $chunk_size $test_file" ]

if [ $nodes -gt 20 ]; then 
	echo "Done, now sleeping for $($nodes*2) secs..."
        sleep $($nodes*2)
else
	echo "Done, now sleeping for 30 secs..."
        sleep 30
fi

