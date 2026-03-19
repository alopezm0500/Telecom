#!/bin/bash
#==========================================================================
# ------------------------ Realiza reinicio DTDs y TAFEs ------------------------------
# Author:           Adrian
# Description:      Restart the PODs fpr DTD and TAFEs as prevention
# Version:          Test    08/2023
# Usage:            bash quincenal_pods.sh
#==========================================================================

### Variables initialization
HOME_DIR="/root"
LOG="/root/quincenal.log"
lista_tafes="/root/tafes.txt"
lista_dtds="/root/dtds.txt"

### Functions
### Main
echo -e "\n### Comienzo a buscar PODs DTD y TAFE `date '+%b %d %Y %H:%m:%S'` ###\n ${datelog} \n"
echo -e "\nUna vez identificados, procedere a borrar los pods para reiniciarles... \n"
echo -e "\n### Se inicia ejecucion `date '+%b %d %Y %H:%m:%S'` \n" >> ${LOG}
kubectl get pod -o wide | grep tafe- | awk -F" " '{print$1}' > ${lista_tafes}
for tafes in `cat ${lista_tafes}`
do
    echo $tafes
    echo $tafes >> ${LOG}
    kubectl delete pod ${tafes}
    sleep 45
done

kubectl get pod -o wide | grep dtd- | awk -F" " '{print$1}' > ${lista_dtds}
for dtds in `cat ${lista_dtds}`
do
    echo $dtds
    echo $dtds >> ${LOG}
    kubectl delete pod ${dtds}
    sleep 45
done

datelog=`date +%d-%m-%Y_%H:%M`
echo -e "\n\t???? ${datelog} Se ejecuto el script, verifique lo ejecutado en: ${LOG} \n"
echo -e "\t ${datelog} Se ejecuto el script\n" >> ${LOG}
