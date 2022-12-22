#!/bin/bash
VERSION="conn_qmicli - v0.1b12"

## ////////////////////////////////////////////////////////////////////////////////
## HELP FUNCTION

function help {
  echo " Program Name : conn_qmicli.sh"
  echo " Version : ${VERSION}"
  echo " Purpose : establish 4G connection"
  echo " Usage   : conn_qmicli.sh <config file>"
  echo "--------------------------------------------------------------------------"
  echo " Authors:"
  echo "        - Dimitris Anastasiou, dganastasiou@gmail.com"
  echo "        - Yiannis Karamitros, jkaram@noa.gr"
  echo "--------------------------------------------------------------------------"
  echo " History:"
  echo "   2021.09.21 : Initial beta version"
  echo "   2022.03.20 : Add config file, documentation, clen code"
  echo "   2022.04.29 : Ad mknod to enable ttyUSB* if disconected"
 }

## Set bash parameters
set -o pipefail

## TODO check if config file exist
source $1

LOG=.log/conn_$(date -u +%Y%m%d).log


## Check if necessary programms exista qmicli
if ! [ -x "$(command -v qmicli)" ]
then
     echo "$(date +%Y.%m.%d_%H:%M:%S) [ERROR]: libqmi-utils is not install " >> ${LOG}
     exit 1

fi

## CHeck udhcpc
if ! [ -x "$(command -v udhcpc)" ]
then
     echo "$(date +%Y.%m.%d_%H:%M:%S) [ERROR]: udhcpc is not install " >> ${LOG}
     exit 1
fi

## ////////////////////////////////////////////////////////////////////////////////
## GET CML Arguments
if [ "$#" == 0 ]
then
    echo "[ERROR]: No input file"
    help
fi

## TODO get arguments chec if config file exists
#while [ $# -gt 0 ]
#do
#    case "$1" in
#	conf_file
#done

#wait

## TODO down if wlan0 is up check if exist
sudo ifconfig wlan0 down >> ${LOG} 2>&1

## check connection to paliki
nc -z "${CHECKIP}" "${CHECKPORT}" >/dev/null 2>&1
checknet=$?

if [ ${checknet} -eq 0 ]
then
    echo "$(date +%Y.%m.%d_%H:%M:%S) [DEBUG]: Raspberry is online!" >> ${LOG}
    exit 0
else


    echo "$(date +%Y.%m.%d_%H:%M:%S) [WRNG]: Raspberry is OFFLINE. Try new connection" >>${LOG}

    ## set encounter to 0
    enc=0
    while [ ${enc} -lt 60 ]
    do

        if [ -c /dev/ttyUSB0 ] && [ -c /dev/ttyUSB1 ] && [ -c /dev/ttyUSB2 ] && [ -c /dev/ttyUSB3 ] && [ -c /dev/ttyUSB4 ]
    	then
            ## If ttyUSB exist setup the connection
    	    echo "$(date +%Y.%m.%d_%H:%M:%S) [DEBUG]: ttyUSB exist, start qmicli" >> ${LOG}
            #sleep 60
    	    sudo socat - /dev/ttyUSB2,crnl <<<'AT+CPIN='${CPIN}  >> ${LOG}

    	    qmicli -d /dev/cdc-wdm0 --dms-set-operating-mode='online' >> ${LOG}

    	    qmicli -d /dev/cdc-wdm0 --dms-get-operating-mode >> ${LOG}

    	    qmicli -d /dev/cdc-wdm0 --nas-get-signal-strength >> ${LOG}

    	    qmicli -d /dev/cdc-wdm0 --nas-get-home-network >> ${LOG}

	        ifconfig >> ${LOG}

	        ip link set wwan0 down >> ${LOG}

    	    echo 'Y' > /sys/class/net/wwan0/qmi/raw_ip

    	    ip link set wwan0 up >> ${LOG}

    	    ifconfig >> ${LOG}

    	    sudo qmicli --device=/dev/cdc-wdm0 \
        		    --device-open-net="net-raw-ip|net-no-qos-header"\
		            --wds-start-network="ip-type=4,apn=${APNNAME}, username=${USERNAME}, password=${USERPASSWD}" \
        		    --client-no-release-cid >> ${LOG}

            #sudo ifconfig wlan0 down >> ${LOG} 2>&1

	        ## set static ip
    	    sudo udhcpc -i wwan0 >> ${LOG}
        	sleep 10
	        ## set wwan0 as default
    	    sudo route add default dev wwan0 >> ${LOG}

    	    nc -z "${CHECKIP}" "${CHECKPORT}" >/dev/null 2>&1
    	    checknet=$?

    	    if [ ${checknet} -eq 0 ]
    	    then
	            echo "$(date +%Y.%m.%d_%H:%M:%S) [DEBUG]: Raspberry is online!" >> ${LOG}

                ## If rasberry is online exit the script with status 0
	            exit 0
    	    else
	            echo "$(date +%Y.%m.%d_%H:%M:%S) [WRNG]: Raspberry is OFFLINE. Try new connection" >>${LOG}
	            enc=0
    	    fi

        else
            ## If ttyUSB does not exist....
    	    ## check ttyUSB
	        echo "$(date +%Y.%m.%d_%H:%M:%S) [WRNG]: /dev/ttyUSB* does not exist ($enc)" >> ${LOG}

            ## Check lsusb if router esist
            echo "$(date +%Y.%m.%d_%H:%M:%S) [DEBUG]: Check lsusb output" >> ${LOG}
            lsusb >>${LOG}
##---------------------------
##NEW SOLUTION using modprobe
##-------------------------------------------------------------------------
## TODO Add debug mesaages
  ##---------------------
  ##SOL1 find the driver
            ## New solution using modprobe stop and restart sub usb system
            ## Cat driver name for ttyUSB
            # drv_name=$(sudo lsmod | grep usbserial | awk '{print $4}')

            ## Unload driver
            # sudo modprobe -r ${drv_name}
            # sudo modprobe -r usbserial

            ## Reload driver
            # sudo modprobe ${drv_name}
  ##--------------------------
  ##SOL2 check drive 'option'
  ##+ check lsmod option drive manage usb_wwan and usbserial
  ##+ if option stop then all other drives unloded
            ## Ubload drive
            sudo modprobe -r option

            ## Reload drive
            sudo modprobe option

##------------------------------------------------------------------------
## FINISHED new lines
##--------------------------
            ## Sleep 5sec add encounter and restart while
    	    sleep 5
    	    let enc++
        fi
    done

    ## If ttyUSB not exist enable using kmnod and then reboot raspberry
    ##+THis module not working until now! (221222)
    #    echo "$(date +%Y.%m.%d_%H:%M:%S) [DEBUG]: enable ttyUSB* runing mknod" >> ${LOG}
    #    mknod /dev/ttyUSB0 c 188 0


    ## Check if ttyUSB exist
    if [ -c /dev/ttyUSB0 ] && [ -c /dev/ttyUSB1 ] && [ -c /dev/ttyUSB2 ] && [ -c /dev/ttyUSB3 ] && [ -c /dev/ttyUSB4 ]
    then
    	echo "$(date +%Y.%m.%d_%H:%M:%S) [WRNG]: /dev/ttyUSB* exists " >> ${LOG}
        exit 0
    else
#	    mknod /dev/ttyUSB0 c 188 0
##---------------------------
##NEW SOLUTION using modprobe
##------------------------------------------------------------------------

        ## TODO Add new solution to stop all processing before restart the raspberry
        ## list all processing
        # fuser /dev/ttyUSB0

        ## if fuser return processing killthem by pid
        sudo fuser -k /dev/ttyUSB2

        ## if fuser return nothing then try lsof
        # sudo lsof /def/ttyUSB0

        ## kill all returns from lsof
        # sudo pkill <lsof retuns>


##-------------------------------------------------------------------------
## FINISHED new lines
##--------------------------

        ## send lsusb debug to log file
        echo "$(date +%Y.%m.%d_%H:%M:%S) [DEBUG]: Check lsusb output" >> ${LOG}
        lsusb >> ${LOG}

        ## REBOOT the raspberry
        echo "$(date +%Y.%m.%d_%H:%M:%S) [ERROR]: Ras will reboot. no connection" >> ${LOG}
        sudo reboot
    fi
#    echo "$(date +%Y.%m.%d_%H:%M:%S) [ERROR]: Ras will reboot. no connection" >> ${LOG}
#    sudo reboot

fi
