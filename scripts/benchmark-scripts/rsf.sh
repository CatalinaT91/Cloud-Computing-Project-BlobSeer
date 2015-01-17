#!/bin/bash

# argument: $1 retry number, $2 test node list, $3 ip_address of logging server
# hadoop source folder, chunk size

echo "Execute rsf.sh"

retry=$1
ip_address=$3
nodeslist=$2
HADOOP_HOME=$4
chunk_size=$5
test_file=$6

NODE=`hostname`
INDEX=`grep -x -n $NODE $nodeslist | cut -d ':' -f 1 `
echo "Read file $test_file"
$HADOOP_HOME/bin/hadoop ReadChunkFromFile $test_file $chunk_size $INDEX $retry $ip_address $LOGGING_PORT
