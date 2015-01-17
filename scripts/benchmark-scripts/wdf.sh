#!/bin/bash
# argument: $1 retry number, $2 list of nodes execute the operation, $3 input file size, $4 ip_address of logging server

echo "Execute wdf.sh"

retry=$1
file_size=$3
ip_address=$4
nodeslist=$2
HADOOP_HOME=$5

NODE=`hostname`
INDEX=`grep -x -n $NODE $nodeslist | cut -d ':' -f 1 `
$HADOOP_HOME/bin/hadoop WriteToFile /tests-$INDEX.dat ${file_size} ${retry} $ip_address $LOGGING_PORT

