#!/bin/bash
#==========================================================================
# ------------------------ ClearCache ------------------------------
# Author:           Adrian
# Description:      Clear Cache NTAS 
# Version:          Test    03/2026
# Usage:            bash ClearCache.sh
#==========================================================================

### Variables initialization
HOME_DIR="/root/"
LOG="/root/ClearCache.log"
lista_tafes="/root/cliIP.txt"

### Functions
### Main
echo -e "\n### Busco la direccion de pod CLI `date '+%b %d %Y %H:%M'` ### \n"
echo -e "\nUna vez identificada, procedere a hacer Clear Cache... \n"
echo -e "\n### Se inicia ejecucion `date '+%b %d %Y %H:%M'` \n" >> ${LOG}
kubectl get pod -o wide | grep cli- | awk -F" " '{print$6}' > ${lista_tafes}
for tafes in `cat ${lista_tafes}`
do
    echo $tafes
    sshpass -p 'xxxxxx' ssh tsuser@$tafes "sdb subscriber show counter" >> ${LOG}
    sshpass -p 'xxxxxx' ssh tsuser@$tafes "sdb subscriber clear_cache" >> ${LOG}
    sleep 45
    sshpass -p 'xxxxxx' ssh tsuser@$tafes "sdb subscriber show counter" >> ${LOG}
done

datelog=`date +%d-%m-%Y_%H:%M`
echo -e "\n\t???? ${datelog} Se ejecuto el script, verifique lo ejecutado en: ${LOG} \n"
echo -e "\t ${datelog} Se ejecuto el script\n" >> ${LOG}
