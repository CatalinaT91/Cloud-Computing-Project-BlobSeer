#!/bin/bash

printMessage() {
        echo "Usage of input parameters:";
        echo "-m, --mnumber                     : Number of meta-data storage providers."
        echo "-p, --pnumber                     : Number of storage providers."
	echo "-s, --snumber  		  	  : Number of Hadoop slaves."
        echo "-a, --nmanager                    : Specify the Namespace Manager. 
                                                  (-a 5 means 5th node in available nodes list, default is the first node)"
        echo "-b, --block_size                  : Block size of the file system (power of 2)."
        echo "-t, --test                        : If automatic test is required, set this option to true."
        echo "-c, --cleanup                     : If automatic clean up is required, set this option to true."
        echo "-h, -?, --help                    : Display this help message.";
}


args=$#
mnumber=0
pnumber=0
snumber=0
block_size=0
host_list=""
vmanager=""
pmanager=""
dht=""
providers=""
autotest=""
autoclean=""
r_nmanager=""

while [ $args -gt 0 ]
do
        case $1 in
        "--m-number"|"-m")
                if [ $2 -gt 0 ]; then
                        mnumber=$2
                        echo "Meta-data storage provider number is set to $mnumber"
                fi
                shift 2;
                args=$(( args-2 ));
        ;;

        "--p-number"|"-p")
                if [ $2 -gt 0 ]; then
                        pnumber=$2
                        echo "Data storage provider number is set to $pnumber"
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "--s-number"|"-s")
                if [ $2 -gt 0 ]; then
                        snumber=$2
                        echo "Hadoop slave number is set to $snumber"
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

        "--nmanager"|"-a")
                if [ $2 -gt 0 ]; then
                        r_nmanager=$2
                        echo "Namespace Manager is the ${r_nmanager}th node."
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
                echo $2
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
                        echo "**Attention: BlobSeer should be cleaned up manually.";
                fi
                shift 2;
                args=$(( args-2 ))
        ;;

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

#echo " "
#echo "***** Check input parameters *****"
#param_check
#echo " "

echo "---------------------------------"
echo "----- Start deploy BlobSeer -----"
echo "---------------------------------"
echo " "
bs-single-clustest.sh -p $pnumber -m $mnumber 

echo " "
echo "-------------------------------"
echo "----- Start deploy Hadoop -----"
echo "-------------------------------"
echo " "

deploy-bsfs-hadoop.sh -o $HADOOP_BSFS_HOME -a $r_nmanager -s $snumber -b ${block_size}

if [ "$autoclean" == "true" ]; then
	echo "***** Clean up Hadoop & BlobSeer"
	./hb-clean.sh -e $ENVFILE
	echo " "
fi


exit 0
