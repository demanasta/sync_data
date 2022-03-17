#!/bin/bash
#Set bash parameters
set -o pipefail

# TODO check if config file exist
source $1

LOG=.log/conn_$(date -u +%Y%m%d).log

#wait

# down if wlan0 is up
sudo ifconfig wlan0 down >> ${LOG} 2>&1

#check connection to paliki
nc -z ${CHECKIP} ${CHECKPORT} >/dev/null 2>&1
checknet=$?

if [ ${checknet} -eq 0 ]
then
    echo "$(date +%Y.%m.%d_%H:%M:%S) [DEBUG]: Raspberry is online!" >> ${LOG}
    exit 0
else

    echo "$(date +%Y.%m.%d_%H:%M:%S) [WRNG]: Raspberry is OFFLINE. Try new connection" >>${LOG}

    # set encounter to 0
    enc=0
    while [ ${enc} -lt 60 ]
    do

        if [ -c /dev/ttyUSB0 ] && [ -c /dev/ttyUSB1 ] && [ -c /dev/ttyUSB2 ] && [ -c /dev/ttyUSB3 ] && [ -c /dev/ttyUSB4 ]
	then

	    echo "$(date +%Y.%m.%d_%H:%M:%S) [DEBUG]: ttyUSB exist, start qmicli" >> ${LOG}skdfm
    #sleep 60
    	    sudo socat - /dev/ttyUSB2 <<<'AT+CPIN=${CPIN}'  >> ${LOG}

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

	    # set static ip
	    sudo udhcpc -i wwan0 >> ${LOG}
	sleep 10
	    # set wwan0 as default
	    sudo route add default dev wwan0 >> ${LOG}

	    nc -z ${SHECKIP} ${CHECKPORT} >/dev/null 2>&1
	    checknet=$?

	    if [ ${checknet} -eq 0 ]
	    then
	        echo "$(date +%Y.%m.%d_%H:%M:%S) [DEBUG]: Raspberry is online!" >> ${LOG}
	        exit 0
	    else
	        echo "$(date +%Y.%m.%d_%H:%M:%S) [WRNG]: Raspberry is OFFLINE. Try new connection" >>${LOG}
	        enc=0
	    fi

        else
	    #check ttyUSB
	    echo "$(date +%Y.%m.%d_%H:%M:%S) [WRNG]: /dev/ttyUSB* does not exist ($enc)" >> ${LOG}
	    sleep 5
	    let enc++
        fi

    done
    echo "$(date +%Y.%m.%d_%H:%M:%S) [ERROR]: Ras will reboot. no connection" >> ${LOG}
    sudo reboot

fi
