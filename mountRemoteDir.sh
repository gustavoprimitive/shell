#Montaje de directorio de host remoto en un punto de montaje local con CIFS. 
#Si el directorio no está montado, se realiza el montaje. En caso contrario, se desmonta.
#Gustavo Tejerina

#!/bin/bash

#Credenciales de acceso remoto
user=""
pass=""
domain=""
host=""

#Directorios local y remoto
mountdir="/home/gustavo/vpn"
remotedir="/"

#Si no existe el directorio que será los puntos de montaje, se crea
if [[ ! -d "$mountdir" ]]; then
	mkdir -p "$mountdir"
fi
 
#Si no están montados los directorios
if [[ `mount -l |grep "$mountdir" |grep -c cifs` -eq 0 ]]; then
	#Prueba de conectividad con host remoto
	ping -c 1 $host 2>&1 1>/dev/null
	if [[ $? -ne 0 ]]; then
		echo "ERROR. No hay conectividad con el host remoto"
		exit 1
	fi

	#Montaje
	sudo mount -t cifs -o rw,dir_mode=0777,file_mode=0666,username=$user,password=$pass,domain=$domain //$host"$remotedir" "$mountdir"

	#Permisos
	sudo chmod -R 777 "$mountdir"

#Si los directorios están montados, se desmontan
else
	sudo umount -f "$mountdir" 2>/dev/null
fi

exit 0
