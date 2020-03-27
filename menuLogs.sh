#!/bin/bash
#Menú para acceso rápido a logs en ejecución.
#Gustavo Tejerina

#Ruta absoluta de logs
LOG_PATH="/var/log"

#Se muestra el menú y se solicita una opción válida
PS3="Introduce una opcion: "
echo "Las posibles opciones son:"

select i in syslog kernel auth
do
    if [[ -n "${i:-}" ]];then
	seleccion=${i:-}
	break
    else
	echo "Intruduce un numero del 1 al 3"
    fi
done

echo "Se ha seleccionado ${REPLY} ($i)"

#Output de trazas del log seleccionado que se están generando
case $i in
    syslog)
	tail -f $LOG_PATH/syslog;;
    kernel)
        tail -f $LOG_PATH/kern.log;;
    auth)
        tail -f $LOG_PATH/auth.log;;
esac

exit 0
