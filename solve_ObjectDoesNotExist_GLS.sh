#!/bin/bash
#==========================================================================
#----------------------- Object does not exist ----------------------------
# Author:           Adrian
# Description:      Script to save a list for the error and run the workaround
# Version:          0.1
# Last modified:    08/2023
# Usage:            bash not_exist.sh
#==========================================================================

### Variables initialization
HOM_DIR="/home/axadmin/workaround_IT/not_exist"
TMP_DIR="/tmp/not_exist"
LOGS_DIR="/alcatel/omc1/OMCP/Server/05_09_05_00_GA4/lumos/log"
HISTORY=${TMP_DIR}/history
TEMPO=${TMP_DIR}/temp
RESULTS=${TMP_DIR}/results
ERRORHIST=${TMP_DIR}/error_history
LOG_RUN=${HOM_DIR}/run_log.txt
RET_DIR="/home/axadmin/Consultar_Masivo"
dateleg=`date +%d-%m-%Y_%H:%M`
datee=`date +%d-%m-%Y_%H_%M`
condi_start=`cat ${HOM_DIR}/flag_run.txt`

### Functions
### Main
if [ $condi_start == "NoRun" ]
then
        echo "Run" > ${HOM_DIR}/flag_run.txt
        echo "${dateleg}: Script started successfully" >> ${LOG_RUN}
        rm -f ${TEMPO}/*
        cat ${LOGS_DIR}/plxwebapi.log.soap | grep 'FailureCode="4"' | awk -F+ '{print $2}'| awk '{print $1}' > ${HOM_DIR}/users_list_to_fix.txt
        for user in `cat ${HOM_DIR}/users_list_to_fix.txt`
        do
                msisdn=`echo $user`
                condition=`ls -lrth ${HISTORY} | grep $msisdn | wc -l`
                if [ $condition == "0" ]
                then
                        cp ${RET_DIR}/retrieve_template.txt ${TEMPO}/user_${msisdn}.txt
                        sed -i 's/NUMBER_TO_CHANGE/'${msisdn}'/g' ${TEMPO}/user_${msisdn}.txt
                        echo "${msisdn}" >> ${TMP_DIR}/Log${dateleg}.txt

                else
                        echo "${msisdn}: Already attended" >> ${HOM_DIR}/Already_attended_Log.txt
                fi
        done
        sleep 1
        files=`ls -lrth ${TEMPO} | grep txt | awk '{print $9}'`
        for user2 in $files
        do
                msisdn=`echo $user2 | awk -F_ '{print $2}' | awk -F. '{print $1}'`
                curl -k -H "SOAPAction: \"\"" --header 'Content-Type: text/xml; charset=utf-8' 'https://10.150.182.98:8443/plxwebapi/api'  --data @${TEMPO}/${user2} > ${RESULTS}/result_${msisdn}.txt
                verify=`cat ${RESULTS}/result_${msisdn}.txt | grep -i success | wc -l`
                if [ $verify == "1" ]
                then
                        cp ${RESULTS}/result_${msisdn}.txt ${HISTORY}/attended_${msisdn}.txt
                else
                        cp ${RESULTS}/result_${msisdn}.txt ${ERRORHIST}/attended_${msisdn}.txt
                fi
        done
        echo "NoRun" > ${HOM_DIR}/flag_run.txt
        dateleg2=`date +%d-%m-%Y_%H:%M`
        echo "${dateleg2}: Script finished successfully" >> ${LOG_RUN}
else
        echo "${dateleg}: Script not started, another process running" >> ${LOG_RUN}
fi
