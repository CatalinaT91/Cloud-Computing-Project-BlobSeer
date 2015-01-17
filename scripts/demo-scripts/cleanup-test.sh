#!/bin/bash

NODES_LIST=$HOME/.nodes-list.txt
CONFIG=$HOME/.tmp-config.txt
TMP_CHECK=$HOME/.tmp-check.txt
TMP_FS=${HOME}/.tmp-fs.txt

echo "----------------------------------------"
echo "----- Clean up previous deployment -----"
echo "----------------------------------------"
echo " "

if [ -f ${NODES_LIST} ]; then
	master=`head -n 1 ${NODES_LIST}`
	echo "The master node of the Demo is ${master}."
else
	echo "The list of nodes is not available, cannot clean up previous deployment."
fi 

echo " "

if [ -f ${TMP_FS} ]; then
	fs=`cat ${TMP_FS}`
	echo "Previously deployed file system is ${fs}."
	echo " "
	case ${fs} in
        "HDFS")
        	ssh demouser@${master} "source /usr/games/env; clean-hdfs-hadoop.sh"
	;;
        "BSFS")
        	ssh demouser@${master} "source /usr/games/env; hb-clean.sh"
	;;
        *)
                echo "No matching file system. Try to clean up both BSFS and HDFS."
		ssh demouser@${master} "source /usr/games/env; clean-hdfs-hadoop.sh"
		ssh demouser@${master} "source /usr/games/env; hb-clean.sh"
        esac 
else
	echo "Previously deployed file system is unknown. Try to clean up both BSFS and HDFS."
	echo " "
        ssh demouser@${master} "source /usr/games/env; clean-hdfs-hadoop.sh"
        ssh demouser@${master} "source /usr/games/env; hb-clean.sh"
fi

echo "Close Log Server."
ssh demouser@${master} "ps aux | grep LogServer" > ${TMP_CHECK}
numproc=`cat ${TMP_CHECK} | wc -l`
if [ ${numproc} -gt 2 ]; then
        numproc=$((${numproc} - 2))
        proc=`head -n ${numproc} ${TMP_CHECK} | sed 's/\s\+/ /g' | cut -d " " -f 2`
        for (( i=1; i<=${numproc}; i++ )) do
                c_proc=`echo ${proc} | cut -d " " -f ${i}`
                ssh demouser@${master} "kill -9 ${c_proc}"
        done
fi


echo " "

exit 0
