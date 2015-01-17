#!/bin/bash

#$HADOOP_HOME/bin/hadoop AppendToFile $TEST_FILE $CHUNK_SIZE >> $CLIENT_OUTPUT
#argument: $1 retry number, $2 destination file name, $3 append data size, $4 ip_address of logging server

retry=$1
testfile=$2
input_data_size=$3
ip_address=$4		
HADOOP_HOME=$5

$HADOOP_HOME/bin/hadoop AppendToFile ${testfile} ${input_data_size} ${retry} ${ip_address} ${LOGGING_PORT}


