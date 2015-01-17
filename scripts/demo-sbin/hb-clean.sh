#!/bin/bash

printMessage() {
        echo "Usage of input parameters:";
        echo "-h, -?, --help                    : Display this help message.";
}

args=$#

while [ $args -gt 0 ]
do
        case $1 in
        "-h"|"-?"|"--help")
                printMessage
                exit 0;
        ;;
        *)
                echo "parametre $1 is invalid : please use option -h for help !";
                exit 1;
                ;;
        esac

done

bs-cleanup.sh
echo " "

echo "***** Clean up Hadoop *****"
clean-bsfs-hadoop.sh
echo " "
