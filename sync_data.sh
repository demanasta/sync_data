#!/usr/bin/env bash
VERSION="symc_data - v0.1b37"
## Sync data to remote server
## Send ebery hour
LOG=.log_sync/sync_data_$(date -u +%Y-%m-%d).log

# Test if log directory exist
if test -f .log_sync
then
    echo "$(date +%Y.%m.%d-%H:%M:%S) [ERROR]: No configuration input"  >>/dev/null
else
    mkdir .log_sync
    echo "$(date +%Y.%m.%d-%H:%M:%S) [DEBUG]: Create .log_sync directory"  >>${LOG} 2>&1
fi


# /////////////////////////////////////////////////////////////////////
# HELP FUNCTION
function help {
  echo " Program Name : sync_data.sh"
  echo " Version : ${VERSION}"
  echo " Purpose : sync data to remote server"
  echo " Usage   : sync_data.sh  --config <config_file> [options] "
  echo " Switches: "
  echo "        --config <file>: input confoguration file"
#  echo "        --daily : create daily file 30s"
#  echo "        --highrate: create hourly highrate(1Hz) rinex"
  echo "   -v | --version : check versrion"
  echo "   -h | --help : help screen"
  echo "-----------------------------------------------------------------------"
  echo " Authors:"
  echo "         - Dimitris Anastasiou, dganastasiou@gmail.com"
  echo "         - Yannis Karamitros, jkaram@noa.gr"
  echo " Funded: National Observatory of Athens, PROION Project"
  echo "-----------------------------------------------------------------------"
  echo " History:"
  echo "   2022.03.10 : Initial beta version"
  exit 1
}




# /////////////////////////////////////////////////////////////////////
# GET CML ARGUMENTS
if [ "$#" == 0 ]
then
    echo "$(date +%Y.%m.%d-%H:%M:%S) [ERROR]: No configuration input"  >>${LOG} 2>&1
    help
    ##TODO help function
fi

while [ $# -gt 0 ]
do
    case "$1" in
	--config)
	    conf_file=${2}
	    #Check if configuration file exist
	    if [ ! -f ${conf_file} ]
	    then
		echo "$(date +%Y.%m.%d-%H:%M:%S) [ERROR]:Configuration file ${conf_file} does not exist"  >>${LOG} 2>&1	
	        exit 1	
	    else	
		echo "$(date +%Y.%m.%d-%H:%M:%S) [DEBUG]: Load configuration file"  >>${LOG} 2>&1
		source ${conf_file}
	    fi
	    shift 2
	    ;;
	-h | --help)
	    help
	    ;;
	-v | --version)
	    echo "verxion: ${VERSION}"
	    exit 1
	    shift
	    ;;
    esac
done



#source naot2paliki.config
# Check connection
nc -z ${REM_IPADDR} ${REM_PORT} > /dev/null 2>&1
checknet=$?

if  [ ${checknet} -ne 0 ]
then
    #call conn_qmicli using configuration file
    cd /home/pi/sync_data && nohup sudo ./conn_qmicli.sh ${CONNCONF}
else

#local_data=$1
REMSSH=${REM_USER}@${REM_IPADDR}
#PALUBXFOL=/home/proion/data/raw_ubx
#PALACCFOL=/home/proion/data/raw_acc

#RASUBXFOL=/home/pi/gnss/rtkbase/data
#RASACCFOL=/home/pi/Desktop/Send

#LOCAL=/home/PROION/data/raw_ubx
#REMOTE=pi@10.254.90.146:/home/pi/gnss/rtkbase/data
#REMFOL=/home/pi/gnss/rtkbase/data
#LOG=sync_data$(date).log

#if [ $(date -u +%H) -eq 0 ]
#then
#    ubx_file=$(date --date="-1 day -1 hour" -u +%Y-%m-%d_%H)-00-00_GNSS-1.ubx
#    LOG=sync_data_$(date --date="-1 day -1 hour" -u +%Y-%m-%d).log
#
#else
#ubx_file=$(date --date="-1 hour" -u +%Y-%m-%d_%H)-00-00_GNSS-1.ubx
#LOG=sync_data_$(date --date="-1 hour" -u +%Y-%m-%d).log
#fi

#if test -f ${REMOTE}/${ubx_file}
#then
hod_fname=$(date --date="-1hour" -u +%Y-%m-%d_%H-)
for ubx_file in `cd ${RASUBXFOL} && ls ${hod_fname}*_${SITE_NAME}.ubx`
do
#Sync ubx data
if [ -f "${RASUBXFOL}/${ubx_file}" ]
then
    /usr/bin/rsync --delete \
	       --no-links \
	       -azP \
	       -e "ssh" \
	       ${RASUBXFOL}/${ubx_file}  \
	       ${REMSSH}:${REMUBXFOL}/${ubx_file} \
	       --progress
	       1>>${LOG} 2>&1
    if [ $? -eq 0 ]
    then
	echo "$(date +%Y.%m.%d-%H:%M:%S) [DEBUG]: file ${ubx_file} transferred " >>${LOG} 2>&1
    else
	echo "$(date +%Y.%m.%d-%H:%M:%S) [ERROR]: file ${ubx_file} not transferred " >>${LOG} 2>&1
    fi
else
    echo "$(date +%Y.%m.%d-%H:%M:%S) [ERROR]: file ${ubx_file} does not exist" >> ${LOG} 2>&1
#    exit 1
fi
echo "$(date +%Y.%m.%d-%H:%M:%S) [DEBUG]: sync status exit" $? >>${LOG} 2>&1
done

#Sync accel data
if [ "$(ls -A $RASACCFOL)" ]
then
#    echo "$(date +%Y.%m.%d-%H:%M:%S) [DEBUG]: Transfer accel data" >>${LOG} 2>&1
    /usr/bin/rsync --no-links \
	       -azP \
	       -e "ssh" \
	       ${RASACCFOL}/*  \
	       ${REMSSH}:${REMACCFOL}/ \
	       --progress
	       1>>${LOG} 2>&1
    if [ $? -eq 0 ]
    then
    	echo "$(date +%Y.%m.%d-%H:%M:%S) [DEBUG]: Accelerometric data transferred " >>${LOG} 2>&1
    else
    	echo "$(date +%Y.%m.%d-%H:%M:%S) [ERROR]: No data tranfered not transferred " >>${LOG} 2>&1
    fi
else
    echo "$(date +%Y.%m.%d-%H:%M:%S) [DEBUG]: No new accel data" >>${LOG} 2>&1
fi





fi
